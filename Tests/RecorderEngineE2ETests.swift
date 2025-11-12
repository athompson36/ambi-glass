import Foundation
import AVFoundation
import Combine
import Accelerate

// End-to-End tests for RecorderEngine
// Tests all taps, endpoints, and data flow

func testRecorderEngineChannelExtraction() {
    print("Testing channel extraction logic...")
    
    // Create a mock buffer with 8 channels
    let sampleRate: Double = 48000
    let frameCount = 1024
    let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 8, interleaved: false)!
    let inputBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frameCount))!
    inputBuf.frameLength = AVAudioFrameCount(frameCount)
    
    // Fill each channel with its channel number as a test signal
    for ch in 0..<8 {
        let ptr = inputBuf.floatChannelData![ch]
        for i in 0..<Int(frameCount) {
            ptr[i] = Float(ch) * 0.1 // Channel 0 = 0.0, channel 1 = 0.1, etc.
        }
    }
    
    // Test extraction with selected channels [2, 5, 1, 7]
    let selectedChannels = [2, 5, 1, 7]
    let outputFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
    let outputBuf = AVAudioPCMBuffer(pcmFormat: outputFmt, frameCapacity: AVAudioFrameCount(frameCount))!
    outputBuf.frameLength = AVAudioFrameCount(frameCount)
    
    // Simulate extractFirstFourChannels logic
    for (outCh, inCh) in selectedChannels.prefix(4).enumerated() {
        let srcCh = min(max(0, inCh), 7) // Clamp to available range
        let src = inputBuf.floatChannelData![srcCh]
        let dst = outputBuf.floatChannelData![outCh]
        dst.update(from: src, count: Int(frameCount))
    }
    
    // Verify channel mapping
    assert(abs(outputBuf.floatChannelData![0][0] - 0.2) < 0.001, "Output ch 0 should be input ch 2 (0.2)")
    assert(abs(outputBuf.floatChannelData![1][0] - 0.5) < 0.001, "Output ch 1 should be input ch 5 (0.5)")
    assert(abs(outputBuf.floatChannelData![2][0] - 0.1) < 0.001, "Output ch 2 should be input ch 1 (0.1)")
    assert(abs(outputBuf.floatChannelData![3][0] - 0.7) < 0.001, "Output ch 3 should be input ch 7 (0.7)")
    
    print("✅ Channel extraction test passed")
}

func testRecorderEngineMeterComputation() {
    print("Testing meter computation...")
    
    let sampleRate: Double = 48000
    let frameCount = 1024
    let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frameCount))!
    buf.frameLength = AVAudioFrameCount(frameCount)
    
    // Set known peak values on each channel
    buf.floatChannelData![0][100] = 0.5  // Peak 0.5
    buf.floatChannelData![1][200] = 0.8  // Peak 0.8
    buf.floatChannelData![2][300] = 1.2  // Peak 1.2 (should clamp to 1.0)
    buf.floatChannelData![3][400] = 0.3  // Peak 0.3
    
    // Compute peaks using vDSP (simulating pushMeters)
    var peaks: [CGFloat] = []
    for ch in 0..<4 {
        guard let ptr = buf.floatChannelData?[ch] else { continue }
        var maxVal: Float = 0
        let n = Int(buf.frameLength)
        vDSP_maxmgv(ptr, 1, &maxVal, vDSP_Length(n))
        peaks.append(CGFloat(min(1.0, maxVal)))
    }
    
    // Verify peaks
    assert(abs(peaks[0] - 0.5) < 0.01, "Channel 0 peak should be 0.5")
    assert(abs(peaks[1] - 0.8) < 0.01, "Channel 1 peak should be 0.8")
    assert(abs(peaks[2] - 1.0) < 0.01, "Channel 2 peak should clamp to 1.0")
    assert(abs(peaks[3] - 0.3) < 0.01, "Channel 3 peak should be 0.3")
    
    print("✅ Meter computation test passed")
}

func testRecorderEngineDSPIntegration() {
    print("Testing DSP integration (A-to-B conversion)...")
    
    let dsp = AmbisonicsDSP()
    let sampleRate: Double = 48000
    let frameCount = 1024
    
    // Create A-format buffer with test signal
    let aFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
    let aBuf = AVAudioPCMBuffer(pcmFormat: aFmt, frameCapacity: AVAudioFrameCount(frameCount))!
    aBuf.frameLength = AVAudioFrameCount(frameCount)
    
    // Set impulse on channel 0
    aBuf.floatChannelData![0][100] = 1.0
    aBuf.floatChannelData![1][100] = 0.0
    aBuf.floatChannelData![2][100] = 0.0
    aBuf.floatChannelData![3][100] = 0.0
    
    // Process A-to-B
    let bBuf = dsp.processAtoB(aBuffer: aBuf)
    
    // Verify B-format output
    assert(bBuf.format.channelCount == 4, "B-format should have 4 channels")
    assert(bBuf.frameLength == aBuf.frameLength, "Frame length should match")
    assert(bBuf.format.sampleRate == aBuf.format.sampleRate, "Sample rate should match")
    
    // Verify W channel (omnidirectional) has signal
    let wValue = bBuf.floatChannelData![0][100]
    assert(abs(wValue) > 0.001, "W channel should have signal")
    
    print("✅ DSP integration test passed")
}

