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
            .handleEvents(receiveOutput: { peaks in
                // Debug: Log first few publisher outputs
                if self.meterDecimateCounter <= 5 {
                    print("MeterPublisher output: \(peaks.map { String(format: "%.3f", $0) })")
                }
            })
            .eraseToAnyPublisher()
    }
    private let dsp = AmbisonicsDSP()

    @Published var selectedDeviceID: String = "__no_devices__" // Start with placeholder
    @Published var selectedInputChannels: [Int] = [] // Start empty, user must select
    @Published var safetyRecord: Bool = true
    @Published var currentSampleRate: Double = 48000.0 // Auto-detected from hardware
    @Published var requestedSampleRate: Double = 48000.0 // User-requested sample rate
    @Published var hasMicrophonePermission: Bool = false

    private var aWriter: AVAudioFile?
    private var bWriter: AVAudioFile?
    private var isMonitoring = false
    private var isRecordingActive = false
    private var monitoringTask: Task<Void, Never>?
    private var meterDecimateCounter: Int = 0
    private let meterDecimateN: Int = 2
    private let audioEngineQueue = DispatchQueue(label: "com.ambi-studio.audio-engine", qos: .userInitiated)
    private var lastMonitorSignature: String?

    // Start monitoring input levels (meters only, no recording)
    // Use larger buffer size to reduce callback frequency and prevent overload
    // Note: Very large buffers (>8192) can cause latency, but smaller buffers cause overload
    func startMonitoring(sampleRate: Double? = nil, bufferFrames: AVAudioFrameCount = 16384) {
        // Use requested sample rate if provided, otherwise use current detected rate
        let rateToUse = sampleRate ?? requestedSampleRate
        // Cancel any existing monitoring task
        monitoringTask?.cancel()
        
        // Stop if already monitoring
        if isMonitoring {
            stopMonitoring()
        }
        
        // Validate prerequisites
        guard !selectedDeviceID.isEmpty, selectedDeviceID != "__no_devices__" else {
            print("⚠️ Monitoring: No device selected (deviceID: '\(selectedDeviceID)')")
            return
        }
        
        // Use selected channels if available, otherwise default to first 4
        let channelsToMonitor = selectedInputChannels.count >= 4 
            ? Array(selectedInputChannels.prefix(4))
            : [0, 1, 2, 3] // Default to first 4 channels for monitoring
        
        if selectedInputChannels.count < 4 {
            print("⚠️ Monitoring: Only \(selectedInputChannels.count) channels selected, using default [0,1,2,3] for meters")
        }
        
        // Don't start if recording is active
        guard !isRecordingActive else {
            return
        }
        
        // Avoid redundant restarts
        let signature = "\(selectedDeviceID)|\(channelsToMonitor)"
        if isMonitoring, signature == lastMonitorSignature { 
            print("Monitoring: Already monitoring with same signature, skipping restart")
            return 
        }
        lastMonitorSignature = signature
        print("🔍 Starting monitoring: device=\(selectedDeviceID), channels=\(channelsToMonitor)")

        // Start monitoring in background task (not on main) to avoid pinwheeling UI
        monitoringTask = Task.detached { [weak self] in
            guard let self else { return }
            // Check if cancelled
            guard !Task.isCancelled else { return }
            
            do {
                // Small delay to ensure audio system is ready (non-blocking)
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.audioEngineQueue.async { [weak self] in
                        guard let self else { return cont.resume() }
                        #if os(iOS)
                        let session = AVAudioSession.sharedInstance()
                        try? session.setCategory(.playAndRecord, options: [.allowBluetooth, .mixWithOthers])
                        try? session.setActive(true)
                        #endif

                        if self.engine.isRunning {
                            self.engine.inputNode.removeTap(onBus: 0)
                            self.engine.stop()
                        }

                        let input = self.engine.inputNode
                        let hw = input.inputFormat(forBus: 0)
                        let availableChannels = Int(hw.channelCount)

                        guard availableChannels >= 4 else {
                            print("❌ Monitoring: Device has only \(availableChannels) channels, need 4")
                            return cont.resume()
                        }
                        
                        // Validate channels to monitor
                        let channelsToUse = channelsToMonitor
                        guard channelsToUse.allSatisfy({ $0 >= 0 && $0 < availableChannels }) else {
                            print("❌ Monitoring: Channels \(channelsToUse) out of range (0-\(availableChannels-1))")
                            return cont.resume()
                        }
                        
                        print("✅ Monitoring: Device has \(availableChannels) channels, using \(channelsToUse)")
                        print("✅ Monitoring: Hardware sample rate: \(hw.sampleRate) Hz, format: \(hw)")
                        guard hw.sampleRate > 0 && hw.channelCount > 0 else {
                            print("Monitoring: Invalid audio format - sampleRate: \(hw.sampleRate), channels: \(hw.channelCount)")
                            return cont.resume()
                        }
                        
                        #if os(macOS)
                        // On macOS, AVAudioEngine uses the system default input device
                        // Verify the selected device matches what the engine is actually using
                        // Note: User may need to set the input device in System Preferences > Sound
                        print("ℹ️ macOS: Using system default input device. Selected device ID: \(self.selectedDeviceID)")
                        print("ℹ️ If meters show no signal, verify the selected device is set as default in System Preferences > Sound")
                        #endif

                        // Install tap with nil format first
                        // Use larger buffer to reduce callback frequency and prevent audio system overload
                        input.installTap(onBus: 0, bufferSize: bufferFrames, format: nil) { [weak self] buf, _ in
                            guard let self, !self.isRecordingActive else { return }
                            
                            // Validate buffer has data
                            guard buf.frameLength > 0, buf.format.channelCount > 0 else { return }
                            
                            // Debug: Scan ALL channels for signal (only on first callback to reduce overhead)
                            if self.meterDecimateCounter == 1 {
                                print("=== Audio Signal Scan ===")
                                print("Monitoring tap callback: frames=\(buf.frameLength), channels=\(buf.format.channelCount), selected=\(self.selectedInputChannels)")
                                
                                guard let channelData = buf.floatChannelData else {
                                    print("  ERROR: floatChannelData is nil!")
                                    print("========================")
                                    return
                                }
                                
                                var channelsWithSignal: [Int] = []
                                let totalChannels = Int(buf.format.channelCount)
                                
                                // Scan all channels for any non-zero samples
                                for ch in 0..<totalChannels {
                                    let ptr = channelData[ch]
                                    // Check multiple sample positions
                                    let sample0 = ptr[0]
                                    let sample100 = buf.frameLength > 100 ? ptr[min(100, Int(buf.frameLength)-1)] : sample0
                                    let sampleMid = buf.frameLength > 1 ? ptr[Int(buf.frameLength)/2] : sample0
                                    let sampleEnd = buf.frameLength > 1 ? ptr[Int(buf.frameLength)-1] : sample0
                                    
                                    // Check if any sample is non-zero (use very low threshold to catch any signal)
                                    if abs(sample0) > 0.00001 || abs(sample100) > 0.00001 || abs(sampleMid) > 0.00001 || abs(sampleEnd) > 0.00001 {
                                        channelsWithSignal.append(ch)
                                        let maxSample = max(abs(sample0), abs(sample100), abs(sampleMid), abs(sampleEnd))
                                        print("  ✓ Channel \(ch) HAS SIGNAL: peak≈\(String(format: "%.6f", maxSample)), samples=[\(String(format: "%.6f", sample0)), \(String(format: "%.6f", sample100)), \(String(format: "%.6f", sampleMid))]")
                                    }
                                }
                                
                                if channelsWithSignal.isEmpty {
                                    print("  ✗ NO SIGNAL detected on ANY of \(totalChannels) channels")
                                    print("  Sample values from first 4 channels:")
                                    for ch in 0..<min(4, totalChannels) {
                                        let ptr = channelData[ch]
                                        print("    ch\(ch): [0]=\(String(format: "%.8f", ptr[0])), [100]=\(String(format: "%.8f", ptr[min(100, Int(buf.frameLength)-1)]))")
                                    }
                                    print("  Possible causes:")
                                    print("    - No audio input connected to device")
                                    print("    - Device not receiving signal")
                                    print("    - Aggregate device routing misconfigured")
                                    print("    - Input levels muted or zero")
                                    print("    - Audio interface not powered on")
                                    print("    - Wrong input source selected on device")
                                } else {
                                    print("  ✓ Found signal on channels: \(channelsWithSignal)")
                                    print("  Selected channels [\(self.selectedInputChannels.prefix(4).map(String.init).joined(separator: ", "))]")
                                    let selectedHaveSignal = self.selectedInputChannels.prefix(4).filter { channelsWithSignal.contains($0) }
                                    if selectedHaveSignal.count < 4 {
                                        print("  ⚠️  WARNING: Only \(selectedHaveSignal.count)/4 selected channels have signal!")
                                        print("  Consider selecting channels with signal: \(channelsWithSignal.prefix(4).map(String.init).joined(separator: ", "))")
                                    }
                                }
                                
                                // Check selected channels specifically
                                print("  Selected channel details:")
                                for selCh in self.selectedInputChannels.prefix(4) {
                                    if selCh < totalChannels {
                                        let ptr = channelData[selCh]
                                        let sample = ptr[0]
                                        let sampleMid = buf.frameLength > 1 ? ptr[Int(buf.frameLength)/2] : sample
                                        let hasSignal = abs(sample) > 0.00001 || abs(sampleMid) > 0.00001
                                        print("    ch\(selCh): [0]=\(String(format: "%.8f", sample)), [mid]=\(String(format: "%.8f", sampleMid)) \(hasSignal ? "✓ HAS SIGNAL" : "✗ NO SIGNAL")")
                                    }
                                }
                                print("========================")
                            }
                            
                            // Direct meter computation from input buffer to reduce overhead
                            // Skip expensive channel extraction during monitoring
                            // Use channelsToMonitor (which defaults to [0,1,2,3] if not enough selected)
                            self.pushMetersDirect(from: buf, selectedChannels: channelsToUse)
                        }

                        do {
                            try self.engine.start()
                            self.isMonitoring = true
                            print("Monitoring started successfully - device: \(self.selectedDeviceID), channels: \(self.selectedInputChannels), format: \(hw)")
                            cont.resume()
                        } catch {
                            // Retry with hardware format
                            self.engine.inputNode.removeTap(onBus: 0)
                            print("Monitoring: engine.start() failed with \(error.localizedDescription), trying HW format")
                            input.installTap(onBus: 0, bufferSize: bufferFrames, format: hw) { [weak self] buf, _ in
                                guard let self, !self.isRecordingActive else { return }
                                
                                // Validate buffer has data
                                guard buf.frameLength > 0, buf.format.channelCount > 0 else { return }
                                
                                // Direct meter computation to reduce overhead
                                self.pushMetersDirect(from: buf, selectedChannels: self.selectedInputChannels)
                            }
                            do {
                                try self.engine.start()
                                self.isMonitoring = true
                                print("Monitoring started with HW format - device: \(self.selectedDeviceID), channels: \(self.selectedInputChannels)")
                            } catch {
                                print("Monitoring: engine.start() retry failed: \(error.localizedDescription)")
                            }
                            cont.resume()
                        }
                    }
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
    
    // Request microphone permission (macOS)
    #if os(macOS)
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            print("⚠️ Microphone permission denied or restricted")
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    // Check microphone permission status
    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DispatchQueue.main.async {
            self.hasMicrophonePermission = (status == .authorized)
        }
    }
    
    // Request microphone permission (public method for UI)
    func requestMicrophonePermission() {
        // Run on background queue to avoid blocking UI
        Task.detached { [weak self] in
            guard let self else { return }
            
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .authorized:
                await MainActor.run {
                    self.hasMicrophonePermission = true
                }
            case .notDetermined:
                // Request permission (this will show system dialog)
                // Use completion handler version to avoid blocking
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        Task { @MainActor in
                            self.hasMicrophonePermission = granted
                            if granted {
                                print("✅ Microphone permission granted")
                                // Restart monitoring if channels are selected
                                if self.selectedInputChannels.count == 4 {
                                    self.startMonitoring()
                                }
                            } else {
                                print("❌ Microphone permission denied")
                            }
                        }
                        continuation.resume()
                    }
                }
            case .denied, .restricted:
                print("⚠️ Microphone permission denied or restricted. Please enable in System Preferences > Security & Privacy > Privacy > Microphone")
                await MainActor.run {
                    self.hasMicrophonePermission = false
                }
            @unknown default:
                await MainActor.run {
                    self.hasMicrophonePermission = false
                }
            }
        }
    }
    #else
    func checkMicrophonePermission() {
        // iOS handles permissions via Info.plist and system prompts
        hasMicrophonePermission = true
    }
    
    func requestMicrophonePermission() {
        // iOS handles permissions automatically via Info.plist
        checkMicrophonePermission()
    }
    #endif

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

        // Request microphone permission on macOS
        #if os(macOS)
        var permissionGranted = false
        let semaphore = DispatchSemaphore(value: 0)
        requestMicrophonePermission { granted in
            permissionGranted = granted
            DispatchQueue.main.async {
                self.hasMicrophonePermission = granted
            }
            semaphore.signal()
        }
        semaphore.wait()
        guard permissionGranted else {
            throw NSError(domain: "RecorderEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        }
        #endif
        
        let input = engine.inputNode
        let hw = input.inputFormat(forBus: 0)
        
        // Auto-detect and update sample rate
        let detectedSampleRate = hw.sampleRate
        DispatchQueue.main.async {
            self.currentSampleRate = detectedSampleRate
        }
        
        // Use requested sample rate if different from detected
        let rateToUse = abs(requestedSampleRate - detectedSampleRate) > 1.0 ? requestedSampleRate : detectedSampleRate
        
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
        
        // Try multiple approaches to create format (same as extractFirstFourChannels)
        let fmt: AVAudioFormat
        if let commonFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rateToUse, channels: 4, interleaved: false) {
            fmt = commonFmt
        } else if let standardFmt = AVAudioFormat(standardFormatWithSampleRate: rateToUse, channels: 4) {
            fmt = standardFmt
        } else {
            // Use hardware format properties
            var settings = hw.settings
            settings[AVNumberOfChannelsKey] = 4
            settings[AVSampleRateKey] = rateToUse
            settings[AVLinearPCMBitDepthKey] = 32
            settings[AVLinearPCMIsFloatKey] = true
            // Remove interleaved key to ensure non-interleaved
            settings.removeValue(forKey: AVLinearPCMIsBigEndianKey)
            
            if let settingsFmt = AVAudioFormat(settings: settings) {
                fmt = settingsFmt
            } else if let derivedFmt = AVAudioFormat(commonFormat: hw.commonFormat, sampleRate: rateToUse, channels: 4, interleaved: hw.isInterleaved) {
                fmt = derivedFmt
            } else {
                // Last resort: use hardware format directly (we'll extract 4 channels during processing)
                // This should always work since it's the actual hardware format
                fmt = hw
                print("Warning: Using hardware format directly for recording (28 channels), will extract 4 during processing")
            }
        }
        inputFormat = fmt

        // Auto-apply latest interface channel gains from calibration
        if let iface = ProfileStore.shared.latestInterfaceProfile(), iface.channelGains_dB.count == 4 {
            dsp.interfaceGains_dB = iface.channelGains_dB.map { Float($0) }
        }

        let recordingFolder = RecordingFolderManager.shared.getFolder()
        if safetyRecord {
            do {
                aWriter = try AVAudioFile(forWriting: recordingFolder.appendingPathComponent("Aformat_\(Date().timeIntervalSince1970).wav"), settings: fmt.settings)
            } catch {
                print("Warning: Failed to create A-format file: \(error.localizedDescription)")
                aWriter = nil
            }
        } else {
            aWriter = nil
        }
        // Use same format as A-format for B-format (they're both 4-channel)
        let bfmt = fmt
        do {
            bWriter = try AVAudioFile(forWriting: recordingFolder.appendingPathComponent("BformatAmbiX_\(Date().timeIntervalSince1970).wav"), settings: bfmt.settings)
        } catch {
            print("Warning: Failed to create B-format file: \(error.localizedDescription)")
            bWriter = nil
        }

        // Install tap with the hardware format
        isRecordingActive = true
        input.installTap(onBus: 0, bufferSize: bufferFrames, format: hw) { [weak self] buf, _ in
            guard let self else { return }
            let four = self.extractFirstFourChannels(buffer: buf)
            if let f = self.aWriter {
                do {
                    try f.write(from: four)
                } catch {
                    print("Warning: A-format write error: \(error.localizedDescription)")
                }
            }
            if let bFile = self.bWriter {
                let bBuf = self.dsp.processAtoB(aBuffer: four)
                do {
                    try bFile.write(from: bBuf)
                } catch {
                    print("Warning: B-format write error: \(error.localizedDescription)")
                }
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
        let sampleRate = buffer.format.sampleRate
        
        // Try multiple approaches to create the format
        let fmt: AVAudioFormat
        
        // Approach 1: Try commonFormat
        if let commonFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate, channels: 4, interleaved: false) {
            fmt = commonFmt
        }
        // Approach 2: Try standardFormat
        else if let standardFmt = AVAudioFormat(standardFormatWithSampleRate: buffer.format.sampleRate, channels: 4) {
            fmt = standardFmt
        }
        // Approach 3: Use buffer's format settings and modify channel count
        else {
            var settings = buffer.format.settings
            settings[AVNumberOfChannelsKey] = 4
            settings[AVSampleRateKey] = sampleRate
            settings[AVLinearPCMBitDepthKey] = 32
            settings[AVLinearPCMIsFloatKey] = true
            // Note: Non-interleaved is indicated by absence of interleaving, not a separate key
            // Remove any interleaved-related keys to ensure non-interleaved
            settings.removeValue(forKey: AVLinearPCMIsBigEndianKey) // Will use default
            
            if let settingsFmt = AVAudioFormat(settings: settings) {
                fmt = settingsFmt
            }
            // Approach 4: Derive from input format
            else if let derivedFmt = AVAudioFormat(commonFormat: buffer.format.commonFormat, sampleRate: buffer.format.sampleRate, channels: 4, interleaved: buffer.format.isInterleaved) {
                fmt = derivedFmt
            }
            // Last resort: create format from buffer's format directly (will work but may have wrong channel layout)
            else {
                // Use the buffer's format but we'll only use 4 channels
                // This is safe because we control which channels we copy
                fmt = buffer.format
            }
        }
        
        // Create output buffer - if format has more than 4 channels, that's OK, we'll only use 4
        guard let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else {
            // If buffer creation fails, try with buffer's original format
            guard let fallbackOut = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: frameCount) else {
                fatalError("Failed to create output audio buffer. Input format: \(buffer.format), Attempted format: \(fmt)")
            }
            fallbackOut.frameLength = frameCount
            // Copy only the 4 channels we need
            let selectedChannels = selectedInputChannels.prefix(4)
            let availableChannels = Int(buffer.format.channelCount)
            for (outCh, inCh) in selectedChannels.enumerated() {
                let srcCh = min(max(0, inCh), availableChannels - 1)
                let src = buffer.floatChannelData![srcCh]
                // Use the first 4 channels of output, even if format has more
                let dstCh = min(outCh, Int(fallbackOut.format.channelCount) - 1)
                let dst = fallbackOut.floatChannelData![dstCh]
                dst.update(from: src, count: Int(frameCount))
            }
            return fallbackOut
        }
        out.frameLength = frameCount
        
        // Map selected input channels to output channels
        let selectedChannels = selectedInputChannels.prefix(4)
        let availableChannels = Int(buffer.format.channelCount)
        
        let outputChannelCount = Int(out.format.channelCount)
        for (outCh, inCh) in selectedChannels.enumerated() {
            // Clamp input channel to available range
            let srcCh = min(max(0, inCh), availableChannels - 1)
            let src = buffer.floatChannelData![srcCh]
            // Clamp output channel to available range (in case format has more than 4 channels)
            let dstCh = min(outCh, outputChannelCount - 1)
            let dst = out.floatChannelData![dstCh]
            dst.update(from: src, count: Int(frameCount))
        }
        
        return out
    }

    private func pushMeters(from buf: AVAudioPCMBuffer) {
        // Decimate meter updates to reduce message rate
        meterDecimateCounter &+= 1
        if meterDecimateCounter % meterDecimateN != 0 { return }

        let n = Int(buf.frameLength)
        var peaks: [CGFloat] = []
        let channelCount = Int(buf.format.channelCount)
        for ch in 0..<4 {
            // Clamp to available channels
            let actualCh = min(ch, channelCount - 1)
            guard let ptr = buf.floatChannelData?[actualCh] else { continue }
            var maxVal: Float = 0
            // Compute peak magnitude efficiently
            vDSP_maxmgv(ptr, 1, &maxVal, vDSP_Length(n))
            peaks.append(CGFloat(min(1.0, maxVal)))
        }
        meterSubject.send(peaks)
    }
    
    // Direct meter computation from input buffer (reduces overhead)
    private func pushMetersDirect(from buf: AVAudioPCMBuffer, selectedChannels: [Int]) {
        // Decimate meter updates to reduce message rate
        meterDecimateCounter &+= 1
        if meterDecimateCounter % meterDecimateN != 0 { return }

        let n = Int(buf.frameLength)
        guard n > 0 else { return } // Skip empty buffers
        
        var peaks: [CGFloat] = []
        let availableChannels = Int(buf.format.channelCount)
        
        // Use selected channels - ensure we have exactly 4
        guard selectedChannels.count >= 4 else {
            // Not enough channels selected, send zeros
            meterSubject.send([0, 0, 0, 0])
            return
        }
        
        guard let channelData = buf.floatChannelData else {
            meterSubject.send([0, 0, 0, 0])
            return
        }
        
        // Map each of the 4 output meters to the corresponding selected input channel
        for outCh in 0..<4 {
            let inCh = selectedChannels[outCh] // Get the selected channel for this meter
            let actualCh = min(max(0, inCh), availableChannels - 1)
            
            // Verify channel is valid
            guard actualCh < availableChannels else {
                peaks.append(0)
                continue
            }
            
            let ptr = channelData[actualCh]
            var maxVal: Float = 0
            vDSP_maxmgv(ptr, 1, &maxVal, vDSP_Length(n))
            let peak = CGFloat(min(1.0, maxVal))
            peaks.append(peak)
            
            // Debug: Log meter values for all channels
            if meterDecimateCounter <= 5 {
                let sample0 = ptr[0]
                print("Meter[\(outCh)] reading from input ch\(actualCh) (selected: \(inCh)): peak=\(String(format: "%.4f", peak)), sample[0]=\(String(format: "%.4f", sample0))")
            }
        }
        
        // Always send peaks (even if all zeros) to keep UI updated
        meterSubject.send(peaks)
        
        // Debug: Log first few sends
        if meterDecimateCounter <= 5 {
            print("Meters sent: \(peaks.map { String(format: "%.3f", $0) }) (from selected channels \(selectedChannels.prefix(4).map(String.init).joined(separator: ", ")))")
        }
    }
}

