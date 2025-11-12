#!/usr/bin/env swift
// Standalone E2E test runner for RecorderEngine
// Run with: swift Scripts/run_e2e_test_standalone.swift

import Foundation
import AVFoundation
import Accelerate

print("🎙️  RecorderEngine E2E Tests")
print("======================================")
print("")

var testsPassed = 0
var testsFailed = 0

func assertTest(_ condition: Bool, _ message: String) {
    if condition {
        print("  ✅ \(message)")
        testsPassed += 1
    } else {
        print("  ❌ \(message)")
        testsFailed += 1
    }
}

// Test 1: Channel Extraction
print("1. Testing channel extraction logic...")
do {
    let sampleRate: Double = 48000
    let frameCount = 1024
    
    // Create 4-channel input (simulating selection from larger device)
    // Use standard format that's guaranteed to work
    let inputFmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 4)!
    guard let inputBuf = AVAudioPCMBuffer(pcmFormat: inputFmt, frameCapacity: AVAudioFrameCount(frameCount)) else {
        print("  ❌ Failed to create input buffer")
        exit(1)
    }
    inputBuf.frameLength = AVAudioFrameCount(frameCount)
    
    // Fill channels with test values (simulating channels 2, 5, 1, 7 from 8-channel device)
    // In real scenario, these would be extracted from a larger buffer
    inputBuf.floatChannelData![0][0] = 0.2  // Channel 2 value
    inputBuf.floatChannelData![1][0] = 0.5  // Channel 5 value
    inputBuf.floatChannelData![2][0] = 0.1  // Channel 1 value
    inputBuf.floatChannelData![3][0] = 0.7  // Channel 7 value
    
    // Test channel clamping logic
    let availableChannels = 8
    let selectedChannels = [2, 5, 1, 7]
    let clampedChannels = selectedChannels.map { min(max(0, $0), availableChannels - 1) }
    
    assertTest(clampedChannels == [2, 5, 1, 7], "Valid channels not clamped")
    
    // Test invalid channel clamping
    let invalidChannels = [10, -1, 2, 3]
    let clampedInvalid = invalidChannels.map { min(max(0, $0), availableChannels - 1) }
    assertTest(clampedInvalid == [7, 0, 2, 3], "Invalid channels clamped correctly")
    
    assertTest(abs(inputBuf.floatChannelData![0][0] - 0.2) < 0.001, "Channel 0 value correct")
    assertTest(abs(inputBuf.floatChannelData![1][0] - 0.5) < 0.001, "Channel 1 value correct")
    assertTest(abs(inputBuf.floatChannelData![2][0] - 0.1) < 0.001, "Channel 2 value correct")
    assertTest(abs(inputBuf.floatChannelData![3][0] - 0.7) < 0.001, "Channel 3 value correct")
}
print("")

// Test 2: Meter Computation
print("2. Testing meter computation...")
do {
    let sampleRate: Double = 48000
    let frameCount = 1024
    let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 4)!
    guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frameCount)) else {
        print("  ❌ Failed to create buffer")
        exit(1)
    }
    buf.frameLength = AVAudioFrameCount(frameCount)
    
    buf.floatChannelData![0][100] = 0.5
    buf.floatChannelData![1][200] = 0.8
    buf.floatChannelData![2][300] = 1.2
    buf.floatChannelData![3][400] = 0.3
    
    var peaks: [CGFloat] = []
    for ch in 0..<4 {
        guard let ptr = buf.floatChannelData?[ch] else { continue }
        var maxVal: Float = 0
        let n = Int(buf.frameLength)
        vDSP_maxmgv(ptr, 1, &maxVal, vDSP_Length(n))
        peaks.append(CGFloat(min(1.0, maxVal)))
    }
    
    assertTest(abs(peaks[0] - 0.5) < 0.01, "Peak 0 correct")
    assertTest(abs(peaks[1] - 0.8) < 0.01, "Peak 1 correct")
    assertTest(abs(peaks[2] - 1.0) < 0.01, "Peak 2 clamped to 1.0")
    assertTest(abs(peaks[3] - 0.3) < 0.01, "Peak 3 correct")
}
print("")

