import Foundation
import AVFoundation
import Combine

final class RecorderEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private var inputFormat: AVAudioFormat?
    private let meterSubject = PassthroughSubject<[CGFloat], Never>()
    var meterPublisher: AnyPublisher<[CGFloat], Never> { meterSubject.eraseToAnyPublisher() }
    private let dsp = AmbisonicsDSP()

    @Published var selectedDeviceID: String = "default"
    @Published var safetyRecord: Bool = true

    private var aWriter: AVAudioFile?
    private var bWriter: AVAudioFile?

    func start(sampleRate: Double = 48000, bufferFrames: AVAudioFrameCount = 1024) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.allowBluetooth, .mixWithOthers])
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(Double(bufferFrames)/sampleRate)
        try session.setActive(true)
        #endif

        let input = engine.inputNode
        let hw = input.inputFormat(forBus: 0)
        guard hw.channelCount >= 4 else {
            throw NSError(domain: "RecorderEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Need ≥4 input channels"])
        }
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
        inputFormat = fmt

        // Auto-apply latest interface channel gains from calibration
        if let iface = ProfileStore.shared.latestInterfaceProfile(), iface.channelGains_dB.count == 4 {
            dsp.interfaceGains_dB = iface.channelGains_dB.map { Float($0) }
        }

        let tmp = FileManager.default.temporaryDirectory
        if safetyRecord {
            aWriter = try? AVAudioFile(forWriting: tmp.appendingPathComponent("Aformat_\(Date().timeIntervalSince1970).wav"), settings: fmt.settings)
        } else {
            aWriter = nil
        }
        let bfmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 4, interleaved: false)!
        bWriter = try? AVAudioFile(forWriting: tmp.appendingPathComponent("BformatAmbiX_\(Date().timeIntervalSince1970).wav"), settings: bfmt.settings)

        input.installTap(onBus: 0, bufferSize: bufferFrames, format: hw) { [weak self] buf, _ in
            guard let self else { return }
            let four = self.extractFirstFourChannels(buffer: buf)
            if let f = self.aWriter { try? f.write(from: four) }
            if let bFile = self.bWriter {
                let bBuf = self.dsp.processAtoB(aBuffer: four)
                try? bFile.write(from: bBuf)
            }
            self.pushMeters(from: four)
        }

        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        aWriter = nil
        bWriter = nil
    }

    private func extractFirstFourChannels(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let frameCount = buffer.frameLength
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate, channels: 4, interleaved: false)!
        let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount)!
        out.frameLength = frameCount
        for ch in 0..<4 {
            let src = buffer.floatChannelData![min(Int(ch), Int(buffer.format.channelCount)-1)]
            let dst = out.floatChannelData![Int(ch)]
            dst.update(from: src, count: Int(frameCount))
        }
        return out
    }

    private func pushMeters(from buf: AVAudioPCMBuffer) {
        let n = Int(buf.frameLength)
        var peaks: [CGFloat] = []
        for ch in 0..<4 {
            let p = buf.floatChannelData![ch].withMemoryRebound(to: Float.self, capacity: n) { ptr -> Float in
                var peak: Float = 0
                for i in 0..<n { peak = max(peak, abs(ptr[i])) }
                return peak
            }
            peaks.append(CGFloat(min(1.0, p)))
        }
        meterSubject.send(peaks)
    }
}
