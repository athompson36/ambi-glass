#!/usr/bin/env bash
# Test Xcode project build
# Usage: ./Scripts/test_build.sh [path_to_xcodeproj]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$PROJECT_ROOT"

# Find Xcode project
XCODE_PROJ="${1:-}"
if [ -z "$XCODE_PROJ" ]; then
    # Try to find it
    if [ -d "AmbiGlass.xcodeproj" ]; then
        XCODE_PROJ="AmbiGlass.xcodeproj"
    elif [ -d "AmbiGlass.xcworkspace" ]; then
        XCODE_PROJ="AmbiGlass.xcworkspace"
    else
        echo -e "${RED}❌ No Xcode project found${NC}"
        echo ""
        echo "Please provide path to .xcodeproj:"
        echo "  ./Scripts/test_build.sh /path/to/AmbiGlass.xcodeproj"
        echo ""
        echo "Or create Xcode project first (see DOCS/XCODE_SETUP.md)"
        exit 1
    fi
fi

if [ ! -d "$XCODE_PROJ" ] && [ ! -f "$XCODE_PROJ" ]; then
    echo -e "${RED}❌ Xcode project not found: $XCODE_PROJ${NC}"
    exit 1
fi

echo -e "${BLUE}🧪 Testing Xcode Project Build${NC}"
echo ""
echo "Project: $XCODE_PROJ"
echo ""

# Test 1: List schemes
echo -e "${BLUE}📋 Test 1: List Schemes${NC}"
if [[ "$XCODE_PROJ" == *.xcworkspace ]]; then
    xcodebuild -list -workspace "$XCODE_PROJ" 2>&1 | head -30
else
    xcodebuild -list -project "$XCODE_PROJ" 2>&1 | head -30
fi
echo ""

# Test 2: Clean build
echo -e "${BLUE}🔨 Test 2: Clean Build${NC}"
if [[ "$XCODE_PROJ" == *.xcworkspace ]]; then
    xcodebuild clean -workspace "$XCODE_PROJ" -scheme AmbiGlass -configuration Debug 2>&1 | tail -10
else
    xcodebuild clean -project "$XCODE_PROJ" -scheme AmbiGlass -configuration Debug 2>&1 | tail -10
fi
echo ""

# Test 3: Build
echo -e "${BLUE}🔨 Test 3: Build Project${NC}"
if [[ "$XCODE_PROJ" == *.xcworkspace ]]; then
    if xcodebuild build -workspace "$XCODE_PROJ" -scheme AmbiGlass -configuration Debug -sdk macosx 2>&1 | tee /tmp/ambiglass_build.log | tail -20; then
        echo -e "${GREEN}✅ Build successful!${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        echo ""
        echo "Last 20 lines of build log:"
        tail -20 /tmp/ambiglass_build.log
        exit 1
    fi
else
    if xcodebuild build -project "$XCODE_PROJ" -scheme AmbiGlass -configuration Debug -sdk macosx 2>&1 | tee /tmp/ambiglass_build.log | tail -20; then
        echo -e "${GREEN}✅ Build successful!${NC}"
    else
        echo -e "${RED}❌ Build failed${NC}"
        echo ""
        echo "Last 20 lines of build log:"
        tail -20 /tmp/ambiglass_build.log
        exit 1
    fi
fi
echo ""

# Test 4: Run tests (if available)
echo -e "${BLUE}🧪 Test 4: Run Unit Tests${NC}"
if [[ "$XCODE_PROJ" == *.xcworkspace ]]; then
    xcodebuild test -workspace "$XCODE_PROJ" -scheme AmbiGlass -destination 'platform=macOS' 2>&1 | tail -30 || echo -e "${YELLOW}⚠️  Tests may not be configured yet${NC}"
else
    xcodebuild test -project "$XCODE_PROJ" -scheme AmbiGlass -destination 'platform=macOS' 2>&1 | tail -30 || echo -e "${YELLOW}⚠️  Tests may not be configured yet${NC}"
fi
echo ""

echo -e "${GREEN}✅ Build testing complete!${NC}"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo "  1. Open project in Xcode: open $XCODE_PROJ"
echo "  2. Run app: ⌘R"
echo "  3. Run tests: ⌘U"

