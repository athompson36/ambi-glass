import Foundation
import AVFoundation
import Accelerate

final class Transcoder: ObservableObject {
    private var fourMono: [URL] = []
    private let dsp = AmbisonicsDSP()

    func handleFourMono(urls: [URL]) {
        fourMono = urls
        print("Queued 4 mono files: \\(urls.map{ $0.lastPathComponent })")
    }

    // Load four mono files, align length, pack into buffer
    private func loadFourMono(sampleRate: Double = 48000.0) throws -> AVAudioPCMBuffer {
        guard fourMono.count == 4 else { throw NSError(domain: "Transcoder", code: -1, userInfo: [NSLocalizedDescriptionKey:"Need 4 mono files"]) }
        let files = try fourMono.map { try AVAudioFile(forReading: $0) }
        let minFrames = files.map { Int($0.length) }.min() ?? 0
        guard minFrames > 0 else { throw NSError(domain: "Transcoder", code: -2, userInfo: [NSLocalizedDescriptionKey:"Empty files"]) }

        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
        let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(minFrames))!
        out.frameLength = AVAudioFrameCount(minFrames)

        for (i, f) in files.enumerated() {
            let monoFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: fmt.sampleRate, channels: 1, interleaved: false)!
            let buf = AVAudioPCMBuffer(pcmFormat: monoFmt, frameCapacity: AVAudioFrameCount(minFrames))!
            try f.read(into: buf, frameCount: AVAudioFrameCount(minFrames))
            // copy to channel i
            let dst = out.floatChannelData![i]
            let src = buf.floatChannelData![0]
            dst.assign(from: src, count: Int(buf.frameLength))
        }
        return out
    }

    // Write interleaved 4ch WAV
    private func write4Ch(url: URL, buffer: AVAudioPCMBuffer) throws {
        let interleaved = true
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate, channels: 4, interleaved: interleaved)!
        let inter = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: buffer.frameCapacity)!
        inter.frameLength = buffer.frameLength

        // deinterleave -> interleave
        let n = Int(buffer.frameLength)
        let ch0 = buffer.floatChannelData![0]
        let ch1 = buffer.floatChannelData![1]
        let ch2 = buffer.floatChannelData![2]
        let ch3 = buffer.floatChannelData![3]
        let dst = inter.floatChannelData![0]
        var idx = 0
        for i in 0..<n {
            dst[idx+0] = ch0[i]
            dst[idx+1] = ch1[i]
            dst[idx+2] = ch2[i]
            dst[idx+3] = ch3[i]
            idx += 4
        }

        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        try file.write(from: inter)
    }

    public func exportAmbiX(to directory: URL? = nil) {
        do {
            let aBuf = try loadFourMono()
            // A->B
            let bBuf = dsp.processAtoB(aBuffer: aBuf) // W,Y,Z,X (AmbiX ordering in our DSP)
            let base = directory ?? FileManager.default.temporaryDirectory
            let out = base.appendingPathComponent("AmbiX_\\(Int(Date().timeIntervalSince1970)).wav")
            try write4Ch(url: out, buffer: bBuf)
            print("AmbiX written: \\(out.path)")
        } catch {
            print("AmbiX export error: \\(error)")
        }
    }

    public func exportFuMa(to directory: URL? = nil) {
        do {
            let aBuf = try loadFourMono()
            // A->B first (AmbiX SN3D W,Y,Z,X)
            let bAmbiX = dsp.processAtoB(aBuffer: aBuf)

            // Map to FuMa W,X,Y,Z and scale SN3D -> FuMa
            let n = Int(bAmbiX.frameLength)
            let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: bAmbiX.format.sampleRate, channels: 4, interleaved: false)!
            let fuma = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: bAmbiX.frameCapacity)!
            fuma.frameLength = bAmbiX.frameLength
            let Wsn = bAmbiX.floatChannelData![0]
            let Ysn = bAmbiX.floatChannelData![1]
            let Zsn = bAmbiX.floatChannelData![2]
            let Xsn = bAmbiX.floatChannelData![3]
            let Wf = fuma.floatChannelData![0] // W
            let Xf = fuma.floatChannelData![1] // X
            let Yf = fuma.floatChannelData![2] // Y
            let Zf = fuma.floatChannelData![3] // Z

            let sW = 1.0/Float(sqrt(2.0))       // SN3D -> FuMa
            let sXYZ = Float(sqrt(3.0/2.0))

            for i in 0..<n {
                Wf[i] = Wsn[i] * sW
                Xf[i] = Xsn[i] * sXYZ
                Yf[i] = Ysn[i] * sXYZ
                Zf[i] = Zsn[i] * sXYZ
            }

            let base = directory ?? FileManager.default.temporaryDirectory
            let out = base.appendingPathComponent("FuMa_\\(Int(Date().timeIntervalSince1970)).wav")
            try write4Ch(url: out, buffer: fuma)
            print("FuMa written: \\(out.path)")
        } catch {
            print("FuMa export error: \\(error)")
        }
    }
    
    // Export stereo (simple decode: L=W+X, R=W-X)
    public func exportStereo(to directory: URL? = nil) {
        do {
            let aBuf = try loadFourMono()
            let bBuf = dsp.processAtoB(aBuffer: aBuf) // W,Y,Z,X
            let n = Int(bBuf.frameLength)
            let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: bBuf.format.sampleRate, channels: 2, interleaved: false)!
            let stereo = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: bBuf.frameCapacity)!
            stereo.frameLength = bBuf.frameLength
            
            let W = bBuf.floatChannelData![0]
            let X = bBuf.floatChannelData![3]
            let L = stereo.floatChannelData![0]
            let R = stereo.floatChannelData![1]
            
            // Simple decode: L = W + X, R = W - X
            for i in 0..<n {
                L[i] = W[i] + X[i]
                R[i] = W[i] - X[i]
            }
            
            let base = directory ?? FileManager.default.temporaryDirectory
            let out = base.appendingPathComponent("Stereo_\\(Int(Date().timeIntervalSince1970)).wav")
            try write2Ch(url: out, buffer: stereo)
            print("Stereo written: \\(out.path)")
        } catch {
            print("Stereo export error: \\(error)")
        }
    }
    
    // Export 5.1 (L, R, C, LFE, Ls, Rs)
    public func export5_1(to directory: URL? = nil) {
        do {
            let aBuf = try loadFourMono()
            let bBuf = dsp.processAtoB(aBuffer: aBuf) // W,Y,Z,X
            let n = Int(bBuf.frameLength)
            let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: bBuf.format.sampleRate, channels: 6, interleaved: false)!
            let out51 = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: bBuf.frameCapacity)!
            out51.frameLength = bBuf.frameLength
            
            let W = bBuf.floatChannelData![0]
            let Y = bBuf.floatChannelData![1]
            let Z = bBuf.floatChannelData![2]
            let X = bBuf.floatChannelData![3]
            
            let L = out51.floatChannelData![0]
            let R = out51.floatChannelData![1]
            let C = out51.floatChannelData![2]
            let LFE = out51.floatChannelData![3]
            let Ls = out51.floatChannelData![4]
            let Rs = out51.floatChannelData![5]
            
            // 5.1 decode from FOA
            let sqrt2 = Float(sqrt(2.0))
            for i in 0..<n {
                L[i] = (W[i] + X[i]) / sqrt2
                R[i] = (W[i] - X[i]) / sqrt2
                C[i] = W[i] / sqrt2
                LFE[i] = 0 // LFE typically filtered
                Ls[i] = (W[i] + Y[i]) / sqrt2
                Rs[i] = (W[i] - Y[i]) / sqrt2
            }
            
            let base = directory ?? FileManager.default.temporaryDirectory
            let out = base.appendingPathComponent("5.1_\\(Int(Date().timeIntervalSince1970)).wav")
            try write6Ch(url: out, buffer: out51)
            print("5.1 written: \\(out.path)")
        } catch {
            print("5.1 export error: \\(error)")
        }
    }
    
    // Export 7.1 (L, R, C, LFE, Ls, Rs, Lb, Rb)
    public func export7_1(to directory: URL? = nil) {
        do {
            let aBuf = try loadFourMono()
            let bBuf = dsp.processAtoB(aBuffer: aBuf) // W,Y,Z,X
            let n = Int(bBuf.frameLength)
            let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: bBuf.format.sampleRate, channels: 8, interleaved: false)!
            let out71 = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: bBuf.frameCapacity)!
            out71.frameLength = bBuf.frameLength
            
            let W = bBuf.floatChannelData![0]
            let Y = bBuf.floatChannelData![1]
            let Z = bBuf.floatChannelData![2]
            let X = bBuf.floatChannelData![3]
            
            let L = out71.floatChannelData![0]
            let R = out71.floatChannelData![1]
            let C = out71.floatChannelData![2]
            let LFE = out71.floatChannelData![3]
            let Ls = out71.floatChannelData![4]
            let Rs = out71.floatChannelData![5]
            let Lb = out71.floatChannelData![6]
            let Rb = out71.floatChannelData![7]
            
            // 7.1 decode from FOA
            let sqrt2 = Float(sqrt(2.0))
            for i in 0..<n {
                L[i] = (W[i] + X[i]) / sqrt2
                R[i] = (W[i] - X[i]) / sqrt2
                C[i] = W[i] / sqrt2
                LFE[i] = 0
                Ls[i] = (W[i] + Y[i]) / sqrt2
                Rs[i] = (W[i] - Y[i]) / sqrt2
                Lb[i] = (W[i] + Z[i]) / sqrt2
                Rb[i] = (W[i] - Z[i]) / sqrt2
            }
            
            let base = directory ?? FileManager.default.temporaryDirectory
            let out = base.appendingPathComponent("7.1_\\(Int(Date().timeIntervalSince1970)).wav")
            try write8Ch(url: out, buffer: out71)
            print("7.1 written: \\(out.path)")
        } catch {
            print("7.1 export error: \\(error)")
        }
    }
    
    // Export binaural (stereo with HRTF - placeholder for future HRTF implementation)
    public func exportBinaural(to directory: URL? = nil) {
        // For now, use simple stereo decode. Future: load HRTF and convolve
        exportStereo(to: directory)
        print("Binaural export: using simple stereo decode (HRTF not yet implemented)")
    }
    
    // Helper: write 2ch interleaved
    private func write2Ch(url: URL, buffer: AVAudioPCMBuffer) throws {
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate, channels: 2, interleaved: true)!
        let inter = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: buffer.frameCapacity)!
        inter.frameLength = buffer.frameLength
        let n = Int(buffer.frameLength)
        let ch0 = buffer.floatChannelData![0]
        let ch1 = buffer.floatChannelData![1]
        let dst = inter.floatChannelData![0]
        for i in 0..<n {
            dst[i*2] = ch0[i]
            dst[i*2+1] = ch1[i]
        }
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        try file.write(from: inter)
    }
    
    // Helper: write 6ch interleaved
    private func write6Ch(url: URL, buffer: AVAudioPCMBuffer) throws {
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate, channels: 6, interleaved: true)!
        let inter = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: buffer.frameCapacity)!
        inter.frameLength = buffer.frameLength
        let n = Int(buffer.frameLength)
        let dst = inter.floatChannelData![0]
        for i in 0..<n {
            for ch in 0..<6 {
                dst[i*6+ch] = buffer.floatChannelData![ch][i]
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        try file.write(from: inter)
    }
    
    // Helper: write 8ch interleaved
    private func write8Ch(url: URL, buffer: AVAudioPCMBuffer) throws {
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate, channels: 8, interleaved: true)!
        let inter = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: buffer.frameCapacity)!
        inter.frameLength = buffer.frameLength
        let n = Int(buffer.frameLength)
        let dst = inter.floatChannelData![0]
        for i in 0..<n {
            for ch in 0..<8 {
                dst[i*8+ch] = buffer.floatChannelData![ch][i]
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        try file.write(from: inter)
    }
}
