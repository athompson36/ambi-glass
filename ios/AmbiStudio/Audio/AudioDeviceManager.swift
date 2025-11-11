import Foundation
import AVFoundation
import Combine

final class AudioDeviceManager: ObservableObject {
    struct Device: Identifiable {
        let id: String
        let name: String
        let inputChannels: [InputChannel]
        let outputChannels: [OutputChannel]
    }
    
    struct InputChannel: Identifiable {
        let id: Int
        let name: String
        let channelNumber: Int
    }
    
    struct OutputChannel: Identifiable {
        let id: Int
        let name: String
        let channelNumber: Int
    }

    @Published var inputDevices: [Device] = []
    @Published var outputDevices: [Device] = []

    func refreshDevices() {
        var inputArr: [Device] = []
        var outputArr: [Device] = []
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        
        // Input devices
        if let inputs = session.availableInputs {
            inputArr = inputs.map { port in
                let channels = enumerateInputChannels(for: port)
                return Device(id: port.uid, name: port.portName, inputChannels: channels, outputChannels: [])
            }
        } else {
            inputArr = [Device(id: "default", name: "Default Input", inputChannels: [], outputChannels: [])]
        }
        
        // Output devices (iOS has limited output enumeration)
        outputArr = [Device(id: "default", name: "Default Output", inputChannels: [], outputChannels: enumerateOutputChannels())]
        
        #elseif os(macOS)
        // Use AVAudioEngine to enumerate devices
        let engine = AVAudioEngine()
        
        // Get input devices via AVCaptureDevice
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone, .externalUnknown], mediaType: .audio, position: .unspecified)
        let devices = discovery.devices
        
        if devices.isEmpty {
            // Fallback: use engine's input node format
            let inputNode = engine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)
            let channels = enumerateChannelsFromFormat(inputFormat)
            inputArr = [Device(id: "default", name: "System Default", inputChannels: channels, outputChannels: [])]
        } else {
            // Enumerate each device and get its channel count
            inputArr = devices.map { device in
                // Try to get actual channel count from device
                // For now, we'll query the engine when the device is selected
                // Default to 4 channels for Ambi-Alice interfaces
                let channels = (0..<max(4, 8)).map { i in
                    InputChannel(id: i, name: "Input \(i + 1)", channelNumber: i)
                }
                return Device(id: device.uniqueID, name: device.localizedName, inputChannels: channels, outputChannels: [])
            }
        }
        
        // Output devices - enumerate via engine
        let outputNode = engine.outputNode
        let outputFormat = outputNode.outputFormat(forBus: 0)
        let outputChannels = enumerateOutputChannelsFromFormat(outputFormat)
        outputArr = [Device(id: "default", name: "System Default", inputChannels: [], outputChannels: outputChannels)]
        
        #else
        inputArr = [Device(id: "default", name: "System Default", inputChannels: [], outputChannels: [])]
        outputArr = [Device(id: "default", name: "System Default", inputChannels: [], outputChannels: [])]
        #endif
        
        DispatchQueue.main.async {
            self.inputDevices = inputArr
            self.outputDevices = outputArr
        }
    }
    
    #if os(iOS)
    private func enumerateInputChannels(for port: AVAudioSessionPortDescription) -> [InputChannel] {
        var channels: [InputChannel] = []
        // AVAudioSessionPortDescription doesn't directly expose channel count
        // We'll enumerate based on available data sources
        if let dataSources = port.dataSources, !dataSources.isEmpty {
            for (index, _) in dataSources.enumerated() {
                channels.append(InputChannel(id: index, name: "Input \(index + 1)", channelNumber: index))
            }
        } else {
            // Default: assume 4 channels for Ambi-Alice
            for i in 0..<4 {
                channels.append(InputChannel(id: i, name: "Input \(i + 1)", channelNumber: i))
            }
        }
        return channels
    }
    #endif
    
    private func enumerateOutputChannels() -> [OutputChannel] {
        var channels: [OutputChannel] = []
        // Default: enumerate common output channel counts
        for i in 0..<8 {
            channels.append(OutputChannel(id: i, name: "Output \(i + 1)", channelNumber: i))
        }
        return channels
    }
    
    private func enumerateChannelsFromFormat(_ format: AVAudioFormat) -> [InputChannel] {
        var channels: [InputChannel] = []
        let channelCount = Int(format.channelCount)
        for i in 0..<channelCount {
            channels.append(InputChannel(id: i, name: "Channel \(i + 1)", channelNumber: i))
        }
        return channels
    }
    
    private func enumerateOutputChannelsFromFormat(_ format: AVAudioFormat) -> [OutputChannel] {
        var channels: [OutputChannel] = []
        let channelCount = Int(format.channelCount)
        // Enumerate up to 8 channels for common interfaces
        let maxChannels = max(channelCount, 8)
        for i in 0..<maxChannels {
            channels.append(OutputChannel(id: i, name: "Output \(i + 1)", channelNumber: i))
        }
        return channels
    }
    
    // Get physical input channels for a device
    func getInputChannels(for deviceId: String) -> [InputChannel] {
        if let device = inputDevices.first(where: { $0.id == deviceId }) {
            return device.inputChannels
        }
        return []
    }
    
    // Get physical output channels for a device
    func getOutputChannels(for deviceId: String) -> [OutputChannel] {
        if let device = outputDevices.first(where: { $0.id == deviceId }) {
            return device.outputChannels
        }
        return []
    }
}
