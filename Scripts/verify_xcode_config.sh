#!/usr/bin/env bash
# Script to verify Xcode project configuration for Watch Remote Addon

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_FILE="ios/AmbiStudio/AmbiStudio.xcodeproj/project.pbxproj"

echo -e "${BLUE}🔍 Verifying Xcode Project Configuration${NC}"
echo ""

# Check if files are in build phases
echo -e "${BLUE}Checking build phases...${NC}"

FILES_IN_BUILD=0
for file in "RemoteProtocol.swift" "LANListener.swift" "PhoneRelay.swift"; do
    if grep -q "${file} in Sources" "$PROJECT_FILE"; then
        echo -e "  ${GREEN}✅${NC} $file in Sources build phase"
        ((FILES_IN_BUILD++))
    else
        echo -e "  ${RED}❌${NC} $file NOT in Sources build phase"
    fi
done

# Check frameworks
echo ""
echo -e "${BLUE}Checking frameworks...${NC}"

if grep -q "WatchConnectivity.framework in Frameworks" "$PROJECT_FILE"; then
    echo -e "  ${GREEN}✅${NC} WatchConnectivity.framework added"
else
    echo -e "  ${RED}❌${NC} WatchConnectivity.framework NOT added"
fi

if grep -q "Network.framework in Frameworks" "$PROJECT_FILE"; then
    echo -e "  ${GREEN}✅${NC} Network.framework added"
else
    echo -e "  ${RED}❌${NC} Network.framework NOT added"
fi

# Check for watchOS target
echo ""
echo -e "${BLUE}Checking targets...${NC}"

if grep -q "watchOS\|watchos\|AmbiGlassWatch" "$PROJECT_FILE"; then
    echo -e "  ${GREEN}✅${NC} watchOS target found"
else
    echo -e "  ${YELLOW}⚠️${NC}  watchOS target not found (needs to be created manually)"
fi

# Summary
echo ""
echo -e "${BLUE}Summary:${NC}"
if [ $FILES_IN_BUILD -eq 3 ]; then
    echo -e "  ${GREEN}✅ All files configured${NC}"
else
    echo -e "  ${YELLOW}⚠️  Some files missing from build phases${NC}"
fi

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Open Xcode and verify target memberships"
echo "  2. Create watchOS target if needed (File → New → Target → watchOS → App)"
echo "  3. Add Info.plist entry for network usage"
echo "  4. Build and test"

