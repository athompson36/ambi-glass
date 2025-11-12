import Foundation
import Combine

/// Observes RemoteMessage notifications on iPhone and controls TransportController.
public final class RemoteMessageObserver {
    private var token: Any?
    public init() {
        token = NotificationCenter.default.addObserver(forName: .init("RemoteMessage"), object: nil, queue: .main) { note in
            guard let msg = note.object as? RemoteMessage else { return }
            let t = TransportController.shared
            switch msg.cmd {
            case .startRecording: t.startRecording()
            case .stopRecording:  t.stopRecording()
            case .startIR:        t.startIR()
            case .stopIR:         t.stopIR()
            case .ping: break
            }
        }
    }
    deinit { if let token = token { NotificationCenter.default.removeObserver(token) } }
}
