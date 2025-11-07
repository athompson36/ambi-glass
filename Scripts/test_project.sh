#!/usr/bin/env bash
# Comprehensive test script for AmbiGlass Xcode project
# Tests code structure, dependencies, and prepares for Xcode testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 AmbiGlass Project Testing${NC}"
echo ""

cd "$PROJECT_ROOT"

# Test 1: Check file structure
echo -e "${BLUE}📁 Test 1: File Structure${NC}"
missing=0
required_dirs=("App" "Audio" "DSP" "Transcode" "UI" "Theme" "Resources" "Tests")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✅${NC} $dir/"
    else
        echo -e "  ${RED}❌${NC} $dir/ (MISSING)"
        missing=$((missing + 1))
    fi
done

if [ $missing -eq 0 ]; then
    echo -e "${GREEN}✅ All directories present${NC}"
else
    echo -e "${RED}❌ Missing $missing directories${NC}"
fi
echo ""

# Test 2: Check required Swift files
echo -e "${BLUE}📄 Test 2: Required Swift Files${NC}"
missing=0
required_files=(
    "App/AmbiGlassApp.swift"
    "App/ContentView.swift"
    "Audio/AudioDeviceManager.swift"
    "Audio/RecorderEngine.swift"
    "DSP/AmbisonicsDSP.swift"
    "DSP/IRKit.swift"
    "DSP/CalibrationKit.swift"
    "DSP/MicCalLoader.swift"
    "DSP/Profiles.swift"
    "Transcode/Transcoder.swift"
    "UI/RecordView.swift"
    "UI/MeasureIRView.swift"
    "UI/BatchTranscodeView.swift"
    "UI/CalibrationView.swift"
    "UI/SettingsView.swift"
    "UI/CalibrationCurveView.swift"
    "Theme/LiquidGlassTheme.swift"
    "Theme/ThemeManager.swift"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file" | tr -d ' ')
        echo -e "  ${GREEN}✅${NC} $file ($lines lines)"
    else
        echo -e "  ${RED}❌${NC} $file (MISSING)"
        missing=$((missing + 1))
    fi
done

if [ $missing -eq 0 ]; then
    echo -e "${GREEN}✅ All required files present${NC}"
else
    echo -e "${RED}❌ Missing $missing files${NC}"
fi
echo ""

# Test 3: Check imports and dependencies
echo -e "${BLUE}🔍 Test 3: Import Dependencies${NC}"
imports_ok=true

# Check for AVFoundation usage
if grep -r "import AVFoundation" App/ Audio/ DSP/ Transcode/ UI/ 2>/dev/null | grep -q .; then
    echo -e "  ${GREEN}✅${NC} AVFoundation imports found"
else
    echo -e "  ${YELLOW}⚠️${NC}  AVFoundation imports not found (may be needed)"
fi

# Check for Accelerate usage
if grep -r "import Accelerate" DSP/ Transcode/ 2>/dev/null | grep -q .; then
    echo -e "  ${GREEN}✅${NC} Accelerate imports found"
else
    echo -e "  ${YELLOW}⚠️${NC}  Accelerate imports not found (may be needed)"
fi

# Check for SwiftUI usage
if grep -r "import SwiftUI" App/ UI/ Theme/ 2>/dev/null | grep -q .; then
    echo -e "  ${GREEN}✅${NC} SwiftUI imports found"
else
    echo -e "  ${RED}❌${NC} SwiftUI imports not found"
    imports_ok=false
fi

# Check for Combine usage
if grep -r "import Combine" Audio/ 2>/dev/null | grep -q .; then
    echo -e "  ${GREEN}✅${NC} Combine imports found"
else
    echo -e "  ${YELLOW}⚠️${NC}  Combine imports not found (may be needed)"
fi

if [ "$imports_ok" = true ]; then
    echo -e "${GREEN}✅ Import dependencies look good${NC}"
else
    echo -e "${YELLOW}⚠️  Some imports may be missing${NC}"
fi
echo ""

# Test 4: Check for syntax errors (basic)
echo -e "${BLUE}🔤 Test 4: Basic Syntax Check${NC}"
syntax_errors=0

# Check for common Swift syntax issues
for file in $(find App Audio DSP Transcode UI Theme -name "*.swift" 2>/dev/null); do
    # Check for unclosed braces (basic check)
    open_braces=$(grep -o '{' "$file" 2>/dev/null | wc -l | tr -d ' ')
    close_braces=$(grep -o '}' "$file" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$open_braces" != "$close_braces" ]; then
        echo -e "  ${YELLOW}⚠️${NC}  $file: Possible brace mismatch"
        syntax_errors=$((syntax_errors + 1))
    fi
done

if [ $syntax_errors -eq 0 ]; then
    echo -e "${GREEN}✅ No obvious syntax errors detected${NC}"
else
    echo -e "${YELLOW}⚠️  Found $syntax_errors potential issues${NC}"
fi
echo ""

# Test 5: Check resources
echo -e "${BLUE}📦 Test 5: Resources${NC}"
if [ -f "Resources/Presets/AmbiAlice_v1.json" ]; then
    echo -e "  ${GREEN}✅${NC} Resources/Presets/AmbiAlice_v1.json"
    # Check if JSON is valid
    if python3 -m json.tool "Resources/Presets/AmbiAlice_v1.json" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} JSON is valid"
    else
        echo -e "  ${YELLOW}⚠️${NC}  JSON may be invalid"
    fi
else
    echo -e "  ${RED}❌${NC} Resources/Presets/AmbiAlice_v1.json (MISSING)"
fi
echo ""

# Test 6: Check test files
echo -e "${BLUE}🧪 Test 6: Test Files${NC}"
test_files=$(find Tests -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$test_files" -gt 0 ]; then
    echo -e "  ${GREEN}✅${NC} Found $test_files test files"
    for test_file in Tests/*.swift; do
        if [ -f "$test_file" ]; then
            echo -e "    - $(basename "$test_file")"
        fi
    done
else
    echo -e "  ${YELLOW}⚠️${NC}  No test files found"
fi
echo ""

# Test 7: Check for Xcode project
echo -e "${BLUE}📱 Test 7: Xcode Project${NC}"
if find . -name "*.xcodeproj" -o -name "*.xcworkspace" 2>/dev/null | grep -q .; then
    xcode_proj=$(find . -name "*.xcodeproj" -o -name "*.xcworkspace" 2>/dev/null | head -1)
    echo -e "  ${GREEN}✅${NC} Xcode project found: $xcode_proj"
    
    # Try to build if xcodebuild is available
    if command -v xcodebuild &> /dev/null; then
        echo -e "${BLUE}🔨 Attempting build...${NC}"
        if xcodebuild -project "$xcode_proj" -scheme AmbiGlass -configuration Debug clean build 2>&1 | tail -20; then
            echo -e "${GREEN}✅ Build successful!${NC}"
        else
            echo -e "${YELLOW}⚠️  Build had issues (check output above)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️${NC}  xcodebuild not found, cannot test build"
    fi
else
    echo -e "  ${YELLOW}⚠️${NC}  No Xcode project found"
    echo -e "  ${BLUE}💡${NC}  Create Xcode project following DOCS/XCODE_SETUP.md"
fi
echo ""

# Summary
echo -e "${BLUE}📊 Test Summary${NC}"
echo ""
total_files=$(find App Audio DSP Transcode UI Theme -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
total_lines=$(find App Audio DSP Transcode UI Theme -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
echo "  Total Swift files: $total_files"
echo "  Total lines of code: $total_lines"
echo ""

if [ $missing -eq 0 ] && [ "$imports_ok" = true ] && [ $syntax_errors -eq 0 ]; then
    echo -e "${GREEN}✅ All basic tests passed!${NC}"
    echo ""
    echo -e "${BLUE}📝 Next Steps:${NC}"
    echo "  1. Create Xcode project (see DOCS/XCODE_SETUP.md)"
    echo "  2. Add all files to Xcode project"
    echo "  3. Configure build settings"
    echo "  4. Build and run (⌘R)"
    echo "  5. Run unit tests (⌘U)"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some issues detected. Review output above.${NC}"
    exit 1
fi

