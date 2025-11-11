import SwiftUI
struct IRTestView: View {
    @StateObject var host = IRTestHost()
    @EnvironmentObject var theme: ThemeManager
    let latestIR: URL?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("IR Reverb Audition").font(.title3).bold()
                Spacer()
                Text(String(format: "I/O Latency: %.1f ms", host.latencyMs)).font(.footnote).opacity(0.7)
            }
            HStack(spacing: 12) {
                Button(host.isRunning ? "Stop" : "Start") {
                    if host.isRunning { host.stop() }
                    else {
                        do { if let url = latestIR { try host.loadIR(from: url) }; try host.start() }
                        catch { print("IR host error:", error) }
                    }
                }.buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                VStack(alignment: .leading) {
                    Text("Wet/Dry")
                    Slider(value: Binding(get: { Double(host.wetDryMix) }, set: { host.wetDryMix = Float($0) }), in: 0...100)
                }
            }
        }.padding()
    }
}
