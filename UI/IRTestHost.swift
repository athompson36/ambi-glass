import AVFoundation
import Combine
final class IRTestHost: ObservableObject {
    private let engine = AVAudioEngine()
    private let conv = AVAudioUnitConvolution()
    @Published var isRunning = false
    @Published var wetDryMix: Float = 100 { didSet { conv.wetDryMix = wetDryMix } }
    @Published var latencyMs: Double = 0
    func loadIR(from url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                         frameCapacity: AVAudioFrameCount(file.length)) else {
            throw NSError(domain: "IRTestHost", code: -1, userInfo: [NSLocalizedDescriptionKey:"IR buffer alloc failed"])
        }
        try file.read(into: buf)
        conv.loadAudioBuffer(buf, at: .zero)
    }
    func start(ioBufferFrames: AVAudioFrameCount = 512, sampleRate: Double = 48000) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(Double(ioBufferFrames)/sampleRate)
        try session.setActive(true)
        #endif
        let input = engine.inputNode
        let output = engine.outputNode
        let inFmt = input.inputFormat(forBus: 0)
        let outFmt = output.outputFormat(forBus: 0)
        conv.wetDryMix = wetDryMix
        engine.attach(conv)
        engine.connect(input, to: conv, format: inFmt)
        engine.connect(conv, to: output, format: outFmt)
        try engine.start()
        isRunning = true
        latencyMs = (engine.outputNode.presentationLatency + engine.inputNode.presentationLatency) * 1000.0
    }
    func stop() { engine.stop(); isRunning = false }
}
