# Xcode Project File Restoration Guide

**Date:** November 7, 2025  
**Issue:** Xcode project file (`project.pbxproj`) is corrupted and cannot be read

---

## Current Status

- **File Location:** `ios/AmbiGlass/AmbiGlass.xcodeproj/project.pbxproj`
- **Issue:** Xcode reports "The project 'AmbiGlass' is damaged and cannot be opened due to a parse error"
- **Braces:** Balanced (355 open, 355 close)
- **File Structure:** Starts correctly with `// !$*UTF8*$!`

---

## Restoration Options

### Option 1: Open in Xcode (Recommended)

Xcode can often automatically fix corrupted project files:

1. **Open Xcode**
2. **File → Open** → Navigate to `ios/AmbiGlass/AmbiGlass.xcodeproj`
3. Xcode may prompt to fix the project file automatically
4. If prompted, click "Fix" or "Repair"
5. Xcode will attempt to restore the project structure

### Option 2: Restore from Backup

If you have a backup:

1. **Time Machine:**
   ```bash
   # Navigate to the file in Time Machine
   # Restore from a previous version
   ```

2. **Git History:**
   ```bash
   # If the file was ever committed
   git log --all --full-history -- ios/AmbiGlass/AmbiGlass.xcodeproj/project.pbxproj
   git checkout <commit-hash> -- ios/AmbiGlass/AmbiGlass.xcodeproj/project.pbxproj
   ```

3. **Trash:**
   - Check `/Users/andrew/.Trash/` for any backups
   - Found: `AmbiGlass_Xcode.zip` in Trash (dated Nov 7, 01:00)

### Option 3: Recreate Project File

If restoration fails, you may need to recreate the project:

1. **Create New Xcode Project:**
   - File → New → Project
   - Choose "App" template
   - Name: AmbiGlass
   - Location: `ios/AmbiGlass/`

2. **Add Source Files:**
   - Add all files from:
     - `App/`
     - `Audio/`
     - `DSP/`
     - `Transcode/`
     - `UI/`
     - `Theme/`
     - `Resources/`
     - `Tests/`

3. **Configure Targets:**
   - Main target: AmbiGlass
   - Test target: AmbiGlassTests
   - UI test target: AmbiGlassUITests

4. **Configure Build Settings:**
   - Deployment Target: macOS 14.0+ / iOS 17.0+
   - Swift Version: 5.9
   - Frameworks: AVFoundation, Accelerate, SwiftUI, Combine

---

## What Happened

The project file was corrupted when attempting to remove references to duplicate folders ("App 2", "Audio 2", etc.) programmatically. The file structure was damaged during the automated cleanup process.

---

## Prevention

1. **Always backup project files** before making automated changes
2. **Use Xcode** for project file modifications when possible
3. **Version control** project files (though they can be large and change frequently)

---

## Next Steps

1. **Try Option 1 first** (Open in Xcode and let it fix)
2. **If that fails**, try Option 2 (Restore from backup)
3. **If both fail**, use Option 3 (Recreate project)

---

## File Status

- **Braces:** ✅ Balanced (355 = 355)
- **File Start:** ✅ Correct (`// !$*UTF8*$!`)
- **File End:** ✅ Ends with closing brace
- **Xcode Readable:** ❌ Cannot be read by Xcode

The file appears structurally correct but Xcode cannot parse it, suggesting there may be subtle syntax errors or formatting issues that need Xcode's parser to fix.

---

**Recommendation:** Open the project in Xcode and let it attempt automatic repair.

