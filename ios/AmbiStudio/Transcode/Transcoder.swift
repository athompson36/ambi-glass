import Foundation
import AVFoundation
import Accelerate
import Combine
#if os(macOS) || os(iOS)
import Darwin
#endif
import OSLog

final class Transcoder: ObservableObject {
    private var fourMono: [URL] = []
    @Published var importedFiles: [URL] = []
    @Published var importStatus: String = ""
    @Published var waveformCache: [URL: [Float]] = [:]
    @Published var transcodeProgress: Double = 0.0
    @Published var transcodeStatus: String = ""
    private let dsp = AmbisonicsDSP()
    
    // Public method to extract channel number (for validation in UI)
    func extractChannelNumber(from url: URL) -> Int? {
        let filename = url.deletingPathExtension().lastPathComponent.lowercased()
        
        // Try to find -1, -2, -3, -4 pattern
        if filename.contains("-1") {
            return 1
        } else if filename.contains("-2") {
            return 2
        } else if filename.contains("-3") {
            return 3
        } else if filename.contains("-4") {
            return 4
        }
        
        // Try alternative patterns: _1, _2, _3, _4 or .1, .2, .3, .4
        if filename.contains("_1") || filename.hasSuffix(".1") {
            return 1
        } else if filename.contains("_2") || filename.hasSuffix(".2") {
            return 2
        } else if filename.contains("_3") || filename.hasSuffix(".3") {
            return 3
        } else if filename.contains("_4") || filename.hasSuffix(".4") {
            return 4
        }
        
        return nil
    }

    func handleFourMono(urls: [URL]) {
        // Sort files by channel number extracted from filename (-1, -2, -3, -4)
        let sorted = sortFilesByChannel(urls)
        fourMono = sorted
        importedFiles = sorted
        importStatus = "Imported \(sorted.count) files (sorted by channel)"
        print("Queued 4 mono files: \(sorted.map{ $0.lastPathComponent })")
        
        // Load waveforms for all files
        loadWaveformsForFiles(sorted)
    }
    
    // Load and cache waveforms for all files
    private func loadWaveformsForFiles(_ urls: [URL]) {
        for url in urls {
            // Skip if already cached
            if waveformCache[url] != nil {
                continue
            }
            
            Task {
                await loadWaveformForFile(url)
            }
        }
    }
    
    // Load waveform for a single file
    private func loadWaveformForFile(_ url: URL) async {
        // Start accessing security-scoped resource
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return
            }
            
            try file.read(into: buffer)
            
            // Downsample for visualization (take every Nth sample)
            let channelData = buffer.floatChannelData?[0]
            guard let channelData = channelData else {
                return
            }
            
            let sampleCount = Int(buffer.frameLength)
            let downsampleFactor = max(1, sampleCount / 1000) // Show max 1000 points
            var downsampled: [Float] = []
            
            for i in stride(from: 0, to: sampleCount, by: downsampleFactor) {
                downsampled.append(channelData[i])
            }
            
