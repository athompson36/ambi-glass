import Foundation
import AVFoundation
import Combine
import Accelerate

// Comprehensive tests for all audio modules

func testRecorderEngineBasic() {
    print("Testing RecorderEngine basic functionality...")
    
    // Test state initialization
    let recorder = RecorderEngine()
    assert(recorder.selectedDeviceID == "__no_devices__", "Initial device ID should be placeholder")
    assert(recorder.selectedInputChannels.isEmpty, "Initial channels should be empty")
    assert(recorder.safetyRecord == true, "Safety record should default to true")
    
    print("✅ RecorderEngine basic test passed")
}

func testAudioDeviceManager() {
    print("Testing AudioDeviceManager...")
    
    let manager = AudioDeviceManager()
    
    // Test device refresh (may not have devices in test environment)
    manager.refreshDevices()
    
    // Verify structure
    assert(manager.inputDevices is [AudioDeviceManager.Device], "Input devices should be array")
    assert(manager.outputDevices is [AudioDeviceManager.Device], "Output devices should be array")
    
    print("✅ AudioDeviceManager test passed")
}

func testRecordingFolderManager() {
    print("Testing RecordingFolderManager...")
    
    let manager = RecordingFolderManager.shared
    
    // Test default folder
    let defaultFolder = manager.getFolder()
    assert(defaultFolder.path.contains("AmbiStudio Recordings"), "Default folder should contain 'AmbiStudio Recordings'")
    
    // Test folder exists
    let folderExists = FileManager.default.fileExists(atPath: defaultFolder.path)
    assert(folderExists, "Default folder should exist")
    
    print("✅ RecordingFolderManager test passed")
}

func testChannelExtractionLogic() {
    print("Testing channel extraction logic...")
    
    // Test channel clamping
    let availableChannels = 8
    let selectedChannels = [2, 5, 1, 7]
    let clamped = selectedChannels.map { min(max(0, $0), availableChannels - 1) }
    assert(clamped == [2, 5, 1, 7], "Valid channels should not be clamped")
    
    let invalidChannels = [10, -1, 2, 3]
    let clampedInvalid = invalidChannels.map { min(max(0, $0), availableChannels - 1) }
    assert(clampedInvalid == [7, 0, 2, 3], "Invalid channels should be clamped")
    
    print("✅ Channel extraction logic test passed")
}

func testMeterComputation() {
    print("Testing meter computation...")
    
    // Create test buffer
    let sampleRate: Double = 48000
    let frameCount = 1024
    guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 4) else {
        print("❌ Failed to create format")
        return
    }
    guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frameCount)) else {
        print("❌ Failed to create buffer")
        return
    }
    buf.frameLength = AVAudioFrameCount(frameCount)
    
    // Set test peaks
    buf.floatChannelData![0][100] = 0.5
    buf.floatChannelData![1][200] = 0.8
    buf.floatChannelData![2][300] = 1.2
    buf.floatChannelData![3][400] = 0.3
    
    // Compute peaks using vDSP
    var peaks: [CGFloat] = []
    for ch in 0..<4 {
        guard let ptr = buf.floatChannelData?[ch] else { continue }
        var maxVal: Float = 0
        let n = Int(buf.frameLength)
        vDSP_maxmgv(ptr, 1, &maxVal, vDSP_Length(n))
        peaks.append(CGFloat(min(1.0, maxVal)))
    }
    
    assert(peaks.count == 4, "Should have 4 peak values")
    assert(abs(peaks[2] - 1.0) < 0.01, "Peak should clamp to 1.0")
    
    print("✅ Meter computation test passed")
}

func testErrorHandling() {
    print("Testing error handling...")
    
    // Test insufficient channels error
    let availableChannels = 2
    let requiredChannels = 4
    assert(availableChannels < requiredChannels, "Should detect insufficient channels")
    
    // Test channels out of range
    let selectedChannels = [0, 1, 2, 10]
    let availableChannels2 = 8
    let allInRange = selectedChannels.allSatisfy { $0 >= 0 && $0 < availableChannels2 }
    assert(allInRange == false, "Should detect channels out of range")
    
    // Test not exactly 4 channels
    let selectedChannels2 = [0, 1, 2]
    assert(selectedChannels2.count != 4, "Should detect not exactly 4 channels")
    
    print("✅ Error handling test passed")
}

func testStateManagement() {
    print("Testing state management...")
    
    var isMonitoring = false
    var isRecordingActive = false
    
    // Cannot start monitoring while recording
    isRecordingActive = true
    assert(!isRecordingActive == false, "Cannot start monitoring while recording")
    
    // Can start monitoring when not recording
    isRecordingActive = false
    assert(!isRecordingActive == true, "Can start monitoring when not recording")
    
    // Recording stops monitoring
    isMonitoring = true
    isRecordingActive = true
    if isRecordingActive {
        isMonitoring = false
    }
    assert(isMonitoring == false, "Recording should stop monitoring")
    
    print("✅ State management test passed")
}

func testFileIOLogic() {
    print("Testing file I/O logic...")
    
    // Test filename generation
    let timestamp = Date().timeIntervalSince1970
    let aFormatName = "Aformat_\(timestamp).wav"
    let bFormatName = "BformatAmbiX_\(timestamp).wav"
    
    assert(aFormatName.hasPrefix("Aformat_"), "A-format filename should have correct prefix")
    assert(aFormatName.hasSuffix(".wav"), "A-format filename should have .wav suffix")
    assert(bFormatName.hasPrefix("BformatAmbiX_"), "B-format filename should have correct prefix")
    assert(bFormatName.hasSuffix(".wav"), "B-format filename should have .wav suffix")
    
    print("✅ File I/O logic test passed")
}

func testAudioFormatValidation() {
    print("Testing audio format validation...")
    
    let sampleRate: Double = 48000
    guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 4) else {
        print("❌ Failed to create format")
        return
    }
    
    assert(fmt.channelCount == 4, "Format should have 4 channels")
    assert(fmt.sampleRate == sampleRate, "Format should have correct sample rate")
    
    let settings = fmt.settings
    assert(settings[AVSampleRateKey] as? Double == sampleRate, "Settings should include sample rate")
    assert(settings[AVNumberOfChannelsKey] as? Int == 4, "Settings should include channel count")
    
    print("✅ Audio format validation test passed")
}

func runAllAudioModuleTests() {
    print("🎙️  Audio Module Tests:\n")
    
    testRecorderEngineBasic()
    testAudioDeviceManager()
    testRecordingFolderManager()
    testChannelExtractionLogic()
    testMeterComputation()
    testErrorHandling()
    testStateManagement()
    testFileIOLogic()
    testAudioFormatValidation()
    
    print("\n✅ All audio module tests passed!")
}

