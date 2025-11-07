import Foundation
import Combine

/// Manages calibration microphones and their calibration files
/// Distinguishes between:
/// - "Ambi-A Mic" (Ambi-Alice microphone being calibrated)
/// - "Calibration Mic" (Reference microphone used for calibration)
/// - "Calibration Files" (Files containing calibration data for calibration mics)
final class CalibrationMicManager: ObservableObject {
    static let shared = CalibrationMicManager()
    
    @Published var popularCalibrationMics: [CalibrationMic] = []
    @Published var userCalibrationMics: [CalibrationMic] = []
    @Published var selectedCalibrationMic: CalibrationMic? = nil
    
    struct CalibrationMic: Identifiable, Codable {
        let id: String
        let name: String
        let manufacturer: String?
        let model: String?
        let calibrationFileURL: URL?
        let isBuiltIn: Bool // true for popular mics, false for user-added
        let dateAdded: Date?
        
        var displayName: String {
            if let manufacturer = manufacturer, let model = model {
                return "\(manufacturer) \(model)"
            }
            return name
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let userMicsKey = "userCalibrationMics"
    
    private init() {
        loadPopularCalibrationMics()
        loadUserCalibrationMics()
    }
    
    // Load popular calibration mics from app bundle
    private func loadPopularCalibrationMics() {
        var mics: [CalibrationMic] = []
        
        // Popular calibration microphones with their calibration files
        let popularMics: [(name: String, manufacturer: String, model: String, filename: String)] = [
            ("Behringer ECM8000", "Behringer", "ECM8000", "Behringer_ECM8000.cal"),
            ("Earthworks M30", "Earthworks", "M30", "Earthworks_M30.cal"),
            ("DPA 4006", "DPA", "4006", "DPA_4006.cal"),
            ("Neumann KM 183", "Neumann", "KM 183", "Neumann_KM183.cal"),
            ("Schoeps CMC 6", "Schoeps", "CMC 6", "Schoeps_CMC6.cal"),
            ("AKG C414", "AKG", "C414", "AKG_C414.cal"),
            ("Rode NT1", "Rode", "NT1", "Rode_NT1.cal"),
            ("Blue Yeti", "Blue", "Yeti", "Blue_Yeti.cal"),
        ]
        
        for mic in popularMics {
            // Try to find calibration file in app bundle
            var calFileURL: URL? = nil
            let resourceName = mic.filename.replacingOccurrences(of: ".cal", with: "")
            
            // Try CalibrationMics subdirectory first
            if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "cal", subdirectory: "CalibrationMics") {
                calFileURL = bundleURL
            } else if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "cal", subdirectory: "Resources/CalibrationMics") {
                calFileURL = bundleURL
            } else if let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "cal") {
                calFileURL = bundleURL
            }
            
            // Debug: Print if file not found
            if calFileURL == nil {
                print("CalibrationMicManager: Could not find calibration file for \(mic.name): \(mic.filename)")
            } else {
                print("CalibrationMicManager: Found calibration file for \(mic.name): \(calFileURL!.path)")
            }
            
            let calibrationMic = CalibrationMic(
                id: "popular_\(mic.name.replacingOccurrences(of: " ", with: "_"))",
                name: mic.name,
                manufacturer: mic.manufacturer,
                model: mic.model,
                calibrationFileURL: calFileURL,
                isBuiltIn: true,
                dateAdded: nil
            )
            mics.append(calibrationMic)
        }
        
        popularCalibrationMics = mics
    }
    
    // Load user-added calibration mics from UserDefaults
    private func loadUserCalibrationMics() {
        guard let data = userDefaults.data(forKey: userMicsKey),
              let decoded = try? JSONDecoder().decode([UserCalibrationMic].self, from: data) else {
            userCalibrationMics = []
            return
        }
        
        userCalibrationMics = decoded.map { userMic in
            CalibrationMic(
                id: userMic.id,
                name: userMic.name,
                manufacturer: userMic.manufacturer,
                model: userMic.model,
                calibrationFileURL: userMic.calibrationFileURL,
                isBuiltIn: false,
                dateAdded: userMic.dateAdded
            )
        }
    }
    
    // Save user calibration mics to UserDefaults
    private func saveUserCalibrationMics() {
        let userMics = userCalibrationMics.map { mic in
            UserCalibrationMic(
                id: mic.id,
                name: mic.name,
                manufacturer: mic.manufacturer,
                model: mic.model,
                calibrationFileURL: mic.calibrationFileURL,
                dateAdded: mic.dateAdded
            )
        }
        
        if let encoded = try? JSONEncoder().encode(userMics) {
            userDefaults.set(encoded, forKey: userMicsKey)
            userDefaults.synchronize()
        }
    }
    
    // Add a new user calibration mic
    func addUserCalibrationMic(
        name: String,
        manufacturer: String?,
        model: String?,
        calibrationFileURL: URL
    ) {
        let newMic = CalibrationMic(
            id: "user_\(UUID().uuidString)",
            name: name,
            manufacturer: manufacturer,
            model: model,
            calibrationFileURL: calibrationFileURL,
            isBuiltIn: false,
            dateAdded: Date()
        )
        
        userCalibrationMics.append(newMic)
        saveUserCalibrationMics()
    }
    
    // Remove a user calibration mic
    func removeUserCalibrationMic(_ mic: CalibrationMic) {
        guard !mic.isBuiltIn else { return }
        userCalibrationMics.removeAll { $0.id == mic.id }
        saveUserCalibrationMics()
        
        if selectedCalibrationMic?.id == mic.id {
            selectedCalibrationMic = nil
        }
    }
    
    // Get all calibration mics (popular + user)
    var allCalibrationMics: [CalibrationMic] {
        popularCalibrationMics + userCalibrationMics
    }
    
    // Get calibration file for selected mic
    func getCalibrationFile(for mic: CalibrationMic) -> URL? {
        return mic.calibrationFileURL
    }
    
    // Copy calibration file to user's calibration folder
    func saveCalibrationFileToUserFolder(_ sourceURL: URL, micName: String) throws -> URL {
        let folder = RecordingFolderManager.shared.getFolder()
        let calibrationsFolder = folder.appendingPathComponent("CalibrationMics", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: calibrationsFolder.path) {
            try FileManager.default.createDirectory(at: calibrationsFolder, withIntermediateDirectories: true)
        }
        
        let filename = "\(micName.replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970)).cal"
        let destURL = calibrationsFolder.appendingPathComponent(filename)
        
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        
        return destURL
    }
}

// Helper struct for encoding/decoding user calibration mics
private struct UserCalibrationMic: Codable {
    let id: String
    let name: String
    let manufacturer: String?
    let model: String?
    let calibrationFileURL: URL?
    let dateAdded: Date?
}

