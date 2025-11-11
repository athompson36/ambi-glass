import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject var calibrator: CalibrationKit
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var devices: AudioDeviceManager
    @State private var status: String = "Idle"
    @State private var isRunning = false
    @State private var selectedTab: CalibrationTab = .interface
    
    // Loopback device selection
    @State private var loopbackInputDeviceID: String = "default"
    @State private var loopbackOutputDeviceID: String = "default"
    @State private var loopbackInputChannel: Int = 0
    @State private var loopbackOutputChannel: Int = 0
    
    enum CalibrationTab {
        case interface
        case ambiAlice
    }
    
    var body: some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Calibration").font(.title2).bold()
                    
                    // Tab Selection
                    Picker("Calibration Type", selection: $selectedTab) {
                        Text("Interface").tag(CalibrationTab.interface)
                        Text("Ambi-Alice").tag(CalibrationTab.ambiAlice)
                    }
                    .pickerStyle(.segmented)
                    
                    Divider().opacity(0.4)
                    
                    if selectedTab == .interface {
                        interfaceCalibrationView
                    } else {
                        AmbiAliceCalibrationView()
                    }
                }
            }
        }.padding()
    }
    
    private var interfaceCalibrationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interface Calibration").font(.headline)
            Text("Loopback latency & gain balance. Connect an output to an input.")
            
            Divider().opacity(0.4)
            
            // Loopback Input Device Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Loopback Input Device").font(.subheadline).bold()
                Picker("Input Device", selection: $loopbackInputDeviceID) {
                    ForEach(devices.inputDevices, id: \.id) { dev in
                        Text(dev.name).tag(dev.id)
                    }
                }
                .onAppear { devices.refreshDevices() }
            }
            
            // Loopback Input Channel Selection
            if !devices.getInputChannels(for: loopbackInputDeviceID).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Loopback Input Channel").font(.subheadline).bold()
                    Text("Select the physical input channel for loopback:").font(.caption).opacity(0.8)
                    Picker("Input Channel", selection: $loopbackInputChannel) {
                        ForEach(devices.getInputChannels(for: loopbackInputDeviceID), id: \.id) { channel in
                            Text(channel.name).tag(channel.channelNumber)
                        }
                    }
                }
            }
            
            Divider().opacity(0.4)
            
            // Loopback Output Device Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Loopback Output Device").font(.subheadline).bold()
                Picker("Output Device", selection: $loopbackOutputDeviceID) {
                    ForEach(devices.outputDevices, id: \.id) { dev in
                        Text(dev.name).tag(dev.id)
                    }
                }
            }
            
            // Loopback Output Channel Selection
            if !devices.getOutputChannels(for: loopbackOutputDeviceID).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Loopback Output Channel").font(.subheadline).bold()
                    Text("Select the physical output channel for loopback:").font(.caption).opacity(0.8)
                    Picker("Output Channel", selection: $loopbackOutputChannel) {
                        ForEach(devices.getOutputChannels(for: loopbackOutputDeviceID), id: \.id) { channel in
                            Text(channel.name).tag(channel.channelNumber)
                        }
                    }
                }
            }
            
            Divider().opacity(0.4)
            
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
    
}
