import Foundation
#if os(iOS)
import WatchConnectivity
#endif
import Network
import Combine

#if os(iOS)
public final class PhoneRelay: NSObject, WCSessionDelegate, ObservableObject {
    public static let shared = PhoneRelay()
    private var session = WCSession.default
    private var connection: NWConnection?
    @Published public var lastStatus: RemoteStatus = .init(.idle)

    public override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation completion
    }

    public func session(_ session: WCSession, didReceiveMessageData data: Data) {
        if let msg = try? JSONDecoder().decode(RemoteMessage.self, from: data) {
            NotificationCenter.default.post(name: .init("RemoteMessage"), object: msg)
            forwardToLAN(msg)
        }
    }

    public func pushStatus(_ status: RemoteStatus) {
        lastStatus = status
        guard session.isReachable, let data = try? JSONEncoder().encode(status) else { return }
        session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
    }

    public func connectToHost(host: String, port: UInt16 = 47655) {
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .udp)
        connection?.start(queue: .main)
    }
    private func forwardToLAN(_ msg: RemoteMessage) {
        guard let connection, let data = try? JSONEncoder().encode(msg) else { return }
        connection.send(content: data, completion: .contentProcessed({ _ in }))
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {}
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
#else
// Stub for non-iOS platforms
import Combine

public final class PhoneRelay: ObservableObject {
    public static let shared = PhoneRelay()
    @Published public var lastStatus: RemoteStatus = .init(.idle)
    
    public init() {}
    
    public func pushStatus(_ status: RemoteStatus) {
        lastStatus = status
    }
    
    public func connectToHost(host: String, port: UInt16 = 47655) {
        // Not available on non-iOS
    }
}
#endif
