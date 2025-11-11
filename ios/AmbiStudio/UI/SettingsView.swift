import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager
    @StateObject private var folderManager = RecordingFolderManager.shared
    @State private var useMicCal = true
    @EnvironmentObject var micCal: MicCalLoader

    @State private var showingImporter = false
    @State private var showingFolderPicker = false

    var body: some View {
        ScrollView {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings").font(.title2).bold()
                    Toggle("High Contrast", isOn: $theme.highContrast)
                    
                    Divider().opacity(0.4)
                    
                    // Recording Folder Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recording Folder").font(.headline)
                        HStack {
                            Button("Select Folder") {
                                showingFolderPicker = true
                            }
                            .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Current: \(folderManager.folderName)").font(.footnote).opacity(0.8)
                                if let folder = folderManager.recordingFolder {
                                    Text(folder.path).font(.caption).opacity(0.6).lineLimit(2)
                                }
                            }
                        }
                        
                        Button("Reset to Default") {
                            folderManager.clearFolder()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Divider().opacity(0.4)
                    Toggle("Apply Mic Calibration", isOn: $useMicCal)
                    HStack {
                        Button("Load Mic Cal File") { showingImporter = true }
                            .buttonStyle(NeonButtonStyle(highContrast: theme.highContrast))
                        if !micCal.filename.isEmpty {
                            Text("Loaded: \\(micCal.filename)").font(.footnote).opacity(0.8)
                        }
                    }
                    
                    if let cal = micCal.cal {
                        Divider().opacity(0.4)
                        Text("Calibration Curve").bold()
                        Text("Frequency Response (dB)").font(.footnote).opacity(0.8)
                        CalibrationCurveView(curve: cal)
                            .padding(.vertical, 8)
                        
                        // Stats
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Range: \(String(format: "%.0f", cal.freqs.first ?? 0)) - \(String(format: "%.0f", cal.freqs.last ?? 0)) Hz").font(.caption)
                            Text("Gain: \(String(format: "%.2f", cal.gains.min() ?? 0)) to \(String(format: "%.2f", cal.gains.max() ?? 0)) dB").font(.caption)
                            Text("Points: \(cal.freqs.count)").font(.caption)
                        }
                        .opacity(0.7)
                    }
                }
            }
        }
        .padding()
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.text, .commaSeparatedText, .plainText], allowsMultipleSelection: false) { res in
            switch res {
            case .success(let urls):
                if let url = urls.first { micCal.load(from: url) }
            case .failure(let err):
                print("Importer error: \(err)")
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    folderManager.setFolder(url)
                }
            case .failure(let error):
                print("Folder selection error: \(error.localizedDescription)")
            }
        }
    }
}
