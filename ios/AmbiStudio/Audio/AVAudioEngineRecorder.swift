import Foundation
import AVFoundation
import Combine
import Accelerate

/// AVAudioEngine implementation for iOS - uses the existing AVAudioEngine approach
final class AVAudioEngineRecorder: AudioRecorderProtocol {
    // Configuration
    var selectedDeviceID: String = "__no_devices__"
    var selectedInputChannels: [Int] = []
    var requestedSampleRate: Double = 48000.0
    var recordingFormat: RecordingFormat = .ambiA
    
    // State
    @Published private(set) var currentSampleRate: Double = 48000.0
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var hasMicrophonePermission: Bool = true // iOS handles via Info.plist
    
    // Meters
    private let meterSubject = PassthroughSubject<[CGFloat], Never>()
    var meterPublisher: AnyPublisher<[CGFloat], Never> {
        meterSubject
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    // Callbacks
    var onBufferReceived: ((AVAudioPCMBuffer) -> Void)?
    
    // AVAudioEngine components
    private let engine = AVAudioEngine()
    private var isRecordingActive: Bool = false
    private var monitoringTask: Task<Void, Never>?
    private let audioQueue = DispatchQueue(label: "com.ambi-studio.audioengine", qos: .userInitiated)
    
    // Buffer management
    private var meterDecimateCounter: Int = 0
    private let meterDecimateN: Int = 2
    
    init() {
        checkMicrophonePermission()
    }
    
    deinit {
        stop()
        Task {
            await stopMonitoring()
        }
    }
    
    // MARK: - Channel Extraction
    
    /// Manual channel extraction when format creation fails
    /// This allocates memory directly and creates a buffer structure
    private func manualChannelExtraction(buffer: AVAudioPCMBuffer, mappedChannels: [Int], targetChannels: Int, frameCount: AVAudioFrameCount, sampleRate: Double) -> AVAudioPCMBuffer {
        // Create a mono format first (this usually works)
        guard let monoFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let tempBuffer = AVAudioPCMBuffer(pcmFormat: monoFmt, frameCapacity: frameCount) else {
            print("❌ AVAudioEngine: Even mono format creation failed in manual extraction")
            return buffer
        }
        
        // Manually allocate memory for target channels
        let frameSize = MemoryLayout<Float>.size
        let totalBytes = Int(frameCount) * frameSize * targetChannels
        
        // Allocate channel data
        var channelPointers: [UnsafeMutablePointer<Float>] = []
        for _ in 0..<targetChannels {
            let ptr = UnsafeMutablePointer<Float>.allocate(capacity: Int(frameCount))
            channelPointers.append(ptr)
        }
        
        // Copy data from source channels
        let availableChannels = Int(buffer.format.channelCount)
        for (outCh, mappedCh) in mappedChannels.prefix(targetChannels).enumerated() {
            guard mappedCh < availableChannels,
                  outCh < targetChannels,
                  let src = buffer.floatChannelData?[mappedCh] else {
                continue
            }
            channelPointers[outCh].update(from: src, count: Int(frameCount))
        }
        
        // CRITICAL: We MUST create a PCM format - AVAudioPCMBuffer requires PCM format
        // Try multiple approaches to create a PCM format
        var finalFmt: AVAudioFormat?
        
        // Approach 1: Direct PCM format creation (most reliable)
        finalFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: AVAudioChannelCount(targetChannels), interleaved: false)
        
        // Approach 2: Settings dictionary (ensure it's PCM)
        if finalFmt == nil {
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: targetChannels,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: true
            ]
            finalFmt = AVAudioFormat(settings: settings)
            // Validate it's actually PCM
            if let fmt = finalFmt, !fmt.isStandard {
                finalFmt = nil
            }
        }
        
