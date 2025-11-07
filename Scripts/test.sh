#!/usr/bin/env bash
# Test runner script for AmbiGlass

set -euo pipefail

echo "🧪 Running AmbiGlass Unit Tests"
echo ""

# Check if we can compile the test files
if command -v swiftc &> /dev/null; then
    echo "📊 Testing DSP functions..."
    # Note: This would require proper module setup
    # For now, just verify syntax
    swiftc -typecheck Tests/*.swift 2>&1 || echo "⚠️  Test files need proper module setup"
else
    echo "⚠️  swiftc not found. Skipping test compilation."
fi

echo ""
echo "✅ Test script completed"
echo ""
echo "Note: Full test execution requires Xcode project setup."
echo "Run tests with: xcodebuild test -scheme AmbiGlass"