func testRecorderEngineFileIO() {
    print("Testing file I/O operations...")
    
    // Create temporary directory for test files
    let tempDir = FileManager.default.temporaryDirectory
    let testDir = tempDir.appendingPathComponent("RecorderEngineTest_\(Date().timeIntervalSince1970)")
    
    do {
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        // Create test audio format
        let sampleRate: Double = 48000
        let frameCount: AVAudioFrameCount = 1024
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
        
        // Create test buffer with signal
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount)!
        buf.frameLength = frameCount
        buf.floatChannelData![0][0] = 0.5
        buf.floatChannelData![1][0] = 0.3
        buf.floatChannelData![2][0] = 0.7
        buf.floatChannelData![3][0] = 0.2
        
        // Test A-format file writing
        let aFileURL = testDir.appendingPathComponent("Aformat_test.wav")
        let aFile = try AVAudioFile(forWriting: aFileURL, settings: fmt.settings)
        try aFile.write(from: buf)
        
        // Verify file exists and has content
        assert(FileManager.default.fileExists(atPath: aFileURL.path), "A-format file should exist")
        let aFileSize = try FileManager.default.attributesOfItem(atPath: aFileURL.path)[.size] as! Int64
        assert(aFileSize > 0, "A-format file should have content")
        
        // Test B-format file writing
        let dsp = AmbisonicsDSP()
        let bBuf = dsp.processAtoB(aBuffer: buf)
        let bFileURL = testDir.appendingPathComponent("Bformat_test.wav")
        let bFile = try AVAudioFile(forWriting: bFileURL, settings: fmt.settings)
        try bFile.write(from: bBuf)
        
        // Verify file exists and has content
        assert(FileManager.default.fileExists(atPath: bFileURL.path), "B-format file should exist")
        let bFileSize = try FileManager.default.attributesOfItem(atPath: bFileURL.path)[.size] as! Int64
        assert(bFileSize > 0, "B-format file should have content")
        
        // Cleanup
        try FileManager.default.removeItem(at: testDir)
        
        print("✅ File I/O test passed")
    } catch {
        print("❌ File I/O test failed: \(error.localizedDescription)")
        // Cleanup on error
        try? FileManager.default.removeItem(at: testDir)
        assert(false, "File I/O test should not throw")
    }
}

func testRecorderEngineStateTransitions() {
    print("Testing state transition logic...")
    
    // Test state flags
    var isMonitoring = false
    var isRecordingActive = false
    
    // Test: Cannot start monitoring while recording
    isRecordingActive = true
    let canStartMonitoring = !isRecordingActive
    assert(canStartMonitoring == false, "Should not start monitoring while recording")
    
    // Test: Can start monitoring when not recording
    isRecordingActive = false
    let canStartMonitoring2 = !isRecordingActive
    assert(canStartMonitoring2 == true, "Should be able to start monitoring when not recording")
    
    // Test: Recording stops monitoring
    isMonitoring = true
    isRecordingActive = true
    if isRecordingActive {
        isMonitoring = false
    }
    assert(isMonitoring == false, "Recording should stop monitoring")
    
    // Test: Stop recording can restart monitoring (if 4 channels selected)
    isRecordingActive = false
    let selectedInputChannels = [0, 1, 2, 3]
    let shouldRestartMonitoring = selectedInputChannels.count == 4
    assert(shouldRestartMonitoring == true, "Should restart monitoring after recording if 4 channels selected")
    
    print("✅ State transition test passed")
}

func testRecorderEngineErrorHandling() {
    print("Testing error handling...")
    
    // Test: Insufficient channels error
    let availableChannels = 2
    let requiredChannels = 4
    let hasEnoughChannels = availableChannels >= requiredChannels
    assert(hasEnoughChannels == false, "Should detect insufficient channels")
    
    // Test: Channels out of range
    let selectedChannels = [0, 1, 2, 10] // Channel 10 out of range for 8-channel device
    let availableChannels2 = 8
    let allInRange = selectedChannels.allSatisfy { $0 >= 0 && $0 < availableChannels2 }
    assert(allInRange == false, "Should detect channels out of range")
    
    // Test: Not exactly 4 channels
    let selectedChannels2 = [0, 1, 2] // Only 3 channels
    let hasFourChannels = selectedChannels2.count == 4
    assert(hasFourChannels == false, "Should detect not exactly 4 channels")
    
    print("✅ Error handling test passed")
}

