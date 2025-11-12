import Foundation
import Combine

/// Minimal transport shim you can call from any platform target.
public final class TransportController: ObservableObject {
    public static let shared = TransportController()
    @Published public var status = RemoteStatus(.idle, "")
    private init() {}

    // MARK: - Hooks to your existing audio/IR engines
    public func startRecording() {
        // TODO: Call into your RecorderEngine.start() here.
        status = .init(.recording, "Recording…")
        NotificationCenter.default.post(name: .init("TransportStatusDidChange"), object: status)
    }
    public func stopRecording() {
        // TODO: RecorderEngine.stop()
        status = .init(.idle, "Stopped")
        NotificationCenter.default.post(name: .init("TransportStatusDidChange"), object: status)
    }
    public func startIR() {
        // TODO: IRKit.runSweep(...)
        status = .init(.irMeasuring, "Sweep running…")
        NotificationCenter.default.post(name: .init("TransportStatusDidChange"), object: status)
    }
    public func stopIR() {
        // TODO: Stop IR capture/processing as needed
        status = .init(.idle, "IR stopped")
        NotificationCenter.default.post(name: .init("TransportStatusDidChange"), object: status)
    }
}
