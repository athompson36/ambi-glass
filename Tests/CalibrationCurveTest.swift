import Foundation

// Simple test to verify calibration curve preview logic
func testCalibrationCurvePreview() {
    // Create a test curve
    let testFreqs: [Double] = [20, 100, 1000, 5000, 20000]
    let testGains: [Double] = [-2.0, -1.0, 0.0, 0.5, 1.0]
    let curve = MicCalCurve(freqs: testFreqs, gains: testGains)
    
    // Test interpolation
    assert(curve.gainAt(freq: 50) >= -2.0 && curve.gainAt(freq: 50) <= -1.0, "Interpolation test 1")
    assert(curve.gainAt(freq: 500) >= -1.0 && curve.gainAt(freq: 500) <= 0.0, "Interpolation test 2")
    assert(curve.gainAt(freq: 10000) >= 0.5 && curve.gainAt(freq: 10000) <= 1.0, "Interpolation test 3")
    
    // Test edge cases
    assert(curve.gainAt(freq: 10) == testGains.first, "Edge case: below range")
    assert(curve.gainAt(freq: 30000) == testGains.last, "Edge case: above range")
    
    print("✅ Calibration curve preview test passed")
}

