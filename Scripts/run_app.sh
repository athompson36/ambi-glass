#!/usr/bin/env bash
# Script to build and run AmbiStudio app

set -euo pipefail

PROJECT_DIR="ios/AmbiStudio"
PROJECT_FILE="$PROJECT_DIR/AmbiStudio.xcodeproj"
SCHEME="AmbiStudio"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔨 Building AmbiStudio...${NC}"

# Build for macOS
cd "$(dirname "$0")/.."
xcodebuild -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -sdk macosx \
    -configuration Debug \
    build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    
    # Find the app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "AmbiStudio.app" -path "*/Build/Products/Debug/*" 2>/dev/null | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo -e "${BLUE}🚀 Launching AmbiStudio...${NC}"
        open "$APP_PATH"
        echo -e "${GREEN}✅ App launched!${NC}"
    else
        echo -e "${YELLOW}⚠️  App bundle not found. Build may have completed but app location unknown.${NC}"
        echo "Try opening Xcode and running from there (⌘R)"
    fi
else
    echo -e "${YELLOW}⚠️  Build had issues. Check output above.${NC}"
    exit 1
fi

