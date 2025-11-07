import Foundation
import Accelerate
import AVFoundation

final class IRKit: ObservableObject {
    @Published var selectedOutputChannels: [Int] = [1, 2]
    // Generate exponential sine sweep
    func generateESS(sr: Double, seconds: Double, f0: Double, f1: Double) -> [Float] {
        let N = Int(sr * seconds)
        var y = [Float](repeating: 0, count: N)
        let L = log(f1/f0)
        for n in 0..<N {
            let t = Double(n)/sr
            let phi = 2.0 * .pi * f0 * seconds / L * (exp(t * L / seconds) - 1.0)
            y[n] = Float(sin(phi))
        }
        return y
    }

    // Inverse filter for ESS (time-reverse with amplitude pre-emphasis)
    func inverseESS(sweep: [Float], sr: Double, seconds: Double, f0: Double, f1: Double) -> [Float] {
        let N = sweep.count
        let L = log(f1/f0)
        var inv = [Float](repeating: 0, count: N)
        for n in 0..<N {
            let t = Double(N-1-n)/sr
            let w = Float(exp(t * L / seconds)) // amplitude correction
            inv[n] = sweep[N-1-n] * w
        }
        return inv
    }

    // FFT-based deconvolution with windowing, normalization, and peak alignment
    func deconvolve(recorded: [Float], inverse: [Float]) -> [Float] {
        let N = 1 << Int(ceil(log2(Double(recorded.count + inverse.count - 1))))
        var a = recorded + [Float](repeating: 0, count: N - recorded.count)
        var b = inverse + [Float](repeating: 0, count: N - inverse.count)

        var splitAReal = [Float](repeating: 0, count: N/2)
        var splitAImag = [Float](repeating: 0, count: N/2)
        var splitBReal = [Float](repeating: 0, count: N/2)
        var splitBImag = [Float](repeating: 0, count: N/2)

        var tempA = DSPSplitComplex(realp: &splitAReal, imagp: &splitAImag)
        var tempB = DSPSplitComplex(realp: &splitBReal, imagp: &splitBImag)

        a.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            let buf = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(buf.baseAddress!, 2, &tempA, 1, vDSP_Length(N/2))
        }
        b.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            let buf = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(buf.baseAddress!, 2, &tempB, 1, vDSP_Length(N/2))
        }

        let log2n = vDSP_Length(log2(Double(N)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(FFT_RADIX2)) else { return recorded }
        vDSP_fft_zrip(setup, &tempA, 1, log2n, FFTDirection(FFT_FORWARD))
        vDSP_fft_zrip(setup, &tempB, 1, log2n, FFTDirection(FFT_FORWARD))

        // Complex multiply: A * B (deconvolution: divide by inverse filter in frequency domain)
        var outReal = [Float](repeating: 0, count: N/2)
        var outImag = [Float](repeating: 0, count: N/2)
        var out = DSPSplitComplex(realp: &outReal, imagp: &outImag)
        vDSP_zvmul(&tempA, 1, &tempB, 1, &out, 1, vDSP_Length(N/2), 1)

        // IFFT
        vDSP_fft_zrip(setup, &out, 1, log2n, FFTDirection(FFT_INVERSE))

        // Scale by 1/N
        var scale = Float(1.0 / Float(N))
        var result = [Float](repeating: 0, count: N)
        result.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            var cplxPtr = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ztoc(&out, 1, &cplxPtr.baseAddress!, 2, vDSP_Length(N/2))
        }
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(N))

        vDSP_destroy_fftsetup(setup)
        
        // Find main peak and align
        var maxVal: Float = 0
        var maxIdx: vDSP_Length = 0
        vDSP_maxvi(result, 1, &maxVal, &maxIdx, vDSP_Length(result.count))
        
        // Extract window around peak (keep 2 seconds after peak, 0.1s before)
        let sr = 48000.0
        let preSamples = Int(sr * 0.1)
        let postSamples = Int(sr * 2.0)
        let startIdx = max(0, Int(maxIdx) - preSamples)
        let endIdx = min(result.count, Int(maxIdx) + postSamples)
        var windowed = Array(result[startIdx..<endIdx])
        
        // Normalize to peak = 1.0
        if maxVal > 0 {
            let norm = 1.0 / maxVal
            vDSP_vsmul(windowed, 1, &norm, &windowed, 1, vDSP_Length(windowed.count))
        }
        
        // Apply exponential decay window to reduce noise tail
        let decayTime = 1.0 // seconds
        let decaySamples = Int(sr * decayTime)
        for i in 0..<windowed.count {
            if i > preSamples {
                let t = Double(i - preSamples) / sr
                let w = exp(-t / decayTime)
                windowed[i] *= Float(w)
            }
        }
        
        return windowed
    }

    // Process sweep and return IRs for all channels
    func runSweep(seconds: Double, f0: Double, f1: Double) -> [[Float]] {
        let sr = 48000.0
        let sweep = generateESS(sr: sr, seconds: seconds, f0: f0, f1: f1)
        let inv = inverseESS(sweep: sweep, sr: sr, seconds: seconds, f0: f0, f1: f1)

        // In lieu of live capture, demo deconvolution using a mocked IR (Dirac)
        var mockIR = [Float](repeating: 0, count: 512)
        mockIR[16] = 1.0
        // Simulate recorded sweep (convolve with mock IR)
        let sim = deconvolve(recorded: sweep, inverse: mockIR)
        let rec = sim // pretend this is recorded
        
        // Deconvolve to get IR (for demo, return 4 channels with slight variations)
        let ir0 = deconvolve(recorded: rec, inverse: inv)
        var irs: [[Float]] = [ir0]
        for ch in 1..<4 {
            // Add slight delay variation per channel
            var ir = [Float](repeating: 0, count: ir0.count)
            let offset = ch * 10
            for i in 0..<ir0.count {
                if i + offset < ir0.count {
                    ir[i + offset] = ir0[i] * Float(0.9 + Double(ch) * 0.05)
                }
            }
            irs.append(ir)
        }
        return irs
    }
    
    // Export mono IR
    func exportMonoIR(_ ir: [Float], sampleRate: Double, to url: URL) throws {
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(ir.count))!
        buf.frameLength = AVAudioFrameCount(ir.count)
        ir.withUnsafeBufferPointer { ptr in
            buf.floatChannelData![0].assign(from: ptr.baseAddress!, count: ir.count)
        }
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        try file.write(from: buf)
    }
    
    // Export stereo IR (2 channels)
    func exportStereoIR(_ irs: [[Float]], sampleRate: Double, to url: URL) throws {
        guard irs.count >= 2 else { throw NSError(domain: "IRKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Need at least 2 channels"]) }
        let maxLen = irs.map { $0.count }.max() ?? 0
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false)!
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(maxLen))!
        buf.frameLength = AVAudioFrameCount(maxLen)
        for ch in 0..<2 {
            let src = irs[ch]
            let dst = buf.floatChannelData![ch]
            for i in 0..<min(src.count, maxLen) {
                dst[i] = src[i]
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        try file.write(from: buf)
    }
    
    // Export true-stereo IR (4 channels, A-format)
    func exportTrueStereoIR(_ irs: [[Float]], sampleRate: Double, to url: URL) throws {
        guard irs.count >= 4 else { throw NSError(domain: "IRKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Need 4 channels"]) }
        let maxLen = irs.map { $0.count }.max() ?? 0
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(maxLen))!
        buf.frameLength = AVAudioFrameCount(maxLen)
        for ch in 0..<4 {
            let src = irs[ch]
            let dst = buf.floatChannelData![ch]
            for i in 0..<min(src.count, maxLen) {
                dst[i] = src[i]
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        try file.write(from: buf)
    }
    
    // Export FOA IR (B-format, AmbiX W,Y,Z,X)
    func exportFOAIR(_ irs: [[Float]], sampleRate: Double, dsp: AmbisonicsDSP, to url: URL) throws {
        guard irs.count >= 4 else { throw NSError(domain: "IRKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Need 4 channels"]) }
        let maxLen = irs.map { $0.count }.max() ?? 0
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
        let aBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(maxLen))!
        aBuf.frameLength = AVAudioFrameCount(maxLen)
        for ch in 0..<4 {
            let src = irs[ch]
            let dst = aBuf.floatChannelData![ch]
            for i in 0..<min(src.count, maxLen) {
                dst[i] = src[i]
            }
        }
        // Convert A->B
        let bBuf = dsp.processAtoB(aBuffer: aBuf)
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        try file.write(from: bBuf)
    }
}
