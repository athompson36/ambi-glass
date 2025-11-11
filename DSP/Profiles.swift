import Foundation

struct Orientation: Codable {
    var yaw: Double
    var pitch: Double
    var roll: Double
}

struct MicProfile: Codable, Identifiable {
    var id: String { name }
    var name: String
    var matrix: [Float]
    var ordering: String
    var orientation: Orientation
    var capsuleTrims_dB: [Float]
}

struct InterfaceProfile: Codable, Identifiable {
    var id: String { "\(deviceId)_\(Int(sampleRate))_\(Int(bufferFrames))_\(Int(createdAt.timeIntervalSince1970))" }
    var deviceId: String
    var sampleRate: Double
    var bufferFrames: Int
    var ioLatencyMs: Double
    var channelGains_dB: [Double]
    var createdAt: Date
}

final class ProfileStore {
    static let shared = ProfileStore()
    private init() {}

    private let fm = FileManager.default
    private var baseDir: URL {
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AmbiGlass", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var ifaceURL: URL { baseDir.appendingPathComponent("InterfaceProfiles.json") }
    private var micURL: URL { baseDir.appendingPathComponent("MicProfiles.json") }

    func saveInterfaceProfile(_ profile: InterfaceProfile) {
        var list = loadInterfaceProfiles()
        list.append(profile)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: ifaceURL)
        }
    }

    func loadInterfaceProfiles() -> [InterfaceProfile] {
        guard let data = try? Data(contentsOf: ifaceURL) else { return [] }
        return (try? JSONDecoder().decode([InterfaceProfile].self, from: data)) ?? []
    }

    func latestInterfaceProfile() -> InterfaceProfile? {
        return loadInterfaceProfiles().sorted { $0.createdAt > $1.createdAt }.first
    }

    func saveMicProfile(_ profile: MicProfile) {
        var list = loadMicProfiles().filter { $0.name != profile.name }
        list.append(profile)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: micURL)
        }
    }

    func loadMicProfiles() -> [MicProfile] {
        guard let data = try? Data(contentsOf: micURL) else { return [] }
        return (try? JSONDecoder().decode([MicProfile].self, from: data)) ?? []
    }
}


