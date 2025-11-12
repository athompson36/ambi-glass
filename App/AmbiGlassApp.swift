import SwiftUI
#if os(iOS)
import Foundation // For PhoneRelay
#endif

@main
struct AmbiGlassApp: App {
    @StateObject private var devices = AudioDeviceManager()
    @StateObject private var recorder = RecorderEngine()
    @StateObject private var transcoder = Transcoder()
    @StateObject private var irkit = IRKit()
    @StateObject private var calibrator = CalibrationKit()
    @StateObject private var micCal = MicCalLoader()
    @StateObject private var theme = ThemeManager.shared
    
    #if os(iOS)
    // Initialize PhoneRelay for WatchConnectivity (iPhone only)
    private let _ = PhoneRelay.shared
    #endif
    
    #if os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst))
    // LAN listener for iPad/Mac hosts to receive remote commands
    @State private var lanListener: LANListener?
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(devices)
                .environmentObject(recorder)
                .environmentObject(transcoder)
                .environmentObject(irkit)
                .environmentObject(calibrator)
                .environmentObject(micCal)
                .environmentObject(theme)
                .preferredColorScheme(.dark)
                .onAppear {
                    setupRemoteControl()
                }
        }
    }
    
    private func setupRemoteControl() {
        #if os(iOS)
        // On iPhone: Observe RemoteMessage notifications from PhoneRelay
        // PhoneRelay posts these when it receives commands from Watch
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RemoteMessage"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let message = notification.object as? RemoteMessage else { return }
            switch message.cmd {
            case .startRecording:
                do {
                    try self?.recorder.start()
                } catch {
                    print("Failed to start recording from remote: \(error)")
                }
            case .stopRecording:
                self?.recorder.stop()
            case .startIR:
                // Post notification for IR measurement start
                NotificationCenter.default.post(
                    name: NSNotification.Name("StartIRMeasurement"),
                    object: nil
                )
            case .stopIR:
                // Post notification for IR measurement stop
                NotificationCenter.default.post(
                    name: NSNotification.Name("StopIRMeasurement"),
                    object: nil
                )
            case .ping:
                break
            }
        }
        #endif
        
        #if os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst))
        // Set up LAN listener for iPad/Mac to receive commands from iPhone relay
        do {
            lanListener = try LANListener(port: 47655) { [weak self] message in
                // Handle incoming remote command
                DispatchQueue.main.async {
                    switch message.cmd {
                    case .startRecording:
                        do {
                            try self?.recorder.start()
                        } catch {
                            print("Failed to start recording from remote: \(error)")
                        }
                    case .stopRecording:
                        self?.recorder.stop()
                    case .startIR:
                        // Post notification for IR measurement start
                        NotificationCenter.default.post(
                            name: NSNotification.Name("StartIRMeasurement"),
                            object: nil
                        )
                    case .stopIR:
                        // Post notification for IR measurement stop
                        NotificationCenter.default.post(
                            name: NSNotification.Name("StopIRMeasurement"),
                            object: nil
                        )
                    case .ping:
                        break
                    }
                }
            }
        } catch {
            print("Failed to start LAN listener: \(error)")
        }
        #endif
    }
}
