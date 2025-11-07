import Foundation
import Testing
@testable import AmbiStudio

struct CalibrationCurveTest {
    
    // Simple test to verify calibration curve preview logic
    @Test func testCalibrationCurvePreview() async throws {
        // Create a test curve
        let testFreqs: [Double] = [20, 100, 1000, 5000, 20000]
        let testGains: [Double] = [-2.0, -1.0, 0.0, 0.5, 1.0]
        let curve = MicCalCurve(freqs: testFreqs, gains: testGains)
        
        // Test interpolation
        #expect(curve.gainAt(freq: 50) >= -2.0 && curve.gainAt(freq: 50) <= -1.0, "Interpolation test 1")
        #expect(curve.gainAt(freq: 500) >= -1.0 && curve.gainAt(freq: 500) <= 0.0, "Interpolation test 2")
        #expect(curve.gainAt(freq: 10000) >= 0.5 && curve.gainAt(freq: 10000) <= 1.0, "Interpolation test 3")
        
        // Test edge cases
        #expect(curve.gainAt(freq: 10) == testGains.first, "Edge case: below range")
        #expect(curve.gainAt(freq: 30000) == testGains.last, "Edge case: above range")
    }
}

