#!/usr/bin/env bash
# Script to help add Watch Remote Addon files to Xcode project
# This script verifies files exist and provides instructions

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT="${PROJECT_ROOT}/ios/AmbiStudio/AmbiStudio.xcodeproj"

echo -e "${BLUE}📱 Watch Remote Addon - Xcode Integration Helper${NC}"
echo ""

# Check if Xcode project exists
if [ ! -d "$XCODE_PROJECT" ]; then
    echo -e "${YELLOW}⚠️  Xcode project not found at: $XCODE_PROJECT${NC}"
    echo "Please ensure the Xcode project exists before running this script."
    exit 1
fi

echo -e "${GREEN}✅ Xcode project found${NC}"
echo ""

# Verify files exist
echo -e "${BLUE}📋 Verifying files...${NC}"

FILES_TO_ADD=(
    "SharedRemote/RemoteProtocol.swift"
    "SharedRemote/LANListener.swift"
    "iOS-Relay/PhoneRelay.swift"
    "watchOS-App/WatchRemote.swift"
    "watchOS-App/WatchTransportView.swift"
    "watchOS-App/AmbiGlassWatchApp.swift"
)

MISSING_FILES=()

for file in "${FILES_TO_ADD[@]}"; do
    full_path="${PROJECT_ROOT}/${file}"
    if [ -f "$full_path" ]; then
        echo -e "  ${GREEN}✅${NC} $file"
    else
        echo -e "  ${YELLOW}⚠️${NC} $file (not found)"
        MISSING_FILES+=("$file")
    fi
done

echo ""

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some files are missing. Please ensure all files are in place.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All files verified${NC}"
echo ""

# Generate instructions
cat << 'EOF'
📝 MANUAL XCODE INTEGRATION STEPS
==================================

Follow these steps to add the Watch Remote Addon files to your Xcode project:

STEP 1: Open Xcode Project
---------------------------
1. Open: ios/AmbiStudio/AmbiStudio.xcodeproj

STEP 2: Create Folder Groups (if they don't exist)
---------------------------------------------------
In Xcode Project Navigator, create these groups:
- SharedRemote
- iOS-Relay  
- watchOS-App

STEP 3: Add SharedRemote Files (ALL TARGETS)
---------------------------------------------
1. Right-click "SharedRemote" group → Add Files to "AmbiStudio"...
2. Navigate to: [PROJECT_ROOT]/SharedRemote/
3. Select BOTH files:
   - RemoteProtocol.swift
   - LANListener.swift
4. IMPORTANT: Check these options:
   ✅ "Copy items if needed" (if files aren't already in project directory)
   ✅ "Create groups" (not folder references)
   ✅ TARGET MEMBERSHIP - Check ALL targets:
      ✅ AmbiStudio (iPhone)
      ✅ AmbiStudio (iPad) 
      ✅ AmbiStudio (Mac)
      ✅ AmbiGlassWatch (watchOS) - if exists
5. Click "Add"

STEP 4: Add iOS-Relay Files (iPhone TARGET ONLY)
--------------------------------------------------
1. Right-click "iOS-Relay" group → Add Files to "AmbiStudio"...
2. Navigate to: [PROJECT_ROOT]/iOS-Relay/
3. Select:
   - PhoneRelay.swift
4. IMPORTANT: Check these options:
   ✅ "Copy items if needed"
   ✅ "Create groups"
   ✅ TARGET MEMBERSHIP - Check ONLY:
      ✅ AmbiStudio (iPhone) ONLY
      ❌ Do NOT check iPad, Mac, or watchOS
5. Click "Add"

STEP 5: Add watchOS-App Files (watchOS TARGET ONLY)
----------------------------------------------------
1. First, ensure you have a watchOS app target:
   - If not, create one: File → New → Target → watchOS → App
   - Name it: "AmbiGlassWatch"
   - Set AmbiGlassWatchApp.swift as the entry point

2. Right-click "watchOS-App" group → Add Files to "AmbiStudio"...
3. Navigate to: [PROJECT_ROOT]/watchOS-App/
4. Select ALL THREE files:
   - WatchRemote.swift
   - WatchTransportView.swift
   - AmbiGlassWatchApp.swift
5. IMPORTANT: Check these options:
   ✅ "Copy items if needed"
   ✅ "Create groups"
   ✅ TARGET MEMBERSHIP - Check ONLY:
      ✅ AmbiGlassWatch (watchOS) ONLY
      ❌ Do NOT check iPhone, iPad, or Mac
6. Click "Add"

STEP 6: Verify Target Memberships
----------------------------------
For each file, verify target membership:

SharedRemote/RemoteProtocol.swift:
  ✅ AmbiStudio (iPhone)
  ✅ AmbiStudio (iPad)
  ✅ AmbiStudio (Mac)
  ✅ AmbiGlassWatch (watchOS)

SharedRemote/LANListener.swift:
  ✅ AmbiStudio (iPhone)
  ✅ AmbiStudio (iPad)
  ✅ AmbiStudio (Mac)
  ✅ AmbiGlassWatch (watchOS)

iOS-Relay/PhoneRelay.swift:
  ✅ AmbiStudio (iPhone) ONLY
  ❌ No other targets

watchOS-App/WatchRemote.swift:
  ✅ AmbiGlassWatch (watchOS) ONLY
  ❌ No other targets

watchOS-App/WatchTransportView.swift:
  ✅ AmbiGlassWatch (watchOS) ONLY
  ❌ No other targets

watchOS-App/AmbiGlassWatchApp.swift:
  ✅ AmbiGlassWatch (watchOS) ONLY
  ❌ No other targets

STEP 7: Add Required Frameworks
--------------------------------
For iPhone target (AmbiStudio):
1. Select project → Target "AmbiStudio" → General tab
2. Scroll to "Frameworks, Libraries, and Embedded Content"
3. Add if not present:
   - WatchConnectivity.framework
   - Network.framework

For watchOS target (AmbiGlassWatch):
1. Select project → Target "AmbiGlassWatch" → General tab
2. Scroll to "Frameworks, Libraries, and Embedded Content"
3. Add if not present:
   - WatchConnectivity.framework

STEP 8: Configure Info.plist
------------------------------
For iPhone target:
1. Select project → Target "AmbiStudio" → Info tab
2. Add key: "Privacy - Local Network Usage Description"
   Value: "AmbiGlass needs network access to relay remote control commands from your Apple Watch to your iPad or Mac."

STEP 9: Build and Test
----------------------
1. Build iPhone target: Product → Build (⌘B)
2. Build watchOS target: Select "AmbiGlassWatch" scheme → Build
3. Verify no compilation errors
4. Run on device/simulator to test

TROUBLESHOOTING
---------------
- If files show errors: Check target membership
- If WatchConnectivity errors: Add framework to target
- If network errors: Check Info.plist entry
- If build fails: Clean build folder (⇧⌘K) and rebuild

EOF

echo ""
echo -e "${GREEN}✅ Instructions generated above${NC}"
echo ""
echo -e "${BLUE}💡 Tip: You can also add files by dragging them from Finder into Xcode${NC}"
echo "   Just make sure to check the correct target memberships!"

