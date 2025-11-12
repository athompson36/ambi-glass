import Foundation
import Network

public final class LANListener {
    private var listener: NWListener!
    private let onCommand: (RemoteMessage) -> Void

    public init(port: UInt16 = 47655, onCommand: @escaping (RemoteMessage) -> Void) throws {
        self.onCommand = onCommand
        listener = try NWListener(using: .udp, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .main)
            self?.receive(on: conn)
        }
        listener.start(queue: .main)
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, _, _ in
            if let data, let msg = try? JSONDecoder().decode(RemoteMessage.self, from: data) {
                self?.onCommand(msg)
            }
            self?.receive(on: conn)
        }
    }
}
