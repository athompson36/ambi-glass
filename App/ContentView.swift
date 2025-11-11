import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem { Label("Record", systemImage: "dot.radiowaves.left.and.right") }
            MeasureIRView()
                .tabItem { Label("Measure IR", systemImage: "waveform") }
            BatchTranscodeView()
                .tabItem { Label("Transcode", systemImage: "arrow.2.squarepath") }
            CalibrationView()
                .tabItem { Label("Calibrate", systemImage: "gauge") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .background(GlassBackground())
    }
}
