import Foundation

public enum RemoteCommand: String, Codable { case startRecording, stopRecording, startIR, stopIR, ping }

public struct RemoteMessage: Codable {
    public var cmd: RemoteCommand
    public var timestamp: TimeInterval = Date().timeIntervalSince1970
    public init(_ cmd: RemoteCommand) { self.cmd = cmd }
}

public struct RemoteStatus: Codable {
    public enum Phase: String, Codable { case idle, recording, irMeasuring, processingIR, error }
    public var phase: Phase
    public var detail: String
    public init(_ p: Phase, _ d: String = "") { phase = p; detail = d }
}