        // Approach 3: Channel layout approach (must be PCM)
        if finalFmt == nil {
            // Create a channel layout for target channels
            var channelLayout = AudioChannelLayout()
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_DiscreteInOrder
            channelLayout.mNumberChannelDescriptions = UInt32(targetChannels)
            
            // Try creating format with channel layout
            withUnsafePointer(to: &channelLayout) { layoutPtr in
                let channelLayoutObj = AVAudioChannelLayout(layout: layoutPtr)
                let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, interleaved: false, channelLayout: channelLayoutObj)
                finalFmt = fmt
            }
        }
        
        // Approach 4: Use input format ONLY if it's PCM
        if finalFmt == nil {
            // Check if input format is PCM
            if buffer.format.isStandard && buffer.format.commonFormat == .pcmFormatFloat32 {
                // Input is PCM, but has wrong channel count - we can't use it directly
                // We'll need to create a new buffer with input format but only populate first N channels
                print("⚠️ AVAudioEngine: Cannot create \(targetChannels)-channel PCM format, but input is PCM - will create buffer with input format")
                finalFmt = buffer.format
            } else {
                print("❌ AVAudioEngine: Input format is not PCM, cannot create PCM buffer")
                // Clean up allocated memory
                for ptr in channelPointers {
                    ptr.deallocate()
                }
                return buffer
            }
        }
        
        guard let format = finalFmt else {
            print("❌ AVAudioEngine: Cannot create any format, cleaning up and returning original")
            // Clean up allocated memory
            for ptr in channelPointers {
                ptr.deallocate()
            }
            return buffer
        }
        
        // CRITICAL: Validate format is PCM before creating buffer
        guard format.isStandard && format.commonFormat == .pcmFormatFloat32 else {
            print("❌ AVAudioEngine: Format is not PCM (isStandard=\(format.isStandard), commonFormat=\(format.commonFormat.rawValue)), cannot create AVAudioPCMBuffer")
            // Clean up allocated memory
            for ptr in channelPointers {
                ptr.deallocate()
            }
            return buffer
        }
        
        guard let newOut = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("❌ AVAudioEngine: Cannot create buffer with format")
            // Clean up allocated memory
            for ptr in channelPointers {
                ptr.deallocate()
            }
            return buffer
        }
        
        newOut.frameLength = frameCount
        let outputChannels = Int(newOut.format.channelCount)
        
        // Copy our manually allocated channels to the buffer
        // If output has wrong channel count, only copy to available channels
        let channelsToCopy = min(targetChannels, outputChannels)
        for ch in 0..<channelsToCopy {
            guard ch < targetChannels,
                  ch < channelPointers.count,
                  let dst = newOut.floatChannelData?[ch] else {
                continue
            }
            dst.update(from: channelPointers[ch], count: Int(frameCount))
            channelPointers[ch].deallocate()
        }
        
        // Clean up any remaining allocated channels
        for ch in channelsToCopy..<channelPointers.count {
            channelPointers[ch].deallocate()
        }
        
        // If output format has wrong channel count, log warning but return it anyway
        // The caller will need to handle this
        if outputChannels != targetChannels {
            print("⚠️ AVAudioEngine: Manual extraction created buffer with \(outputChannels) channels instead of \(targetChannels)")
        }
        
        return newOut
    }
    
    private func extractChannels(buffer: AVAudioPCMBuffer, channels: [Int]) -> AVAudioPCMBuffer {
        let frameCount = buffer.frameLength
        let sampleRate = buffer.format.sampleRate
        let availableChannels = Int(buffer.format.channelCount)
        
        // CRITICAL: Validate input buffer first
        guard frameCount > 0 && Double(frameCount).isFinite else {
            print("❌ AVAudioEngine: Invalid frameCount=\(frameCount), cannot extract")
            return buffer
        }
        
        guard sampleRate > 0 && sampleRate.isFinite else {
            print("❌ AVAudioEngine: Invalid sampleRate=\(sampleRate), cannot extract")
            return buffer
        }
        
        guard availableChannels > 0 else {
            print("❌ AVAudioEngine: Invalid availableChannels=\(availableChannels), cannot extract")
            return buffer
        }
        
        // Map selected channels to available channels (wrap around if needed)
        let mappedChannels = channels.map { ch in
            // If channel index exceeds available, wrap around
            ch % max(1, availableChannels)
        }
        
        let targetChannels = channels.count
        
        // If target channels matches available and we just need to reorder, use input format
        if targetChannels == availableChannels && mappedChannels == Array(0..<availableChannels) {
            // No extraction needed, return original
            return buffer
        }
        
        // CRITICAL: We MUST create a buffer with exactly targetChannels, even if format creation fails
        // Try to create target format with fallback chain
        var targetFormat: AVAudioFormat?
        
        if let commonFmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(targetChannels),
            interleaved: false
        ) {
            targetFormat = commonFmt
        } else if let standardFmt = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: AVAudioChannelCount(targetChannels)
        ) {
            targetFormat = standardFmt
        } else if let derivedFmt = AVAudioFormat(
            commonFormat: buffer.format.commonFormat,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(targetChannels),
            interleaved: buffer.format.isInterleaved
        ) {
            targetFormat = derivedFmt
        }
        
        // If format creation failed, manually create a format using the input format's properties
        // but with the target channel count
        let finalFormat: AVAudioFormat
        if let fmt = targetFormat {
            finalFormat = fmt
        } else {
            // Manual format creation - use input format's properties but force channel count
            // This is a workaround for macOS format creation limitations
            if let manualFmt1 = AVAudioFormat(
                commonFormat: buffer.format.commonFormat,
                sampleRate: sampleRate,
                channels: AVAudioChannelCount(targetChannels),
                interleaved: false
            ) {
                finalFormat = manualFmt1
            } else if let manualFmt2 = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: AVAudioChannelCount(targetChannels),
                interleaved: false
            ) {
                finalFormat = manualFmt2
            } else {
                // Absolute last resort: use input format (will be fixed in the channel count check below)
                print("⚠️ AVAudioEngine: All format creation methods failed, will attempt forced format creation")
                finalFormat = buffer.format
            }
        }
        
        // Create output buffer with the final format
        guard let out = AVAudioPCMBuffer(pcmFormat: finalFormat, frameCapacity: frameCount) else {
            print("❌ AVAudioEngine: Failed to allocate output buffer (capacity=\(frameCount), format=\(finalFormat))")
            return buffer
        }
        
        out.frameLength = frameCount
        let outputChannels = Int(out.format.channelCount)
        
        // CRITICAL: If output format has wrong channel count, we need to manually fix it
        // This can happen when format creation falls back to input format
        if outputChannels != targetChannels {
            print("⚠️ AVAudioEngine: Output buffer has \(outputChannels) channels but need \(targetChannels), attempting manual channel extraction")
            
            // Use AVAudioConverter to convert from input format to target format
            // This is the proper way to handle format conversion when direct creation fails
            guard let targetFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: AVAudioChannelCount(targetChannels), interleaved: false) else {
                // If even this fails, manually extract channels using direct memory access
                print("⚠️ AVAudioEngine: Cannot create target format, using manual channel extraction")
                return manualChannelExtraction(buffer: buffer, mappedChannels: mappedChannels, targetChannels: targetChannels, frameCount: frameCount, sampleRate: sampleRate)
            }
            
            guard let converter = AVAudioConverter(from: buffer.format, to: targetFmt),
                  let newOut = AVAudioPCMBuffer(pcmFormat: targetFmt, frameCapacity: frameCount) else {
                print("⚠️ AVAudioEngine: Cannot create converter, using manual channel extraction")
                return manualChannelExtraction(buffer: buffer, mappedChannels: mappedChannels, targetChannels: targetChannels, frameCount: frameCount, sampleRate: sampleRate)
            }
            
            // Convert using the converter
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            converter.convert(to: newOut, error: &error, withInputFrom: inputBlock)
            
            if let error = error {
                print("⚠️ AVAudioEngine: Converter error: \(error), using manual extraction")
                return manualChannelExtraction(buffer: buffer, mappedChannels: mappedChannels, targetChannels: targetChannels, frameCount: frameCount, sampleRate: sampleRate)
            }
            
            // Converter might not copy all channels correctly, so manually copy the mapped channels
            newOut.frameLength = frameCount
            for (outCh, mappedCh) in mappedChannels.prefix(targetChannels).enumerated() {
                guard mappedCh < availableChannels,
                      outCh < targetChannels,
                      let src = buffer.floatChannelData?[mappedCh],
                      let dst = newOut.floatChannelData?[outCh] else {
                    continue
                }
                dst.update(from: src, count: Int(frameCount))
            }
            
            return newOut
        }
        
        // Normal path: output format has correct channel count
        // Copy mapped channels to output
        for (outCh, mappedCh) in mappedChannels.prefix(min(targetChannels, outputChannels)).enumerated() {
            guard outCh < outputChannels,
                  mappedCh < availableChannels,
                  let src = buffer.floatChannelData?[mappedCh],
                  let dst = out.floatChannelData?[outCh] else {
                continue
            }
            let copyCount = Int(frameCount)
            dst.update(from: src, count: copyCount)
        }
        
        // If we need more channels than available, repeat the last available channel
        if targetChannels > outputChannels && outputChannels > 0 {
            let lastSrcCh = min(mappedChannels.last ?? 0, availableChannels - 1)
            if let src = buffer.floatChannelData?[lastSrcCh] {
                for outCh in outputChannels..<targetChannels {
                    if let dst = out.floatChannelData?[outCh] {
                        dst.update(from: src, count: Int(frameCount))
                    }
                }
            }
        }
        
        return out
    }
    
    // MARK: - Meter Processing
    
    private func pushMeters(from buf: AVAudioPCMBuffer) {
        meterDecimateCounter &+= 1
        if meterDecimateCounter % meterDecimateN != 0 { return }
        
        let n = Int(buf.frameLength)
        guard n > 0 else { return }
        
        var peaks: [CGFloat] = []
        let channelCount = Int(buf.format.channelCount)
        
        // Map selected channels to available channels for metering
        let mappedChannels = selectedInputChannels.prefix(4).map { ch in
            ch % max(1, channelCount)
        }
        
        for mappedCh in mappedChannels {
            guard mappedCh < channelCount,
                  let ptr = buf.floatChannelData?[mappedCh] else {
                peaks.append(0)
                continue
            }
            
            // Calculate peak magnitude
            var maxVal: Float = 0
            vDSP_maxmgv(ptr, 1, &maxVal, vDSP_Length(n))
            
            // Ensure we're getting the actual peak (not RMS)
            // Float32 audio is normalized to -1.0 to 1.0, so maxVal should be 0-1
            // Clamp to valid range and convert to CGFloat
            let peak = CGFloat(min(1.0, max(0.0, maxVal)))
            peaks.append(peak)
        }
        
        // Pad to 4 channels if needed
        while peaks.count < 4 {
            peaks.append(0)
        }
        
        // Debug: log first few meter updates to verify scaling
        if meterDecimateCounter <= 10 {
            let dbValues = peaks.map { peak in
                peak > 0.0001 ? 20 * log10(Double(peak)) : -80.0
            }
            print("🔍 Meter peaks (linear): \(peaks.map { String(format: "%.4f", $0) }), dB: \(dbValues.map { String(format: "%.1f", $0) })")
        }
        
        meterSubject.send(peaks)
    }
    
    // MARK: - AudioRecorderProtocol
    
    func startMonitoring(sampleRate: Double? = nil, bufferFrames: AVAudioFrameCount = 16384) async {
        await stopMonitoring()
        
        guard !selectedDeviceID.isEmpty, selectedDeviceID != "__no_devices__" else {
            print("⚠️ AVAudioEngine: No device selected")
            return
        }
        
        guard selectedInputChannels.count >= 4 else {
            print("⚠️ AVAudioEngine: Need at least 4 channels selected")
            return
        }
        
        await audioQueue.sync {
            do {
                #if os(iOS)
                // Configure AVAudioSession (iOS only)
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, options: [.allowBluetooth, .mixWithOthers])
                try session.setActive(true)
                #endif
                
                // Stop engine if running
                if engine.isRunning {
                    engine.inputNode.removeTap(onBus: 0)
                    engine.stop()
                }
                
                let input = engine.inputNode
                let hw = input.inputFormat(forBus: 0)
                
                print("🔍 AVAudioEngine: Hardware format - sampleRate: \(hw.sampleRate), channels: \(hw.channelCount), commonFormat: \(hw.commonFormat.rawValue), isInterleaved: \(hw.isInterleaved)")
                
                guard hw.sampleRate > 0 && hw.sampleRate.isFinite else {
                    print("❌ AVAudioEngine: Invalid sample rate: \(hw.sampleRate)")
                    return
                }
                
                guard hw.channelCount > 0 else {
                    print("❌ AVAudioEngine: Invalid channel count: \(hw.channelCount)")
                    return
                }
                
                // Validate we can actually extract the requested channels
                let availableChannels = Int(hw.channelCount)
                let channelsToUse = selectedInputChannels.prefix(4).map { ch in
                    // Map to available channels (wrap around)
                    ch % max(1, availableChannels)
                }
                
                print("🔍 AVAudioEngine: Installing tap - bufferSize: \(bufferFrames), availableChannels: \(availableChannels), channelsToExtract: \(channelsToUse)")
                
                // Install tap with nil format to use hardware format
                input.installTap(onBus: 0, bufferSize: bufferFrames, format: nil) { [weak self] buf, _ in
                    guard let self, !self.isRecordingActive else { return }
                    
                    // Validate buffer before processing
                    let frameLen = buf.frameLength
                    let chCount = Int(buf.format.channelCount)
                    
                    guard frameLen > 0 && Double(frameLen).isFinite,
                          chCount > 0,
                          buf.format.sampleRate > 0 && buf.format.sampleRate.isFinite else {
                        if self.meterDecimateCounter < 3 {
                            print("⚠️ AVAudioEngine: Received invalid buffer - frameLength: \(frameLen), channels: \(chCount), sampleRate: \(buf.format.sampleRate)")
                        }
                        return
                    }
                    
                    // For monitoring, read meters directly from hardware buffer
                    // This avoids format creation issues
                    self.pushMeters(from: buf)
                    
                    // Also try to extract for potential callbacks (but don't fail if it doesn't work)
                    let extracted = self.extractChannels(buffer: buf, channels: Array(channelsToUse))
                    if extracted.frameLength > 0 {
                        // Extraction succeeded, could use for callbacks if needed
                    }
                }
                
                // Start engine
                try engine.start()
                
                DispatchQueue.main.async { [weak self] in
                    self?.currentSampleRate = hw.sampleRate
                    self?.isMonitoring = true
                }
                
                print("✅ AVAudioEngine: Monitoring started - sampleRate: \(hw.sampleRate)Hz, channels: \(channelsToUse)")
            } catch {
                print("❌ AVAudioEngine: Failed to start monitoring: \(error)")
            }
        }
    }
    
    func stopMonitoring() async {
        await audioQueue.sync {
            if engine.isRunning && !isRecordingActive {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
            DispatchQueue.main.async { [weak self] in
                self?.isMonitoring = false
            }
        }
    }
    
    func start(sampleRate: Double, bufferFrames: AVAudioFrameCount) async throws {
        await stopMonitoring()
        
        guard !selectedDeviceID.isEmpty, selectedDeviceID != "__no_devices__" else {
            throw NSError(domain: "AVAudioEngineRecorder", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No device selected"])
        }
        
        let requiredChannels = recordingFormat.channelCount
        guard selectedInputChannels.count >= requiredChannels else {
            throw NSError(domain: "AVAudioEngineRecorder", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Must select at least \(requiredChannels) channels"])
        }
        
        try await audioQueue.sync {
            #if os(iOS)
            // Configure AVAudioSession (iOS only)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.allowBluetooth, .mixWithOthers])
            try session.setPreferredSampleRate(sampleRate)
            try session.setPreferredIOBufferDuration(Double(bufferFrames) / sampleRate)
            try session.setActive(true)
            #endif
            
            // Stop engine if running
            if engine.isRunning {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
            
            let input = engine.inputNode
            let hw = input.inputFormat(forBus: 0)
            
            print("🔍 AVAudioEngine (Recording): Hardware format - sampleRate: \(hw.sampleRate), channels: \(hw.channelCount), commonFormat: \(hw.commonFormat.rawValue)")
            
            guard hw.sampleRate > 0 && hw.sampleRate.isFinite else {
                throw NSError(domain: "AVAudioEngineRecorder", code: -3,
                             userInfo: [NSLocalizedDescriptionKey: "Invalid sample rate: \(hw.sampleRate)"])
            }
            
            guard Int(hw.channelCount) >= requiredChannels else {
                throw NSError(domain: "AVAudioEngineRecorder", code: -3,
                             userInfo: [NSLocalizedDescriptionKey: "Device has \(hw.channelCount) channels, need \(requiredChannels)"])
            }
            
            // Map selected channels to available channels
            let availableChannels = Int(hw.channelCount)
            let channelsToUse = selectedInputChannels.prefix(requiredChannels).map { ch in
                ch % max(1, availableChannels)
            }
            
            print("🔍 AVAudioEngine (Recording): Installing tap - bufferSize: \(bufferFrames), availableChannels: \(availableChannels), channelsToExtract: \(channelsToUse), requiredChannels: \(requiredChannels)")
            
            // Install tap with hardware format
            input.installTap(onBus: 0, bufferSize: bufferFrames, format: hw) { [weak self] buf, _ in
                guard let self, self.isRecordingActive else { return }
                
                // Validate buffer
                let frameLen = buf.frameLength
                let chCount = Int(buf.format.channelCount)
                
                guard frameLen > 0 && Double(frameLen).isFinite,
                      chCount > 0,
                      buf.format.sampleRate > 0 && buf.format.sampleRate.isFinite else {
                    print("⚠️ AVAudioEngine (Recording): Received invalid buffer - frameLength: \(frameLen), channels: \(chCount), sampleRate: \(buf.format.sampleRate)")
                    return
                }
                
                // Update meters directly from hardware buffer (avoids format creation issues)
                self.pushMeters(from: buf)
                
                // Extract channels for recording (this may fail format creation, but we'll try)
                let extracted = self.extractChannels(buffer: buf, channels: Array(channelsToUse))
                
                // Only send to callback if extraction succeeded and has correct channel count
                if extracted.frameLength > 0 && Int(extracted.format.channelCount) >= requiredChannels {
                    self.onBufferReceived?(extracted)
                } else {
                    // If extraction failed, log but don't crash
                    if self.meterDecimateCounter < 5 {
                        print("⚠️ AVAudioEngine (Recording): Extraction failed or wrong channel count - extracted: \(extracted.format.channelCount), required: \(requiredChannels)")
                    }
                }
            }
            
            // Start engine
            try engine.start()
            
            DispatchQueue.main.async { [weak self] in
                self?.currentSampleRate = hw.sampleRate
            }
            self.isRecordingActive = true
            
            print("✅ AVAudioEngine: Recording started - sampleRate: \(hw.sampleRate)Hz")
        }
    }
    
    func stop() {
        audioQueue.sync {
            isRecordingActive = false
            if engine.isRunning {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
        }
    }
    
    func checkMicrophonePermission() {
        #if os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DispatchQueue.main.async { [weak self] in
            self?.hasMicrophonePermission = (status == .authorized)
        }
        #else
        // iOS handles permissions via Info.plist and system prompts
        DispatchQueue.main.async { [weak self] in
            self?.hasMicrophonePermission = true
        }
        #endif
    }
    
    func requestMicrophonePermission() {
        #if os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            DispatchQueue.main.async { [weak self] in
                self?.hasMicrophonePermission = true
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasMicrophonePermission = granted
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.hasMicrophonePermission = false
            }
        @unknown default:
            DispatchQueue.main.async { [weak self] in
                self?.hasMicrophonePermission = false
            }
        }
        #else
        // iOS handles permissions automatically via Info.plist
        checkMicrophonePermission()
        #endif
    }
}

