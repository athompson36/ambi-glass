import SwiftUI

@main
struct AmbiGlassApp: App {
    @StateObject private var devices = AudioDeviceManager()
    @StateObject private var recorder = RecorderEngine()
    @StateObject private var transcoder = Transcoder()
    @StateObject private var irkit = IRKit()
    @StateObject private var irMeasurementEngine = IRMeasurementEngine()
    @StateObject private var calibrator = CalibrationKit()
    @StateObject private var micCal = MicCalLoader()
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var dualRecorder = DualMicRecorder()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(devices)
                .environmentObject(recorder)
                .environmentObject(transcoder)
                .environmentObject(irkit)
                .environmentObject(irMeasurementEngine)
                .environmentObject(calibrator)
                .environmentObject(micCal)
                .environmentObject(theme)
                .environmentObject(dualRecorder)
                .preferredColorScheme(.dark)
        }
    }
}
