import SwiftUI
import AVFoundation
import Combine

struct RecordView: View {
    @EnvironmentObject var devices: AudioDeviceManager
    @EnvironmentObject var recorder: RecorderEngine
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var transcoder: Transcoder

    @State private var isRecording = false
    @State private var meters: [CGFloat] = [0,0,0,0]

    var body: some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ambi‑Alice Recorder").font(.title2).bold()
                    
                    // Main content area: Meters on left, Input controls on right
                    HStack(alignment: .top, spacing: 16) {
                        // Input Meters - prominent on the left
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input Meters").font(.caption).opacity(0.7)
                            HStack(spacing: 8) {
                                ForEach(0..<4, id: \.self) { i in
                                    MeterBar(value: meters[i]).frame(width: 20, height: 140)
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
                                            if recorder.selectedInputChannels.count == 4 {
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
                                                    if recorder.selectedInputChannels.count < 4 {
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
                                    if recorder.selectedInputChannels.count < 4 {
                                        Text("Select \(4 - recorder.selectedInputChannels.count) more")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                .onChange(of: recorder.selectedInputChannels) { _ in
                                    // Start monitoring when 4 channels are selected (non-blocking)
                                    if recorder.selectedInputChannels.count == 4 {
                                        guard !recorder.selectedDeviceID.isEmpty && recorder.selectedDeviceID != "__no_devices__" else {
                                            print("Cannot start monitoring: no device selected")
                                            return
                                        }
                                        // Use Task instead of DispatchQueue to avoid blocking
                                        Task { @MainActor in
                                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                                            // Verify device is valid before starting
                                            if devices.inputDevices.contains(where: { $0.id == recorder.selectedDeviceID }) {
                                                recorder.startMonitoring()
                                            } else {
                                                print("Cannot start monitoring: device \(recorder.selectedDeviceID) not found")
                                            }
                                        }
                                    } else {
                                        recorder.stopMonitoring()
                                    }
                                }
                            }
                        }
                        .frame(width: 220, alignment: .trailing) // Fixed width for right side
                    }
                    .padding(.vertical, 8)

                    // Record button and Safety toggle at bottom
                    HStack {
                        Button(isRecording ? "Stop" : "Record") {
                            if isRecording {
                                recorder.stop()
                                isRecording = false
                            } else {
                                // Validate before starting
                                guard recorder.selectedInputChannels.count == 4 else {
                                    print("Error: Must select 4 input channels")
                                    return
                                }
                                
                                // Start recording - use async to avoid blocking
                                Task { @MainActor in
                                    do {
                                        try recorder.start()
                                        isRecording = true
                                    } catch {
                                        isRecording = false
                                        print("Recording error: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                        .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                        .disabled(recorder.selectedInputChannels.count != 4)

                        Spacer()
                        Toggle("Safety A‑format", isOn: $recorder.safetyRecord)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .onReceive(recorder.meterPublisher) { meters = $0 }
    }
}