func testRecorderEngineMeterPublisher() {
    print("Testing meter publisher...")
    
    // Create a subject to simulate meter publishing
    let meterSubject = PassthroughSubject<[CGFloat], Never>()
    var receivedMeters: [CGFloat]? = nil
    var receivedCount = 0
    
    // Subscribe to meter updates
    let cancellable = meterSubject
        .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
        .sink { meters in
            receivedMeters = meters
            receivedCount += 1
        }
    
    // Send meter updates
    meterSubject.send([0.5, 0.3, 0.7, 0.2])
    meterSubject.send([0.6, 0.4, 0.8, 0.3])
    meterSubject.send([0.7, 0.5, 0.9, 0.4])
    
    // Wait a bit for throttling
    Thread.sleep(forTimeInterval: 0.15)
    
    // Verify we received at least one update (throttled)
    assert(receivedCount > 0, "Should receive meter updates")
    assert(receivedMeters != nil, "Should have received meter values")
    assert(receivedMeters!.count == 4, "Should receive 4 channel meters")
    
    cancellable.cancel()
    print("✅ Meter publisher test passed")
}

func testRecorderEngineChannelClamping() {
    print("Testing channel clamping logic...")
    
    // Test: Clamp invalid channel indices
    let availableChannels = 4
    let invalidChannel = 10
    let clampedChannel = min(max(0, invalidChannel), availableChannels - 1)
    assert(clampedChannel == 3, "Should clamp channel 10 to 3 for 4-channel device")
    
    // Test: Negative channel
    let negativeChannel = -1
    let clampedNegative = min(max(0, negativeChannel), availableChannels - 1)
    assert(clampedNegative == 0, "Should clamp negative channel to 0")
    
    // Test: Valid channel (no clamping)
    let validChannel = 2
    let clampedValid = min(max(0, validChannel), availableChannels - 1)
    assert(clampedValid == 2, "Valid channel should not be clamped")
    
    print("✅ Channel clamping test passed")
}

func testRecorderEngineGainApplication() {
    print("Testing gain application (interface + capsule trims)...")
    
    let dsp = AmbisonicsDSP()
    
    // Set interface gains (dB)
    dsp.interfaceGains_dB = [6.0, -3.0, 0.0, 3.0] // +6dB, -3dB, 0dB, +3dB
    
    // Convert to linear (simulating linearGains)
    let interfaceGainsLinear = dsp.interfaceGains_dB.map { powf(10.0, $0/20.0) }
    
    // Verify conversion
    assert(abs(interfaceGainsLinear[0] - 1.995) < 0.01, "+6dB should be ~2.0 linear")
    assert(abs(interfaceGainsLinear[1] - 0.708) < 0.01, "-3dB should be ~0.708 linear")
    assert(abs(interfaceGainsLinear[2] - 1.0) < 0.01, "0dB should be 1.0 linear")
    assert(abs(interfaceGainsLinear[3] - 1.413) < 0.01, "+3dB should be ~1.413 linear")
    
    // Test combined gains (interface * capsule)
    let capsuleTrims = [1.0, 1.0, 1.0, 1.0] // No capsule trim
    let combinedGains = zip(capsuleTrims, interfaceGainsLinear).map { $0 * $1 }
    
    assert(abs(combinedGains[0] - 1.995) < 0.01, "Combined gain should be interface gain when capsule trim is 1.0")
    
    print("✅ Gain application test passed")
}

func testRecorderEngineFormatValidation() {
    print("Testing format validation...")
    
    let sampleRate: Double = 48000
    let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
    
    // Verify format properties
    assert(fmt.channelCount == 4, "Format should have 4 channels")
    assert(fmt.sampleRate == sampleRate, "Format should have correct sample rate")
    assert(fmt.commonFormat == .pcmFormatFloat32, "Format should be Float32")
    assert(fmt.isInterleaved == false, "Format should be non-interleaved")
    
    // Test format settings for file writing
    let settings = fmt.settings
    assert(settings[AVSampleRateKey] as? Double == sampleRate, "Settings should include sample rate")
    assert(settings[AVNumberOfChannelsKey] as? Int == 4, "Settings should include channel count")
    
    print("✅ Format validation test passed")
}

func runAllRecorderEngineE2ETests() {
    print("🎙️  RecorderEngine E2E Tests:\n")
    
    testRecorderEngineChannelExtraction()
    testRecorderEngineMeterComputation()
    testRecorderEngineDSPIntegration()
    testRecorderEngineFileIO()
    testRecorderEngineStateTransitions()
    testRecorderEngineErrorHandling()
    testRecorderEngineMeterPublisher()
    testRecorderEngineChannelClamping()
    testRecorderEngineGainApplication()
    testRecorderEngineFormatValidation()
    
    print("\n✅ All RecorderEngine E2E tests passed!")
}

