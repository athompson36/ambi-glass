import SwiftUI
import AVFoundation

struct MeasureIRView: View {
    @EnvironmentObject var irkit: IRKit
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var devices: AudioDeviceManager
    @EnvironmentObject var irMeasurementEngine: IRMeasurementEngine
    @StateObject private var dsp = AmbisonicsDSP()
    @State private var sweepSeconds: Double = 8
    @State private var f0: Double = 20
    @State private var f1: Double = 20000
    @State private var selectedOutputChannels: Set<Int> = [0, 1]
    @State private var selectedInputChannels: Set<Int> = [0, 1, 2, 3]
    @State private var selectedOutputDeviceID: String = "default"
    @State private var selectedInputDeviceID: String = "default"
    @State private var measuredIRs: [[Float]]? = nil
    @State private var exportStatus: String = ""
    @State private var isExporting = false
    @State private var useLiveCapture = true
    
    var body: some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Impulse Response Measurement").font(.title2).bold()
                    
                    // Output Device Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output Device").font(.headline)
                        Picker("Output Device", selection: $selectedOutputDeviceID) {
                            ForEach(devices.outputDevices, id: \.id) { dev in
                                Text(dev.name).tag(dev.id)
                            }
                        }
                        .onAppear { devices.refreshDevices() }
                    }
                    
                    // Output Channel Selection
                    if !devices.getOutputChannels(for: selectedOutputDeviceID).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output Channels").bold()
                            Text("Select output channels for sweep playback:").font(.caption).opacity(0.8)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(devices.getOutputChannels(for: selectedOutputDeviceID), id: \.id) { channel in
                                    let isOn = selectedOutputChannels.contains(channel.channelNumber)
                                    Button(channel.name) {
                                        if isOn {
                                            selectedOutputChannels.remove(channel.channelNumber)
                                        } else {
                                            selectedOutputChannels.insert(channel.channelNumber)
                                        }
                                        irkit.selectedOutputChannels = selectedOutputChannels.map { $0 + 1 }.sorted() // IRKit uses 1-based
                                    }
                                    .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                                    .opacity(isOn ? 1.0 : 0.5)
                                }
                            }
                        }
                    }
                    
                    // Input Device Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input Device").font(.headline)
                        Picker("Input Device", selection: $selectedInputDeviceID) {
                            ForEach(devices.inputDevices, id: \.id) { dev in
                                Text(dev.name).tag(dev.id)
                            }
                        }
                    }
                    
                    // Input Channel Selection
                    if !devices.getInputChannels(for: selectedInputDeviceID).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Input Channels").bold()
                            Text("Select input channels to capture IR from:").font(.caption).opacity(0.8)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(devices.getInputChannels(for: selectedInputDeviceID), id: \.id) { channel in
                                    let isOn = selectedInputChannels.contains(channel.channelNumber)
                                    Button(channel.name) {
                                        if isOn {
                                            selectedInputChannels.remove(channel.channelNumber)
                                        } else {
                                            selectedInputChannels.insert(channel.channelNumber)
                                        }
                                    }
                                    .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                                    .opacity(isOn ? 1.0 : 0.5)
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Stepper(value: $sweepSeconds, in: 2...30, step: 1) { Text("Sweep Length: \(Int(sweepSeconds)) s") }
                    }
                    HStack {
                        Stepper(value: $f0, in: 10...200) { Text("Start F0: \(Int(f0)) Hz") }
                        Stepper(value: $f1, in: 1000...48000) { Text("End F1: \(Int(f1)) Hz") }
                    }
                    
                    Toggle("Use Live Capture", isOn: $useLiveCapture)
                    
                    Button(useLiveCapture ? "Measure IR (Live)" : "Generate Sweep & Measure (Demo)") {
                        if useLiveCapture {
                            measureIRLive()
                        } else {
                            measureIRDemo()
                        }
                    }
                    .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                    .disabled(irMeasurementEngine.isMeasuring)
                    
                    if irMeasurementEngine.isMeasuring {
                        ProgressIndicator(progress: irMeasurementEngine.progress, message: irMeasurementEngine.status)
                    }
                    
                    if measuredIRs != nil {
                        Divider().opacity(0.4)
                        Text("Export IR").bold()
                        HStack {
                            Button("Mono") { exportMono() }
                            Button("Stereo") { exportStereo() }
                            Button("True-Stereo") { exportTrueStereo() }
                            Button("FOA") { exportFOA() }
                        }
                        .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                        .disabled(isExporting)
                        
                        if isExporting {
                            ProgressIndicator(progress: 0.5, message: "Exporting...")
                        }
                        
                        if !exportStatus.isEmpty && !isExporting {
                            Text(exportStatus).font(.footnote).opacity(0.8)
                        }
                    }
                }
            }
        }.padding()
    }
    
    private func exportMono() {
        guard let irs = measuredIRs, !irs.isEmpty else { return }
        isExporting = true
        let folder = ProjectManager.shared.getIRsFolder()
        let url = folder.appendingPathComponent("IR_Mono_\(Int(Date().timeIntervalSince1970)).wav")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try irkit.exportMonoIR(irs[0], sampleRate: 48000, to: url)
                DispatchQueue.main.async {
                    exportStatus = "Exported: \(url.lastPathComponent)"
                    isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    exportStatus = "Export error: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
    
    private func exportStereo() {
        guard let irs = measuredIRs, irs.count >= 2 else { exportStatus = "Need 2+ channels"; return }
        isExporting = true
        let folder = ProjectManager.shared.getIRsFolder()
        let url = folder.appendingPathComponent("IR_Stereo_\(Int(Date().timeIntervalSince1970)).wav")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try irkit.exportStereoIR(irs, sampleRate: 48000, to: url)
                DispatchQueue.main.async {
                    exportStatus = "Exported: \(url.lastPathComponent)"
                    isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    exportStatus = "Export error: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
    
    private func exportTrueStereo() {
        guard let irs = measuredIRs, irs.count >= 4 else { exportStatus = "Need 4 channels"; return }
        isExporting = true
        let folder = ProjectManager.shared.getIRsFolder()
        let url = folder.appendingPathComponent("IR_TrueStereo_\(Int(Date().timeIntervalSince1970)).wav")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try irkit.exportTrueStereoIR(irs, sampleRate: 48000, to: url)
                DispatchQueue.main.async {
                    exportStatus = "Exported: \(url.lastPathComponent)"
                    isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    exportStatus = "Export error: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
    
    private func exportFOA() {
        guard let irs = measuredIRs, irs.count >= 4 else { exportStatus = "Need 4 channels"; return }
        isExporting = true
        let folder = ProjectManager.shared.getIRsFolder()
        let url = folder.appendingPathComponent("IR_FOA_\(Int(Date().timeIntervalSince1970)).wav")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try irkit.exportFOAIR(irs, sampleRate: 48000, dsp: dsp, to: url)
                DispatchQueue.main.async {
                    exportStatus = "Exported: \(url.lastPathComponent)"
                    isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    exportStatus = "Export error: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
    
    private func measureIRLive() {
        exportStatus = "Starting measurement..."
        Task {
            do {
                // Generate sweep
                let sampleRate = 48000.0
                let sweep = irkit.generateESS(sr: sampleRate, seconds: sweepSeconds, f0: f0, f1: f1)
                
                // Convert selected channels to arrays
                let inputChannelsArray = Array(selectedInputChannels).sorted()
                let outputChannelsArray = Array(selectedOutputChannels).sorted()
                
                guard !inputChannelsArray.isEmpty else {
                    await MainActor.run {
                        exportStatus = "Error: No input channels selected"
                    }
                    return
                }
                
                guard !outputChannelsArray.isEmpty else {
                    await MainActor.run {
                        exportStatus = "Error: No output channels selected"
                    }
                    return
                }
                
                // Measure IR with live capture
                let recorded = try await irMeasurementEngine.measureIR(
                    sweep: sweep,
                    inputChannels: inputChannelsArray,
                    outputChannels: outputChannelsArray,
                    sampleRate: sampleRate
                )
                
                // Deconvolve to get IRs
                let irs = irkit.runSweepLive(
                    recorded: recorded,
                    seconds: sweepSeconds,
                    f0: f0,
                    f1: f1,
                    sampleRate: sampleRate
                )
                
                await MainActor.run {
                    measuredIRs = irs
                    exportStatus = "IR measured: \(irs.first?.count ?? 0) samples"
                }
            } catch {
                await MainActor.run {
                    exportStatus = "Measurement error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func measureIRDemo() {
        exportStatus = "Measuring (demo mode)..."
        Task {
            let irs = irkit.runSweep(seconds: sweepSeconds, f0: f0, f1: f1)
            await MainActor.run {
                measuredIRs = irs
                exportStatus = "IR measured (demo): \(irs.first?.count ?? 0) samples"
            }
        }
    }
}
