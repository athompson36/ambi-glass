import Foundation
import Accelerate

// Offline test IR deconvolution with known IR
func testIRDeconvolution() {
    print("Testing IR deconvolution with known IR...")
    
    let irkit = IRKit()
    let sampleRate: Double = 48000
    let seconds = 2.0
    let f0: Double = 20
    let f1: Double = 20000
    
    // Generate sweep
    let sweep = irkit.generateESS(sr: sampleRate, seconds: seconds, f0: f0, f1: f1)
    assert(sweep.count == Int(sampleRate * seconds), "Sweep length should match")
    
    // Generate inverse
    let inv = irkit.inverseESS(sweep: sweep, sr: sampleRate, seconds: seconds, f0: f0, f1: f1)
    assert(inv.count == sweep.count, "Inverse length should match sweep")
    
    // Create a known test IR (Dirac at sample 100)
    var testIR = [Float](repeating: 0, count: 512)
    testIR[100] = 1.0
    
    // Simulate recording: convolve sweep with test IR
    // For simplicity, just shift the sweep
    var recorded = [Float](repeating: 0, count: sweep.count + 512)
    for i in 0..<sweep.count {
        if i + 100 < recorded.count {
            recorded[i + 100] = sweep[i]
        }
    }
    
    // Deconvolve
    let deconvolved = irkit.deconvolve(recorded: recorded, inverse: inv)
    
    // Find peak
    var maxVal: Float = 0
    var maxIdx: Int = 0
    for (i, val) in deconvolved.enumerated() {
        if abs(val) > abs(maxVal) {
            maxVal = val
            maxIdx = i
        }
    }
    
    // Peak should be around sample 100 (within reasonable tolerance)
    // Note: deconvolution includes windowing, so peak position may shift slightly
    assert(maxIdx >= 50 && maxIdx <= 150, "Deconvolved peak should be near original IR position")
    assert(abs(maxVal - 1.0) < 0.5, "Deconvolved peak should be normalized to ~1.0")
    
    print("✅ IR deconvolution test passed (peak at sample \(maxIdx), value \(maxVal))")
}

func runAllIRTests() {
    testIRDeconvolution()
    print("✅ All IR tests passed")
}

