import SwiftUI

struct CalibrationCurveView: View {
    @EnvironmentObject var theme: ThemeManager
    var curve: MicCalCurve
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let padding: CGFloat = 20
            
            // Find min/max for scaling
            let minGain = curve.gains.min() ?? -10
            let maxGain = curve.gains.max() ?? 10
            let gainRange = maxGain - minGain
            let gainScale = gainRange > 0 ? (height - 2 * padding) / gainRange : 1.0
            
            // Frequency range (log scale)
            let minFreq = log10(curve.freqs.first ?? 20)
            let maxFreq = log10(curve.freqs.last ?? 20000)
            let freqRange = maxFreq - minFreq
            let freqScale = freqRange > 0 ? (width - 2 * padding) / freqRange : 1.0
            
            ZStack {
                // Background grid
                Path { path in
                    // Horizontal lines (gain)
                    for i in 0...4 {
                        let y = padding + CGFloat(i) * (height - 2 * padding) / 4
                        path.move(to: CGPoint(x: padding, y: y))
                        path.addLine(to: CGPoint(x: width - padding, y: y))
                    }
                    // Vertical lines (frequency, log scale)
                    for i in 0...4 {
                        let logFreq = minFreq + Double(i) * freqRange / 4
                        let x = padding + CGFloat(i) * (width - 2 * padding) / 4
                        path.move(to: CGPoint(x: x, y: padding))
                        path.addLine(to: CGPoint(x: x, y: height - padding))
                    }
                }
                .stroke(theme.highContrast ? .white.opacity(0.3) : .white.opacity(0.15), lineWidth: 0.5)
                
                // Zero line
                if minGain < 0 && maxGain > 0 {
                    let zeroY = padding + CGFloat(maxGain - 0) * gainScale
                    Path { path in
                        path.move(to: CGPoint(x: padding, y: zeroY))
                        path.addLine(to: CGPoint(x: width - padding, y: zeroY))
                    }
                    .stroke(.cyan.opacity(0.5), lineWidth: 1)
                }
                
                // Curve
                if curve.freqs.count > 1 {
                    Path { path in
                        for (i, freq) in curve.freqs.enumerated() {
                            let logFreq = log10(freq)
                            let x = padding + CGFloat(logFreq - minFreq) * freqScale
                            let gain = curve.gains[i]
                            let y = padding + CGFloat(maxGain - gain) * gainScale
                            
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(theme.highContrast ? .cyan : .purple, lineWidth: 2)
                }
            }
            .background(theme.highContrast ? Color.black.opacity(0.3) : Color.black.opacity(0.1))
        }
        .frame(height: 200)
    }
}

