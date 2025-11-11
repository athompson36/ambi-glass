import SwiftUI
import AVFoundation
import Accelerate

struct WaveformView: View {
    let audioURL: URL
    let channelNumber: Int
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var transcoder: Transcoder
    @State private var waveformData: [Float] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Channel \(channelNumber)").font(.caption).bold()
                Text(audioURL.lastPathComponent).font(.caption2).opacity(0.7)
                Spacer()
            }
            
            if isLoading {
                ProgressView()
                    .frame(height: 60)
            } else if waveformData.isEmpty {
                Text("Unable to load waveform").font(.caption2).opacity(0.6)
                    .frame(height: 60)
            } else {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    
                    Path { path in
                        let sampleCount = waveformData.count
                        guard sampleCount > 0 else { return }
                        
                        let step = width / CGFloat(sampleCount)
                        let centerY = height / 2
                        let maxAmplitude = waveformData.map { abs($0) }.max() ?? 1.0
                        let scale = maxAmplitude > 0 ? Double(height / 2) / Double(maxAmplitude) : 1.0
                        
                        for (i, sample) in waveformData.enumerated() {
                            let x = CGFloat(i) * step
                            let amplitude = CGFloat(sample) * CGFloat(scale)
                            let y = centerY - amplitude
                            
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(theme.highContrast ? .cyan : .blue, lineWidth: 1.5)
                }
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.2))
                )
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadWaveform()
        }
        .onChange(of: transcoder.waveformCache) { cache in
            if let cached = cache[audioURL] {
                waveformData = cached
                isLoading = false
            }
        }
    }
    
    private func loadWaveform() {
        // Check cache first
        if let cached = transcoder.getWaveformData(for: audioURL) {
            waveformData = cached
            isLoading = false
            return
        }
        
        // If not cached, show loading and wait for cache to be populated
        isLoading = true
        
        // The waveform will be loaded by Transcoder when files are imported
        // We'll update via onChange when it's ready
    }
}

