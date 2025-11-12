import Foundation
import AVFoundation
import Combine
import Accelerate

final class RecorderEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private var inputFormat: AVAudioFormat?
    private let meterSubject = PassthroughSubject<[CGFloat], Never>()
    var meterPublisher: AnyPublisher<[CGFloat], Never> { 
        meterSubject
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    private let dsp = AmbisonicsDSP()

    @Published var selectedDeviceID: String = "__no_devices__" // Start with placeholder
    @Published var selectedInputChannels: [Int] = [] // Start empty, user must select
    @Published var safetyRecord: Bool = true

    private var aWriter: AVAudioFile?
    private var bWriter: AVAudioFile?
    private var isMonitoring = false
    private var isRecordingActive = false
    private var monitoringTask: Task<Void, Never>?
    private var meterDecimateCounter: Int = 0
    private let meterDecimateN: Int = 2

    // Start monitoring input levels (meters only, no recording)
    func startMonitoring(sampleRate: Double = 48000, bufferFrames: AVAudioFrameCount = 4096) {
        // Cancel any existing monitoring task
        monitoringTask?.cancel()
        
        // Stop if already monitoring
        if isMonitoring {
            stopMonitoring()
        }
        
        // Validate prerequisites
        guard !selectedDeviceID.isEmpty, selectedDeviceID != "__no_devices__" else {
            print("Monitoring: No device selected")
            return
        }
        
        guard selectedInputChannels.count == 4 else {
            print("Monitoring: Need 4 channels selected, have \(selectedInputChannels.count)")
            return
        }
        
        // Don't start if recording is active
        guard !isRecordingActive else {
            return
        }
        
        // Start monitoring in background task to avoid blocking
        monitoringTask = Task { @MainActor in
            // Check if cancelled
            guard !Task.isCancelled else { return }
            
            do {
                // Small delay to ensure audio system is ready (non-blocking)
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                // Check again if cancelled
                guard !Task.isCancelled else { return }
                
                #if os(iOS)
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playAndRecord, options: [.allowBluetooth, .mixWithOthers])
                try? session.setActive(true)
                #endif
                
                // Check again if cancelled
                guard !Task.isCancelled else { return }
                
                // Remove existing tap if any
                if engine.isRunning {
                    engine.inputNode.removeTap(onBus: 0)
                    engine.stop()
                }
                
                // Check again if cancelled
                guard !Task.isCancelled else { return }
                
                let input = engine.inputNode
                let hw = input.inputFormat(forBus: 0)
                let availableChannels = Int(hw.channelCount)
                
                // Validate we have enough channels
                guard availableChannels >= 4 else {
                    print("Monitoring: Device has only \(availableChannels) channels, need 4")
                    return
                }
                
                guard selectedInputChannels.allSatisfy({ $0 >= 0 && $0 < availableChannels }) else {
                    print("Monitoring: Selected channels \(selectedInputChannels) out of range (0-\(availableChannels-1))")
                    return
                }
                
                // Validate format is supported
                guard hw.sampleRate > 0 && hw.channelCount > 0 else {
                    print("Monitoring: Invalid audio format - sampleRate: \(hw.sampleRate), channels: \(hw.channelCount)")
                    return
                }
                
                // Check again if cancelled before installing tap
                guard !Task.isCancelled else { return }
                
                // Install tap - use nil format to let system choose compatible format
                // This avoids -10877 format errors by letting CoreAudio choose the best format
                input.installTap(onBus: 0, bufferSize: bufferFrames, format: nil) { [weak self] buf, _ in
                    guard let self, !self.isRecordingActive else { return }
                    let four = self.extractFirstFourChannels(buffer: buf)
                    self.pushMeters(from: four)
                }
                
                // Check again if cancelled before starting engine
                guard !Task.isCancelled else {
                    if engine.inputNode.numberOfInputs > 0 {
                        engine.inputNode.removeTap(onBus: 0)
                    }
                    return
                }
                
                // Start engine - this might throw -10877 if format is incompatible
                // Wrap in do-catch to handle gracefully
                do {
                    try engine.start()
                    isMonitoring = true
                    print("Monitoring started successfully - device: \(selectedDeviceID), channels: \(selectedInputChannels), format: \(hw)")
                } catch {
                    // If start fails, remove tap and try with hardware format
                    engine.inputNode.removeTap(onBus: 0)
                    print("Monitoring: engine.start() failed with \(error.localizedDescription), trying with hardware format")
                    
                    // Try again with explicit hardware format
                    input.installTap(onBus: 0, bufferSize: bufferFrames, format: hw) { [weak self] buf, _ in
                        guard let self, !self.isRecordingActive else { return }
                        let four = self.extractFirstFourChannels(buffer: buf)
                        self.pushMeters(from: four)
                    }
                    
                    try engine.start()
                    isMonitoring = true
                    print("Monitoring started with hardware format - device: \(selectedDeviceID), channels: \(selectedInputChannels)")
                }
            } catch {
                print("Monitoring error: \(error.localizedDescription) (code: \((error as NSError).code))")
                isMonitoring = false
            }
        }
    }
    
    func stopMonitoring() {
        // Cancel any pending monitoring task
        monitoringTask?.cancel()
        monitoringTask = nil
        
        if engine.isRunning && !isRecordingActive {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        isMonitoring = false
    }

    func start(sampleRate: Double = 48000, bufferFrames: AVAudioFrameCount = 1024) throws {
        // Stop monitoring if active
        stopMonitoring()
        
        // Stop engine if already running
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        
        // Reset writers
        aWriter = nil
        bWriter = nil
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.allowBluetooth, .mixWithOthers])
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(Double(bufferFrames)/sampleRate)
        try session.setActive(true)
        #endif

        let input = engine.inputNode
        let hw = input.inputFormat(forBus: 0)
        
        // Check if we have enough channels
        let availableChannels = Int(hw.channelCount)
        guard availableChannels >= selectedInputChannels.count else {
            throw NSError(domain: "RecorderEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device has \(availableChannels) channels, but \(selectedInputChannels.count) selected"])
        }
        
        // Validate selected channels are within range
        guard selectedInputChannels.allSatisfy({ $0 >= 0 && $0 < availableChannels }) else {
            throw NSError(domain: "RecorderEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "Selected channels out of range. Device has \(availableChannels) channels"])
        }
        
        guard selectedInputChannels.count == 4 else {
            throw NSError(domain: "RecorderEngine", code: -3, userInfo: [NSLocalizedDescriptionKey: "Must select exactly 4 input channels"])
        }
        
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
        inputFormat = fmt

        // Auto-apply latest interface channel gains from calibration
        if let iface = ProfileStore.shared.latestInterfaceProfile(), iface.channelGains_dB.count == 4 {
            dsp.interfaceGains_dB = iface.channelGains_dB.map { Float($0) }
        }

        let recordingFolder = RecordingFolderManager.shared.getFolder()
        if safetyRecord {
            aWriter = try? AVAudioFile(forWriting: recordingFolder.appendingPathComponent("Aformat_\(Date().timeIntervalSince1970).wav"), settings: fmt.settings)
        } else {
            aWriter = nil
        }
        let bfmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
        bWriter = try? AVAudioFile(forWriting: recordingFolder.appendingPathComponent("BformatAmbiX_\(Date().timeIntervalSince1970).wav"), settings: bfmt.settings)

        // Install tap with the hardware format
        isRecordingActive = true
        input.installTap(onBus: 0, bufferSize: bufferFrames, format: hw) { [weak self] buf, _ in
            guard let self else { return }
            let four = self.extractFirstFourChannels(buffer: buf)
            if let f = self.aWriter { try? f.write(from: four) }
            if let bFile = self.bWriter {
                let bBuf = self.dsp.processAtoB(aBuffer: four)
                try? bFile.write(from: bBuf)
            }
            self.pushMeters(from: four)
        }

        try engine.start()
    }

    func stop() {
        isRecordingActive = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        aWriter = nil
        bWriter = nil
        
        // Restart monitoring if we had it before
        if selectedInputChannels.count == 4 {
            startMonitoring()
        }
    }

    private func extractFirstFourChannels(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let frameCount = buffer.frameLength
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate, channels: 4, interleaved: false)!
        let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount)!
        out.frameLength = frameCount
        
        // Map selected input channels to output channels
        let selectedChannels = selectedInputChannels.prefix(4)
        let availableChannels = Int(buffer.format.channelCount)
        
        for (outCh, inCh) in selectedChannels.enumerated() {
            // Clamp input channel to available range
            let srcCh = min(max(0, inCh), availableChannels - 1)
            let src = buffer.floatChannelData![srcCh]
            let dst = out.floatChannelData![outCh]
            dst.assign(from: src, count: Int(frameCount))
        }
        
        return out
    }

    private func pushMeters(from buf: AVAudioPCMBuffer) {
        // Decimate meter updates to reduce message rate
        meterDecimateCounter &+= 1
        if meterDecimateCounter % meterDecimateN != 0 { return }

        let n = Int(buf.frameLength)
        var peaks: [CGFloat] = []
        for ch in 0..<4 {
            guard let ptr = buf.floatChannelData?[ch] else { continue }
            var maxVal: Float = 0
            // Compute peak magnitude efficiently
            vDSP_maxmgv(ptr, 1, &maxVal, vDSP_Length(n))
            peaks.append(CGFloat(min(1.0, maxVal)))
        }
        meterSubject.send(peaks)
    }
}
