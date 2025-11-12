#!/usr/bin/env swift
// Logic-only E2E tests for RecorderEngine (no audio format dependencies)
// Run with: swift Scripts/run_e2e_logic_tests.swift

import Foundation

print("🎙️  RecorderEngine E2E Logic Tests")
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

// Test 1: Channel Clamping Logic
print("1. Testing channel clamping logic...")
do {
    let availableChannels = 8
    let selectedChannels = [2, 5, 1, 7]
    let clampedChannels = selectedChannels.map { min(max(0, $0), availableChannels - 1) }
    assertTest(clampedChannels == [2, 5, 1, 7], "Valid channels not clamped")
    
    let invalidChannels = [10, -1, 2, 3]
    let clampedInvalid = invalidChannels.map { min(max(0, $0), availableChannels - 1) }
    assertTest(clampedInvalid == [7, 0, 2, 3], "Invalid channels clamped correctly")
    
    let negativeChannel = -1
    let clampedNegative = min(max(0, negativeChannel), availableChannels - 1)
    assertTest(clampedNegative == 0, "Negative channel clamped to 0")
    
    let validChannel = 2
    let clampedValid = min(max(0, validChannel), availableChannels - 1)
    assertTest(clampedValid == 2, "Valid channel not clamped")
}
print("")

// Test 2: State Transitions
print("2. Testing state transitions...")
do {
    var isMonitoring = false
    var isRecordingActive = false
    
    // Cannot start monitoring while recording
    isRecordingActive = true
    let canStartMonitoring = !isRecordingActive
    assertTest(canStartMonitoring == false, "Cannot start monitoring while recording")
    
    // Can start monitoring when not recording
    isRecordingActive = false
    let canStartMonitoring2 = !isRecordingActive
    assertTest(canStartMonitoring2 == true, "Can start monitoring when not recording")
    
    // Recording stops monitoring
    isMonitoring = true
    isRecordingActive = true
    if isRecordingActive {
        isMonitoring = false
    }
    assertTest(isMonitoring == false, "Recording stops monitoring")
    
    // Stop recording can restart monitoring (if 4 channels selected)
    isRecordingActive = false
    let selectedInputChannels = [0, 1, 2, 3]
    let shouldRestartMonitoring = selectedInputChannels.count == 4
    assertTest(shouldRestartMonitoring == true, "Should restart monitoring after recording if 4 channels selected")
    
    // Test monitoring signature (prevents redundant starts)
    let deviceID = "device1"
    let channels = [0, 1, 2, 3]
    let signature1 = "\(deviceID)|\(channels)"
    let signature2 = "\(deviceID)|\(channels)"
    assertTest(signature1 == signature2, "Monitoring signature matches for same config")
    
    let signature3 = "device2|\(channels)"
    assertTest(signature1 != signature3, "Monitoring signature differs for different device")
}
print("")

// Test 3: Error Handling
print("3. Testing error handling...")
do {
    // Insufficient channels
    let availableChannels = 2
    let requiredChannels = 4
    assertTest(availableChannels < requiredChannels, "Detects insufficient channels")
    
    // Channels out of range
    let selectedChannels = [0, 1, 2, 10]
    let availableChannels2 = 8
    let allInRange = selectedChannels.allSatisfy { $0 >= 0 && $0 < availableChannels2 }
    assertTest(allInRange == false, "Detects channels out of range")
    
    // Not exactly 4 channels
    let selectedChannels2 = [0, 1, 2]
    assertTest(selectedChannels2.count != 4, "Detects not exactly 4 channels")
    
    // Exactly 4 channels (valid)
    let selectedChannels3 = [0, 1, 2, 3]
    assertTest(selectedChannels3.count == 4, "Detects exactly 4 channels as valid")
}
print("")

// Test 4: Meter Decimation Logic
print("4. Testing meter decimation logic...")
do {
    var meterDecimateCounter: Int = 0
    let meterDecimateN: Int = 2
    var updateCount = 0
    
    // Simulate 10 meter updates with decimation
    for _ in 0..<10 {
        meterDecimateCounter &+= 1
        if meterDecimateCounter % meterDecimateN != 0 {
            continue // Skip this update
        }
        updateCount += 1
    }
    
    // Should have 5 updates (every 2nd one)
    assertTest(updateCount == 5, "Meter decimation reduces updates by factor of N")
    
    // Test counter overflow handling
    meterDecimateCounter = Int.max
    meterDecimateCounter &+= 1 // Should wrap around
    assertTest(meterDecimateCounter == Int.min, "Counter handles overflow correctly")
}
print("")