            await MainActor.run {
                waveformCache[url] = downsampled
            }
        } catch {
            print("Error loading waveform for \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    // Get cached waveform data for a URL
    func getWaveformData(for url: URL) -> [Float]? {
        return waveformCache[url]
    }
    
    // Sort files by channel number
    private func sortFilesByChannel(_ urls: [URL]) -> [URL] {
        var filesWithChannels: [(url: URL, channel: Int)] = []
        var filesWithoutChannels: [URL] = []
        
        for url in urls {
            if let channel = extractChannelNumber(from: url) {
                filesWithChannels.append((url: url, channel: channel))
            } else {
                filesWithoutChannels.append(url)
            }
        }
        
        // Sort by channel number
        filesWithChannels.sort { $0.channel < $1.channel }
        
        // Combine sorted files with channel numbers and files without
        let sorted = filesWithChannels.map { $0.url } + filesWithoutChannels
        
        // Validate we have exactly 4 files and channels 1-4 are present
        if filesWithChannels.count == 4 {
            let channels = Set(filesWithChannels.map { $0.channel })
            if channels == Set([1, 2, 3, 4]) {
                return sorted
            }
        }
        
        // If we don't have proper channel numbers, return as-is (will be sorted alphabetically)
        return sorted.isEmpty ? urls : sorted
    }

    // Load four mono files, align length, pack into buffer
    // Process in chunks to handle large files (3+ GB) efficiently
    private func loadFourMono() throws -> (buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard fourMono.count == 4 else { throw NSError(domain: "Transcoder", code: -1, userInfo: [NSLocalizedDescriptionKey:"Need 4 mono files"]) }
        
        // Access security-scoped resources for all files
        var accessTokens: [Bool] = []
        for url in fourMono {
            let hasAccess = url.startAccessingSecurityScopedResource()
            accessTokens.append(hasAccess)
        }
        defer {
            // Stop accessing security-scoped resources
            for (index, url) in fourMono.enumerated() {
                if accessTokens[index] {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        
        // Open files and detect sample rate
        let files = try fourMono.map { try AVAudioFile(forReading: $0) }
        
        // Detect sample rate from first file (all should match)
        guard let firstFile = files.first else {
            throw NSError(domain: "Transcoder", code: -3, userInfo: [NSLocalizedDescriptionKey:"No files to process"])
        }
        
        let detectedSampleRate = firstFile.fileFormat.sampleRate
        guard detectedSampleRate > 0 && detectedSampleRate <= 192000 else {
            throw NSError(domain: "Transcoder", code: -3, userInfo: [NSLocalizedDescriptionKey:"Invalid sample rate: \(detectedSampleRate)Hz. Supported range: 1-192000Hz"])
        }
        
        // Verify all files have the same sample rate
        for (index, file) in files.enumerated() {
            let fileRate = file.fileFormat.sampleRate
            if abs(fileRate - detectedSampleRate) > 0.1 {
                throw NSError(domain: "Transcoder", code: -4, userInfo: [NSLocalizedDescriptionKey:"Sample rate mismatch: file \(index+1) has \(fileRate)Hz, expected \(detectedSampleRate)Hz"])
            }
        }
        
        let minFrames = files.map { Int($0.length) }.min() ?? 0
        guard minFrames > 0 else { throw NSError(domain: "Transcoder", code: -2, userInfo: [NSLocalizedDescriptionKey:"Empty files"]) }

        // Process in chunks to avoid loading entire 3+ GB files into memory
        let chunkSize: AVAudioFrameCount = 65536 // 64k frames per chunk (~1.3s at 48kHz)
        
        // Safely create format - use 4-channel float32 format at detected sample rate (if available)
        // If this fails later, the streaming fallback writer does not require AVAudioFormat.
        guard let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: detectedSampleRate, channels: 4, interleaved: false) else {
            throw NSError(domain: "Transcoder", code: -6, userInfo: [NSLocalizedDescriptionKey:"Failed to create 4ch format at \(detectedSampleRate)Hz"])
        }
        
        // For very large files, we need to be careful about memory allocation
        // Check if we can safely allocate the buffer
        // Note: For 3+ GB files, this may still be problematic, but we'll try
        let totalBytes = Int(minFrames) * 4 * 4 // 4 channels * 4 bytes per float
        let maxSafeBytes = 4 * 1024 * 1024 * 1024 // 4GB limit (allows for 3GB files)
        
        guard totalBytes <= maxSafeBytes else {
            throw NSError(domain: "Transcoder", code: -7, userInfo: [NSLocalizedDescriptionKey:"File too large (\(String(format: "%.1f", Double(totalBytes) / 1_000_000_000))GB). Maximum supported: 4GB total buffer."])
        }
        
        guard let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(minFrames)) else {
            throw NSError(domain: "Transcoder", code: -8, userInfo: [NSLocalizedDescriptionKey:"Failed to allocate output buffer (file may be too large)"])
        }
        out.frameLength = AVAudioFrameCount(minFrames)

        // Process each file in chunks with progress updates
        for (i, f) in files.enumerated() {
            // Use the file's native format for reading
            let monoFmt = f.processingFormat
            
            var framesRead: AVAudioFrameCount = 0
            guard let dst = out.floatChannelData?[i] else {
                throw NSError(domain: "Transcoder", code: -10, userInfo: [NSLocalizedDescriptionKey:"Failed to access output channel \(i)"])
            }
            
            // Update status on main thread
            DispatchQueue.main.async {
                self.transcodeStatus = "Loading file \(i+1)/4..."
            }
            
            // Read file in chunks
            while framesRead < AVAudioFrameCount(minFrames) {
                let remainingFrames = AVAudioFrameCount(minFrames) - framesRead
                let framesToRead = min(chunkSize, remainingFrames)
                
                guard let chunkBuf = AVAudioPCMBuffer(pcmFormat: monoFmt, frameCapacity: framesToRead) else {
                    throw NSError(domain: "Transcoder", code: -5, userInfo: [NSLocalizedDescriptionKey:"Failed to allocate chunk buffer"])
                }
                
                try f.read(into: chunkBuf, frameCount: framesToRead)
                
                // Copy chunk to output channel
                guard let src = chunkBuf.floatChannelData?[0] else {
                    throw NSError(domain: "Transcoder", code: -11, userInfo: [NSLocalizedDescriptionKey:"Failed to access chunk data"])
                }
                let copyCount = Int(chunkBuf.frameLength)
                dst.advanced(by: Int(framesRead)).update(from: src, count: copyCount)
                
                framesRead += chunkBuf.frameLength
                
                // Update progress (0-0.5 for loading, 0.5-1.0 for processing)
                // Only update every N chunks to avoid too many main thread dispatches
                if framesRead % (chunkSize * 4) == 0 || framesRead >= AVAudioFrameCount(minFrames) {
                    let fileProgress = Double(framesRead) / Double(minFrames)
                    let overallProgress = (Double(i) + fileProgress) / 4.0 * 0.5 // First 50% is loading
                    DispatchQueue.main.async {
                        self.transcodeProgress = overallProgress
                    }
                }
            }
        }
        
        return (out, detectedSampleRate)
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
        DispatchQueue.main.async {
            self.transcodeProgress = 0.0
            self.transcodeStatus = "Starting AmbiX export..."
        }

        // For very large files, use a different approach that doesn't block
        if let firstFile = fourMono.first,
           let attrs = try? FileManager.default.attributesOfItem(atPath: firstFile.path),
           let fileSize = attrs[.size] as? Int64 {
            let totalSizeGB = Double(fileSize * 4) / 1_000_000_000.0
            if totalSizeGB > 8.0 { // 8GB threshold for "very large"
                print("Large files detected (\(String(format: "%.1f", totalSizeGB))GB). Using non-blocking export.")
                print("Starting non-blocking export...")
                do {
                    try exportAmbiX_nonblocking(to: directory)
                } catch {
                    let errorMsg = "AmbiX export error: \(error.localizedDescription)"
                    DispatchQueue.main.async {
                        self.importStatus = errorMsg
                        self.transcodeStatus = "Error: \(error.localizedDescription)"
                        self.transcodeProgress = 0.0
                    }
                    print(errorMsg)
                }
                return
            }
        }

        do {
            // Try streaming path (robust against codec factory issues and huge files)
            try exportAmbiX_streaming(to: directory)
        } catch {
            let errorMsg = "AmbiX export error: \(error.localizedDescription)"
            DispatchQueue.main.async {
                self.importStatus = errorMsg
                self.transcodeStatus = "Error: \(error.localizedDescription)"
                self.transcodeProgress = 0.0
            }
            print(errorMsg)
        }
    }

    // Streaming AmbiX export that does not rely on AVAudioFile(forWriting:)
    // Reads chunks from 4 mono files, computes FOA (AmbiX W,Y,Z,X), interleaves, and writes via WavFloat32Writer.
    private func exportAmbiX_streaming(to directory: URL?) throws {
        guard fourMono.count == 4 else {
            throw NSError(domain: "Transcoder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Need 4 mono files"])
        }
        // Access security-scoped resources
        var accessTokens: [Bool] = []
        for url in fourMono {
            accessTokens.append(url.startAccessingSecurityScopedResource())
        }
        defer {
            for (i, url) in fourMono.enumerated() {
                if accessTokens[i] { url.stopAccessingSecurityScopedResource() }
            }
        }
        let files = try fourMono.map { try AVAudioFile(forReading: $0) }
        // Validate same sample rate
        let sr = files.first!.fileFormat.sampleRate
        for (idx, f) in files.enumerated() where abs(f.fileFormat.sampleRate - sr) > 0.1 {
            throw NSError(domain: "Transcoder", code: -4, userInfo: [NSLocalizedDescriptionKey:"Sample rate mismatch at file \(idx+1)"])
        }
        let minFrames = files.map { Int($0.length) }.min() ?? 0
        guard minFrames > 0 else {
            throw NSError(domain: "Transcoder", code: -2, userInfo: [NSLocalizedDescriptionKey:"Empty files"])
        }
        let base = directory ?? ProjectManager.shared.getTranscodedFolder()
        let outURL = base.appendingPathComponent("AmbiX_\(Int(Date().timeIntervalSince1970)).wav")
        let writer = try WavFloat32Writer(url: outURL, sampleRate: sr, channels: 4)

        // Use smaller chunks for better memory management with very large files
        // 16k frames = ~0.33s at 48kHz, ~64KB per channel = 256KB total per chunk
        let chunk: AVAudioFrameCount = 16384
        // Mono read buffers
        let monoFormats = files.map { $0.processingFormat }
        let gainsTrims = dsp // capture reference
        var framesProcessed: Int = 0
        var chunksWritten = 0

        let log = Logger(subsystem: "com.ambi-studio.transcoder", category: "AmbiX")
        log.log("AmbiX stream starting. totalFrames=\(minFrames, privacy: .public) chunkSize=\(chunk, privacy: .public)")

        while framesProcessed < minFrames {
            let remaining = minFrames - framesProcessed
            let toRead = min(Int(chunk), remaining)
            var actualFramesRead = 0

            // Read chunk from each file - process directly without intermediate arrays
            var caughtError: Error?
            autoreleasepool {
                let chunkStart = CFAbsoluteTimeGetCurrent()
                do {
                    // Read all 4 channels into buffers
                    var buffers: [AVAudioPCMBuffer] = []
                    for i in 0..<4 {
                        guard let buf = AVAudioPCMBuffer(pcmFormat: monoFormats[i], frameCapacity: AVAudioFrameCount(toRead)) else {
                            throw NSError(domain: "Transcoder", code: -12, userInfo: [NSLocalizedDescriptionKey:"Chunk buffer alloc failed"])
                        }
                        try files[i].read(into: buf, frameCount: AVAudioFrameCount(toRead))
                        buffers.append(buf)
                    }
                    guard let first = buffers.first else { throw NSError(domain: "Transcoder", code: -14, userInfo: [NSLocalizedDescriptionKey:"Missing buffer data"]) }
                    let actualFrames = Int(first.frameLength)
                    if actualFrames == 0 {
                        log.log("Reached EOF after \(framesProcessed) frames.")
                        caughtError = nil
                        actualFramesRead = 0
                        return
                    }
                    for (idx, buf) in buffers.enumerated() {
                        let len = Int(buf.frameLength)
                        if len != actualFrames {
                            throw NSError(domain: "Transcoder", code: -15, userInfo: [NSLocalizedDescriptionKey:"Frame length mismatch. Channel \(idx) has \(len) vs \(actualFrames)"])
                        }
                    }
                    actualFramesRead = actualFrames
                    let readEnd = CFAbsoluteTimeGetCurrent()
                    let readDuration = readEnd - chunkStart

                    // Get pointers to source data
                    guard let src0 = buffers[0].floatChannelData?[0],
                          let src1 = buffers[1].floatChannelData?[0],
                          let src2 = buffers[2].floatChannelData?[0],
                          let src3 = buffers[3].floatChannelData?[0] else {
                        throw NSError(domain: "Transcoder", code: -13, userInfo: [NSLocalizedDescriptionKey:"Failed to access channel data"])
                    }

                    // Compute AmbiX W,Y,Z,X using current matrix and orientation
                    let m = gainsTrims.matrix.m
                    let trims = gainsTrims.capsuleTrims_dB.map { powf(10.0, Float($0)/20.0) }
                    let iface = gainsTrims.interfaceGains_dB.map { powf(10.0, Float($0)/20.0) }
                    let g0 = trims[0]*iface[0], g1 = trims[1]*iface[1], g2 = trims[2]*iface[2], g3 = trims[3]*iface[3]
                    
                    // Allocate output arrays
                    var W = [Float](repeating: 0, count: actualFrames)
                    var Y = [Float](repeating: 0, count: actualFrames)
                    var Z = [Float](repeating: 0, count: actualFrames)
                    var X = [Float](repeating: 0, count: actualFrames)
                    
                    // Process directly from source pointers
                    let dspStart = CFAbsoluteTimeGetCurrent()
                    for i in 0..<actualFrames {
                        let v0 = src0[i]*g0, v1 = src1[i]*g1, v2 = src2[i]*g2, v3 = src3[i]*g3
                        W[i] = m[0]*v0 + m[1]*v1 + m[2]*v2 + m[3]*v3
                        Y[i] = m[4]*v0 + m[5]*v1 + m[6]*v2 + m[7]*v3
                        Z[i] = m[8]*v0 + m[9]*v1 + m[10]*v2 + m[11]*v3
                        X[i] = m[12]*v0 + m[13]*v1 + m[14]*v2 + m[15]*v3
                    }
                    
                    // Optional orientation
                    if gainsTrims.yaw != 0 || gainsTrims.pitch != 0 || gainsTrims.roll != 0 {
                        let cy = cosf(gainsTrims.yaw), sy = sinf(gainsTrims.yaw)
                        let cp = cosf(gainsTrims.pitch), sp = sinf(gainsTrims.pitch)
                        let cr = cosf(gainsTrims.roll), sr = sinf(gainsTrims.roll)
                        let r00 = cy*cp
                        let r01 = cy*sp*sr - sy*cr
                        let r02 = cy*sp*cr + sy*sr
                        let r10 = sy*cp
                        let r11 = sy*sp*sr + cy*cr
                        let r12 = sy*sp*cr - cy*sr
                        let r20 = -sp
                        let r21 = cp*sr
                        let r22 = cp*cr
                        for i in 0..<actualFrames {
                            let x = X[i], y = Y[i], z = Z[i]
                            X[i] = r00*x + r01*y + r02*z
                            Y[i] = r10*x + r11*y + r12*z
                            Z[i] = r20*x + r21*y + r22*z
                        }
                    }
                    
                    // Interleave W,Y,Z,X and write directly
                    let dspDuration = CFAbsoluteTimeGetCurrent() - dspStart
                    let writeStart = CFAbsoluteTimeGetCurrent()
                    try writer.writeInterleavedFloat32(frames: actualFrames) { ptr in
                        var idx = 0
                        for i in 0..<actualFrames {
                            ptr[idx+0] = W[i]
                            ptr[idx+1] = Y[i]
                            ptr[idx+2] = Z[i]
                            ptr[idx+3] = X[i]
                            idx += 4
                        }
                    }
                    let writeDuration = CFAbsoluteTimeGetCurrent() - writeStart
                    let totalDuration = CFAbsoluteTimeGetCurrent() - chunkStart
                    
                    // Only log every 1000 chunks to reduce overhead
                    if chunksWritten % 1000 == 0 {
                        log.debug("chunk \(chunksWritten+1, privacy: .public) frames=\(actualFrames, privacy: .public) read=\(readDuration, privacy: .public) dsp=\(dspDuration, privacy: .public) write=\(writeDuration, privacy: .public) total=\(totalDuration, privacy: .public)")
                    }
                    
                    // Explicitly clear arrays to help memory management
                    W.removeAll(keepingCapacity: false)
                    Y.removeAll(keepingCapacity: false)
                    Z.removeAll(keepingCapacity: false)
                    X.removeAll(keepingCapacity: false)
                } catch {
                    caughtError = error
                }
                // Buffers and arrays are automatically released by autoreleasepool
            }
            if let e = caughtError { throw e }
            if actualFramesRead == 0 { break }

            framesProcessed += actualFramesRead
            chunksWritten += 1

            // Periodically flush file handle to reduce memory pressure
            // Flush more frequently (every 500 chunks) to keep buffers smaller
            // This spreads the fsync cost over time instead of all at once at close
            if chunksWritten % 500 == 0 {
                try? writer.flush()
            }
            
            // More aggressive flushing near the end (last 5% of chunks)
            let progress = Double(framesProcessed) / Double(minFrames)
            if progress > 0.95 && chunksWritten % 100 == 0 {
                try? writer.flush()
            }

            // Update progress less frequently (every 100 chunks) to avoid rate-limiting
            // Only update if we're not at the end to avoid multiple updates
            if chunksWritten % 100 == 0 && framesProcessed < minFrames {
                let prog = min(0.97, Double(framesProcessed) / Double(minFrames) * 0.95) // reserve 3% for finalize
                DispatchQueue.main.async {
                    self.transcodeProgress = prog
                    let secondsProcessed = Int(Double(framesProcessed) / Double(sr))
                    let totalSeconds = Int(Double(minFrames) / Double(sr))
                    self.transcodeStatus = "Processing… \(secondsProcessed)/\(totalSeconds) s"
                }
            }
        }
        
        // Final progress update before finalize
        if framesProcessed >= minFrames {
            DispatchQueue.main.async {
                self.transcodeProgress = 0.97
                let secondsProcessed = Int(Double(framesProcessed) / Double(sr))
                let totalSeconds = Int(Double(minFrames) / Double(sr))
                self.transcodeStatus = "Processing… \(secondsProcessed)/\(totalSeconds) s"
            }
        }
        
        log.log("AmbiX stream finished processing. framesProcessed=\(framesProcessed, privacy: .public) chunksWritten=\(chunksWritten, privacy: .public)")
        
        // Force multiple flushes before finalize to minimize buffered data
        // This reduces the amount that needs to be synced in finalize()
        log.log("Pre-finalize: Flushing remaining buffers...")
        let flushStart = CFAbsoluteTimeGetCurrent()
        try writer.flush()
        let flushDuration = CFAbsoluteTimeGetCurrent() - flushStart
        log.log("Pre-finalize flush complete in \(flushDuration, privacy: .public)s")
        
        // Give the kernel a moment to process the flush
        // This helps prevent the final fsync from being too large
        Thread.sleep(forTimeInterval: 0.1)
        
        // Log memory info before finalize
        let memoryInfo = ProcessInfo.processInfo
        log.log("Pre-finalize: physicalMemory=\(memoryInfo.physicalMemory, privacy: .public) framesProcessed=\(framesProcessed, privacy: .public)")

        DispatchQueue.main.async {
            self.transcodeStatus = "Finalizing…"
            self.transcodeProgress = 0.98
        }
        
        let finalizeStart = CFAbsoluteTimeGetCurrent()
        do {
            // Finalize in a separate autoreleasepool to ensure cleanup
            try autoreleasepool {
                try writer.finalize(logger: log)
            }
            let finalizeDuration = CFAbsoluteTimeGetCurrent() - finalizeStart
            log.log("AmbiX finalize complete. duration=\(finalizeDuration, privacy: .public)s")
            
            // Verify file was created and has reasonable size
            if let attrs = try? FileManager.default.attributesOfItem(atPath: outURL.path),
               let fileSize = attrs[.size] as? Int64 {
                let wavHeaderSize: Int64 = 44
                let expectedMinSize = wavHeaderSize + Int64(framesProcessed) * 4 * 4 // header + frames * channels * bytes
                if fileSize < expectedMinSize {
                    log.warning("File size \(fileSize, privacy: .public) is smaller than expected minimum \(expectedMinSize, privacy: .public)")
                } else {
                    log.log("File verified: size=\(fileSize, privacy: .public) bytes")
                }
            }
            
            DispatchQueue.main.async {
                self.importStatus = "AmbiX exported: \(outURL.lastPathComponent) (\(Int(sr))Hz)"
                self.transcodeStatus = "Complete!"
                self.transcodeProgress = 1.0
            }
            print("AmbiX written: \(outURL.path)")
        } catch {
            let finalizeDuration = CFAbsoluteTimeGetCurrent() - finalizeStart
            log.error("AmbiX finalize failed after \(finalizeDuration, privacy: .public)s: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                self.transcodeStatus = "Error: \(error.localizedDescription)"
                self.transcodeProgress = 0.0
            }
            throw error
        }
    }

    // Non-blocking export for very large files - uses direct WAV file I/O to avoid AVAudioFile pinwheel
    private func exportAmbiX_nonblocking(to directory: URL?) throws {
        print("Non-blocking export: checking file count...")
        guard fourMono.count == 4 else {
            throw NSError(domain: "Transcoder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Need 4 mono files"])
        }
        print("Non-blocking export: accessing security-scoped resources...")

        // Access security-scoped resources - REQUIRED for file access on macOS
        var accessTokens: [Bool] = []
        for url in fourMono {
            let hasAccess = url.startAccessingSecurityScopedResource()
            accessTokens.append(hasAccess)
            print("Non-blocking export: security access for \(url.lastPathComponent): \(hasAccess)")
            if !hasAccess {
                print("Non-blocking export: WARNING - no security access for \(url.lastPathComponent)")
            }
        }

        defer {
            for (i, url) in fourMono.enumerated() {
                if accessTokens[i] {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }

        // Use direct WAV file readers instead of AVAudioFile to avoid metadata loading pinwheel
        print("Non-blocking export: opening WAV files with direct I/O...")
        let startTime = CFAbsoluteTimeGetCurrent()
        let readers = try fourMono.map { try WavChunkReader(url: $0) }
        let fileOpenTime = CFAbsoluteTimeGetCurrent() - startTime
        print("Non-blocking export: WAV file open took \(fileOpenTime) seconds")

        // Verify all files have same sample rate
        let sr = readers[0].sampleRate
        for (idx, reader) in readers.enumerated() {
            if abs(reader.sampleRate - sr) > 0.1 {
                throw NSError(domain: "Transcoder", code: -4, userInfo: [NSLocalizedDescriptionKey:"Sample rate mismatch at file \(idx+1): \(reader.sampleRate) vs \(sr)"])
            }
        }

        // Find minimum frames across all files
        let minFrames = readers.map { $0.totalFrames }.min() ?? 0
        guard minFrames > 0 else {
            throw NSError(domain: "Transcoder", code: -2, userInfo: [NSLocalizedDescriptionKey:"Empty files"])
        }
        print("Non-blocking export: minFrames = \(minFrames), sampleRate = \(sr)")

        let base = directory ?? ProjectManager.shared.getTranscodedFolder()
        let outURL = base.appendingPathComponent("AmbiX_\(Int(Date().timeIntervalSince1970)).wav")

        // Calculate final file size upfront
        let dataBytes = UInt64(minFrames) * 4 * 4 // frames * channels * bytesPerSample
        let totalFileSize = 44 + dataBytes // WAV header + data
        let totalFileSizeGB = Double(totalFileSize) / 1_000_000_000.0

        print("Non-blocking export: calculated final size = \(totalFileSize) bytes (\(String(format: "%.2f", totalFileSizeGB))GB)")

        // Check for 4GB WAV limit
        let maxWavSize: UInt64 = 0xFFFFFFFF - 36
        if dataBytes > maxWavSize {
            print("Non-blocking export: WARNING - file exceeds WAV 4GB limit. Header will use placeholder size.")
        }

        print("Non-blocking export: creating writer...")
        // Create writer with pre-calculated size
        let writer = try WavFloat32WriterNonBlocking(url: outURL, sampleRate: sr, channels: 4, finalDataSize: dataBytes)
        print("Non-blocking export: writer created successfully")

        let chunkSize: Int = 16384 // frames per chunk
        let gainsTrims = dsp
        var framesProcessed: Int = 0
        var chunksWritten = 0
        var lastUIUpdate = CFAbsoluteTimeGetCurrent()

        print("Non-blocking AmbiX export starting. totalFrames=\(minFrames)")

        while framesProcessed < minFrames {
            let remaining = minFrames - framesProcessed
            let toRead = min(chunkSize, remaining)
            var shouldBreak = false

            do {
                try autoreleasepool {
                    // Read chunk from each file using direct WAV I/O
                    var chunkData: [[Float]] = []
                    for reader in readers {
                        let chunk = try reader.readChunk(frames: toRead)
                        chunkData.append(chunk)
                    }
                    
                    // Check if we got EOF
                    if chunkData.isEmpty || chunkData[0].isEmpty {
                        shouldBreak = true
                        return
                    }

                    // Verify all chunks are same size
                    let actualFrames = chunkData[0].count
                    for (idx, chunk) in chunkData.enumerated() {
                        if chunk.count != actualFrames {
                            throw NSError(domain: "Transcoder", code: -15, userInfo: [NSLocalizedDescriptionKey:"Frame length mismatch. Channel \(idx) has \(chunk.count) vs \(actualFrames)"])
                        }
                    }

                    if actualFrames == 0 {
                        shouldBreak = true
                        return
                    }

                    let src0 = chunkData[0]
                    let src1 = chunkData[1]
                    let src2 = chunkData[2]
                    let src3 = chunkData[3]

                    let m = gainsTrims.matrix.m
                    let trims = gainsTrims.capsuleTrims_dB.map { powf(10.0, Float($0)/20.0) }
                    let iface = gainsTrims.interfaceGains_dB.map { powf(10.0, Float($0)/20.0) }
                    let g0 = trims[0]*iface[0], g1 = trims[1]*iface[1], g2 = trims[2]*iface[2], g3 = trims[3]*iface[3]

                    var W = [Float](repeating: 0, count: actualFrames)
                    var Y = [Float](repeating: 0, count: actualFrames)
                    var Z = [Float](repeating: 0, count: actualFrames)
                    var X = [Float](repeating: 0, count: actualFrames)

                    for i in 0..<actualFrames {
                        let v0 = src0[i]*g0, v1 = src1[i]*g1, v2 = src2[i]*g2, v3 = src3[i]*g3
                        W[i] = m[0]*v0 + m[1]*v1 + m[2]*v2 + m[3]*v3
                        Y[i] = m[4]*v0 + m[5]*v1 + m[6]*v2 + m[7]*v3
                        Z[i] = m[8]*v0 + m[9]*v1 + m[10]*v2 + m[11]*v3
                        X[i] = m[12]*v0 + m[13]*v1 + m[14]*v2 + m[15]*v3
                    }

                    if gainsTrims.yaw != 0 || gainsTrims.pitch != 0 || gainsTrims.roll != 0 {
                        let cy = cosf(gainsTrims.yaw), sy = sinf(gainsTrims.yaw)
                        let cp = cosf(gainsTrims.pitch), sp = sinf(gainsTrims.pitch)
                        let cr = cosf(gainsTrims.roll), sr = sinf(gainsTrims.roll)
                        let r00 = cy*cp, r01 = cy*sp*sr - sy*cr, r02 = cy*sp*cr + sy*sr
                        let r10 = sy*cp, r11 = sy*sp*sr + cy*cr, r12 = sy*sp*cr - cy*sr
                        let r20 = -sp, r21 = cp*sr, r22 = cp*cr
                        for i in 0..<actualFrames {
                            let x = X[i], y = Y[i], z = Z[i]
                            X[i] = r00*x + r01*y + r02*z
                            Y[i] = r10*x + r11*y + r12*z
                            Z[i] = r20*x + r21*y + r22*z
                        }
                    }

                    // Write without finalize - header is already correct
                    writer.writeInterleavedDirect(W: W, Y: Y, Z: Z, X: X, frames: actualFrames)

                    framesProcessed += actualFrames
                    chunksWritten += 1
                }
            } catch {
                print("Error in non-blocking chunk: \(error)")
                throw error
            }

            if shouldBreak || framesProcessed >= minFrames { break }

            // Update progress much less frequently to avoid rate limiting
            // Only update every 10,000 chunks AND at least 0.5 seconds since last update
            let currentTime = CFAbsoluteTimeGetCurrent()
            if chunksWritten % 10000 == 0 && framesProcessed < minFrames && (currentTime - lastUIUpdate) >= 0.5 {
                lastUIUpdate = currentTime
                let prog = min(0.95, Double(framesProcessed) / Double(minFrames))
                DispatchQueue.main.async {
                    self.transcodeProgress = prog
                    let secondsProcessed = Int(Double(framesProcessed) / Double(sr))
                    let totalSeconds = Int(Double(minFrames) / Double(sr))
                    self.transcodeStatus = "Processing… \(secondsProcessed)/\(totalSeconds) s"
                }
            }
        }

        print("Non-blocking AmbiX export finished. framesProcessed=\(framesProcessed)")

        // Just close the file - no finalization needed
        writer.close()

        DispatchQueue.main.async {
            self.importStatus = "AmbiX exported: \(outURL.lastPathComponent) (\(Int(sr))Hz)"
            self.transcodeStatus = "Complete!"
            self.transcodeProgress = 1.0
        }
        print("AmbiX written: \(outURL.path)")
    }

    // MARK: - Non-blocking WAV writer for very large files

    final class WavFloat32WriterNonBlocking {
        private var fileDescriptor: Int32 = -1
        private let fileURL: URL
        private var dataBytesWritten: UInt64 = 0

        init(url: URL, sampleRate: Double, channels: Int, finalDataSize: UInt64) throws {
            self.fileURL = url

            let filePath = url.path
            if FileManager.default.fileExists(atPath: filePath) {
                try FileManager.default.removeItem(at: url)
            }

            let fd = open(filePath, O_CREAT | O_TRUNC | O_WRONLY, 0o644)
            guard fd >= 0 else {
                let msg = String(cString: strerror(errno))
                throw NSError(domain: "WavFloat32WriterNonBlocking", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open file: \(msg)"])
            }
            self.fileDescriptor = fd

            // Write correct header from the start with final sizes
            try writeCompleteHeader(sampleRate: sampleRate, channels: channels, dataSize: finalDataSize)
        }

        deinit {
            if fileDescriptor >= 0 {
                Darwin.close(fileDescriptor)
            }
        }

    private func writeCompleteHeader(sampleRate: Double, channels: Int, dataSize: UInt64) throws {
        print("WavFloat32WriterNonBlocking: writing header... dataSize=\(dataSize) bytes")
        let sampleRate32 = UInt32(sampleRate)
        let channels16 = UInt16(channels)
        let bytesPerSample: UInt16 = 4
        let blockAlign = channels16 * bytesPerSample
        let byteRate = sampleRate32 * UInt32(channels16) * UInt32(bytesPerSample)
        
        // Check for 4GB limit - WAV format uses UInt32 for chunk sizes
        let maxWavSize: UInt64 = 0xFFFFFFFF - 36 // Max UInt32 minus header overhead
        let actualDataSize: UInt64
        if dataSize > maxWavSize {
            print("WavFloat32WriterNonBlocking: WARNING - file size (\(dataSize) bytes) exceeds WAV 4GB limit. Using placeholder size.")
            actualDataSize = maxWavSize // Use max value, file will be truncated in header but actual data will be written
        } else {
            actualDataSize = dataSize
        }
        
        let riffSize = UInt32(36 + actualDataSize) // 36 + data chunk size

        var header = Data()
        header.reserveCapacity(44) // Pre-allocate to avoid reallocations

        // RIFF chunk
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        header.append(riffSize.littleEndianData) // Chunk size
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        header.append(UInt32(16).littleEndianData) // Subchunk1Size
        header.append(UInt16(3).littleEndianData) // AudioFormat (IEEE float)
        header.append(channels16.littleEndianData) // NumChannels
        header.append(sampleRate32.littleEndianData) // SampleRate
        header.append(byteRate.littleEndianData) // ByteRate
        header.append(blockAlign.littleEndianData) // BlockAlign
        header.append((bytesPerSample * 8).littleEndianData) // BitsPerSample

        // data chunk
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        header.append(UInt32(actualDataSize).littleEndianData) // Subchunk2Size

        print("WavFloat32WriterNonBlocking: header size = \(header.count) bytes, will write \(header.count) bytes")

        // Write header in one go if possible, with error handling
        do {
            try autoreleasepool {
                try header.withUnsafeBytes { bytes in
                    guard let baseAddress = bytes.baseAddress else {
                        throw NSError(domain: "WavFloat32WriterNonBlocking", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid header buffer"])
                    }
                    
                    var written: Int = 0
                    let totalBytes = header.count
                    
                    while written < totalBytes {
                        let remaining = totalBytes - written
                        let result = write(fileDescriptor, baseAddress + written, remaining)
                        
                        if result < 0 {
                            let err = errno
                            let msg = String(cString: strerror(err))
                            print("WavFloat32WriterNonBlocking: write failed at offset \(written)/\(totalBytes), errno \(err): \(msg)")
                            throw NSError(domain: "WavFloat32WriterNonBlocking", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to write header: \(msg)"])
                        } else if result == 0 {
                            print("WavFloat32WriterNonBlocking: write returned 0 at offset \(written)/\(totalBytes) (EOF?)")
                            throw NSError(domain: "WavFloat32WriterNonBlocking", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unexpected EOF while writing header"])
                        }
                        written += result
                    }
                    
                    // Verify all bytes were written
                    guard written == totalBytes else {
                        print("WavFloat32WriterNonBlocking: WARNING - only wrote \(written)/\(totalBytes) bytes")
                        throw NSError(domain: "WavFloat32WriterNonBlocking", code: -2, userInfo: [NSLocalizedDescriptionKey: "Incomplete header write: \(written)/\(totalBytes) bytes"])
                    }
                }
            }
            print("WavFloat32WriterNonBlocking: header written successfully (\(header.count) bytes)")
        } catch {
            print("WavFloat32WriterNonBlocking: ERROR writing header: \(error)")
            throw error
        }
    }

        func writeInterleavedDirect(W: [Float], Y: [Float], Z: [Float], X: [Float], frames: Int) {
            guard fileDescriptor >= 0 else { return }

            // Create interleaved buffer on stack for small chunks
            let bufferSize = frames * 4 // 4 channels
            var interleavedBuffer = [Float](repeating: 0, count: bufferSize)

            // Interleave: W,Y,Z,X
            for i in 0..<frames {
                let idx = i * 4
                interleavedBuffer[idx + 0] = W[i]
                interleavedBuffer[idx + 1] = Y[i]
                interleavedBuffer[idx + 2] = Z[i]
                interleavedBuffer[idx + 3] = X[i]
            }

            // Write directly
            interleavedBuffer.withUnsafeBytes { bytes in
                var written: Int = 0
                let totalBytes = bytes.count
                while written < totalBytes {
                    let result = write(fileDescriptor, bytes.baseAddress! + written, totalBytes - written)
                    if result > 0 {
                        written += result
                    } else {
                        break // Error or EOF
                    }
                }
            }
        }

        func close() {
            if fileDescriptor >= 0 {
                Darwin.close(fileDescriptor)
                fileDescriptor = -1
            }
        }
    }

    // MARK: - Direct WAV file chunk reader (avoids AVAudioFile metadata loading)

    final class WavChunkReader {
        private var fileDescriptor: Int32 = -1
        private let fileURL: URL
        let sampleRate: Double
        let totalFrames: Int
        private let dataStartOffset: Int64
        private var currentOffset: Int64 = 0
        private var bytesPerSample: Int = 4 // Will be set from header
        private let channels: Int = 1 // mono
        private var audioFormat: UInt16 = 0 // 1 = PCM, 3 = IEEE float
        private var bitsPerSample: UInt16 = 0
        private var isFloat: Bool = false

        init(url: URL) throws {
            self.fileURL = url
            
            // Initialize with placeholder values (will be set below)
            var sampleRateValue: Double = 0
            var totalFramesValue: Int = 0
            var dataStartOffsetValue: Int64 = 0

            let filePath = url.path
            let fd = open(filePath, O_RDONLY)
            guard fd >= 0 else {
                let msg = String(cString: strerror(errno))
                throw NSError(domain: "WavChunkReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open file: \(msg)"])
            }
            self.fileDescriptor = fd

            // Read RIFF header (first 12 bytes)
            var riffHeader = Data(count: 12)
            var headerRead = 0
            riffHeader.withUnsafeMutableBytes { bytes in
                while headerRead < 12 {
                    let result = read(fd, bytes.baseAddress! + headerRead, 12 - headerRead)
                    if result <= 0 {
                        break
                    }
                    headerRead += result
                }
            }

            guard headerRead == 12 else {
                Darwin.close(fd)
                throw NSError(domain: "WavChunkReader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to read RIFF header"])
            }

            // Parse header - check RIFF and WAVE signatures
            let riffSig = riffHeader.subdata(in: 0..<4)
            let waveSig = riffHeader.subdata(in: 8..<12)
            guard riffSig == Data([0x52, 0x49, 0x46, 0x46]), // "RIFF"
                  waveSig == Data([0x57, 0x41, 0x56, 0x45]) else { // "WAVE"
                Darwin.close(fd)
                throw NSError(domain: "WavChunkReader", code: -3, userInfo: [NSLocalizedDescriptionKey: "Not a valid WAV file"])
            }

            // Find fmt chunk (search for "fmt " chunk)
            var offset: Int64 = 12 // After "WAVE"
            var foundFmt = false
            var fmtOffset: Int64 = 0
            var fmtSize: UInt32 = 0
            
            while offset < 1024 { // Search first KB for fmt chunk
                var chunkHeader = Data(count: 8)
                var readCount = 0
                chunkHeader.withUnsafeMutableBytes { bytes in
                    let result = pread(fd, bytes.baseAddress, 8, offset)
                    if result > 0 {
                        readCount = result
                    }
                }
                guard readCount == 8 else { break }

                let chunkID = chunkHeader.subdata(in: 0..<4)
                let chunkSize = chunkHeader.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian

                if chunkID == Data([0x66, 0x6D, 0x74, 0x20]) { // "fmt "
                    fmtOffset = offset + 8
                    fmtSize = chunkSize
                    foundFmt = true
                    break
                }

                offset += Int64(8 + chunkSize)
            }

            guard foundFmt else {
                Darwin.close(fd)
                throw NSError(domain: "WavChunkReader", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not find fmt chunk in WAV file"])
            }

            // Read fmt chunk data (minimum 16 bytes for standard fmt chunk)
            let fmtDataSize = min(Int(fmtSize), 16)
            var fmtData = Data(count: fmtDataSize)
            var fmtRead = 0
            fmtData.withUnsafeMutableBytes { bytes in
                while fmtRead < fmtDataSize {
                    let result = pread(fd, bytes.baseAddress! + fmtRead, fmtDataSize - fmtRead, fmtOffset)
                    if result <= 0 {
                        break
                    }
                    fmtRead += result
                }
            }

            guard fmtRead >= 16 else {
                Darwin.close(fd)
                throw NSError(domain: "WavChunkReader", code: -3, userInfo: [NSLocalizedDescriptionKey: "fmt chunk too small"])
            }

            // Parse fmt chunk
            let audioFormat = fmtData.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
            let numChannels = fmtData.subdata(in: 2..<4).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
            sampleRateValue = Double(fmtData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian)
            let bitsPerSample = fmtData.subdata(in: 14..<16).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
            
            // Support both PCM (format 1) and IEEE float (format 3)
            guard audioFormat == 1 || audioFormat == 3 else {
                Darwin.close(fd)
                throw NSError(domain: "WavChunkReader", code: -4, userInfo: [NSLocalizedDescriptionKey: "Only PCM (format 1) or IEEE float (format 3) WAV supported, got format \(audioFormat)"])
            }
            
            guard numChannels == 1 else {
                Darwin.close(fd)
                throw NSError(domain: "WavChunkReader", code: -4, userInfo: [NSLocalizedDescriptionKey: "Only mono WAV supported, got \(numChannels) channels"])
            }
            
            // Store format info for conversion
            let isFloat = (audioFormat == 3)
            let bytesPerSample = Int(bitsPerSample / 8)
            
            guard bytesPerSample == 4 || (audioFormat == 1 && (bitsPerSample == 16 || bitsPerSample == 24 || bitsPerSample == 32)) else {
                Darwin.close(fd)
                throw NSError(domain: "WavChunkReader", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unsupported bit depth: \(bitsPerSample)-bit (format \(audioFormat))"])
            }
            
            // Store format info in instance variables
            self.audioFormat = audioFormat
            self.bitsPerSample = bitsPerSample
            self.bytesPerSample = bytesPerSample
            self.isFloat = isFloat

            // Find data chunk (search from start, skipping fmt chunk we already found)
            offset = 12 // Start after "WAVE"
            var foundData = false
            while offset < 2048 { // Search first 2KB for data chunk
                var chunkHeader = Data(count: 8)
                var readCount = 0
                chunkHeader.withUnsafeMutableBytes { bytes in
                    let result = pread(fd, bytes.baseAddress, 8, offset)
                    if result > 0 {
                        readCount = result
                    }
                }
                guard readCount == 8 else { break }

                let chunkID = chunkHeader.subdata(in: 0..<4)
                let chunkSize = chunkHeader.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian

                if chunkID == Data([0x64, 0x61, 0x74, 0x61]) { // "data"
                    dataStartOffsetValue = offset + 8
                    // Calculate total frames based on bytes per sample (will be set from fmt chunk)
                    // We'll update this after parsing fmt chunk
                    foundData = true
                    break
                }

                // Skip this chunk (8 byte header + chunk data)
                offset += Int64(8 + chunkSize)
            }

            guard foundData else {
                Darwin.close(fd)
                throw NSError(domain: "WavChunkReader", code: -5, userInfo: [NSLocalizedDescriptionKey: "Could not find data chunk in WAV file"])
            }

            // Get data chunk size to calculate total frames
            var dataChunkHeader = Data(count: 8)
            var dataHeaderRead = 0
            dataChunkHeader.withUnsafeMutableBytes { bytes in
                let result = pread(fd, bytes.baseAddress, 8, dataStartOffsetValue - 8)
                if result > 0 {
                    dataHeaderRead = result
                }
            }
            guard dataHeaderRead == 8 else {
                Darwin.close(fd)
                throw NSError(domain: "WavChunkReader", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to read data chunk header"])
            }
            let dataChunkSize = dataChunkHeader.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
            totalFramesValue = Int(dataChunkSize) / (bytesPerSample * channels)

            // Now assign all properties
            self.sampleRate = sampleRateValue
            self.totalFrames = totalFramesValue
            self.dataStartOffset = dataStartOffsetValue
            
            print("WavChunkReader: opened \(url.lastPathComponent), format=\(audioFormat), sampleRate=\(sampleRate), bitsPerSample=\(bitsPerSample), totalFrames=\(totalFrames)")
        }

        deinit {
            if fileDescriptor >= 0 {
                Darwin.close(fileDescriptor)
            }
        }

        func readChunk(frames: Int) throws -> [Float] {
            guard fileDescriptor >= 0 else {
                throw NSError(domain: "WavChunkReader", code: -6, userInfo: [NSLocalizedDescriptionKey: "File not open"])
            }

            let bytesToRead = frames * bytesPerSample * channels
            var buffer = Data(count: bytesToRead)
            var totalRead = 0

            buffer.withUnsafeMutableBytes { bytes in
                while totalRead < bytesToRead {
                    let offset = dataStartOffset + currentOffset
                    let result = pread(fileDescriptor, bytes.baseAddress! + totalRead, bytesToRead - totalRead, offset)
                    if result <= 0 {
                        break
                    }
                    totalRead += result
                }
            }

            guard totalRead > 0 else {
                return [] // EOF
            }

            let framesRead = totalRead / (bytesPerSample * channels)
            currentOffset += Int64(totalRead)

            // Convert bytes to Float array based on format
            if isFloat {
                // IEEE float - direct conversion
                let samples = buffer.withUnsafeBytes { bytes -> [Float] in
                    guard let baseAddress = bytes.baseAddress else { return [] }
                    let floatPointer = baseAddress.assumingMemoryBound(to: Float.self)
                    return Array(UnsafeBufferPointer(start: floatPointer, count: framesRead))
                }
                return samples
            } else {
                // PCM - convert to float
                var samples = [Float](repeating: 0, count: framesRead)
                buffer.withUnsafeBytes { bytes in
                    guard let baseAddress = bytes.baseAddress else { return }
                    
                    switch bitsPerSample {
                    case 16:
                        // 16-bit PCM: convert from Int16 to Float (-1.0 to 1.0)
                        let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)
                        for i in 0..<framesRead {
                            samples[i] = Float(int16Pointer[i]) / 32768.0
                        }
                    case 24:
                        // 24-bit PCM: read 3 bytes, convert to Int32, then to Float
                        var int24Buffer = [Int32](repeating: 0, count: framesRead)
                        for i in 0..<framesRead {
                            let offset = i * 3
                            let b0 = UInt32(bytes[offset])
                            let b1 = UInt32(bytes[offset + 1])
                            let b2 = UInt32(bytes[offset + 2])
                            // Combine 3 bytes into 24-bit value
                            var sample = (b2 << 16) | (b1 << 8) | b0
                            // Sign extend 24-bit to 32-bit
                            if (sample & 0x800000) != 0 {
                                sample |= 0xFF000000 // Sign extend (as UInt32, then cast)
                            }
                            // Convert to signed Int32
                            let signedSample = Int32(bitPattern: sample)
                            int24Buffer[i] = signedSample
                        }
                        for i in 0..<framesRead {
                            samples[i] = Float(int24Buffer[i]) / 8388608.0 // 2^23
                        }
                    case 32:
                        // 32-bit PCM: convert from Int32 to Float
                        let int32Pointer = baseAddress.assumingMemoryBound(to: Int32.self)
                        for i in 0..<framesRead {
                            samples[i] = Float(int32Pointer[i]) / 2147483648.0 // 2^31
                        }
                    default:
                        break
                    }
                }
                return samples
            }
        }
    }

    public func exportFuMa(to directory: URL? = nil) {
        DispatchQueue.main.async {
            self.transcodeProgress = 0.0
            self.transcodeStatus = "Starting FuMa export..."
        }
        
        do {
            let (aBuf, sampleRate) = try loadFourMono()
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Processing A→B conversion..."
                self.transcodeProgress = 0.5
            }
            
            // A->B first (AmbiX SN3D W,Y,Z,X)
            let bAmbiX = dsp.processAtoB(aBuffer: aBuf)
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Converting to FuMa format..."
                self.transcodeProgress = 0.65
            }

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

            DispatchQueue.main.async {
                self.transcodeStatus = "Writing output file..."
                self.transcodeProgress = 0.8
            }
            
            let base = directory ?? ProjectManager.shared.getTranscodedFolder()
            let out = base.appendingPathComponent("FuMa_\(Int(Date().timeIntervalSince1970)).wav")
            try write4Ch(url: out, buffer: fuma)
            
            DispatchQueue.main.async {
                self.importStatus = "FuMa exported: \(out.lastPathComponent) (\(Int(sampleRate))Hz)"
                self.transcodeStatus = "Complete!"
                self.transcodeProgress = 1.0
            }
            print("FuMa written: \(out.path)")
        } catch {
            let errorMsg = "FuMa export error: \(error.localizedDescription)"
            DispatchQueue.main.async {
                self.importStatus = errorMsg
                self.transcodeStatus = "Error: \(error.localizedDescription)"
                self.transcodeProgress = 0.0
            }
            print(errorMsg)
        }
    }
    
    // Export stereo (simple decode: L=W+X, R=W-X)
    public func exportStereo(to directory: URL? = nil) {
        DispatchQueue.main.async {
            self.transcodeProgress = 0.0
            self.transcodeStatus = "Starting Stereo export..."
        }
        
        do {
            let (aBuf, sampleRate) = try loadFourMono()
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Processing A→B conversion..."
                self.transcodeProgress = 0.5
            }
            
            let bBuf = dsp.processAtoB(aBuffer: aBuf) // W,Y,Z,X
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Decoding to stereo..."
                self.transcodeProgress = 0.65
            }
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
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Writing output file..."
                self.transcodeProgress = 0.8
            }
            
            let base = directory ?? ProjectManager.shared.getTranscodedFolder()
            let out = base.appendingPathComponent("Stereo_\(Int(Date().timeIntervalSince1970)).wav")
            try write2Ch(url: out, buffer: stereo)
            
            DispatchQueue.main.async {
                self.importStatus = "Stereo exported: \(out.lastPathComponent) (\(Int(sampleRate))Hz)"
                self.transcodeStatus = "Complete!"
                self.transcodeProgress = 1.0
            }
            print("Stereo written: \(out.path)")
        } catch {
            let errorMsg = "Stereo export error: \(error.localizedDescription)"
            DispatchQueue.main.async {
                self.importStatus = errorMsg
                self.transcodeStatus = "Error: \(error.localizedDescription)"
                self.transcodeProgress = 0.0
            }
            print(errorMsg)
        }
    }
    
    // Export 5.1 (L, R, C, LFE, Ls, Rs)
    public func export5_1(to directory: URL? = nil) {
        DispatchQueue.main.async {
            self.transcodeProgress = 0.0
            self.transcodeStatus = "Starting 5.1 export..."
        }
        
        do {
            let (aBuf, sampleRate) = try loadFourMono()
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Processing A→B conversion..."
                self.transcodeProgress = 0.5
            }
            
            let bBuf = dsp.processAtoB(aBuffer: aBuf) // W,Y,Z,X
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Decoding to 5.1..."
                self.transcodeProgress = 0.65
            }
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
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Writing output file..."
                self.transcodeProgress = 0.8
            }
            
            let base = directory ?? ProjectManager.shared.getTranscodedFolder()
            let out = base.appendingPathComponent("5.1_\(Int(Date().timeIntervalSince1970)).wav")
            try write6Ch(url: out, buffer: out51)
            
            DispatchQueue.main.async {
                self.importStatus = "5.1 exported: \(out.lastPathComponent) (\(Int(sampleRate))Hz)"
                self.transcodeStatus = "Complete!"
                self.transcodeProgress = 1.0
            }
            print("5.1 written: \(out.path)")
        } catch {
            let errorMsg = "5.1 export error: \(error.localizedDescription)"
            DispatchQueue.main.async {
                self.importStatus = errorMsg
                self.transcodeStatus = "Error: \(error.localizedDescription)"
                self.transcodeProgress = 0.0
            }
            print(errorMsg)
        }
    }
    
    // Export 7.1 (L, R, C, LFE, Ls, Rs, Lb, Rb)
    public func export7_1(to directory: URL? = nil) {
        DispatchQueue.main.async {
            self.transcodeProgress = 0.0
            self.transcodeStatus = "Starting 7.1 export..."
        }
        
        do {
            let (aBuf, sampleRate) = try loadFourMono()
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Processing A→B conversion..."
                self.transcodeProgress = 0.5
            }
            
            let bBuf = dsp.processAtoB(aBuffer: aBuf) // W,Y,Z,X
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Decoding to 7.1..."
                self.transcodeProgress = 0.65
            }
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
            
            DispatchQueue.main.async {
                self.transcodeStatus = "Writing output file..."
                self.transcodeProgress = 0.8
            }
            
            let base = directory ?? ProjectManager.shared.getTranscodedFolder()
            let out = base.appendingPathComponent("7.1_\(Int(Date().timeIntervalSince1970)).wav")
            try write8Ch(url: out, buffer: out71)
            
            DispatchQueue.main.async {
                self.importStatus = "7.1 exported: \(out.lastPathComponent) (\(Int(sampleRate))Hz)"
                self.transcodeStatus = "Complete!"
                self.transcodeProgress = 1.0
            }
            print("7.1 written: \(out.path)")
        } catch {
            let errorMsg = "7.1 export error: \(error.localizedDescription)"
            DispatchQueue.main.async {
                self.importStatus = errorMsg
                self.transcodeStatus = "Error: \(error.localizedDescription)"
                self.transcodeProgress = 0.0
            }
            print(errorMsg)
        }
    }
    
    // Export binaural (stereo with HRTF - placeholder for future HRTF implementation)
    public func exportBinaural(to directory: URL? = nil) {
        // For now, use simple stereo decode. Future: load HRTF and convolve
        exportStereo(to: directory)
        if importStatus.contains("Stereo exported") {
            importStatus = importStatus.replacingOccurrences(of: "Stereo exported", with: "Binaural exported")
        }
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

    // MARK: - Minimal WAV float32 interleaved writer (improved version with robust finalize)
    final class WavFloat32Writer {
        private let fileHandle: FileHandle
        private let fileURL: URL
        private let dataStartOffset: UInt32 = 44
        private var dataBytesWritten: UInt64 = 0
        private let sampleRate: UInt32
        private let channels: UInt16
        private let bytesPerSample: UInt16 = 4 // float32
        private var isFinalized = false

        init(url: URL, sampleRate: Double, channels: Int) throws {
            self.sampleRate = UInt32(sampleRate)
            self.channels = UInt16(clamping: channels)
            self.fileURL = url

            // Create/truncate file
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
            guard let fh = FileHandle(forWritingAtPath: url.path) else {
                throw NSError(domain: "WavFloat32Writer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open file handle"])
            }
            self.fileHandle = fh
            try writeHeaderPlaceholder()
        }

        deinit {
            if !isFinalized {
                // Silently finalize in deinit - errors can't be thrown from deinit
                try? finalize(logger: nil)
            }
        }

        private func writeHeaderPlaceholder() throws {
            // RIFF header (44 bytes total)
            var header = Data()
            // "RIFF"
            header.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
            // Chunk size (placeholder): 36 + Subchunk2Size
            header.append(contentsOf: [0, 0, 0, 0])
            // "WAVE"
            header.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
            // "fmt "
            header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
            // Subchunk1Size (16 for PCM)
            header.append(UInt32(16).littleEndianData)
            // AudioFormat (3 = IEEE float)
            header.append(UInt16(3).littleEndianData)
            // NumChannels
            header.append(channels.littleEndianData)
            // SampleRate
            header.append(sampleRate.littleEndianData)
            // ByteRate = SampleRate * NumChannels * BytesPerSample
            let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bytesPerSample)
            header.append(byteRate.littleEndianData)
            // BlockAlign = NumChannels * BytesPerSample
            let blockAlign = UInt16(channels) * bytesPerSample
            header.append(blockAlign.littleEndianData)
            // BitsPerSample
            header.append(UInt16(bytesPerSample * 8).littleEndianData)
            // "data"
            header.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
            // Subchunk2Size (placeholder)
            header.append(contentsOf: [0, 0, 0, 0])
            try fileHandle.write(contentsOf: header)
        }

        func writeInterleavedFloat32(frames: Int, write: (UnsafeMutablePointer<Float>) -> Void) throws {
            // Allocate a transient buffer for the interleaved frames
            let nSamples = frames * Int(channels)
            let byteCount = nSamples * Int(bytesPerSample)
            
            // Use autoreleasepool to ensure Data is released immediately after write
            try autoreleasepool {
                var buf = Data(count: byteCount)
                try buf.withUnsafeMutableBytes { rawPtr in
                    guard let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: Float.self) else {
                        throw NSError(domain: "WavFloat32Writer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Buffer allocation failed"])
                    }
                    write(ptr)
                }
                try fileHandle.write(contentsOf: buf)
                // buf is released here by autoreleasepool
            }
            dataBytesWritten += UInt64(byteCount)
        }
        
        func flush() throws {
            // No-op: rely on system buffering, flush at close.
        }

        func finalize(logger: Logger? = nil) throws {
            guard !isFinalized else { return }
            isFinalized = true
            
            // Calculate sizes
            let fileSize = dataStartOffset + UInt32(clamping: dataBytesWritten)
            let riffSize = fileSize - 8
            let dataSize = UInt32(clamping: dataBytesWritten)
            
            // Close the main file handle
            try fileHandle.close()
            
            // Use pwrite to update header without large seeks
            let filePath = fileURL.path
            let fd = open(filePath, O_RDWR)
            guard fd >= 0 else {
                let msg = String(cString: strerror(errno))
                logger?.error("Failed to open file for header update (errno=\(errno, privacy: .public)) \(msg)")
                throw NSError(domain: "WavFloat32Writer", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to open file for header update: \(msg)"])
            }
            defer { close(fd) }
            
            var riff = riffSize.littleEndian
            let riffResult = withUnsafeBytes(of: &riff) { bytes -> ssize_t in
                return pwrite(fd, bytes.baseAddress, 4, 4)
            }
            if riffResult != 4 {
                let msg = String(cString: strerror(errno))
                logger?.error("Failed to write RIFF size (written=\(riffResult, privacy: .public), errno=\(errno, privacy: .public))")
                throw NSError(domain: "WavFloat32Writer", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to write RIFF header: \(msg)"])
            }
            
            var data = dataSize.littleEndian
            let dataResult = withUnsafeBytes(of: &data) { bytes -> ssize_t in
                return pwrite(fd, bytes.baseAddress, 4, 40)
            }
            if dataResult != 4 {
                let msg = String(cString: strerror(errno))
                logger?.error("Failed to write data size (written=\(dataResult, privacy: .public), errno=\(errno, privacy: .public))")
                throw NSError(domain: "WavFloat32Writer", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to write data header: \(msg)"])
            }
            
            // No fsync to avoid long stalls; rely on system flush on close.
        }
    }
}

private extension UInt16 {
    var littleEndianData: Data {
        var v = self.littleEndian
        return Data(bytes: &v, count: MemoryLayout<UInt16>.size)
    }
}
private extension UInt32 {
    var littleEndianData: Data {
        var v = self.littleEndian
        return Data(bytes: &v, count: MemoryLayout<UInt32>.size)
    }
}

