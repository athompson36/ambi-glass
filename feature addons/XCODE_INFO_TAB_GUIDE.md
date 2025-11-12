# How to Find the Target's Info Tab in Xcode

**Quick Guide:** Accessing Info.plist settings in Xcode

---

## Step-by-Step Instructions

### Method 1: Using the Project Navigator (Recommended)

1. **Open Xcode**
   - Open: `ios/AmbiStudio/AmbiStudio.xcodeproj`

2. **Select the Project**
   - In the **Project Navigator** (left sidebar), click on the **blue project icon** at the very top
   - It should say "AmbiStudio" (the project name)

3. **Select the Target**
   - In the main editor area, you'll see **TARGETS** section
   - Click on **"AmbiStudio"** (the app target, not the project)

4. **Open the Info Tab**
   - At the top of the editor, you'll see tabs: **General**, **Signing & Capabilities**, **Resource Tags**, **Info**, **Build Settings**, **Build Phases**, **Build Rules**
   - Click on the **"Info"** tab

5. **View Info.plist Entries**
   - You'll see a table with **Key** and **Value** columns
   - Look for **"Privacy - Local Network Usage Description"** or **"NSLocalNetworkUsageDescription"**
   - The value should be: `"AmbiGlass needs network access to relay remote control commands from your Apple Watch to your iPad or Mac."`

---

## Method 2: Using the Search Bar

1. **Open Xcode** and select the project
2. **Select the Target** "AmbiStudio"
3. **Press ⌘F** (or Edit → Find → Find)
4. **Search for:** `NSLocalNetworkUsageDescription` or `Local Network`
5. The search will highlight the entry if it exists

---

## Visual Guide

```
Xcode Window Layout:
┌─────────────────────────────────────────┐
│ Project Navigator (Left Sidebar)       │
│ ┌───────────────────────────────────┐ │
│ │ 📁 AmbiStudio (blue icon) ← Click  │ │
│ │   ├─ 📁 AmbiStudio                 │ │
│ │   ├─ 📁 SharedRemote               │ │
│ │   └─ ...                           │ │
│ └───────────────────────────────────┘ │
│                                         │
│ Main Editor Area                        │
│ ┌───────────────────────────────────┐ │
│ │ PROJECT: AmbiStudio                │ │
│ │                                     │ │
│ │ TARGETS:                            │ │
│ │ ┌───────────────────────────────┐ │ │
│ │ │ AmbiStudio ← Click this        │ │ │
│ │ └───────────────────────────────┘ │ │
│ │                                     │ │
│ │ [General] [Signing] [Info] ← Click │ │
│ │                                     │ │
│ │ Info Tab Content:                  │ │
│ │ Key                    Value        │ │
│ │ ────────────────────────────────── │ │
│ │ Local Network Usage... "AmbiGlass..."│ │
│ └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

---

## What You Should See

In the **Info** tab, you should see entries like:

| Key | Type | Value |
|-----|------|-------|
| Privacy - Local Network Usage Description | String | AmbiGlass needs network access to relay remote control commands from your Apple Watch to your iPad or Mac. |
| Application Category | String | public.app-category.music |
| ... (other entries) | ... | ... |

---

## Alternative: Check Build Settings

If you don't see it in the Info tab, you can also check Build Settings:

1. **Select Target** "AmbiStudio"
2. **Click "Build Settings"** tab
3. **Search for:** `INFOPLIST_KEY_NSLocalNetworkUsageDescription`
4. You should see the value we added

---

## Troubleshooting

### Can't Find the Info Tab?

- Make sure you selected the **TARGET** (AmbiStudio), not the **PROJECT** (AmbiStudio at the top)
- The Info tab only appears when a target is selected
- If using Xcode 15+, the Info tab might be under "Build Settings" → "Info.plist Values"

### Entry Not Showing?

- The entry was added as `INFOPLIST_KEY_NSLocalNetworkUsageDescription` in build settings
- Xcode will generate it in the Info.plist at build time
- You can verify it exists by searching in Build Settings

### Using Xcode 15+ (New Format)?

In newer Xcode versions, Info.plist entries might be shown differently:
1. Select Target → **Build Settings**
2. Search for: `INFOPLIST`
3. Look for `INFOPLIST_KEY_NSLocalNetworkUsageDescription`

---

## Quick Verification Command

You can also verify from the command line:

```bash
cd ios/AmbiStudio
grep -A 1 "INFOPLIST_KEY_NSLocalNetworkUsageDescription" AmbiStudio.xcodeproj/project.pbxproj
```

This will show the entry we added.

---

**Location Summary:**
- **Project Navigator** → Click blue project icon
- **Main Editor** → Click "AmbiStudio" target
- **Tabs** → Click "Info" tab
- **Look for:** "Privacy - Local Network Usage Description"

