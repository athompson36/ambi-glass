import SwiftUI
import UniformTypeIdentifiers

struct BatchTranscodeView: View {
    @EnvironmentObject var transcoder: Transcoder
    @EnvironmentObject var theme: ThemeManager
    @State private var dropped: [URL] = []
    @State private var errorText: String = ""
    @State private var successMessage: String = ""
    @State private var showingImporter = false

    var body: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Batch Transcode").font(.title2).bold()
                    Text("Import or drag and drop 4 mono WAV files from Ambi-Alice capsules (A-format).")
                    
                    // Naming Convention Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("File Naming Convention").font(.headline)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Files must be named with channel numbers: -1, -2, -3, -4").font(.caption).bold()
                            Text("Example: capsule-1.wav, capsule-2.wav, capsule-3.wav, capsule-4.wav").font(.caption).opacity(0.8)
                            Text("Channel mapping:").font(.caption).bold()
                            Text("• -1 → Channel 1 (Capsule 1)").font(.caption).opacity(0.7)
                            Text("• -2 → Channel 2 (Capsule 2)").font(.caption).opacity(0.7)
                            Text("• -3 → Channel 3 (Capsule 3)").font(.caption).opacity(0.7)
                            Text("• -4 → Channel 4 (Capsule 4)").font(.caption).opacity(0.7)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Import Button
                    HStack {
                        Button("Import Files") {
                            showingImporter = true
                        }
                        .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                        
                        Spacer()
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Drag and Drop Area
                    DropArea(
                        onComplete: { urls in
                            validateAndQueue(urls)
                        },
                        onError: { errorMessage in
                            errorText = errorMessage
                            successMessage = ""
                        }
                    )
                    
                    // Success Message
                    if !successMessage.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(successMessage).font(.footnote).foregroundColor(.green)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                    
                    // Error Message
                    if !errorText.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorText).font(.footnote).foregroundColor(.red)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                    
                    Divider().opacity(0.4)
                    
                    // Show imported files and waveforms
                    if !transcoder.importedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Imported Files (sorted by channel):").font(.headline).bold()
                            
                            ForEach(Array(transcoder.importedFiles.enumerated()), id: \.offset) { index, url in
                                WaveformView(audioURL: url, channelNumber: index + 1)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
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
        }
        .padding()
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                validateAndQueue(urls)
            case .failure(let error):
                errorText = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

struct DropArea: View {
    var onComplete: ([URL]) -> Void
    var onError: ((String) -> Void)? = nil
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
                            print("Error loading dropped file: \(error.localizedDescription)")
                        }
                    }
                    await MainActor.run {
                        if urls.count == 4 {
                            onComplete(urls)
                        } else if !urls.isEmpty {
                            onError?("Please drop exactly 4 files. Found \(urls.count) file(s).")
                        }
                    }
                }
                return true
            }
    }
}

private extension BatchTranscodeView {
    func validateAndQueue(_ urls: [URL]) {
        errorText = ""
        
        // Start accessing security-scoped resources
        for url in urls {
            _ = url.startAccessingSecurityScopedResource()
        }
        defer {
            // Stop accessing security-scoped resources
            for url in urls {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard urls.count == 4 else {
            errorText = "Please drop exactly 4 files. Found \(urls.count) file(s)."
            dropped = []
            return
        }
        
        let wavs = urls.filter { $0.pathExtension.lowercased() == "wav" }
        guard wavs.count == 4 else {
            errorText = "All files must be .wav format. Found \(wavs.count) WAV file(s)."
            dropped = []
            return
        }
        
        // Validate channel numbers in filenames
        let channels = wavs.compactMap { transcoder.extractChannelNumber(from: $0) }
        if channels.count < 4 {
            let missingChannels = Set([1, 2, 3, 4]).subtracting(Set(channels))
            errorText = "Missing channel numbers in filenames. Files must contain -1, -2, -3, -4. Missing: \(missingChannels.sorted().map { "-\($0)" }.joined(separator: ", "))"
            successMessage = ""
            dropped = []
            return
        }
        
        dropped = wavs
        transcoder.handleFourMono(urls: wavs)
        
        // Show success message
        successMessage = "Successfully imported 4 WAV files! Files sorted by channel number."
        errorText = ""
        
        // Clear success message after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if successMessage == "Successfully imported 4 WAV files! Files sorted by channel number." {
                successMessage = ""
            }
        }
    }
}