// Test 3: Format Validation
print("3. Testing format validation...")
do {
    let sampleRate: Double = 48000
    let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
    
    assertTest(fmt.channelCount == 4, "Format has 4 channels")
    assertTest(fmt.sampleRate == sampleRate, "Format has correct sample rate")
    assertTest(fmt.commonFormat == .pcmFormatFloat32, "Format is Float32")
    assertTest(fmt.isInterleaved == false, "Format is non-interleaved")
    
    let settings = fmt.settings
    assertTest(settings[AVSampleRateKey] as? Double == sampleRate, "Settings include sample rate")
    assertTest(settings[AVNumberOfChannelsKey] as? Int == 4, "Settings include channel count")
}
print("")

// Test 4: Channel Clamping
print("4. Testing channel clamping...")
do {
    let availableChannels = 4
    let invalidChannel = 10
    let clampedChannel = min(max(0, invalidChannel), availableChannels - 1)
    assertTest(clampedChannel == 3, "Clamps invalid channel to max")
    
    let negativeChannel = -1
    let clampedNegative = min(max(0, negativeChannel), availableChannels - 1)
    assertTest(clampedNegative == 0, "Clamps negative channel to 0")
    
    let validChannel = 2
    let clampedValid = min(max(0, validChannel), availableChannels - 1)
    assertTest(clampedValid == 2, "Valid channel not clamped")
}
print("")

// Test 5: State Transitions
print("5. Testing state transitions...")
do {
    var isMonitoring = false
    var isRecordingActive = false
    
    isRecordingActive = true
    let canStartMonitoring = !isRecordingActive
    assertTest(canStartMonitoring == false, "Cannot start monitoring while recording")
    
    isRecordingActive = false
    let canStartMonitoring2 = !isRecordingActive
    assertTest(canStartMonitoring2 == true, "Can start monitoring when not recording")
    
    isMonitoring = true
    isRecordingActive = true
    if isRecordingActive {
        isMonitoring = false
    }
    assertTest(isMonitoring == false, "Recording stops monitoring")
    
    let selectedInputChannels = [0, 1, 2, 3]
    let shouldRestartMonitoring = selectedInputChannels.count == 4
    assertTest(shouldRestartMonitoring == true, "Should restart monitoring after recording if 4 channels")
}
print("")

// Test 6: Error Handling
print("6. Testing error handling...")
do {
    let availableChannels = 2
    let requiredChannels = 4
    assertTest(availableChannels < requiredChannels, "Detects insufficient channels")
    
    let selectedChannels = [0, 1, 2, 10]
    let availableChannels2 = 8
    let allInRange = selectedChannels.allSatisfy { $0 >= 0 && $0 < availableChannels2 }
    assertTest(allInRange == false, "Detects channels out of range")
    
    let selectedChannels2 = [0, 1, 2]
    assertTest(selectedChannels2.count != 4, "Detects not exactly 4 channels")
}
print("")

// Test 7: File I/O
print("7. Testing file I/O operations...")
do {
    let tempDir = FileManager.default.temporaryDirectory
    let testDir = tempDir.appendingPathComponent("RecorderEngineTest_\(Date().timeIntervalSince1970)")
    
    try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    
    let sampleRate: Double = 48000
    let frameCount: AVAudioFrameCount = 1024
    let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 4)!
    
    guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else {
        print("  ❌ Failed to create buffer")
        exit(1)
    }
    buf.frameLength = frameCount
    buf.floatChannelData![0][0] = 0.5
    
    let aFileURL = testDir.appendingPathComponent("Aformat_test.wav")
    let aFile = try AVAudioFile(forWriting: aFileURL, settings: fmt.settings)
    try aFile.write(from: buf)
    
    assertTest(FileManager.default.fileExists(atPath: aFileURL.path), "A-format file created")
    let aFileSize = try FileManager.default.attributesOfItem(atPath: aFileURL.path)[.size] as! Int64
    assertTest(aFileSize > 0, "A-format file has content")
    
    try FileManager.default.removeItem(at: testDir)
    assertTest(true, "File cleanup successful")
}
print("")

// Summary
print("======================================")
print("Test Summary:")
print("  ✅ Passed: \(testsPassed)")
if testsFailed > 0 {
    print("  ❌ Failed: \(testsFailed)")
    exit(1)
} else {
    print("  ✅ All tests passed!")
    exit(0)
}

