import Foundation
import WatchConnectivity
import Network

final class PhoneRelay: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = PhoneRelay()
    private var session = WCSession.default
    private var connection: NWConnection?
    @Published var lastStatus: RemoteStatus = .init(.idle)

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, didReceiveMessageData data: Data) {
        if let msg = try? JSONDecoder().decode(RemoteMessage.self, from: data) {
            NotificationCenter.default.post(name: .init("RemoteMessage"), object: msg)
            forwardToLAN(msg)
        }
    }

    func pushStatus(_ status: RemoteStatus) {
        lastStatus = status
        guard session.isReachable, let data = try? JSONEncoder().encode(status) else { return }
        session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
    }

    func connectToHost(host: String, port: UInt16 = 47655) {
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .udp)
        connection?.start(queue: .main)
    }
    private func forwardToLAN(_ msg: RemoteMessage) {
        guard let connection, let data = try? JSONEncoder().encode(msg) else { return }
        connection.send(content: data, completion: .contentProcessed({ _ in }))
    }

    func sessionReachabilityDidChange(_ session: WCSession) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
