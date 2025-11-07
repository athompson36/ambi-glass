import Foundation
import AVFoundation
import Combine

final class AudioDeviceManager: ObservableObject {
    struct Device: Identifiable {
        let id: String
        let name: String
    }

    @Published var inputDevices: [Device] = []

    func refreshDevices() {
        var arr: [Device] = []
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if let inputs = session.availableInputs {
            arr = inputs.map { Device(id: $0.uid, name: $0.portName) }
        } else {
            arr = [Device(id: "default", name: "Default Input")]
        }
        #elseif os(macOS)
        // Enumerate macOS audio capture devices via AVCaptureDevice for a user-facing list
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .externalUnknown], mediaType: .audio, position: .unspecified)
        let devices = discovery.devices
        if devices.isEmpty {
            arr = [Device(id: "default", name: "System Default")]
        } else {
            arr = devices.map { Device(id: $0.uniqueID, name: $0.localizedName) }
        }
        #else
        arr = [Device(id: "default", name: "System Default")]
        #endif
        DispatchQueue.main.async { self.inputDevices = arr }
    }
}
