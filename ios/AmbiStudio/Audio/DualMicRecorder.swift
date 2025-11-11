import Foundation
import AVFoundation
import Combine
import Accelerate

final class DualMicRecorder: ObservableObject {
    private let engine = AVAudioEngine()
    private var ambiAliceWriter: AVAudioFile?
    private var referenceWriter: AVAudioFile?
    
    @Published var isRecording = false
    @Published var progress: Double = 0.0
    @Published var status: String = "Ready"
    
    private var ambiAliceBuffers: [AVAudioPCMBuffer] = []
    private var referenceBuffers: [AVAudioPCMBuffer] = []
    
    // Record from both mics simultaneously
    func recordDual(
        ambiAliceChannels: [Int],
        referenceChannel: Int,
        ambiAliceDeviceID: String,
        referenceDeviceID: String,
        sampleRate: Double = 48000.0,
        duration: Double? = nil
    ) async throws -> (ambiAlice: [[Float]], reference: [Float]) {
        await MainActor.run {
            isRecording = true
            progress = 0.0
            status = "Preparing..."
        }
        
        // Setup audio engine
        try setupEngine(sampleRate: sampleRate)
        
        // Setup input nodes
        let ambiAliceInput = engine.inputNode
        let ambiAliceFormat = ambiAliceInput.inputFormat(forBus: 0)
        
        // Clear buffers
        ambiAliceBuffers = []
        referenceBuffers = []
        
        // Install tap for Ambi-Alice (4 channels)
        let bufferSize: AVAudioFrameCount = 4096
        ambiAliceInput.installTap(onBus: 0, bufferSize: bufferSize, format: ambiAliceFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }
            
            // Extract selected channels
            let extracted = self.extractChannels(buffer: buffer, channels: ambiAliceChannels)
            self.ambiAliceBuffers.append(extracted)
        }
        
        // Start engine
        try engine.start()
        
        await MainActor.run {
            status = "Recording from both microphones..."
        }
        
        // Record for specified duration or until stopped
        let startTime = Date()
        let recordDuration = duration ?? 10.0 // Default 10 seconds
        
        while Date().timeIntervalSince(startTime) < recordDuration && isRecording {
            let elapsed = Date().timeIntervalSince(startTime)
            let progressValue = min(1.0, elapsed / recordDuration)
            await MainActor.run {
                progress = progressValue
                status = "Recording... \(String(format: "%.1f", elapsed))s / \(String(format: "%.1f", recordDuration))s"
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Stop recording
        ambiAliceInput.removeTap(onBus: 0)
        engine.stop()
        
        await MainActor.run {
            status = "Processing recorded data..."
        }
        
        // Process Ambi-Alice buffers (4 channels)
        var ambiAliceData: [[Float]] = []
        guard !ambiAliceBuffers.isEmpty else {
            throw NSError(domain: "DualMicRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "No Ambi-Alice data recorded"])
        }
        
        let ambiChannelCount = Int(ambiAliceBuffers[0].format.channelCount)
        for ch in 0..<ambiChannelCount {
            var channelSamples: [Float] = []
            for buffer in ambiAliceBuffers {
                let channelPtr = buffer.floatChannelData![ch]
                let frameCount = Int(buffer.frameLength)
                channelSamples.append(contentsOf: Array(UnsafeBufferPointer(start: channelPtr, count: frameCount)))
            }
            ambiAliceData.append(channelSamples)
        }
        
        // Process reference mic buffer (1 channel)
        // For now, we'll use the same input but extract a different channel
        // In a real implementation, you'd have a separate input device
        var referenceData: [Float] = []
        if !ambiAliceBuffers.isEmpty {
            // Extract reference channel from Ambi-Alice input (temporary - should be separate device)
            let refChannel = min(referenceChannel, ambiChannelCount - 1)
            for buffer in ambiAliceBuffers {
                let channelPtr = buffer.floatChannelData![refChannel]
                let frameCount = Int(buffer.frameLength)
                referenceData.append(contentsOf: Array(UnsafeBufferPointer(start: channelPtr, count: frameCount)))
            }
        }
        
        await MainActor.run {
            isRecording = false
            progress = 1.0
            status = "Recording complete: Ambi-Alice \(ambiAliceData.first?.count ?? 0) samples, Reference \(referenceData.count) samples"
        }
        
        return (ambiAlice: ambiAliceData, reference: referenceData)
    }
    
    // Record in two stages: first Ambi-Alice, then reference
    func recordStaged(
        ambiAliceChannels: [Int],
        referenceChannel: Int,
        ambiAliceDeviceID: String,
        referenceDeviceID: String,
        sampleRate: Double = 48000.0,
        duration: Double = 10.0
    ) async throws -> (ambiAlice: [[Float]], reference: [Float]) {
        // Stage 1: Record Ambi-Alice
        await MainActor.run {
            status = "Stage 1: Recording Ambi-Alice..."
        }
        
        let (ambiAliceData, _) = try await recordDual(
            ambiAliceChannels: ambiAliceChannels,
            referenceChannel: referenceChannel,
            ambiAliceDeviceID: ambiAliceDeviceID,
            referenceDeviceID: referenceDeviceID,
            sampleRate: sampleRate,
            duration: duration
        )
        
        // Wait a moment
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Stage 2: Record reference mic
        await MainActor.run {
            status = "Stage 2: Recording reference microphone..."
        }
        
        let (_, referenceData) = try await recordDual(
            ambiAliceChannels: [],
            referenceChannel: referenceChannel,
            ambiAliceDeviceID: referenceDeviceID,
            referenceDeviceID: referenceDeviceID,
            sampleRate: sampleRate,
            duration: duration
        )
        
        return (ambiAlice: ambiAliceData, reference: referenceData)
    }
    
    private func setupEngine(sampleRate: Double) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, options: [.allowBluetooth])
        try session.setPreferredSampleRate(sampleRate)
        try session.setActive(true)
        #endif
    }
    
    private func extractChannels(buffer: AVAudioPCMBuffer, channels: [Int]) -> AVAudioPCMBuffer {
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
    
    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        status = "Stopped"
    }
}

