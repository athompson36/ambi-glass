import Foundation
import AVFoundation
import Combine
import Accelerate
#if os(macOS)
import CoreAudio
#endif

enum RecordingFormat: String, CaseIterable {
    case mono = "Mono"
    case stereo = "Stereo"
    case ambiA = "Ambi-A (4ch)"

    var channelCount: Int {
        switch self {
        case .mono: return 1
        case .stereo: return 2
        case .ambiA: return 4
        }
    }

    var displayName: String {
        return self.rawValue
    }
}

// Thread-safe counter for debugging tap callbacks
final class AtomicCounter {
    private var counter: Int32 = 0

    func increment() -> Int {
        return Int(OSAtomicIncrement32(&counter))
    }

    func get() -> Int {
        return Int(counter)
    }
}

final class RecorderEngine: ObservableObject {
    // Platform-specific recorder implementation
    // NOTE: Temporarily using AVAudioEngine on all platforms
    // CoreAudioRecorder has issues with multi-stream aggregate devices (see COREAUDIO_28CH_ISSUE_SUMMARY.md)
    // TODO: Implement device type detection and use CoreAudio for simple devices only
    private let recorder: AudioRecorderProtocol = AVAudioEngineRecorder()
    
    // Engine-owned meter publisher (merges engine-computed meters with recorder meters for monitoring)
    private let engineMeterSubject = PassthroughSubject<[CGFloat], Never>()
    var meterPublisher: AnyPublisher<[CGFloat], Never> {
        recorder.meterPublisher
            .merge(with: engineMeterSubject.eraseToAnyPublisher())
            .handleEvents(receiveOutput: { peaks in
                if self.meterDecimateCounter <= 5 {
                    print("MeterPublisher output: \(peaks.map { String(format: "%.3f", $0) })")
                }
            })
            .eraseToAnyPublisher()
    }
    
    // Peak hold values (for brief hold display)
    @Published var peakHoldValues: [CGFloat] = [0, 0, 0, 0]
    private var peakHoldTimers: [Timer?] = [nil, nil, nil, nil]
    private let peakHoldDuration: TimeInterval = 2.5 // 2.5 second hold
    private let dsp = AmbisonicsDSP()

    // Configuration - forwarded to underlying recorder
    @Published var selectedDeviceID: String = "__no_devices__" {
        didSet { recorder.selectedDeviceID = selectedDeviceID }
    }
    @Published var selectedInputChannels: [Int] = [] {
        didSet { recorder.selectedInputChannels = selectedInputChannels }
    }
    @Published var safetyRecord: Bool = true
    @Published var currentSampleRate: Double = 48000.0 {
        didSet { /* Read-only from recorder */ }
    }
    @Published var requestedSampleRate: Double = 48000.0 {
        didSet { recorder.requestedSampleRate = requestedSampleRate }
    }
    @Published var hasMicrophonePermission: Bool = false {
        didSet { /* Read-only from recorder */ }
    }
    @Published var recordingFormat: RecordingFormat = .ambiA {
        didSet { recorder.recordingFormat = recordingFormat }
    }
    @Published var waveformData: [[Float]] = [[], [], [], []] // Live waveform data per channel
    private let waveformMaxSamples = 500 // Number of samples to display in waveform
    private var waveformUpdateCounter: Int = 0 // Counter for throttling waveform updates

    private var aWriter: AVAudioFile?
    private var bWriter: AVAudioFile?
    @Published var isMonitoring = false {
        didSet { /* Read-only from recorder */ }
    }
    private var isRecordingActive = false
    @Published var recordingStartTime: Date? // Track when recording started
    @Published var recordingElapsedTime: TimeInterval = 0 // Elapsed time in seconds
    private var recordingTimer: Timer? // Timer to update elapsed time
    private var monitoringTask: Task<Void, Never>?
    private let recordingQueue = DispatchQueue(label: "com.ambi-studio.recording", qos: .userInitiated) // Background queue for file I/O
    private var meterDecimateCounter: Int = 0
    private let meterDecimateN: Int = 2 // Process every 2nd buffer for responsive meters (reduced from 8)
    private var lastMonitorSignature: String?
    
    // Subscribe to meter updates for peak hold
    private var meterSubscription: AnyCancellable?
    
