import SwiftUI
import Accelerate

struct LiveWaveformView: View {
    @EnvironmentObject var theme: ThemeManager
    let waveformData: [[Float]]
    let channelCount: Int
    
    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width) // Ensure positive width
            let height = max(1, geo.size.height) // Ensure positive height
            let channelHeight = max(1, height / CGFloat(max(1, channelCount))) // Ensure positive channel height
            
            // Validate all dimensions are finite before proceeding
            guard width.isFinite && height.isFinite && channelHeight.isFinite,
                  width > 0 && height > 0 && channelHeight > 0 else {
                // Return empty view if dimensions are invalid
                return AnyView(EmptyView())
            }
            
            return AnyView(
                VStack(spacing: 0) {
                    ForEach(0..<channelCount, id: \.self) { ch in
                        let data = ch < waveformData.count ? waveformData[ch] : []
                        if !data.isEmpty && data.count > 0 {
                            // Validate data before drawing
                            let validData = data.filter { $0.isFinite }
                            if !validData.isEmpty {
                                Path { path in
                                    let sampleCount = validData.count
                                    guard sampleCount > 0 else { return }
                                    
                                    let step = max(0.1, width / CGFloat(sampleCount))
                                    guard step.isFinite && step > 0 else { return }
                                    
                                    let centerY = channelHeight / 2
                                    guard centerY.isFinite else { return }
                                    
                                    let maxAmplitude = validData.map { abs($0) }.max() ?? 1.0
                                    let scale = maxAmplitude > 0 ? Double(channelHeight / 2) / Double(maxAmplitude) : 1.0
                                    guard scale.isFinite && scale > 0 else { return }
                                    
                                    var hasValidPoint = false
                                    for (i, sample) in validData.enumerated() {
                                        let x = CGFloat(i) * step
                                        let amplitude = CGFloat(sample) * CGFloat(scale)
                                        let y = centerY - amplitude
                                        
                                        // Ensure coordinates are finite and within bounds
                                        guard x.isFinite && y.isFinite,
                                              x >= 0 && x <= width,
                                              y >= 0 && y <= channelHeight else { continue }
                                        
                                        if !hasValidPoint {
                                            path.move(to: CGPoint(x: x, y: y))
                                            hasValidPoint = true
                                        } else {
                                            path.addLine(to: CGPoint(x: x, y: y))
                                        }
                                    }
                                }
                                .stroke(theme.highContrast ? .cyan : .blue, lineWidth: 1.5)
                                .frame(height: channelHeight)
                                .clipped()
                            } else {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: channelHeight)
                            }
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: channelHeight)
                        }
                    }
                }
            )
        }
    }
}

