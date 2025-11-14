import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

final class ProjectManager: ObservableObject {
    static let shared = ProjectManager()
    
    @Published var projectName: String = ""
    @Published var projectNotes: String = ""
    @Published var projectFolder: URL? = nil
    @Published var folderName: String = "Not Set"
    
    private let userDefaults = UserDefaults.standard
    private let projectNameKey = "currentProjectName"
    private let projectNotesKey = "currentProjectNotes"
    private let projectFolderKey = "currentProjectFolder"
    
    private init() {
        loadProject()
    }
    
    #if os(macOS)
    func selectFolderWithNSOpenPanel() {
        // Use NSOpenPanel to properly request file system access on macOS
        let panel = NSOpenPanel()
        panel.title = "Select Project Folder"
        panel.message = "Choose a folder for your project. You'll be prompted to grant access."
        panel.prompt = "Select"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // NSOpenPanel automatically grants security-scoped access
                Task.detached {
                    await self.setProjectFolder(url)
                    // Verify access was granted
                    let hasAccess = await self.checkWritePermissions()
                    await MainActor.run {
                        if hasAccess {
                            print("✅ Folder access granted: \(url.lastPathComponent)")
                        } else {
                            print("⚠️ Folder selected but write access not available. Try selecting a different folder.")
                        }
                    }
                }
            }
        }
    }
    #endif
    
    func setProjectFolder(_ url: URL) async {
        // When called from NSOpenPanel or fileImporter, the URL has security-scoped access
        // We need to create a bookmark to persist access
        
        #if os(macOS)
        // Start accessing the security-scoped resource (NSOpenPanel grants this automatically)
        let hasAccess = url.startAccessingSecurityScopedResource()
        if !hasAccess {
            print("⚠️ Warning: Could not start accessing security-scoped resource for: \(url.path)")
        }
        
        // Store bookmark for persistent access (macOS security-scoped)
        // This bookmark will allow us to access the folder in future app launches
        if let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: [.isDirectoryKey, .isWritableKey],
            relativeTo: nil
        ) {
            await MainActor.run {
                self.userDefaults.set(bookmark, forKey: self.projectFolderKey)
                self.projectFolder = url
                self.folderName = url.lastPathComponent
            }
            self.userDefaults.synchronize()
            print("✅ Security-scoped bookmark saved for: \(url.lastPathComponent)")
        } else {
            print("❌ Failed to create security-scoped bookmark for: \(url.path)")
        }
        #else
        // iOS: Store bookmark without security scope
        if let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            await MainActor.run {
                self.userDefaults.set(bookmark, forKey: self.projectFolderKey)
                self.projectFolder = url
                self.folderName = url.lastPathComponent
            }
            self.userDefaults.synchronize()
        }
        #endif
    }
    
    func getProjectFolder() -> URL {
        if let folder = projectFolder {
            // Ensure we have access (macOS security-scoped)
            #if os(macOS)
            _ = folder.startAccessingSecurityScopedResource()
            #endif
            return folder
        }
        
        // Try to restore from bookmark
        if let bookmarkData = userDefaults.data(forKey: projectFolderKey) {
            var isStale = false
            #if os(macOS)
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                let hasAccess = url.startAccessingSecurityScopedResource()
                if hasAccess {
                    projectFolder = url
                    folderName = url.lastPathComponent
                    // Note: Folder structure will be created when Save button is pressed
                    return url
                } else {
                    print("⚠️ Security-scoped bookmark is stale or invalid. Please re-select folder.")
                }
            }
            #else
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                projectFolder = url
                folderName = url.lastPathComponent
                // Note: Folder structure will be created when Save button is pressed
                return url
            }
            #endif
        }
        
        // Fallback to Documents directory (this won't have security-scoped access, so user must select a folder)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let defaultFolder = documentsURL.appendingPathComponent("AmbiStudio Projects", isDirectory: true)
        
        // Create directory if it doesn't exist (async)
        Task.detached {
            if !FileManager.default.fileExists(atPath: defaultFolder.path) {
                try? FileManager.default.createDirectory(at: defaultFolder, withIntermediateDirectories: true)
            }
        }
        
        projectFolder = defaultFolder
        folderName = defaultFolder.lastPathComponent
        // Note: Folder structure will be created when Save button is pressed
        // Note: This default folder may not have write permissions - user should select a folder via Browse
        return defaultFolder
    }
    
    func getRecordingsFolder() -> URL {
        let base = getProjectFolder()
        return base.appendingPathComponent("Recording", isDirectory: true)
    }
    
    func getIRsFolder() -> URL {
        let base = getProjectFolder()
        return base.appendingPathComponent("IR", isDirectory: true)
    }
    
    func getTranscodedFolder() -> URL {
        let base = getProjectFolder()
        return base.appendingPathComponent("Transcode", isDirectory: true)
    }
    
    func getCalibrationFolder() -> URL {
        let base = getProjectFolder()
        return base.appendingPathComponent("Calibration", isDirectory: true)
    }
    
    func getSettingsFolder() -> URL {
        let base = getProjectFolder()
        return base.appendingPathComponent("Settings", isDirectory: true)
    }
    
    func checkWritePermissions() async -> Bool {
        let base = await MainActor.run { self.projectFolder }
        guard let base = base else {
            return false
        }
        
        // Ensure we have access to the folder (macOS security-scoped)
        #if os(macOS)
        let hasAccess = base.startAccessingSecurityScopedResource()
        if !hasAccess {
            print("⚠️ Cannot access security-scoped resource for: \(base.path)")
        }
        #endif
        
        // Check if we can write to the folder
        return await Task.detached {
            let fm = FileManager.default
            let folderPath = base.path
            
            // Check if folder exists
            guard fm.fileExists(atPath: folderPath) else {
                print("❌ Folder does not exist: \(folderPath)")
                return false
            }
            
            // Check if folder is writable
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: folderPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                print("❌ Path is not a directory: \(folderPath)")
                return false
            }
            
            // Try to create a test file to verify write permissions
            let testFile = base.appendingPathComponent(".write_test_\(UUID().uuidString)")
            do {
                try "test".write(to: testFile, atomically: true, encoding: .utf8)
                try? fm.removeItem(at: testFile)
                print("✅ Write permissions verified for: \(folderPath)")
                return true
            } catch {
                print("❌ No write permissions for: \(folderPath)")
                print("   Error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Error domain: \(nsError.domain), code: \(nsError.code)")
                }
                return false
            }
        }.value
    }
    
    func createProjectStructure() async {
        let base = await MainActor.run { self.projectFolder }
        guard let base = base else {
            await MainActor.run {
                print("❌ Cannot create folder structure: no project folder selected")
            }
            return
        }
        
        // Ensure we have access to the folder (macOS security-scoped)
        #if os(macOS)
        let hasAccess = base.startAccessingSecurityScopedResource()
        if !hasAccess {
            print("⚠️ Cannot access security-scoped resource. Please re-select the folder using Browse.")
            return
        }
        
        // Keep the resource alive for the duration of folder creation
        defer {
            base.stopAccessingSecurityScopedResource()
        }
        #endif
        
        let folders = [
            base.appendingPathComponent("Recording", isDirectory: true),
            base.appendingPathComponent("IR", isDirectory: true),
            base.appendingPathComponent("Transcode", isDirectory: true),
            base.appendingPathComponent("Calibration", isDirectory: true),
            base.appendingPathComponent("Settings", isDirectory: true)
        ]
        
        // Create directories synchronously to ensure security-scoped access is maintained
        var createdCount = 0
        var errorCount = 0
        for folder in folders {
            let folderPath = folder.path
            if !FileManager.default.fileExists(atPath: folderPath) {
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    createdCount += 1
                    print("✅ Created folder: \(folder.lastPathComponent) at \(folderPath)")
                } catch {
                    errorCount += 1
                    print("❌ Failed to create folder \(folder.lastPathComponent): \(error.localizedDescription)")
                    print("   Path: \(folderPath)")
                    if let nsError = error as NSError? {
                        print("   Error domain: \(nsError.domain), code: \(nsError.code)")
                        if nsError.code == 513 {
                            print("   💡 Tip: This folder may require security-scoped access. Try re-selecting it using Browse.")
                        }
                    }
                }
            } else {
                print("ℹ️ Folder already exists: \(folder.lastPathComponent)")
            }
        }
        if createdCount > 0 {
            print("✅ Created \(createdCount) new folder(s) in project structure")
        }
        if errorCount > 0 {
            print("❌ Failed to create \(errorCount) folder(s). Check file permissions.")
        }
    }
    
    func saveProjectInfo() {
        // Save to UserDefaults immediately (lightweight)
        userDefaults.set(projectName, forKey: projectNameKey)
        userDefaults.set(projectNotes, forKey: projectNotesKey)
        
        // Save to file on background thread to avoid blocking
        Task.detached { [weak self] in
            guard let self else { return }
            self.userDefaults.synchronize()
            
            // Also save to project folder as JSON
            let folder = await MainActor.run { self.projectFolder }
            let projectName = await MainActor.run { self.projectName }
            let projectNotes = await MainActor.run { self.projectNotes }
            
            if let folder = folder {
                let infoFile = folder.appendingPathComponent("project_info.json")
                let info: [String: String] = [
                    "name": projectName,
                    "notes": projectNotes,
                    "created": ISO8601DateFormatter().string(from: Date())
                ]
                if let data = try? JSONSerialization.data(withJSONObject: info, options: .prettyPrinted) {
                    try? data.write(to: infoFile)
                }
            }
        }
    }
    
    private func loadProject() {
        // Load project name and notes
        projectName = userDefaults.string(forKey: projectNameKey) ?? ""
        projectNotes = userDefaults.string(forKey: projectNotesKey) ?? ""
        
        // Load project folder
        if let bookmarkData = userDefaults.data(forKey: projectFolderKey) {
            var isStale = false
            #if os(macOS)
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                projectFolder = url
                folderName = url.lastPathComponent
                // Note: Folder structure will be created when Save button is pressed
                return
            }
            #else
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                projectFolder = url
                folderName = url.lastPathComponent
                // Note: Folder structure will be created when Save button is pressed
                return
            }
            #endif
        }
        
        // Fallback to default folder
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let defaultFolder = documentsURL.appendingPathComponent("AmbiStudio Projects", isDirectory: true)
        
        // Create directory async
        Task.detached {
            if !FileManager.default.fileExists(atPath: defaultFolder.path) {
                try? FileManager.default.createDirectory(at: defaultFolder, withIntermediateDirectories: true)
            }
        }
        
        projectFolder = defaultFolder
        folderName = defaultFolder.lastPathComponent
        // Note: Folder structure will be created when Save button is pressed
    }
}

