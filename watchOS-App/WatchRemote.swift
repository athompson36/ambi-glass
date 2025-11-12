import Foundation
import WatchConnectivity
import Combine

public final class WatchRemote: NSObject, ObservableObject, WCSessionDelegate {
    @Published public var statusText = "Idle"
    private var session = WCSession.default

    public override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    public func send(_ cmd: RemoteCommand) {
        let msg = RemoteMessage(cmd)
        if let data = try? JSONEncoder().encode(msg) {
            session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
        }
    }

    public func session(_ session: WCSession, didReceiveMessageData data: Data) {
        if let s = try? JSONDecoder().decode(RemoteStatus.self, from: data) {
            DispatchQueue.main.async { self.statusText = "\(s.phase.rawValue.capitalized) \(s.detail)" }
        }
    }
}
