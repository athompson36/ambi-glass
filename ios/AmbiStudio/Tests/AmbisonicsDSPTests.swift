import Foundation
import AVFoundation
import Accelerate

// Unit tests for A->B mapping with synthetic impulses
func testAtoBMapping() {
    print("Testing A->B mapping with synthetic impulses...")
    
    let dsp = AmbisonicsDSP()
    let sampleRate: Double = 48000
    let frameCount = 1024
    
    // Create test buffer with impulse on channel 0
    let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
    let aBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frameCount))!
    aBuf.frameLength = AVAudioFrameCount(frameCount)
    
    // Set impulse on channel 0 at sample 100
    aBuf.floatChannelData![0][100] = 1.0
    aBuf.floatChannelData![1][100] = 0.0
    aBuf.floatChannelData![2][100] = 0.0
    aBuf.floatChannelData![3][100] = 0.0
    
    // Process A->B
    let bBuf = dsp.processAtoB(aBuffer: aBuf)
    
    // Verify output has 4 channels
    assert(bBuf.format.channelCount == 4, "B-format should have 4 channels")
    assert(bBuf.frameLength == aBuf.frameLength, "Frame length should match")
    
    // With identity matrix, W should equal A0
    let matrix = dsp.matrix.m
    let expectedW = matrix[0] * 1.0 + matrix[1] * 0.0 + matrix[2] * 0.0 + matrix[3] * 0.0
    let actualW = bBuf.floatChannelData![0][100]
    
    assert(abs(actualW - expectedW) < 0.001, "W channel should match matrix calculation")
    
    // Test with impulse on channel 1
    aBuf.floatChannelData![0][100] = 0.0
    aBuf.floatChannelData![1][100] = 1.0
    let bBuf2 = dsp.processAtoB(aBuffer: aBuf)
    let expectedW2 = matrix[4] * 1.0 // A1 contribution to W
    let actualW2 = bBuf2.floatChannelData![0][100]
    
    assert(abs(actualW2 - expectedW2) < 0.001, "W channel should match matrix calculation for A1")
    
    print("✅ A->B mapping test passed")
}

func testOrientationTransform() {
    print("Testing orientation transform...")
    
    let dsp = AmbisonicsDSP()
    let sampleRate: Double = 48000
    let frameCount = 1024
    
    // Create test buffer
    let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
    let aBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frameCount))!
    aBuf.frameLength = AVAudioFrameCount(frameCount)
    
    // Set test signal
    aBuf.floatChannelData![0][100] = 1.0
    aBuf.floatChannelData![1][100] = 0.0
    aBuf.floatChannelData![2][100] = 0.0
    aBuf.floatChannelData![3][100] = 0.0
    
    // Process without orientation
    let bBuf1 = dsp.processAtoB(aBuffer: aBuf)
    let w1 = bBuf1.floatChannelData![0][100]
    
    // Apply 90 degree yaw rotation
    dsp.setOrientationDegrees(yaw: 90, pitch: 0, roll: 0)
    let bBuf2 = dsp.processAtoB(aBuffer: aBuf)
    let w2 = bBuf2.floatChannelData![0][100]
    
    // W should remain unchanged (omnidirectional)
    assert(abs(w1 - w2) < 0.001, "W channel should be unchanged by rotation")
    
    // X and Y should swap with 90 degree yaw
    let x1 = bBuf1.floatChannelData![3][100]
    let y1 = bBuf1.floatChannelData![1][100]
    let x2 = bBuf2.floatChannelData![3][100]
    let y2 = bBuf2.floatChannelData![1][100]
    
    // With 90 degree yaw: X' = -Y, Y' = X
    assert(abs(x2 + y1) < 0.1 || abs(y2 - x1) < 0.1, "Orientation transform should rotate X/Y")
    
    print("✅ Orientation transform test passed")
}

func runAllDSPTests() {
    testAtoBMapping()
    testOrientationTransform()
    print("✅ All DSP tests passed")
}

