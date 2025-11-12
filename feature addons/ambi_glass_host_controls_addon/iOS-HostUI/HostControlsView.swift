import SwiftUI
import Combine

/// Simple iPhone control panel to run the host locally and/or relay to LAN.
public struct HostControlsView: View {
    @StateObject var transport = TransportController.shared
    @StateObject var relay = PhoneRelay.shared
    @State private var hostAddress: String = "ipad-or-mac.local"
    @State private var isRelayingToLAN = false
    private let obs = RemoteMessageObserver() // ensure watch commands drive the transport

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ambi-A IR — Host Controls").font(.headline)
            Text("Status: \(relay.lastStatus.phase.rawValue.capitalized) \(relay.lastStatus.detail)").font(.footnote).opacity(0.8)

            HStack {
                Button("Start Rec") { transport.startRecording(); relay.pushStatus(transport.status) }
                    .buttonStyle(.borderedProminent)
                Button("Stop") { transport.stopRecording(); relay.pushStatus(transport.status) }
                    .buttonStyle(.bordered)
            }

            HStack {
                Button("Start IR") { transport.startIR(); relay.pushStatus(transport.status) }
                    .buttonStyle(.bordered)
                Button("Abort IR") { transport.stopIR(); relay.pushStatus(transport.status) }
                    .buttonStyle(.bordered)
            }

            Divider()
            Toggle("Relay commands to LAN host", isOn: $isRelayingToLAN)
            HStack {
                TextField("Host name or IP", text: $hostAddress)
                    .textFieldStyle(.roundedBorder)
                Button("Connect") {
                    if isRelayingToLAN {
                        relay.connectToHost(host: hostAddress)
                    }
                }
            }

            Text("Tip: When this iPhone is the recorder, just use the buttons above. When your iPad/Mac is the recorder, enable LAN relay so Watch commands reach the host.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .onReceive(TransportController.shared.$status) { s in
            relay.pushStatus(s)
        }
    }
}
