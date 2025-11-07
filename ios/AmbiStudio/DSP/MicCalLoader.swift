import Foundation
import Combine

struct MicCalCurve: Codable {
    var freqs: [Double]   // Hz (sorted ascending)
    var gains: [Double]   // dB, same length

    func gainAt(freq: Double) -> Double {
        guard let firstF = freqs.first, let lastF = freqs.last, freqs.count > 1 else { return 0 }
        if freq <= firstF { return gains.first ?? 0 }
        if freq >= lastF { return gains.last ?? 0 }
        // linear interp in log-frequency domain for smoother behavior
        let logF = log(freq)
        var i = 0
        while i < freqs.count-1 && !(freqs[i] <= freq && freq <= freqs[i+1]) { i += 1 }
        let f0 = freqs[i], f1 = freqs[i+1]
        let g0 = gains[i], g1 = gains[i+1]
        let t = (logF - log(f0)) / (log(f1) - log(f0))
        return g0 + (g1 - g0) * t
    }
}

final class MicCalLoader: ObservableObject {
    @Published var cal: MicCalCurve? = nil
    @Published var filename: String = ""

    func load(from url: URL) {
        do {
            let txt = try String(contentsOf: url)
            var f: [Double] = []
            var g: [Double] = []
            txt.split(whereSeparator: \.isNewline).forEach { lineSub in
                let line = String(lineSub).trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("#") || line.lowercased().contains("frequency") { return }
                let parts = line
                    .replacingOccurrences(of: ",", with: " ")
                    .split(separator: " ")
                    .map { String($0) }
                    .filter { !$0.isEmpty }
                if parts.count >= 2, let freq = Double(parts[0]), let gain = Double(parts[1]) {
                    f.append(freq); g.append(gain)
                }
            }
            guard f.count > 1 else { print("MicCal: not enough points"); return }
            // Sort by frequency
            let zipped = zip(f, g).sorted { $0.0 < $1.0 }
            let fs = zipped.map { $0.0 }
            let gs = zipped.map { $0.1 }
            DispatchQueue.main.async {
                self.cal = MicCalCurve(freqs: fs, gains: gs)
                self.filename = url.lastPathComponent
            }
        } catch {
            print("MicCal load error: \\(error)")
        }
    }
}
