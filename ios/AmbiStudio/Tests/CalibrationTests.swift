import Foundation
import Accelerate
import Testing
@testable import AmbiStudio

struct CalibrationTests {
    
    // Calibration tests with injected delays and gains
    @Test func testCalibrationLatency() async throws {
        let calibrator = CalibrationKit()
        let sampleRate: Double = 48000
        
        // Create test sweep
        let irkit = IRKit()
        let sweep = irkit.generateESS(sr: sampleRate, seconds: 2.0, f0: 20, f1: 20000)
        
        // Inject known delay (240 samples = 5ms at 48kHz)
        let injectedDelay = 240
        var delayed = [Float](repeating: 0, count: sweep.count + 500)
        for i in 0..<sweep.count {
            if i + injectedDelay < delayed.count {
                delayed[i + injectedDelay] = sweep[i]
            }
        }
        
        // Estimate delay using cross-correlation
        let estimated = calibrator.estimateDelay(reference: sweep, recorded: delayed)
        
        // Should be within ±20 samples of injected delay (FFT padding can cause slight shifts)
        #expect(abs(estimated - injectedDelay) < 20, "Latency estimation should be accurate")
    }
    
    @Test func testCalibrationGains() async throws {
        // Test gain calculation
        let gainsDB: [Double] = [0.0, -0.1, 0.2, -0.05]
        let gainsLinear = gainsDB.map { pow(10.0, $0/20.0) }
        
        // Verify linear conversion
        #expect(abs(gainsLinear[0] - 1.0) < 0.001, "0 dB should be 1.0 linear")
        #expect(gainsLinear[1] < 1.0, "-0.1 dB should be < 1.0")
        #expect(gainsLinear[2] > 1.0, "0.2 dB should be > 1.0")
    }
}

