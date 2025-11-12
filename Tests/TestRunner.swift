import Foundation

// Test runner for all unit tests
func runAllTests() {
    print("🧪 Running AmbiGlass Unit Tests\n")
    
    // DSP Tests
    print("📊 DSP Tests:")
    runAllDSPTests()
    print()
    
    // IR Tests
    print("📈 IR Tests:")
    runAllIRTests()
    print()
    
    // Calibration Tests
    print("🔧 Calibration Tests:")
    runAllCalibrationTests()
    print()
    
    // Calibration Curve Test
    print("📉 Calibration Curve Test:")
    testCalibrationCurvePreview()
    print()
    
    // RecorderEngine E2E Tests
    print("🎙️  RecorderEngine E2E Tests:")
    runAllRecorderEngineE2ETests()
    print()
    
    // Audio Module Tests
    print("🎙️  Audio Module Tests:")
    runAllAudioModuleTests()
    print()
    
    print("✅ All tests completed successfully!")
}

// Run tests if executed directly
if CommandLine.arguments.contains("--test") {
    runAllTests()
}

