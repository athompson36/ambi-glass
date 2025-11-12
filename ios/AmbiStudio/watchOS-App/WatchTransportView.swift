import SwiftUI

struct WatchTransportView: View {
    @StateObject var remote = WatchRemote()
    var body: some View {
        VStack(spacing: 10) {
            Text(remote.statusText).font(.footnote).multilineTextAlignment(.center)
            HStack {
                Button("Rec")  { remote.send(.startRecording) }.buttonStyle(.borderedProminent)
                Button("Stop") { remote.send(.stopRecording)  }.buttonStyle(.bordered)
            }
            HStack {
                Button("IR")   { remote.send(.startIR) }.buttonStyle(.bordered)
                Button("Abort"){ remote.send(.stopIR)  }.buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }
}
