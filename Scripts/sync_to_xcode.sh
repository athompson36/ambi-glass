#!/usr/bin/env bash
# Sync source files from AmbiGlass_Xcode to the actual Xcode project
# Usage: ./Scripts/sync_to_xcode.sh [path_to_xcode_project]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
XCODE_PROJ="${1:-/Users/andrew/Documents/FS-Tech/mvi-app/mvi-app/ios/AmbiGlass}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 Syncing Source Files to Xcode Project${NC}"
echo ""
echo "Source: $SOURCE_DIR"
echo "Target: $XCODE_PROJ"
echo ""

if [ ! -d "$XCODE_PROJ" ]; then
    echo -e "${RED}❌ Xcode project directory not found: $XCODE_PROJ${NC}"
    exit 1
fi

# Create directory structure in Xcode project
echo -e "${BLUE}📁 Creating directory structure...${NC}"
mkdir -p "$XCODE_PROJ/App"
mkdir -p "$XCODE_PROJ/Audio"
mkdir -p "$XCODE_PROJ/DSP"
mkdir -p "$XCODE_PROJ/Transcode"
mkdir -p "$XCODE_PROJ/UI"
mkdir -p "$XCODE_PROJ/Theme"
mkdir -p "$XCODE_PROJ/Resources/Presets"
mkdir -p "$XCODE_PROJ/Tests"

# Copy source files
echo -e "${BLUE}📋 Copying source files...${NC}"

# Copy App files
if [ -f "$SOURCE_DIR/App/AmbiGlassApp.swift" ]; then
    cp "$SOURCE_DIR/App/AmbiGlassApp.swift" "$XCODE_PROJ/App/"
    echo -e "  ${GREEN}✅${NC} App/AmbiGlassApp.swift"
fi
if [ -f "$SOURCE_DIR/App/ContentView.swift" ]; then
    cp "$SOURCE_DIR/App/ContentView.swift" "$XCODE_PROJ/App/"
    echo -e "  ${GREEN}✅${NC} App/ContentView.swift"
fi

# Copy Audio files
for file in "$SOURCE_DIR/Audio"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" "$XCODE_PROJ/Audio/"
        echo -e "  ${GREEN}✅${NC} Audio/$(basename "$file")"
    fi
done

# Copy DSP files
for file in "$SOURCE_DIR/DSP"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" "$XCODE_PROJ/DSP/"
        echo -e "  ${GREEN}✅${NC} DSP/$(basename "$file")"
    fi
done

# Copy Transcode files
for file in "$SOURCE_DIR/Transcode"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" "$XCODE_PROJ/Transcode/"
        echo -e "  ${GREEN}✅${NC} Transcode/$(basename "$file")"
    fi
done

# Copy UI files
for file in "$SOURCE_DIR/UI"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" "$XCODE_PROJ/UI/"
        echo -e "  ${GREEN}✅${NC} UI/$(basename "$file")"
    fi
done

# Copy Theme files
for file in "$SOURCE_DIR/Theme"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" "$XCODE_PROJ/Theme/"
        echo -e "  ${GREEN}✅${NC} Theme/$(basename "$file")"
    fi
done

# Copy Resources
if [ -f "$SOURCE_DIR/Resources/Presets/AmbiAlice_v1.json" ]; then
    cp "$SOURCE_DIR/Resources/Presets/AmbiAlice_v1.json" "$XCODE_PROJ/Resources/Presets/"
    echo -e "  ${GREEN}✅${NC} Resources/Presets/AmbiAlice_v1.json"
fi

# Copy Test files
for file in "$SOURCE_DIR/Tests"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" "$XCODE_PROJ/Tests/"
        echo -e "  ${GREEN}✅${NC} Tests/$(basename "$file")"
    fi
done

echo ""
echo -e "${GREEN}✅ Files synced successfully!${NC}"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "  1. Open Xcode project: open $XCODE_PROJ/AmbiGlass.xcodeproj"
echo "  2. Add files to project (if not already added):"
echo "     - Right-click project → Add Files to AmbiGlass..."
echo "     - Select all folders (App, Audio, DSP, etc.)"
echo "     - Check 'Copy items if needed' (if needed)"
echo "     - Check target membership for each file"
echo "  3. Rebuild: ⌘B"
echo "  4. Run: ⌘R"

