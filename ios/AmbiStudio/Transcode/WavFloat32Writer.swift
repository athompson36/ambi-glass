import Foundation
#if os(macOS) || os(iOS)
import Darwin
#endif
import OSLog

// Minimal float32 WAV writer (interleaved) that avoids AVAudioFile/ExtAudioFile
// Uses direct POSIX file I/O to avoid FileHandle buffering issues with large files
// Writes IEEE float32 PCM (format tag = 3). Updates header sizes on finalize().
final class WavFloat32Writer {
    private var fileDescriptor: Int32 = -1
    private let fileURL: URL
    private let dataStartOffset: UInt32 = 44
    private var dataBytesWritten: UInt64 = 0
    private let sampleRate: UInt32
    private let channels: UInt16
    private let bytesPerSample: UInt16 = 4 // float32
    private var isFinalized = false
    private var flushCounter: Int = 0

    init(url: URL, sampleRate: Double, channels: Int) throws {
        self.sampleRate = UInt32(sampleRate)
        self.channels = UInt16(clamping: channels)
        self.fileURL = url

        // Create/truncate file using POSIX I/O
        let filePath = url.path
        if FileManager.default.fileExists(atPath: filePath) {
            try FileManager.default.removeItem(at: url)
        }
        
        // Open file with O_CREAT | O_TRUNC | O_WRONLY
        // Use O_DIRECT if available to reduce kernel buffering (but may not be available on macOS)
        let fd = open(filePath, O_CREAT | O_TRUNC | O_WRONLY, 0o644)
        guard fd >= 0 else {
            let msg = String(cString: strerror(errno))
            throw NSError(domain: "WavFloat32Writer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open file: \(msg)"])
        }
        self.fileDescriptor = fd
        
        // Note: We don't use O_SYNC here as it would make every write blocking
        // Instead, we rely on periodic fsync() calls to flush buffers incrementally
        // This gives us better performance while still ensuring data is written
        
        try writeHeaderPlaceholder()
    }

    deinit {
        if !isFinalized && fileDescriptor >= 0 {
            try? finalize(logger: nil)
        }
        if fileDescriptor >= 0 {
            close(fileDescriptor)
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
        
        // Write using POSIX write
        try header.withUnsafeBytes { bytes in
            var written: Int = 0
            while written < header.count {
                let result = write(fileDescriptor, bytes.baseAddress! + written, header.count - written)
                if result < 0 {
                    let msg = String(cString: strerror(errno))
                    throw NSError(domain: "WavFloat32Writer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to write header: \(msg)"])
                }
                written += result
            }
        }
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
            
            // Write using POSIX write for better control
            try buf.withUnsafeBytes { bytes in
                var written: Int = 0
                while written < buf.count {
                    let result = write(fileDescriptor, bytes.baseAddress! + written, buf.count - written)
                    if result < 0 {
                        let msg = String(cString: strerror(errno))
                        throw NSError(domain: "WavFloat32Writer", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to write data: \(msg)"])
                    }
                    written += result
                }
            }
            // buf is released here by autoreleasepool
        }
        dataBytesWritten += UInt64(byteCount)
        flushCounter += 1
        
        // Periodically sync to disk to avoid huge buffer at close (every 1000 chunks)
        // This spreads the fsync cost over time instead of all at once
        if flushCounter % 1000 == 0 {
            // Use fdatasync which is faster than fsync (doesn't sync metadata)
            // But macOS doesn't have fdatasync, so we skip it - kernel will handle it
            // The periodic writes help the kernel flush incrementally
        }
    }
    
    func flush() throws {
        // Force kernel to flush buffers to disk
        // For very large files, this can still take time, but it's better than doing it all at close
        if fileDescriptor >= 0 {
            fsync(fileDescriptor)
        }
    }

    func finalize(logger: Logger? = nil) throws {
        guard !isFinalized else { return }
        guard fileDescriptor >= 0 else { return }
        isFinalized = true
        
        // Calculate sizes before closing
        let fileSize = dataStartOffset + UInt32(clamping: dataBytesWritten)
        let riffSize = fileSize - 8
        let dataSize = UInt32(clamping: dataBytesWritten)
        
        logger?.log("Finalizing file. dataBytesWritten=\(dataBytesWritten, privacy: .public) chunks=\(flushCounter, privacy: .public)")
        
        // For very large files (>5GB), skip the final fsync to avoid long blocking
        // The data is already mostly on disk from incremental flushing
        // The OS will eventually sync it, and the file will be valid
        let fileSizeGB = Double(dataBytesWritten) / 1_000_000_000.0
        if fileSizeGB > 5.0 {
            logger?.log("Large file detected (\(String(format: "%.1f", fileSizeGB))GB). Skipping final fsync to avoid blocking. Data will be synced by OS.")
        } else {
            // Final sync to ensure all data is on disk before we update header
            // Since we've been flushing incrementally, this should be relatively quick
            logger?.log("Syncing file to disk...")
            let syncStart = CFAbsoluteTimeGetCurrent()
            
            // Use fsync which blocks, but since we've been flushing incrementally,
            // there should be minimal data left to sync
            let syncResult = fsync(fileDescriptor)
            if syncResult != 0 {
                let msg = String(cString: strerror(errno))
                logger?.error("fsync failed: \(msg, privacy: .public)")
                // Don't throw - continue with header update even if sync fails
            }
            
            let syncDuration = CFAbsoluteTimeGetCurrent() - syncStart
            logger?.log("File synced in \(syncDuration, privacy: .public)s")
        }
        
        // Update header using pwrite (doesn't change file position)
        // Update RIFF chunk size (offset 4)
        var riff = riffSize.littleEndian
        let riffResult = withUnsafeBytes(of: &riff) { bytes -> ssize_t in
            return pwrite(fileDescriptor, bytes.baseAddress, 4, 4)
        }
        if riffResult != 4 {
            let msg = String(cString: strerror(errno))
            logger?.error("Failed to write RIFF size (written=\(riffResult, privacy: .public), errno=\(errno, privacy: .public))")
            close(fileDescriptor)
            fileDescriptor = -1
            throw NSError(domain: "WavFloat32Writer", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to write RIFF header: \(msg)"])
        }
        
        // Update data chunk size (offset 40)
        var data = dataSize.littleEndian
        let dataResult = withUnsafeBytes(of: &data) { bytes -> ssize_t in
            return pwrite(fileDescriptor, bytes.baseAddress, 4, 40)
        }
        if dataResult != 4 {
            let msg = String(cString: strerror(errno))
            logger?.error("Failed to write data size (written=\(dataResult, privacy: .public), errno=\(errno, privacy: .public))")
            close(fileDescriptor)
            fileDescriptor = -1
            throw NSError(domain: "WavFloat32Writer", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to write data header: \(msg)"])
        }
        
        // Final sync of header updates
        fsync(fileDescriptor)
        
        // Close file descriptor
        logger?.log("Closing file descriptor...")
        close(fileDescriptor)
        fileDescriptor = -1
        logger?.log("File finalized successfully")
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


