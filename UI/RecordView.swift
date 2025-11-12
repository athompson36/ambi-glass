import SwiftUI
import AVFoundation
import Combine
#if os(iOS)
import Foundation // For PhoneRelay and RemoteStatus
#endif

struct RecordView: View {
    @EnvironmentObject var devices: AudioDeviceManager
    @EnvironmentObject var recorder: RecorderEngine
    @EnvironmentObject var theme: ThemeManager

    @State private var isRecording = false
    @State private var meters: [CGFloat] = [0,0,0,0]
    @State private var errorMessage: String = ""
    @State private var showError = false

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
                    .onAppear { devices.refreshDevices() }

                    HStack {
                        Button(isRecording ? "Stop" : "Record") {
                            if isRecording {
                                recorder.stop()
                                isRecording = false
                                #if os(iOS)
                                PhoneRelay.shared.pushStatus(RemoteStatus(.idle, "Stopped"))
                                #endif
                            } else {
                                do {
                                    try recorder.start()
                                    isRecording = true
                                    errorMessage = ""
                                    #if os(iOS)
                                    PhoneRelay.shared.pushStatus(RemoteStatus(.recording, "Recording…"))
                                    #endif
                                } catch {
                                    errorMessage = "Failed to start recording: \(error.localizedDescription)"
                                    showError = true
                                    isRecording = false
                                    #if os(iOS)
                                    PhoneRelay.shared.pushStatus(RemoteStatus(.error, "Record error: \(error.localizedDescription)"))
                                    #endif
                                }
                            }
                        }
                        .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                        .disabled(isRecording && devices.inputDevices.isEmpty)

                        Spacer()
                        Toggle("Safety A‑format", isOn: $recorder.safetyRecord)
                    }
                    
                    if showError && !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                    
                    if devices.inputDevices.isEmpty {
                        Text("No input devices found. Please connect a 4+ channel audio interface.")
                            .font(.footnote)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RemoteMessage"))) { notification in
            guard let message = notification.object as? RemoteMessage else { return }
            switch message.cmd {
            case .startRecording:
                if !isRecording {
                    do {
                        try recorder.start()
                        isRecording = true
                        errorMessage = ""
                        #if os(iOS)
                        PhoneRelay.shared.pushStatus(RemoteStatus(.recording, "Recording…"))
                        #endif
                    } catch {
                        errorMessage = "Failed to start recording: \(error.localizedDescription)"
                        showError = true
                        isRecording = false
                        #if os(iOS)
                        PhoneRelay.shared.pushStatus(RemoteStatus(.error, "Record error: \(error.localizedDescription)"))
                        #endif
                    }
                }
            case .stopRecording:
                if isRecording {
                    recorder.stop()
                    isRecording = false
                    #if os(iOS)
                    PhoneRelay.shared.pushStatus(RemoteStatus(.idle, "Stopped"))
                    #endif
                }
            default:
                break
            }
        }
    }
}
