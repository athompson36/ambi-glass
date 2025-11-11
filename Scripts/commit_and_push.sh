#!/bin/bash
# Bash script to commit and push AmbiIRverb integration to GitHub
# Run this script from the project root directory

echo "AmbiIRverb Integration - Git Commit & Push"
echo "========================================="
echo ""

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "ERROR: Git is not installed or not in PATH"
    echo "Please install Git from https://git-scm.com/download/"
    exit 1
fi

echo "Git found: $(git --version)"
echo ""

# Check if this is a git repository
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git branch -M main
fi

# Check remote
if ! git remote get-url origin &> /dev/null; then
    echo "Setting up remote origin..."
    git remote add origin https://github.com/athompson36/ambi-glass.git
else
    echo "Remote origin: $(git remote get-url origin)"
fi

# Show status
echo ""
echo "Current git status:"
git status

# Add all files
echo ""
echo "Adding all files..."
git add .

# Commit
echo ""
echo "Creating commit..."
git commit -m "Merge AmbiIRverb plugin integration

- Integrated AmbiIRverb JUCE plugin source code into Plugins/AmbiIRverb/
- Added IR reverb audition UI (IRTestView, IRTestHost)
- Integrated reverb presets (.ambipreset files) into Resources/Presets/
- Updated documentation (README, ARCHITECTURE, UI_GUIDE, PLUGIN_INTEGRATION)
- Updated CHANGELOG with integration details

See DOCS/PLUGIN_INTEGRATION.md for integration details."

# Push to GitHub
echo ""
echo "Pushing to GitHub..."
git push -u origin main

echo ""
echo "✅ Successfully pushed to GitHub!"
echo "Repository: https://github.com/athompson36/ambi-glass"

