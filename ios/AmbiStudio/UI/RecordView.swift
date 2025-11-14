import SwiftUI
import AVFoundation
import Combine
import UniformTypeIdentifiers

struct RecordView: View {
    @EnvironmentObject var devices: AudioDeviceManager
    @EnvironmentObject var recorder: RecorderEngine
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var transcoder: Transcoder
    @StateObject private var projectManager = ProjectManager.shared

    @State private var isRecording = false
    @State private var meters: [CGFloat] = [0,0,0,0]
    @State private var meterUpdateCount = 0
    @State private var showFolderPicker = false

    var body: some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text("Ambi‑Alice Recorder").font(.title2).bold()
                    
                    // Project Folder, Project Name, Recording Format, and Tracks on same row
                    HStack(alignment: .top, spacing: 16) {
                        // Project Folder Browser
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Project Folder").font(.caption).opacity(0.7)
                            HStack {
                                Text(projectManager.folderName)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: 150)
                                
                                Button("Browse...") {
                                    #if os(macOS)
                                    projectManager.selectFolderWithNSOpenPanel()
                                    #else
                                    showFolderPicker = true
                                    #endif
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button("Save") {
                                    // Check permissions and create folder structure
                                    Task.detached(priority: .userInitiated) {
                                        let hasAccess = await projectManager.checkWritePermissions()
                                        if hasAccess {
                                            await projectManager.createProjectStructure()
                                            await MainActor.run {
                                                // Verify folders were created
                                                if let folder = projectManager.projectFolder {
                                                    let fm = FileManager.default
                                                    let folders = ["Recording", "IR", "Transcode", "Calibration", "Settings"]
                                                    var existsCount = 0
                                                    for folderName in folders {
                                                        let path = folder.appendingPathComponent(folderName, isDirectory: true)
                                                        if fm.fileExists(atPath: path.path) {
                                                            existsCount += 1
                                                        }
                                                    }
                                                    if existsCount == folders.count {
                                                        print("✅ Project folder structure created successfully - all \(folders.count) folders exist")
                                                    } else {
                                                        print("⚠️ Only \(existsCount)/\(folders.count) folders created. Check permissions.")
                                                    }
                                                }
                                            }
                                        } else {
                                            await MainActor.run {
                                                print("❌ No write permissions. Please select a folder with write access using Browse.")
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(projectManager.projectFolder == nil)
                            }
                        }
                        
                        // Project Name (on same row as project folder)
                        VStack(alignment: .center, spacing: 4) {
                            Text("Project Name").font(.caption).opacity(0.7)
                            CenteredTextField(placeholder: "Enter project name...", text: $projectManager.projectName)
                                .frame(width: 225) // 25% smaller (300 * 0.75)
                                .onChange(of: projectManager.projectName) { _ in
                                    projectManager.saveProjectInfo()
                                }
                        }
                        
                        Spacer()
                        
                        // Recording Format
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Recording Format").font(.caption).opacity(0.7)
                            Picker("", selection: $recorder.recordingFormat) {
                                ForEach(RecordingFormat.allCases, id: \.self) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                        
                        // Track Count
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Tracks").font(.caption).opacity(0.7)
                            Text("\(recorder.recordingFormat.channelCount)")
                                .font(.system(.title3, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                    
                    // Main content area: Meters on left, Input controls on right
                    HStack(alignment: .top, spacing: 16) {
                        // Input Meters - prominent on the left
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input Meters").font(.caption).opacity(0.7)
                            HStack(spacing: 8) {
                                ForEach(0..<4, id: \.self) { i in
                                    MeterBar(value: meters[i], peakHold: recorder.peakHoldValues[i]).frame(width: 20, height: 140)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Input Device and Selection - condensed on the right
                        VStack(alignment: .trailing, spacing: 8) {
                            // Input Device - narrower dropdown
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Input Device").font(.caption).opacity(0.7)
                                Picker("Input Device", selection: Binding(
                                    get: { 
                                        // Return placeholder only if no devices and current is placeholder
                                        if devices.inputDevices.isEmpty && recorder.selectedDeviceID == "__no_devices__" {
                                            return "__no_devices__"
                                        }
                                        // Return current if valid, otherwise first available or placeholder
                                        if devices.inputDevices.contains(where: { $0.id == recorder.selectedDeviceID }) {
                                            return recorder.selectedDeviceID
                                        }
                                        return devices.inputDevices.first?.id ?? "__no_devices__"
                                    },
                                    set: { newValue in
                                        // Only set if it's a valid device ID (not placeholder)
                                        if newValue != "__no_devices__" {
                                            recorder.selectedDeviceID = newValue
                                        }
                                    }
                                )) {
                                    if devices.inputDevices.isEmpty {
                                        Text("No devices").tag("__no_devices__" as String)
                                    } else {
                                        ForEach(devices.inputDevices, id: \.id) { dev in
                                            Text(dev.name).tag(dev.id)
                                        }
                                    }
                                }
                                .onChange(of: devices.inputDevices) { newDevices in
                                    // If current selection is invalid, select first available device
                                    if !newDevices.isEmpty {
                                        if !newDevices.contains(where: { $0.id == recorder.selectedDeviceID }) || recorder.selectedDeviceID == "__no_devices__" {
                                            recorder.selectedDeviceID = newDevices.first!.id
                                        }
                                    } else {
                                        // No devices available - set placeholder and stop monitoring
                                        if recorder.selectedDeviceID != "__no_devices__" {
                                            recorder.selectedDeviceID = "__no_devices__"
                                        }
                                        recorder.stopMonitoring()
                                    }
                                }
                                .frame(width: 200) // Narrower width for 15-29 characters
                                .onChange(of: recorder.selectedDeviceID) { newDeviceID in
                                    // Stop monitoring when device changes
                                    recorder.stopMonitoring()
                                    
                                    // Only refresh if we have a valid device ID
                                    guard !newDeviceID.isEmpty && newDeviceID != "__no_devices__" else {
                                        return
                                    }
                                    
                                    devices.refreshDevices()
                                    // Wait for devices to refresh, then restart monitoring (non-blocking)
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                        // Verify device is still valid
                                        if devices.inputDevices.contains(where: { $0.id == newDeviceID }) {
                                            let requiredChannels = recorder.recordingFormat.channelCount
                                            if recorder.selectedInputChannels.count >= requiredChannels {
                                                recorder.startMonitoring()
                                            }
                                        } else {
                                            print("Device \(newDeviceID) not found in available devices")
                                        }
                                    }
                                }
                                .onAppear { 
                                    devices.refreshDevices()
                                    // Don't start monitoring immediately - wait for user to select device/channels
                                }
                            }
                            
                            // Input Channel Selection - condensed
                            if !devices.getInputChannels(for: recorder.selectedDeviceID).isEmpty {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Input Channels").font(.caption).opacity(0.7)
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                                        ForEach(devices.getInputChannels(for: recorder.selectedDeviceID), id: \.id) { channel in
                                            let isSelected = recorder.selectedInputChannels.contains(channel.channelNumber)
                                            Button {
                                                if isSelected {
                                                    recorder.selectedInputChannels.removeAll { $0 == channel.channelNumber }
                                                } else {
                                                    let maxChannels = max(4, recorder.recordingFormat.channelCount)
                                                    if recorder.selectedInputChannels.count < maxChannels {
                                                        recorder.selectedInputChannels.append(channel.channelNumber)
                                                        recorder.selectedInputChannels.sort()
                                                    }
                                                }
                                            } label: {
                                                Text("\(channel.channelNumber + 1)")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            }
                                            .frame(width: 32, height: 32)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(.ultraThinMaterial)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(isSelected ? .cyan : .white.opacity(0.25), lineWidth: isSelected ? 2 : 1.5)
                                            )
                                            .opacity(isSelected ? 1.0 : 0.5)
                                        }
                                    }
                                    let requiredChannels = recorder.recordingFormat.channelCount
                                    if recorder.selectedInputChannels.count < requiredChannels {
                                        Text("Select \(requiredChannels - recorder.selectedInputChannels.count) more")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                .onChange(of: recorder.selectedInputChannels) { _ in
                                    handleChannelSelectionChange()
                                }
                                .onChange(of: recorder.recordingFormat) { _ in
                                    // Restart monitoring if channel count requirement changes
                                    let requiredChannels = recorder.recordingFormat.channelCount
                                    if recorder.selectedInputChannels.count >= requiredChannels {
                                        Task.detached(priority: .userInitiated) {
                                            // Stop first
                                            await MainActor.run {
                                                recorder.stopMonitoring()
                                            }
                                            // Add delay to debounce and allow stop to complete
                                            try? await Task.sleep(nanoseconds: 500_000_000)
                                            await MainActor.run {
                                                recorder.startMonitoring()
                                            }
                                        }
                                    } else {
                                        Task.detached(priority: .userInitiated) {
                                            await MainActor.run {
                                                recorder.stopMonitoring()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: 220, alignment: .trailing) // Fixed width for right side
                    }
                    .padding(.vertical, 8)

                    // Sample Rate Display and Control
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sample Rate").font(.caption).opacity(0.7)
                            HStack {
                                Text("\(Int(recorder.currentSampleRate)) Hz")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.cyan)
                                
                                Picker("", selection: $recorder.requestedSampleRate) {
                                    Text("44100").tag(44100.0)
                                    Text("48000").tag(48000.0)
                                    Text("88200").tag(88200.0)
                                    Text("96000").tag(96000.0)
                                    Text("192000").tag(192000.0)
                                }
                                .pickerStyle(.menu)
                                .frame(width: 100)
                                .onChange(of: recorder.requestedSampleRate) { newRate in
                                    // Restart monitoring with new rate
                                    if recorder.selectedInputChannels.count == 4 {
                                        recorder.stopMonitoring()
                                        Task { @MainActor in
                                            try? await Task.sleep(nanoseconds: 200_000_000)
                                            recorder.startMonitoring()
                                        }
                                    }
                                }
                            }
                            if abs(recorder.currentSampleRate - recorder.requestedSampleRate) > 1.0 {
                                Text("⚠️ Requested: \(Int(recorder.requestedSampleRate)) Hz")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        // Microphone Permission Status (macOS)
                        #if os(macOS)
                        if !recorder.hasMicrophonePermission {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("⚠️ Microphone Permission Required")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Button("Request Permission") {
                                    recorder.requestMicrophonePermission()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        #endif
                    }
                    .padding(.vertical, 4)
                    
                    // Record button, time counter, and Safety toggle at bottom
                    HStack {
                        HStack(spacing: 12) {
                            Button(isRecording ? "Stop" : "Record") {
                                if isRecording {
                                    recorder.stop()
                                    isRecording = false
                                } else {
                                    // Validate before starting
                                    let requiredChannels = recorder.recordingFormat.channelCount
                                    guard recorder.selectedInputChannels.count >= requiredChannels else {
                                        print("Error: Must select at least \(requiredChannels) input channels for \(recorder.recordingFormat.displayName)")
                                        return
                                    }
                                    
                                    // Start recording - use async to avoid blocking
                                    Task { @MainActor in
                                        do {
                                            print("🔴 RecordView: Starting recording...")
                                            try await recorder.start()
                                            isRecording = true
                                            print("✅ RecordView: Recording started successfully")
                                        } catch {
                                            isRecording = false
                                            print("❌ RecordView: Recording failed: \(error.localizedDescription)")
                                            // Show error to user (you might want to add an alert here)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                            .disabled(recorder.selectedInputChannels.count < recorder.recordingFormat.channelCount)
                            .overlay(
                                // Red glow effect when recording
                                Group {
                                    if isRecording {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.red, lineWidth: 2)
                                            .shadow(color: .red.opacity(0.8), radius: 8)
                                            .shadow(color: .red.opacity(0.6), radius: 16)
                                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording)
                                    }
                                }
                            )
                            
                            // Recording time counter
                            if isRecording {
                                Text(formatTime(recorder.recordingElapsedTime))
                                    .font(.system(.title3, design: .monospaced))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black.opacity(0.3))
                                    )
                            }
                        }

                        Spacer()
                        Toggle("Safety A‑format", isOn: $recorder.safetyRecord)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .onReceive(recorder.meterPublisher) { newMeters in
            meters = newMeters
            // Debug: Log meter updates to verify UI is receiving data
            meterUpdateCount += 1
            if meterUpdateCount <= 10 {
                print("RecordView: Received meter update #\(meterUpdateCount): \(newMeters.map { String(format: "%.4f", $0) })")
            }
        }
        .onAppear {
            // Check microphone permission
            recorder.checkMicrophonePermission()
            // Debug: Verify meter publisher is set up and start monitoring
            // Don't start immediately - let the view settle first to avoid pinwheeling
            print("RecordView: onAppear - scheduling monitoring start")
            Task.detached(priority: .userInitiated) {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
                await MainActor.run {
                    if recorder.selectedInputChannels.count >= 4 {
                        recorder.startMonitoring()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Set folder on background thread to avoid blocking
                    // The fileImporter automatically grants security-scoped access when user selects a folder
                    Task.detached {
                        await projectManager.setProjectFolder(url)
                        // Verify access was granted
                        let hasAccess = await projectManager.checkWritePermissions()
                        await MainActor.run {
                            if hasAccess {
                                print("✅ Folder access granted: \(url.lastPathComponent)")
                            } else {
                                print("⚠️ Folder selected but write access not available. Try selecting a different folder.")
                            }
                        }
                    }
                }
            case .failure(let error):
                print("Folder selection error: \(error.localizedDescription)")
            }
        }
    }
    
    @State private var channelSelectionDebounceTimer: Timer?
    
    // Format time as MM:SS.mmm
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    private func handleChannelSelectionChange() {
        // Cancel existing timer
        channelSelectionDebounceTimer?.invalidate()
        
        // Create new timer that fires after delay (runs on main thread)
        // Increased delay to prevent rapid restarts causing pinwheeling
        channelSelectionDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak recorder, weak devices] _ in
            guard let recorder = recorder, let devices = devices else { return }
            
            let requiredChannels = recorder.recordingFormat.channelCount
            let hasEnoughChannels = recorder.selectedInputChannels.count >= requiredChannels
            let hasValidDevice = !recorder.selectedDeviceID.isEmpty && recorder.selectedDeviceID != "__no_devices__"
            let deviceExists = devices.inputDevices.contains(where: { $0.id == recorder.selectedDeviceID })
            
            // Only restart if conditions are met
            if hasEnoughChannels && hasValidDevice && deviceExists {
                // Check if we need to restart by comparing current channels with what's being monitored
                // Only restart if channels actually changed
                let currentChannels = Array(recorder.selectedInputChannels.prefix(4))
                let needsRestart = !recorder.isMonitoring || recorder.selectedInputChannels.count < 4
                
                if needsRestart {
                    print("🔄 Restarting monitoring with channels: \(currentChannels)")
                    // Start monitoring in background to avoid blocking UI
                    Task.detached(priority: .userInitiated) {
                        await MainActor.run {
                            recorder.startMonitoring()
                        }
                    }
                } else {
                    print("ℹ️ Monitoring already active with correct channels, skipping restart")
                }
            } else {
                // Stop if conditions not met
                if recorder.isMonitoring {
                    print("🛑 Stopping monitoring: hasEnough=\(hasEnoughChannels), validDevice=\(hasValidDevice), exists=\(deviceExists)")
                    Task.detached(priority: .userInitiated) {
                        await MainActor.run {
                            recorder.stopMonitoring()
                        }
                    }
                }
            }
        }
    }
}