    init() {
        // Forward initial values
        recorder.selectedDeviceID = selectedDeviceID
        recorder.selectedInputChannels = selectedInputChannels
        recorder.requestedSampleRate = requestedSampleRate
        recorder.recordingFormat = recordingFormat
        
        // Subscribe to meter updates for peak hold
        meterSubscription = meterPublisher.sink { [weak self] peaks in
            guard let self else { return }
            DispatchQueue.main.async {
                for (index, peak) in peaks.enumerated() {
                    if peak > self.peakHoldValues[index] {
                        self.peakHoldValues[index] = peak
                        self.peakHoldTimers[index]?.invalidate()
                        self.peakHoldTimers[index] = Timer.scheduledTimer(withTimeInterval: self.peakHoldDuration, repeats: false) { [weak self] _ in
                            guard let self else { return }
                            self.peakHoldValues[index] = 0
                            self.peakHoldTimers[index] = nil
                        }
                    }
                }
            }
        }
        
        // Set up buffer callback for recording
        recorder.onBufferReceived = { [weak self] buffer in
            self?.processRecordingBuffer(buffer)
        }
        
        // Sync state from recorder
        syncStateFromRecorder()
    }
    
    private func syncStateFromRecorder() {
        currentSampleRate = recorder.currentSampleRate
        hasMicrophonePermission = recorder.hasMicrophonePermission
        isMonitoring = recorder.isMonitoring
    }

    // Process recording buffer - handles metering, file writing and DSP during recording
    private func processRecordingBuffer(_ buffer: AVAudioPCMBuffer) {
        // Compute meters for UI (engine-owned)
        pushMeters(from: buffer)
        
        guard isRecordingActive else { return }
        
        // Validate buffer format matches expected format
        let requiredChannels = recordingFormat.channelCount
        let bufferChannels = Int(buffer.format.channelCount)
        
        if bufferChannels != requiredChannels {
            // Log but don't fail - this shouldn't happen with the new extraction logic
            if meterDecimateCounter <= 5 {
                print("⚠️ RecorderEngine: Buffer has \(bufferChannels) channels but expected \(requiredChannels)")
            }
            // Try to write anyway - AVAudioFile might handle it
        }
        
        // Write A-format safety recording
        if let writer = aWriter, safetyRecord {
            do {
                try writer.write(from: buffer)
            } catch {
                // Log write errors but don't crash
                if meterDecimateCounter <= 5 {
                    print("❌ RecorderEngine: Failed to write buffer: \(error)")
                }
            }
        }
    }
    
    // Compute peak meters from a buffer and publish to engineMeterSubject
    private func pushMeters(from buf: AVAudioPCMBuffer) {
        meterDecimateCounter &+= 1
        if meterDecimateCounter % meterDecimateN != 0 { return }
        
        let n = Int(buf.frameLength)
        var peaks: [CGFloat] = []
        let channelCount = Int(buf.format.channelCount)
        let publishChannels = min(4, channelCount)
        
        for ch in 0..<publishChannels {
            guard let ptr = buf.floatChannelData?[ch] else {
                peaks.append(0)
                continue
            }
            var maxVal: Float = 0
            vDSP_maxmgv(ptr, 1, &maxVal, vDSP_Length(n))
            peaks.append(CGFloat(min(1.0, maxVal)))
        }
        
        // Pad to 4 channels for consistent UI shape
        while peaks.count < 4 { peaks.append(0) }
        engineMeterSubject.send(peaks)
    }
    
    // Start monitoring input levels (meters only, no recording)
    func startMonitoring(sampleRate: Double? = nil, bufferFrames: AVAudioFrameCount = 16384) {
        // Validate prerequisites
        guard !selectedDeviceID.isEmpty, selectedDeviceID != "__no_devices__" else {
            print("⚠️ Monitoring: No device selected")
            return
        }
        
        guard selectedInputChannels.count >= 4 else {
            print("⚠️ Monitoring: Need at least 4 channels selected")
            return
        }
        
        guard !isRecordingActive else {
            return
        }
        
        // Delegate to underlying recorder
        Task {
            await recorder.startMonitoring(sampleRate: sampleRate, bufferFrames: bufferFrames)
            await MainActor.run {
                syncStateFromRecorder()
            }
        }
    }
    
    func stopMonitoring() {
        Task {
            await recorder.stopMonitoring()
            await MainActor.run {
                syncStateFromRecorder()
            }
        }
    }
    
