import SwiftUI
import AVFoundation
import Combine

struct RecordView: View {
    @EnvironmentObject var devices: AudioDeviceManager
    @EnvironmentObject var recorder: RecorderEngine
    @EnvironmentObject var theme: ThemeManager

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
                    .onAppear { devices.refreshDevices() }

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
