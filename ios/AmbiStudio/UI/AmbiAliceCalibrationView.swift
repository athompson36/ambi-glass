import SwiftUI
import AVFoundation

struct AmbiAliceCalibrationView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var devices: AudioDeviceManager
    @StateObject private var dualRecorder = DualMicRecorder()
    private let analyzer = FrequencyResponseAnalyzer()
    private let fileManager = CalibrationFileManager.shared
    
    @State private var recordingMode: RecordingMode = .simultaneous
    @State private var ambiAliceDeviceID: String = "default"
    @State private var referenceDeviceID: String = "default"
    @State private var ambiAliceChannels: Set<Int> = [0, 1, 2, 3]
    @State private var referenceChannel: Int = 0
    @State private var recordingDuration: Double = 10.0
    @State private var calibrationName: String = "AmbiAlice_Calibration"
    
    @State private var recordedData: (ambiAlice: [[Float]], reference: [Float])? = nil
    @State private var calibrationCurves: [MicCalCurve]? = nil
    @State private var savedFiles: [URL] = []
    @State private var status: String = "Ready"
    @State private var isAnalyzing = false
    
    enum RecordingMode: String, CaseIterable {
        case simultaneous = "Simultaneous"
        case staged = "Staged (2 stages)"
    }
    
    var body: some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ambi-Alice Calibration").font(.title2).bold()
                    Text("Calibrate Ambi-Alice against a reference microphone").font(.caption).opacity(0.8)
                    
                    Divider().opacity(0.4)
                    
                    // Recording Mode Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recording Mode").font(.headline)
                        Picker("Mode", selection: $recordingMode) {
                            ForEach(RecordingMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text(recordingMode == .simultaneous ?
                             "Record from both mics at the same time (requires 2 audio interfaces or multi-channel interface)" :
                             "Record in 2 stages: first Ambi-Alice, then reference mic")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Ambi-Alice Device Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ambi-Alice Device").font(.headline)
                        Picker("Ambi-Alice Device", selection: $ambiAliceDeviceID) {
                            ForEach(devices.inputDevices, id: \.id) { dev in
                                Text(dev.name).tag(dev.id)
                            }
                        }
                        .onAppear { devices.refreshDevices() }
                    }
                    
                    // Ambi-Alice Channel Selection
                    if !devices.getInputChannels(for: ambiAliceDeviceID).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ambi-Alice Channels").font(.headline)
                            Text("Select 4 channels for Ambi-Alice capsules:").font(.caption).opacity(0.8)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(devices.getInputChannels(for: ambiAliceDeviceID), id: \.id) { channel in
                                    let isSelected = ambiAliceChannels.contains(channel.channelNumber)
                                    Button(channel.name) {
                                        if isSelected {
                                            ambiAliceChannels.remove(channel.channelNumber)
                                        } else {
                                            if ambiAliceChannels.count < 4 {
                                                ambiAliceChannels.insert(channel.channelNumber)
                                            }
                                        }
                                    }
                                    .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                                    .opacity(isSelected ? 1.0 : 0.5)
                                }
                            }
                            if ambiAliceChannels.count < 4 {
                                Text("Select \(4 - ambiAliceChannels.count) more channel(s)").font(.caption).foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Reference Mic Device Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reference Microphone Device").font(.headline)
                        Picker("Reference Device", selection: $referenceDeviceID) {
                            ForEach(devices.inputDevices, id: \.id) { dev in
                                Text(dev.name).tag(dev.id)
                            }
                        }
                    }
                    
                    // Reference Mic Channel Selection
                    if !devices.getInputChannels(for: referenceDeviceID).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reference Mic Channel").font(.headline)
                            Picker("Reference Channel", selection: $referenceChannel) {
                                ForEach(devices.getInputChannels(for: referenceDeviceID), id: \.id) { channel in
                                    Text(channel.name).tag(channel.channelNumber)
                                }
                            }
                        }
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Recording Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recording Duration").font(.headline)
                        Stepper(value: $recordingDuration, in: 5...60, step: 1) {
                            Text("\(Int(recordingDuration)) seconds")
                        }
                        Text("Longer recordings provide better frequency resolution").font(.caption).opacity(0.7)
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Calibration Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calibration Name").font(.headline)
                        TextField("Calibration name", text: $calibrationName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 4)
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Record Button
                    Button(dualRecorder.isRecording ? "Stop Recording" : "Start Recording") {
                        if dualRecorder.isRecording {
                            dualRecorder.stop()
                        } else {
                            startRecording()
                        }
                    }
                    .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                    .disabled(ambiAliceChannels.count != 4)
                    
                    if dualRecorder.isRecording {
                        ProgressIndicator(progress: dualRecorder.progress, message: dualRecorder.status)
                    }
                    
                    // Analyze Button
                    if recordedData != nil {
                        Divider().opacity(0.4)
                        Button("Analyze & Generate Calibration") {
                            analyzeAndGenerate()
                        }
                        .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                        .disabled(isAnalyzing)
                        
                        if isAnalyzing {
                            ProgressIndicator(progress: 0.7, message: "Analyzing frequency response...")
                        }
                    }
                    
                    // Calibration Results
                    if let curves = calibrationCurves {
                        Divider().opacity(0.4)
                        Text("Calibration Results").font(.headline)
                        
                        ForEach(Array(curves.enumerated()), id: \.offset) { index, curve in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Capsule \(index + 1)").font(.subheadline).bold()
                                CalibrationCurveView(curve: curve)
                                    .frame(height: 150)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Save Button
                        Button("Save Calibration Files") {
                            saveCalibrations()
                        }
                        .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                    }
                    
                    // Saved Files
                    if !savedFiles.isEmpty {
                        Divider().opacity(0.4)
                        Text("Saved Files").font(.headline)
                        ForEach(Array(savedFiles.enumerated()), id: \.offset) { index, url in
                            Text("\(index + 1). \(url.lastPathComponent)").font(.caption).opacity(0.8)
                        }
                    }
                    
                    // Status
                    if !status.isEmpty {
                        Divider().opacity(0.4)
                        Text("Status: \(status)").font(.footnote).opacity(0.8)
                    }
                }
            }
        }
        .padding()
    }
    
    private func startRecording() {
        guard ambiAliceChannels.count == 4 else {
            status = "Error: Select 4 Ambi-Alice channels"
            return
        }
        
        status = "Starting recording..."
        Task {
            do {
                let ambiChannels = Array(ambiAliceChannels).sorted()
                
                let data: (ambiAlice: [[Float]], reference: [Float])
                if recordingMode == .simultaneous {
                    data = try await dualRecorder.recordDual(
                        ambiAliceChannels: ambiChannels,
                        referenceChannel: referenceChannel,
                        ambiAliceDeviceID: ambiAliceDeviceID,
                        referenceDeviceID: referenceDeviceID,
                        sampleRate: 48000.0,
                        duration: recordingDuration
                    )
                } else {
                    data = try await dualRecorder.recordStaged(
                        ambiAliceChannels: ambiChannels,
                        referenceChannel: referenceChannel,
                        ambiAliceDeviceID: ambiAliceDeviceID,
                        referenceDeviceID: referenceDeviceID,
                        sampleRate: 48000.0,
                        duration: recordingDuration
                    )
                }
                
                await MainActor.run {
                    recordedData = data
                    status = "Recording complete: Ambi-Alice \(data.ambiAlice.first?.count ?? 0) samples, Reference \(data.reference.count) samples"
                }
            } catch {
                await MainActor.run {
                    status = "Recording error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func analyzeAndGenerate() {
        guard let data = recordedData else { return }
        
        isAnalyzing = true
        status = "Analyzing frequency response..."
        
        Task {
            let curves = analyzer.generateCapsuleCalibrations(
                reference: data.reference,
                ambiAlice: data.ambiAlice,
                sampleRate: 48000.0
            )
            
            await MainActor.run {
                calibrationCurves = curves
                isAnalyzing = false
                status = "Analysis complete: Generated \(curves.count) calibration curves"
            }
        }
    }
    
    private func saveCalibrations() {
        guard let curves = calibrationCurves else { return }
        
        status = "Saving calibration files..."
        
        Task {
            do {
                let folder = RecordingFolderManager.shared.getFolder()
                let files = try fileManager.saveCapsuleCalibrations(
                    curves: curves,
                    baseName: calibrationName,
                    to: folder
                )
                
                await MainActor.run {
                    savedFiles = files
                    status = "Saved \(files.count) calibration files to \(folder.path)/Calibrations"
                }
            } catch {
                await MainActor.run {
                    status = "Save error: \(error.localizedDescription)"
                }
            }
        }
    }
}

