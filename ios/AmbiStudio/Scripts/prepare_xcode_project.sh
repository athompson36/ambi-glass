#!/usr/bin/env bash
# Script to create Xcode project folder structure and organize files
# Usage: ./Scripts/prepare_xcode_project.sh [target_directory]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Target directory (default: create AmbiGlass_Xcode in parent directory)
TARGET_DIR="${1:-$(dirname "$PROJECT_ROOT")/AmbiGlass_Xcode}"

echo -e "${BLUE}🚀 AmbiGlass Xcode Project Preparation${NC}"
echo ""
echo "Source: $PROJECT_ROOT"
echo "Target: $TARGET_DIR"
echo ""

# Check if target directory exists
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}⚠️  Target directory already exists: $TARGET_DIR${NC}"
    read -p "Continue? This will overwrite existing files. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    rm -rf "$TARGET_DIR"
fi

# Create target directory
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

echo -e "${GREEN}📁 Creating folder structure...${NC}"

# Create main folder structure
mkdir -p App
mkdir -p Audio
mkdir -p DSP
mkdir -p Transcode
mkdir -p UI
mkdir -p Theme
mkdir -p Resources/Presets
mkdir -p Tests
mkdir -p Scripts
mkdir -p DOCS

echo -e "${GREEN}✅ Folder structure created${NC}"
echo ""

echo -e "${BLUE}📋 Copying files...${NC}"

# Copy App files
if [ -f "$PROJECT_ROOT/App/AmbiGlassApp.swift" ]; then
    cp "$PROJECT_ROOT/App/AmbiGlassApp.swift" App/
    echo "  ✅ App/AmbiGlassApp.swift"
fi
if [ -f "$PROJECT_ROOT/App/ContentView.swift" ]; then
    cp "$PROJECT_ROOT/App/ContentView.swift" App/
    echo "  ✅ App/ContentView.swift"
fi

# Copy Audio files
for file in "$PROJECT_ROOT/Audio"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" Audio/
        echo "  ✅ Audio/$(basename "$file")"
    fi
done

# Copy DSP files
for file in "$PROJECT_ROOT/DSP"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" DSP/
        echo "  ✅ DSP/$(basename "$file")"
    fi
done

# Copy Transcode files
for file in "$PROJECT_ROOT/Transcode"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" Transcode/
        echo "  ✅ Transcode/$(basename "$file")"
    fi
done

# Copy UI files
for file in "$PROJECT_ROOT/UI"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" UI/
        echo "  ✅ UI/$(basename "$file")"
    fi
done

# Copy Theme files
for file in "$PROJECT_ROOT/Theme"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" Theme/
        echo "  ✅ Theme/$(basename "$file")"
    fi
done

# Copy Resources
if [ -f "$PROJECT_ROOT/Resources/Presets/AmbiAlice_v1.json" ]; then
    cp "$PROJECT_ROOT/Resources/Presets/AmbiAlice_v1.json" Resources/Presets/
    echo "  ✅ Resources/Presets/AmbiAlice_v1.json"
fi

# Copy Tests
for file in "$PROJECT_ROOT/Tests"/*.swift; do
    if [ -f "$file" ]; then
        cp "$file" Tests/
        echo "  ✅ Tests/$(basename "$file")"
    fi
done

# Copy Scripts
for file in "$PROJECT_ROOT/Scripts"/*.sh; do
    if [ -f "$file" ]; then
        cp "$file" Scripts/
        chmod +x "Scripts/$(basename "$file")"
        echo "  ✅ Scripts/$(basename "$file")"
    fi
done

# Copy Documentation
for file in "$PROJECT_ROOT/DOCS"/*.md; do
    if [ -f "$file" ]; then
        cp "$file" DOCS/
        echo "  ✅ DOCS/$(basename "$file")"
    fi
done

# Copy other important files
if [ -f "$PROJECT_ROOT/README.md" ]; then
    cp "$PROJECT_ROOT/README.md" .
    echo "  ✅ README.md"
fi
if [ -f "$PROJECT_ROOT/LICENSE" ]; then
    cp "$PROJECT_ROOT/LICENSE" .
    echo "  ✅ LICENSE"
fi

echo ""
echo -e "${GREEN}✅ All files copied successfully!${NC}"
echo ""

# Create .gitignore if it doesn't exist
if [ ! -f "$TARGET_DIR/.gitignore" ]; then
    cat > "$TARGET_DIR/.gitignore" << 'EOF'
# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
*.xcworkspace/*
!*.xcworkspace/contents.xcworkspacedata
!*.xcworkspace/xcshareddata/

# Build
build/
DerivedData/
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
.swiftpm/
Package.resolved

# CocoaPods
Pods/

# macOS
.DS_Store
.AppleDouble
.LSOverride

# User-specific
*.swp
*~.nib
*.mode1v3
*.mode2v3
*.perspectivev3
*.pbxuser
*.xcuserstate
*.xcuserdatad

# App-specific
*.wav
*.aif
*.aiff
*.m4a
*.mp3
EOF
    echo -e "${GREEN}✅ Created .gitignore${NC}"
fi

# Create Xcode project structure info file
cat > "$TARGET_DIR/PROJECT_STRUCTURE.txt" << 'EOF'
AmbiGlass Xcode Project Structure
==================================

App/
├── AmbiGlassApp.swift
└── ContentView.swift

Audio/
├── AudioDeviceManager.swift
└── RecorderEngine.swift

DSP/
├── AmbisonicsDSP.swift
├── IRKit.swift
├── CalibrationKit.swift
├── MicCalLoader.swift
└── Profiles.swift

Transcode/
└── Transcoder.swift

UI/
├── RecordView.swift
├── MeasureIRView.swift
├── BatchTranscodeView.swift
├── CalibrationView.swift
├── SettingsView.swift
└── CalibrationCurveView.swift

Theme/
├── LiquidGlassTheme.swift
└── ThemeManager.swift

Resources/
└── Presets/
    └── AmbiAlice_v1.json

Tests/
├── AmbisonicsDSPTests.swift
├── IRDeconvolutionTests.swift
├── CalibrationTests.swift
├── CalibrationCurveTest.swift
└── TestRunner.swift

Scripts/
├── build.sh
├── format.sh
├── test.sh
└── setup_xcode.sh

DOCS/
├── XCODE_SETUP.md
├── ARCHITECTURE.md
├── DSP_NOTES.md
├── IR_GUIDE.md
├── FORMATS.md
├── CALIBRATION.md
├── MIC_PROFILES.md
├── UI_GUIDE.md
└── TEST_PLAN.md
EOF

echo ""
echo -e "${GREEN}📊 Project Summary:${NC}"
echo ""
echo "Total files:"
echo "  App: $(find App -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "  Audio: $(find Audio -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "  DSP: $(find DSP -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "  Transcode: $(find Transcode -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "  UI: $(find UI -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "  Theme: $(find Theme -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "  Tests: $(find Tests -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "  Resources: $(find Resources -name "*.json" 2>/dev/null | wc -l | tr -d ' ') files"
echo ""

echo -e "${GREEN}✅ Project preparation complete!${NC}"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "  1. Open Xcode"
echo "  2. Create new Multiplatform App project named 'AmbiGlass'"
echo "  3. Save it in: $TARGET_DIR"
echo "  4. Follow DOCS/XCODE_SETUP.md to add files to the project"
echo ""
echo -e "${YELLOW}💡 Tip: You can also create the Xcode project in a subdirectory:${NC}"
echo "  cd $TARGET_DIR"
echo "  # Then create Xcode project here"
echo ""