    // Async version that waits for completion
    func stopMonitoringAsync() async {
        await recorder.stopMonitoring()
        await MainActor.run {
            syncStateFromRecorder()
        }
    }
    
    // Permission methods - delegate to underlying recorder
    func checkMicrophonePermission() {
        recorder.checkMicrophonePermission()
        DispatchQueue.main.async { [weak self] in
            self?.syncStateFromRecorder()
        }
    }
    
    func requestMicrophonePermission() {
        recorder.requestMicrophonePermission()
        DispatchQueue.main.async { [weak self] in
            self?.syncStateFromRecorder()
        }
    }

    // Start recording - delegates to underlying recorder and sets up file writing
    func start(sampleRate: Double = 48000, bufferFrames: AVAudioFrameCount = 1024) async throws {
        // Stop any existing recording
        stop()
        
        // Stop monitoring and wait for it to complete
        await stopMonitoringAsync()
        
        // Small delay to ensure recorder is fully stopped
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Check permission
        #if os(macOS)
        recorder.checkMicrophonePermission()
        await MainActor.run {
            syncStateFromRecorder()
        }
        guard hasMicrophonePermission else {
            throw NSError(domain: "RecorderEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        }
        #endif
        
        // Validate channels
        let requiredChannels = recordingFormat.channelCount
        guard selectedInputChannels.count >= requiredChannels else {
            throw NSError(domain: "RecorderEngine", code: -2, 
                         userInfo: [NSLocalizedDescriptionKey: "Must select at least \(requiredChannels) channels"])
        }
        
        // Create file format
        guard let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, 
                                     sampleRate: sampleRate, 
                                     channels: AVAudioChannelCount(requiredChannels), 
                                     interleaved: false) else {
            throw NSError(domain: "RecorderEngine", code: -3, 
                         userInfo: [NSLocalizedDescriptionKey: "Cannot create \(requiredChannels)-channel format at \(sampleRate)Hz"])
        }
        
        // Create file writer
        let recordingFolder = ProjectManager.shared.getRecordingsFolder()
        let timestamp = Date().timeIntervalSince1970
        let formatName = recordingFormat == .mono ? "Mono" : recordingFormat == .stereo ? "Stereo" : "Aformat"
        let fileURL = recordingFolder.appendingPathComponent("\(formatName)_\(timestamp).wav")
        let writer = try AVAudioFile(forWriting: fileURL, settings: fmt.settings)
        
        // Update state
        await MainActor.run {
            self.aWriter = writer
            self.bWriter = nil
            self.isRecordingActive = true
            self.waveformData = [[], [], [], []]
            
            // Start timer
            self.recordingStartTime = Date()
            self.recordingElapsedTime = 0
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let startTime = self.recordingStartTime else { return }
                self.recordingElapsedTime = Date().timeIntervalSince(startTime)
            }
            RunLoop.main.add(self.recordingTimer!, forMode: .common)
        }
        
        // Apply interface gains
        if let iface = ProfileStore.shared.latestInterfaceProfile(), iface.channelGains_dB.count == 4 {
            dsp.interfaceGains_dB = iface.channelGains_dB.map { Float($0) }
        }
        
        // Start underlying recorder
        do {
            try await recorder.start(sampleRate: sampleRate, bufferFrames: bufferFrames)
            print("✅ RecorderEngine: Recording started successfully")
        } catch {
            print("❌ RecorderEngine: Failed to start recorder: \(error)")
            // Clean up on failure
            await MainActor.run {
                self.aWriter = nil
                self.isRecordingActive = false
            }
            throw error
        }
        
        // Sync state
        await MainActor.run {
            syncStateFromRecorder()
        }
    }

    func stop() {
        isRecordingActive = false
        
        // Stop underlying recorder
        recorder.stop()
        
        // Close files
        aWriter = nil
        bWriter = nil
        
        // Stop recording timer and clear time
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.recordingStartTime = nil
            self.recordingElapsedTime = 0
            self.waveformData = [[], [], [], []]
        }
        
        // Sync state
        DispatchQueue.main.async { [weak self] in
            self?.syncStateFromRecorder()
        }
        
        // Restart monitoring if we had enough channels selected
        let requiredChannels = recordingFormat.channelCount
        if selectedInputChannels.count >= requiredChannels {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.startMonitoring()
            }
        }
    }

}


