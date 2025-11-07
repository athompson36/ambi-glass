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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ambi‑Alice Recorder").font(.title2).bold()
                    Picker("Input Device", selection: $recorder.selectedDeviceID) {
                        ForEach(devices.inputDevices, id: \.id) { dev in
                            Text(dev.name).tag(dev.id)
                        }
                    }
                    .onChange(of: recorder.selectedDeviceID) { _ in
                        // Update available channels when device changes
                        devices.refreshDevices()
                    }
                    .onAppear { devices.refreshDevices() }
                    
                    // Input Channel Selection
                    if !devices.getInputChannels(for: recorder.selectedDeviceID).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Input Channels").font(.headline)
                            Text("Select 4 input channels to map to Ambi-Alice capsules:").font(.caption).opacity(0.8)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(devices.getInputChannels(for: recorder.selectedDeviceID), id: \.id) { channel in
                                    let isSelected = recorder.selectedInputChannels.contains(channel.channelNumber)
                                    Button(channel.name) {
                                        if isSelected {
                                            recorder.selectedInputChannels.removeAll { $0 == channel.channelNumber }
                                        } else {
                                            if recorder.selectedInputChannels.count < 4 {
                                                recorder.selectedInputChannels.append(channel.channelNumber)
                                                recorder.selectedInputChannels.sort()
                                            }
                                        }
                                    }
                                    .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                                    .opacity(isSelected ? 1.0 : 0.5)
                                }
                            }
                            if recorder.selectedInputChannels.count < 4 {
                                Text("Select \(4 - recorder.selectedInputChannels.count) more channel(s)").font(.caption).foregroundColor(.orange)
                            }
                        }
                        .padding(.top, 8)
                    }

                    HStack {
                        Button(isRecording ? "Stop" : "Record") {
                            if isRecording { recorder.stop() } else { try? recorder.start() }
                            isRecording.toggle()
                        }.buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))

                        Spacer()
                        Toggle("Safety A‑format", isOn: $recorder.safetyRecord)
                    }
                }
            }

            GlassCard {
                VStack {
                    Text("Input Meters")
                    HStack {
                        ForEach(0..<4, id: \.self) { i in
                            MeterBar(value: meters[i]).frame(width: 16, height: 120)
                        }
                    }
                }
            }
        }
        .padding()
        .onReceive(recorder.meterPublisher) { meters = $0 }
    }
}
