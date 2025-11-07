import Foundation
import AVFoundation
import Combine

final class IRMeasurementEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode?
    private var inputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?
    
    @Published var isMeasuring = false
    @Published var progress: Double = 0.0
    @Published var status: String = "Ready"
    
    private var recordedBuffers: [AVAudioPCMBuffer] = []
    private var inputChannels: [Int] = []
    private var outputChannels: [Int] = []
    private var sampleRate: Double = 48000.0
    
    // Start measurement: play sweep and record simultaneously
    func measureIR(
        sweep: [Float],
        inputChannels: [Int],
        outputChannels: [Int],
        sampleRate: Double = 48000.0
    ) async throws -> [[Float]] {
        self.inputChannels = inputChannels
        self.outputChannels = outputChannels
        self.sampleRate = sampleRate
        
        await MainActor.run {
            isMeasuring = true
            progress = 0.0
            status = "Preparing..."
        }
        
        // Setup audio engine
        try setupEngine(sampleRate: sampleRate)
        
        // Create audio buffer from sweep
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let sweepBuffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(sweep.count))!
        sweepBuffer.frameLength = AVAudioFrameCount(sweep.count)
        sweep.withUnsafeBufferPointer { ptr in
            sweepBuffer.floatChannelData![0].assign(from: ptr.baseAddress!, count: sweep.count)
        }
        
        // Prepare recording
        recordedBuffers = []
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let recordFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: AVAudioChannelCount(inputChannels.count), interleaved: false)!
        
        // Install tap to record
        let bufferSize: AVAudioFrameCount = 4096
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, self.isMeasuring else { return }
            
            // Extract selected input channels
            let extracted = self.extractSelectedChannels(buffer: buffer, channels: self.inputChannels)
            self.recordedBuffers.append(extracted)
        }
        
        // Start engine
        try engine.start()
        
        await MainActor.run {
            status = "Playing sweep and recording..."
        }
        
        // Create player node and schedule sweep
        let player = AVAudioPlayerNode()
        engine.attach(player)
        playerNode = player
        
        // Connect player to output
        let outputNode = engine.outputNode
        let outputFormat = outputNode.outputFormat(forBus: 0)
        
        // For multi-channel routing, we need to create a multi-channel buffer
        // and route to specific output channels
        // For now, connect directly - hardware will handle routing
        engine.connect(player, to: outputNode, format: fmt)
        
        // Schedule playback
        player.scheduleBuffer(sweepBuffer, at: nil, options: [], completionHandler: nil)
        player.play()
        
        // Wait for sweep to complete
        let sweepDuration = Double(sweep.count) / sampleRate
        let waitTime = sweepDuration + 0.5 // Add small buffer for recording tail
        
        // Monitor progress
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < waitTime {
            let elapsed = Date().timeIntervalSince(startTime)
            let progressValue = min(1.0, elapsed / waitTime)
            await MainActor.run {
                progress = progressValue
                status = "Recording... \(Int(elapsed))s / \(Int(waitTime))s"
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Stop recording
        inputNode.removeTap(onBus: 0)
        player.stop()
        engine.stop()
        
        await MainActor.run {
            status = "Processing recorded data..."
        }
        
        // Concatenate recorded buffers into single arrays per channel
        var channelData: [[Float]] = []
        
        guard !recordedBuffers.isEmpty else {
            throw NSError(domain: "IRMeasurementEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "No recorded data"])
        }
        
        let channelCount = Int(recordedBuffers[0].format.channelCount)
        
        for ch in 0..<channelCount {
            var channelSamples: [Float] = []
            for buffer in recordedBuffers {
                let channelPtr = buffer.floatChannelData![ch]
                let frameCount = Int(buffer.frameLength)
                channelSamples.append(contentsOf: Array(UnsafeBufferPointer(start: channelPtr, count: frameCount)))
            }
            channelData.append(channelSamples)
        }
        
        await MainActor.run {
            isMeasuring = false
            progress = 1.0
            status = "Measurement complete: \(channelData.first?.count ?? 0) samples"
        }
        
        return channelData
    }
    
    private func setupEngine(sampleRate: Double) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.allowBluetooth, .mixWithOthers])
        try session.setPreferredSampleRate(sampleRate)
        try session.setActive(true)
        #endif
    }
    
    private func extractSelectedChannels(buffer: AVAudioPCMBuffer, channels: [Int]) -> AVAudioPCMBuffer {
        let frameCount = buffer.frameLength
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate, channels: AVAudioChannelCount(channels.count), interleaved: false)!
        let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount)!
        out.frameLength = frameCount
        
        let availableChannels = Int(buffer.format.channelCount)
        
        for (outCh, inCh) in channels.enumerated() {
            let srcCh = min(max(0, inCh), availableChannels - 1)
            let src = buffer.floatChannelData![srcCh]
            let dst = out.floatChannelData![outCh]
            dst.assign(from: src, count: Int(frameCount))
        }
        
        return out
    }
    
    private func concatenateBuffers(_ buffers: [AVAudioPCMBuffer]) -> [AVAudioPCMBuffer] {
        guard !buffers.isEmpty else { return [] }
        
        // Get format from first buffer
        let format = buffers[0].format
        let channelCount = Int(format.channelCount)
        
        // Calculate total frame count
        let totalFrames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        
        // Create output buffers for each channel
        var channelBuffers: [AVAudioPCMBuffer] = []
        
        for ch in 0..<channelCount {
            let monoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate, channels: 1, interleaved: false)!
            let outputBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(totalFrames))!
            outputBuffer.frameLength = AVAudioFrameCount(totalFrames)
            
            var frameOffset = 0
            for buffer in buffers {
                let frameCount = Int(buffer.frameLength)
                let src = buffer.floatChannelData![ch]
                let dst = outputBuffer.floatChannelData![0]
                dst.advanced(by: frameOffset).assign(from: src, count: frameCount)
                frameOffset += frameCount
            }
            
            channelBuffers.append(outputBuffer)
        }
        
        return channelBuffers
    }
    
    func cancel() {
        engine.inputNode.removeTap(onBus: 0)
        playerNode?.stop()
        engine.stop()
        isMeasuring = false
        status = "Cancelled"
    }
}