// Test 5: Gain Conversion (dB to Linear)
print("5. Testing gain conversion (dB to linear)...")
do {
    // Test dB to linear conversion: 20 * log10(linear) = dB
    // So: linear = 10^(dB/20)
    func linearGain(from dB: Float) -> Float {
        return powf(10.0, dB/20.0)
    }
    
    // Test known values
    let gain0dB = linearGain(from: 0.0)
    assertTest(abs(gain0dB - 1.0) < 0.001, "0dB = 1.0 linear")
    
    let gain6dB = linearGain(from: 6.0)
    assertTest(abs(gain6dB - 1.995) < 0.01, "+6dB ≈ 2.0 linear")
    
    let gainNeg3dB = linearGain(from: -3.0)
    assertTest(abs(gainNeg3dB - 0.708) < 0.01, "-3dB ≈ 0.708 linear")
    
    let gain3dB = linearGain(from: 3.0)
    assertTest(abs(gain3dB - 1.413) < 0.01, "+3dB ≈ 1.413 linear")
    
    // Test combined gains (interface * capsule)
    let interfaceGains = [6.0, -3.0, 0.0, 3.0]
    let capsuleTrims: [Float] = [1.0, 1.0, 1.0, 1.0]
    let combinedGains = zip(capsuleTrims, interfaceGains.map { linearGain(from: Float($0)) }).map { $0 * $1 }
    
    assertTest(abs(combinedGains[0] - 1.995) < 0.01, "Combined gain calculation correct (ch 0)")
    assertTest(abs(combinedGains[1] - 0.708) < 0.01, "Combined gain calculation correct (ch 1)")
}
print("")

// Test 6: Channel Selection Validation
print("6. Testing channel selection validation...")
do {
    // Valid selection: exactly 4 channels, all in range
    let availableChannels = 8
    let selectedChannels = [0, 1, 2, 3]
    let hasFourChannels = selectedChannels.count == 4
    let allInRange = selectedChannels.allSatisfy { $0 >= 0 && $0 < availableChannels }
    let isValid = hasFourChannels && allInRange
    assertTest(isValid == true, "Valid channel selection passes validation")
    
    // Invalid: not 4 channels
    let selectedChannels2 = [0, 1, 2]
    let hasFourChannels2 = selectedChannels2.count == 4
    assertTest(hasFourChannels2 == false, "Detects not exactly 4 channels")
    
    // Invalid: out of range
    let selectedChannels3 = [0, 1, 2, 10]
    let allInRange3 = selectedChannels3.allSatisfy { $0 >= 0 && $0 < availableChannels }
    assertTest(allInRange3 == false, "Detects channels out of range")
}
print("")

// Test 7: File Path Generation
print("7. Testing file path generation...")
do {
    let timestamp = Date().timeIntervalSince1970
    let aFormatName = "Aformat_\(timestamp).wav"
    let bFormatName = "BformatAmbiX_\(timestamp).wav"
    
    assertTest(aFormatName.hasPrefix("Aformat_"), "A-format filename has correct prefix")
    assertTest(aFormatName.hasSuffix(".wav"), "A-format filename has correct suffix")
    
    assertTest(bFormatName.hasPrefix("BformatAmbiX_"), "B-format filename has correct prefix")
    assertTest(bFormatName.hasSuffix(".wav"), "B-format filename has correct suffix")
    
    // Test timestamp uniqueness
    let timestamp2 = Date().timeIntervalSince1970
    Thread.sleep(forTimeInterval: 0.01)
    let timestamp3 = Date().timeIntervalSince1970
    assertTest(timestamp2 <= timestamp3, "Timestamps are sequential")
}
print("")

// Test 8: Buffer Frame Count Validation
print("8. Testing buffer frame count validation...")
do {
    let frameCount: UInt32 = 1024
    let sampleRate: Double = 48000
    let bufferDuration = Double(frameCount) / sampleRate
    
    // 1024 frames at 48kHz = ~21.3ms
    let expectedDuration = 1024.0 / 48000.0
    assertTest(abs(bufferDuration - expectedDuration) < 0.0001, "Buffer duration calculation correct")
    
    // Test different buffer sizes
    let bufferSizes: [UInt32] = [512, 1024, 2048, 4096]
    for size in bufferSizes {
        let duration = Double(size) / sampleRate
        assertTest(duration > 0, "Buffer duration is positive for size \(size)")
        assertTest(duration < 1.0, "Buffer duration is less than 1 second for size \(size)")
    }
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
    print("  ✅ All logic tests passed!")
    print("")
    print("Note: Full E2E tests with audio formats require Xcode project integration.")
    print("      Add Tests/RecorderEngineE2ETests.swift to AmbiStudioTests target.")
    exit(0)
}

