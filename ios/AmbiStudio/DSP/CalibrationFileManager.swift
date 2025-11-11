import Foundation

final class CalibrationFileManager {
    static let shared = CalibrationFileManager()
    
    private init() {}
    
    // Save calibration curve to file
    func saveCalibration(
        curve: MicCalCurve,
        name: String,
        to folder: URL
    ) throws -> URL {
        // Create Calibrations subfolder if it doesn't exist
        let calibrationsFolder = folder.appendingPathComponent("Calibrations", isDirectory: true)
        if !FileManager.default.fileExists(atPath: calibrationsFolder.path) {
            try FileManager.default.createDirectory(at: calibrationsFolder, withIntermediateDirectories: true)
        }
        
        // Generate filename with timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(name)_\(timestamp).cal"
        let fileURL = calibrationsFolder.appendingPathComponent(filename)
        
        // Write calibration file (frequency, gain format)
        var content = "# Calibration file: \(name)\n"
        content += "# Generated: \(Date())\n"
        content += "# Format: Frequency (Hz), Gain (dB)\n"
        content += "# Frequency,Gain\n"
        
        for (freq, gain) in zip(curve.freqs, curve.gains) {
            content += String(format: "%.2f,%.4f\n", freq, gain)
        }
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    // Save multiple capsule calibrations
    func saveCapsuleCalibrations(
        curves: [MicCalCurve],
        baseName: String,
        to folder: URL
    ) throws -> [URL] {
        var savedFiles: [URL] = []
        
        for (index, curve) in curves.enumerated() {
            let name = "\(baseName)_Capsule\(index + 1)"
            let fileURL = try saveCalibration(curve: curve, name: name, to: folder)
            savedFiles.append(fileURL)
        }
        
        // Also save a combined calibration (average of all capsules)
        if !curves.isEmpty {
            let avgCurve = averageCalibrationCurves(curves)
            let avgName = "\(baseName)_Average"
            let avgFileURL = try saveCalibration(curve: avgCurve, name: avgName, to: folder)
            savedFiles.append(avgFileURL)
        }
        
        return savedFiles
    }
    
    // Average multiple calibration curves
    private func averageCalibrationCurves(_ curves: [MicCalCurve]) -> MicCalCurve {
        guard !curves.isEmpty else {
            return MicCalCurve(freqs: [], gains: [])
        }
        
        // Use the first curve's frequency points
        let freqs = curves[0].freqs
        var avgGains: [Double] = []
        
        for freq in freqs {
            var sum = 0.0
            var count = 0
            for curve in curves {
                let gain = curve.gainAt(freq: freq)
                sum += gain
                count += 1
            }
            avgGains.append(sum / Double(count))
        }
        
        return MicCalCurve(freqs: freqs, gains: avgGains)
    }
    
    // Load calibration file
    func loadCalibration(from url: URL) throws -> MicCalCurve {
        let content = try String(contentsOf: url)
        var freqs: [Double] = []
        var gains: [Double] = []
        
        content.split(whereSeparator: \.isNewline).forEach { lineSub in
            let line = String(lineSub).trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.lowercased().contains("frequency") { return }
            
            let parts = line
                .replacingOccurrences(of: ",", with: " ")
                .split(separator: " ")
                .map { String($0) }
                .filter { !$0.isEmpty }
            
            if parts.count >= 2, let freq = Double(parts[0]), let gain = Double(parts[1]) {
                freqs.append(freq)
                gains.append(gain)
            }
        }
        
        guard freqs.count > 1 else {
            throw NSError(domain: "CalibrationFileManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid calibration file format"])
        }
        
        // Sort by frequency
        let zipped = zip(freqs, gains).sorted { $0.0 < $1.0 }
        let sortedFreqs = zipped.map { $0.0 }
        let sortedGains = zipped.map { $0.1 }
        
        return MicCalCurve(freqs: sortedFreqs, gains: sortedGains)
    }
    
    // List all calibration files in folder
    func listCalibrations(in folder: URL) -> [URL] {
        let calibrationsFolder = folder.appendingPathComponent("Calibrations", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: calibrationsFolder.path) else {
            return []
        }
        
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: calibrationsFolder,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        ) else {
            return []
        }
        
        return files.filter { $0.pathExtension == "cal" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
    }
}

