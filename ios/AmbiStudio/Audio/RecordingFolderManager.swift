import Foundation
import Combine

final class RecordingFolderManager: ObservableObject {
    static let shared = RecordingFolderManager()
    
    @Published var recordingFolder: URL? = nil
    @Published var folderName: String = "Not Set"
    
    private let userDefaults = UserDefaults.standard
    private let folderKey = "recordingFolderPath"
    
    private init() {
        loadFolder()
    }
    
    func setFolder(_ url: URL) {
        // Request access to the folder
        _ = url.startAccessingSecurityScopedResource()
        
        // Store bookmark for persistent access
        if let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            userDefaults.set(bookmark, forKey: folderKey)
            recordingFolder = url
            folderName = url.lastPathComponent
            userDefaults.synchronize()
        }
    }
    
    func getFolder() -> URL {
        if let folder = recordingFolder {
            return folder
        }
        
        // Try to restore from bookmark
        if let bookmarkData = userDefaults.data(forKey: folderKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                recordingFolder = url
                folderName = url.lastPathComponent
                return url
            }
        }
        
        // Fallback to Documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let defaultFolder = documentsURL.appendingPathComponent("AmbiStudio Recordings", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: defaultFolder.path) {
            try? FileManager.default.createDirectory(at: defaultFolder, withIntermediateDirectories: true)
        }
        
        recordingFolder = defaultFolder
        folderName = defaultFolder.lastPathComponent
        return defaultFolder
    }
    
    private func loadFolder() {
        if let bookmarkData = userDefaults.data(forKey: folderKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                recordingFolder = url
                folderName = url.lastPathComponent
                return
            }
        }
        
        // Fallback to default folder
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let defaultFolder = documentsURL.appendingPathComponent("AmbiStudio Recordings", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: defaultFolder.path) {
            try? FileManager.default.createDirectory(at: defaultFolder, withIntermediateDirectories: true)
        }
        
        recordingFolder = defaultFolder
        folderName = defaultFolder.lastPathComponent
    }
    
    func clearFolder() {
        userDefaults.removeObject(forKey: folderKey)
        recordingFolder = nil
        folderName = "Not Set"
        
        // Reset to default
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let defaultFolder = documentsURL.appendingPathComponent("AmbiStudio Recordings", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: defaultFolder.path) {
            try? FileManager.default.createDirectory(at: defaultFolder, withIntermediateDirectories: true)
        }
        
        recordingFolder = defaultFolder
        folderName = defaultFolder.lastPathComponent
    }
}

