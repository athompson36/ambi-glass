#!/usr/bin/env bash
# Helper script to verify Xcode project setup

set -euo pipefail

echo "🔍 AmbiGlass Xcode Setup Verification"
echo ""

# Check if we're in the right directory
if [ ! -d "App" ] || [ ! -d "Audio" ] || [ ! -d "DSP" ]; then
    echo "❌ Error: Must run from AmbiGlass_starter directory"
    echo "   Current directory: $(pwd)"
    exit 1
fi

echo "✅ Found source directories"
echo ""

# Count files
echo "📊 File Count:"
echo "   App: $(find App -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "   Audio: $(find Audio -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "   DSP: $(find DSP -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "   UI: $(find UI -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "   Theme: $(find Theme -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo "   Tests: $(find Tests -name "*.swift" 2>/dev/null | wc -l | tr -d ' ') files"
echo ""

# Check for required files
echo "🔍 Checking required files:"

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
    "Resources/Presets/AmbiAlice_v1.json"
)

missing=0
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file"
    else
        echo "   ❌ $file (MISSING)"
        missing=$((missing + 1))
    fi
done

echo ""

if [ $missing -eq 0 ]; then
    echo "✅ All required files present!"
    echo ""
    echo "📝 Next Steps:"
    echo "   1. Open Xcode"
    echo "   2. Create new Multiplatform App project named 'AmbiGlass'"
    echo "   3. Follow XCODE_SETUP.md guide"
    echo "   4. Add all files to the project"
    echo ""
else
    echo "❌ Missing $missing required files"
    echo "   Please ensure all source files are present"
    exit 1
fi

