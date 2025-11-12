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
                                Picker("Input Device", selection: $recorder.selectedDeviceID) {
                                    ForEach(devices.inputDevices, id: \.id) { dev in
                                        Text(dev.name).tag(dev.id)
                                    }
                                }
                                .frame(width: 200) // Narrower width for 15-29 characters
                                .onChange(of: recorder.selectedDeviceID) { _ in
                                    devices.refreshDevices()
                                }
                                .onAppear { devices.refreshDevices() }
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
                            }
                        }
                        .frame(width: 220, alignment: .trailing) // Fixed width for right side
                    }
                    .padding(.vertical, 8)

                    // Record button and Safety toggle at bottom
                    HStack {
                        Button(isRecording ? "Stop" : "Record") {
                            if isRecording { recorder.stop() } else { try? recorder.start() }
                            isRecording.toggle()
                        }.buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))

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
