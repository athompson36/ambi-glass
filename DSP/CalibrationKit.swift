import Foundation
import AVFoundation
import Accelerate

final class CalibrationKit: ObservableObject {
    @Published var latencyMs: Double = 0
    @Published var channelGains: [Double] = [0,0,0,0]
    @Published var lastProfile: InterfaceProfile? = nil

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 48000
    private let bufferFrames: AVAudioFrameCount = 1024

    func runLoopbackTest() {
        // Offline simulation for testing: generate sweep, simulate delay/gain, estimate
        let seconds = 5.0
        let N = Int(sampleRate * seconds)
        let sweep = IRKit().generateESS(sr: sampleRate, seconds: seconds, f0: 20, f1: 20000)
        // Simulate per-channel delay (samples) and gains (dB)
        let delays = [Int(240), 260, 250, 255]
        let gainsDB: [Double] = [0.0, -0.1, 0.2, -0.05]
        var recorded: [[Float]] = (0..<4).map { _ in [Float](repeating: 0, count: N + 1024) }
        for ch in 0..<4 {
            let g = powf(10.0, Float(gainsDB[ch])/20.0)
            for i in 0..<N {
                recorded[ch][i+delays[ch]] = sweep[i] * g
            }
        }
        // Estimate latency using cross-correlation on channel 0
        let estSamp = estimateDelay(reference: sweep, recorded: recorded[0])
        let ms = Double(estSamp) * 1000.0 / sampleRate
        DispatchQueue.main.async {
            self.latencyMs = ms
            self.channelGains = gainsDB
        }
        // Persist a profile
        let profile = InterfaceProfile(deviceId: "default", sampleRate: sampleRate, bufferFrames: Int(bufferFrames), ioLatencyMs: ms, channelGains_dB: gainsDB, createdAt: Date())
        ProfileStore.shared.saveInterfaceProfile(profile)
        DispatchQueue.main.async { self.lastProfile = profile }
    }

    // Estimate delay (in samples) by finding maximum of cross-correlation
    // Internal for testing
    func estimateDelay(reference: [Float], recorded: [Float]) -> Int {
        let n = 1 << Int(ceil(log2(Double(reference.count + recorded.count - 1))))
        var a = reference + [Float](repeating: 0, count: n - reference.count)
        var b = recorded + [Float](repeating: 0, count: n - recorded.count)

        var ra = [Float](repeating: 0, count: n/2)
        var ia = [Float](repeating: 0, count: n/2)
        var rb = [Float](repeating: 0, count: n/2)
        var ib = [Float](repeating: 0, count: n/2)
        var A = DSPSplitComplex(realp: &ra, imagp: &ia)
        var B = DSPSplitComplex(realp: &rb, imagp: &ib)

        a.withUnsafeMutableBytes { ptr in
            let c = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(c.baseAddress!, 2, &A, 1, vDSP_Length(n/2))
        }
        b.withUnsafeMutableBytes { ptr in
            let c = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(c.baseAddress!, 2, &B, 1, vDSP_Length(n/2))
        }

        let log2n = vDSP_Length(log2(Double(n)))
        let setup = vDSP_create_fftsetup(log2n, FFTRadix(FFT_RADIX2))!
        vDSP_fft_zrip(setup, &A, 1, log2n, FFTDirection(FFT_FORWARD))
        vDSP_fft_zrip(setup, &B, 1, log2n, FFTDirection(FFT_FORWARD))

        // Cross-power spectrum: A * conj(B)
        var outR = [Float](repeating: 0, count: n/2)
        var outI = [Float](repeating: 0, count: n/2)
        var OUT = DSPSplitComplex(realp: &outR, imagp: &outI)
        var conjB = DSPSplitComplex(realp: B.realp, imagp: B.imagp)
        vDSP_zvneg(B.imagp, 1, conjB.imagp, 1, vDSP_Length(n/2))
        vDSP_zvmul(&A, 1, &conjB, 1, &OUT, 1, vDSP_Length(n/2), 1)

        // IFFT to get correlation
        vDSP_fft_zrip(setup, &OUT, 1, log2n, FFTDirection(FFT_INVERSE))

        var result = [Float](repeating: 0, count: n)
        result.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            var c = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ztoc(&OUT, 1, &c.baseAddress!, 2, vDSP_Length(n/2))
        }
        var scale = 1.0/Float(n)
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(n))
        vDSP_destroy_fftsetup(setup)

        // Find peak index
        var maxVal: Float = 0
        var maxIdx: vDSP_Length = 0
        vDSP_maxvi(result, 1, &maxVal, &maxIdx, vDSP_Length(result.count))
        return Int(maxIdx)
    }
}
