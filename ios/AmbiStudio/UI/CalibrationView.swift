import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject var calibrator: CalibrationKit
    @EnvironmentObject var theme: ThemeManager
    @State private var status: String = "Idle"
    @State private var isRunning = false
    
    var body: some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Interface Calibration").font(.title2).bold()
                    Text("Loopback latency & gain balance. Connect an output to an input.")
                    Button("Run Loopback Test") {
                        isRunning = true
                        status = "Running…"
                        DispatchQueue.global(qos: .userInitiated).async {
                            calibrator.runLoopbackTest()
                            DispatchQueue.main.async {
                                isRunning = false
                                status = "Done: Latency \(String(format: "%.1f", calibrator.latencyMs))ms, Gains \(calibrator.channelGains.map { String(format: "%.2f", $0) }.joined(separator: ", ")) dB"
                            }
                        }
                    }
                    .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                    .disabled(isRunning)
                    
                    if isRunning {
                        ProgressIndicator(progress: 0.5, message: "Measuring loopback...")
                    }
                    
                    if !status.isEmpty && !isRunning {
                        Text("Status: \(status)").font(.footnote).opacity(0.8)
                    }
                    
                    if let profile = calibrator.lastProfile {
                        Divider().opacity(0.4)
                        Text("Last Profile").bold()
                        Text("Device: \(profile.deviceId)").font(.footnote)
                        Text("Sample Rate: \(Int(profile.sampleRate)) Hz").font(.footnote)
                        Text("Latency: \(String(format: "%.1f", profile.ioLatencyMs)) ms").font(.footnote)
                    }
                }
            }
        }.padding()
    }
}
