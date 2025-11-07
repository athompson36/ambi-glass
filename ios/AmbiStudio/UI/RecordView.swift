import SwiftUI
import AVFoundation
import Combine
import UniformTypeIdentifiers

struct RecordView: View {
    @EnvironmentObject var devices: AudioDeviceManager
    @EnvironmentObject var recorder: RecorderEngine
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var transcoder: Transcoder

    @State private var isRecording = false
    @State private var meters: [CGFloat] = [0,0,0,0]
    @State private var showingImporter = false
    @State private var importError: String = ""

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
                        
                        Button("Import") {
                            showingImporter = true
                        }
                        .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))

                        Spacer()
                        Toggle("Safety A‑format", isOn: $recorder.safetyRecord)
                    }
                    
                    if !transcoder.importedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Imported Files:").font(.footnote).bold()
                            ForEach(Array(transcoder.importedFiles.enumerated()), id: \.offset) { index, url in
                                Text("\(index + 1). \(url.lastPathComponent)").font(.caption).opacity(0.8)
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    if !importError.isEmpty {
                        Text(importError).foregroundColor(.red).font(.footnote)
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
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result: result)
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        importError = ""
        switch result {
        case .success(let urls):
            // Filter for WAV files
            let wavFiles = urls.filter { $0.pathExtension.lowercased() == "wav" }
            
            guard wavFiles.count == 4 else {
                importError = "Please select exactly 4 WAV files. Found \(wavFiles.count) WAV file(s)."
                return
            }
            
            // Validate they are mono files (basic check - could be enhanced)
            transcoder.handleFourMono(urls: wavFiles)
            importError = ""
            
        case .failure(let error):
            importError = "Import failed: \(error.localizedDescription)"
        }
    }
}
