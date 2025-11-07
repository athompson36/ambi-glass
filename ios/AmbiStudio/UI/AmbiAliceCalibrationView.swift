import SwiftUI
import AVFoundation

struct AmbiAliceCalibrationView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var devices: AudioDeviceManager
    @StateObject private var dualRecorder = DualMicRecorder()
    @StateObject private var calMicManager = CalibrationMicManager.shared
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
    @State private var calibrationStatus: CalibrationStatus = .notCalibrated
    @State private var existingCalibrations: [URL] = []
    
    // Ambisonic-A Mic Calibration states
    @State private var showingAddCalMic = false
    @State private var showingCalFileImporter = false
    @State private var newCalMicName: String = ""
    @State private var newCalMicManufacturer: String = ""
    @State private var newCalMicModel: String = ""
    @State private var selectedCalFileURL: URL? = nil
    
    enum CalibrationStatus {
        case notCalibrated
        case calibrated([URL])
        
        var isCalibrated: Bool {
            switch self {
            case .notCalibrated:
                return false
            case .calibrated:
                return true
            }
        }
        
        var description: String {
            switch self {
            case .notCalibrated:
                return "Not Calibrated"
            case .calibrated(let files):
                return "Calibrated (\(files.count) file\(files.count == 1 ? "" : "s"))"
            }
        }
    }
    
    enum RecordingMode: String, CaseIterable {
        case simultaneous = "Simultaneous"
        case staged = "Staged (2 stages)"
    }
    
    var body: some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ambi-Alice Calibration").font(.title2).bold()
                    Text("Calibrate Ambi-Alice against a calibration microphone").font(.caption).opacity(0.8)
                    
                    // Calibration Status
                    HStack {
                        Circle()
                            .fill(calibrationStatus.isCalibrated ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                        Text("Ambi-Alice Status: \(calibrationStatus.description)")
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        if calibrationStatus.isCalibrated {
                            Button("Refresh Status") {
                                checkCalibrationStatus()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(calibrationStatus.isCalibrated ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    )
                    
                    if case .calibrated(let files) = calibrationStatus, !files.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Existing Calibration Files:").font(.caption).bold()
                            ForEach(Array(files.prefix(5).enumerated()), id: \.offset) { index, url in
                                Text("• \(url.lastPathComponent)").font(.caption).opacity(0.8)
                            }
                            if files.count > 5 {
                                Text("... and \(files.count - 5) more").font(.caption).opacity(0.6)
                            }
                        }
                        .padding(.leading, 8)
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Ambisonic-A Mic Calibration Section
                    ambisonicAMicCalibrationSection
                    
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
                    
                    // Calibration Mic Device Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calibration Microphone Device").font(.headline)
                        Text("Select the audio interface and input channel for your calibration microphone").font(.caption).opacity(0.8)
                        Picker("Calibration Mic Device", selection: $referenceDeviceID) {
                            ForEach(devices.inputDevices, id: \.id) { dev in
                                Text(dev.name).tag(dev.id)
                            }
                        }
                        .onChange(of: referenceDeviceID) { _ in
                            // Reset channel selection when device changes
                            if let firstChannel = devices.getInputChannels(for: referenceDeviceID).first {
                                referenceChannel = firstChannel.channelNumber
                            }
                        }
                    }
                    
                    // Calibration Mic Channel Selection
                    if !devices.getInputChannels(for: referenceDeviceID).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calibration Mic Input Channel").font(.headline)
                            Text("Select the physical input channel connected to your calibration microphone").font(.caption).opacity(0.8)
                            Picker("Calibration Mic Channel", selection: $referenceChannel) {
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
        .onAppear {
            checkCalibrationStatus()
        }
        .sheet(isPresented: $showingAddCalMic) {
            addCalibrationMicSheet
        }
        .fileImporter(
            isPresented: $showingCalFileImporter,
            allowedContentTypes: [.text, .commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedCalFileURL = url
                }
            case .failure(let error):
                print("File importer error: \(error.localizedDescription)")
            }
        }
    }
    
    private var ambisonicAMicCalibrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ambisonic-A Mic Calibration").font(.headline).bold()
            Text("Manage calibration microphones and their calibration files for calibrating your Ambi-A Mic (Ambi-Alice).")
                .font(.caption)
                .opacity(0.8)
            
            Divider().opacity(0.4)
            
            // Terminology clarification
            VStack(alignment: .leading, spacing: 4) {
                Text("Terminology:").font(.caption).bold()
                Text("• Ambi-A Mic: Your Ambi-Alice microphone being calibrated").font(.caption).opacity(0.7)
                Text("• Calibration Mic: Reference microphone used for calibration").font(.caption).opacity(0.7)
                Text("• Calibration Files: Files containing calibration data for calibration mics").font(.caption).opacity(0.7)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )
            
            Divider().opacity(0.4)
            
            // Popular Calibration Mics
            VStack(alignment: .leading, spacing: 8) {
                Text("Popular Calibration Microphones").font(.subheadline).bold()
                Text("Select a calibration mic with pre-stored calibration file:").font(.caption).opacity(0.8)
                
                if calMicManager.popularCalibrationMics.isEmpty {
                    Text("No popular calibration mics available").font(.caption).opacity(0.6)
                } else {
                    ForEach(calMicManager.popularCalibrationMics) { mic in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mic.displayName).font(.caption).bold()
                                if let manufacturer = mic.manufacturer, let model = mic.model {
                                    Text("\(manufacturer) \(model)").font(.caption2).opacity(0.7)
                                }
                                if mic.calibrationFileURL != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption2)
                                        Text("Calibration file available").font(.caption2).opacity(0.7)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.caption2)
                                        Text("Calibration file not found").font(.caption2).opacity(0.7)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button(calMicManager.selectedCalibrationMic?.id == mic.id ? "Selected" : "Select") {
                                calMicManager.selectedCalibrationMic = mic
                            }
                            .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                            .disabled(mic.calibrationFileURL == nil)
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(calMicManager.selectedCalibrationMic?.id == mic.id ? Color.blue.opacity(0.2) : Color.clear)
                        )
                    }
                }
            }
            
            Divider().opacity(0.4)
            
            // User-Added Calibration Mics
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Your Calibration Microphones").font(.subheadline).bold()
                    Spacer()
                    Button("Add Calibration Mic") {
                        showingAddCalMic = true
                    }
                    .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                    .font(.caption)
                }
                
                if calMicManager.userCalibrationMics.isEmpty {
                    Text("No custom calibration mics added").font(.caption).opacity(0.6)
                } else {
                    ForEach(calMicManager.userCalibrationMics) { mic in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mic.displayName).font(.caption).bold()
                                if let date = mic.dateAdded {
                                    Text("Added: \(date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .opacity(0.7)
                                }
                                if mic.calibrationFileURL != nil {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption2)
                                        Text("Calibration file: \(mic.calibrationFileURL?.lastPathComponent ?? "Unknown")")
                                            .font(.caption2)
                                            .opacity(0.7)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button(calMicManager.selectedCalibrationMic?.id == mic.id ? "Selected" : "Select") {
                                calMicManager.selectedCalibrationMic = mic
                            }
                            .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                            .font(.caption)
                            
                            Button("Remove") {
                                calMicManager.removeUserCalibrationMic(mic)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(calMicManager.selectedCalibrationMic?.id == mic.id ? Color.blue.opacity(0.2) : Color.clear)
                        )
                    }
                }
            }
            
            // Selected Calibration Mic Info
            if let selectedMic = calMicManager.selectedCalibrationMic {
                Divider().opacity(0.4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Calibration Mic:").font(.subheadline).bold()
                    Text(selectedMic.displayName).font(.caption)
                    if let calFile = selectedMic.calibrationFileURL {
                        Text("Calibration File: \(calFile.lastPathComponent)").font(.caption).opacity(0.7)
                    } else {
                        Text("No calibration file available").font(.caption).foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }
    
    private var addCalibrationMicSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Calibration Mic Information")) {
                    TextField("Mic Name", text: $newCalMicName)
                    TextField("Manufacturer (optional)", text: $newCalMicManufacturer)
                    TextField("Model (optional)", text: $newCalMicModel)
                }
                
                Section(header: Text("Calibration File")) {
                    if let fileURL = selectedCalFileURL {
                        HStack {
                            Text("Selected:")
                            Text(fileURL.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Button("Change File") {
                            showingCalFileImporter = true
                        }
                    } else {
                        Button("Upload Calibration File") {
                            showingCalFileImporter = true
                        }
                    }
                }
                
                Section {
                    Button("Save Calibration Mic") {
                        saveNewCalibrationMic()
                    }
                    .disabled(newCalMicName.isEmpty || selectedCalFileURL == nil)
                }
            }
            .navigationTitle("Add Calibration Mic")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddCalMic = false
                        resetAddCalMicForm()
                    }
                }
            }
        }
    }
    
    private func saveNewCalibrationMic() {
        guard let calFileURL = selectedCalFileURL else { return }
        
        do {
            // Copy calibration file to user's folder
            let savedURL = try calMicManager.saveCalibrationFileToUserFolder(calFileURL, micName: newCalMicName)
            
            // Add to user calibration mics
            calMicManager.addUserCalibrationMic(
                name: newCalMicName,
                manufacturer: newCalMicManufacturer.isEmpty ? nil : newCalMicManufacturer,
                model: newCalMicModel.isEmpty ? nil : newCalMicModel,
                calibrationFileURL: savedURL
            )
            
            showingAddCalMic = false
            resetAddCalMicForm()
        } catch {
            print("Error saving calibration mic: \(error.localizedDescription)")
        }
    }
    
    private func resetAddCalMicForm() {
        newCalMicName = ""
        newCalMicManufacturer = ""
        newCalMicModel = ""
        selectedCalFileURL = nil
    }
    
    private func checkCalibrationStatus() {
        let folder = RecordingFolderManager.shared.getFolder()
        let calibrations = fileManager.listCalibrations(in: folder)
        
        if calibrations.isEmpty {
            calibrationStatus = .notCalibrated
            existingCalibrations = []
        } else {
            calibrationStatus = .calibrated(calibrations)
            existingCalibrations = calibrations
        }
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
                    // Refresh calibration status after saving
                    checkCalibrationStatus()
                }
            } catch {
                await MainActor.run {
                    status = "Save error: \(error.localizedDescription)"
                }
            }
        }
    }
}

