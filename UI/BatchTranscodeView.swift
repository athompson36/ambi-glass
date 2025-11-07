import SwiftUI
import UniformTypeIdentifiers

struct BatchTranscodeView: View {
    @EnvironmentObject var transcoder: Transcoder
    @EnvironmentObject var theme: ThemeManager
    @State private var dropped: [URL] = []
    @State private var errorText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Batch Transcode").font(.title2).bold()
                    Text("Drop **4 mono WAV** files recorded from Ambi-Alice (A-format).")
                    DropArea { urls in
                        validateAndQueue(urls)
                    }
                    if !dropped.isEmpty {
                        Text("Queued: \\(dropped.map { $0.lastPathComponent }.joined(separator: \", \"))").font(.footnote)
                    }
                    if !errorText.isEmpty {
                        Text(errorText).foregroundColor(.red).font(.footnote)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Export Formats").bold()
                        HStack {
                            Button("AmbiX") { transcoder.exportAmbiX() }
                            Button("FuMa") { transcoder.exportFuMa() }
                            Button("Stereo") { transcoder.exportStereo() }
                        }
                        .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                        HStack {
                            Button("5.1") { transcoder.export5_1() }
                            Button("7.1") { transcoder.export7_1() }
                            Button("Binaural") { transcoder.exportBinaural() }
                        }
                        .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                    }
                }
            }
        }.padding()
    }
}

struct DropArea: View {
    var onComplete: ([URL]) -> Void
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [6,6]))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(height: 140)
            .overlay(Text("Drop 4 mono WAVs here").font(.headline))
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                Task {
                    var urls: [URL] = []
                    for p in providers {
                        do {
                            let item = try await p.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                            if let url = item as? URL {
                                urls.append(url)
                            } else if let nsurl = item as? NSURL, let u = nsurl as URL? {
                                urls.append(u)
                            }
                        } catch {
                            // ignore individual failures
                        }
                    }
                    if urls.count == 4 { onComplete(urls) }
                }
                return true
            }
    }
}

private extension BatchTranscodeView {
    func validateAndQueue(_ urls: [URL]) {
        errorText = ""
        guard urls.count == 4 else { errorText = "Please drop exactly 4 files."; dropped = []; return }
        let wavs = urls.filter { $0.pathExtension.lowercased() == "wav" }
        guard wavs.count == 4 else { errorText = "All files must be .wav"; dropped = []; return }
        dropped = wavs
        transcoder.handleFourMono(urls: wavs)
    }
}
