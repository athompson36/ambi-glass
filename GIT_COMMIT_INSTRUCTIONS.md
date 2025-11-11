# Git Commit & Push Instructions

Since Git is not currently available in your PATH, here are the steps to commit and push the AmbiIRverb integration to GitHub.

## Option 1: Use the Provided Scripts

### Windows (PowerShell)
```powershell
# Make sure Git is installed and in PATH first
# Then run:
.\Scripts\commit_and_push.ps1
```

### macOS/Linux (Bash)
```bash
# Make the script executable
chmod +x Scripts/commit_and_push.sh

# Run the script
./Scripts/commit_and_push.sh
```

## Option 2: Manual Git Commands

If you prefer to run the commands manually:

### 1. Initialize Repository (if not already initialized)
```bash
git init
git branch -M main
```

### 2. Add Remote (if not already added)
```bash
git remote add origin https://github.com/athompson36/ambi-glass.git
```

### 3. Add All Files
```bash
git add .
```

### 4. Commit Changes
```bash
git commit -m "Merge AmbiIRverb plugin integration

- Integrated AmbiIRverb JUCE plugin source code into Plugins/AmbiIRverb/
- Added IR reverb audition UI (IRTestView, IRTestHost)
- Integrated reverb presets (.ambipreset files) into Resources/Presets/
- Updated documentation (README, ARCHITECTURE, UI_GUIDE, PLUGIN_INTEGRATION)
- Updated CHANGELOG with integration details

See DOCS/PLUGIN_INTEGRATION.md for integration details."
```

### 5. Push to GitHub
```bash
git push -u origin main
```

## Installing Git (if needed)

### Windows
1. Download Git from: https://git-scm.com/download/win
2. Install with default settings (adds Git to PATH)
3. Restart your terminal/PowerShell

### macOS
```bash
# Using Homebrew
brew install git

# Or download from: https://git-scm.com/download/mac
```

### Linux
```bash
# Ubuntu/Debian
sudo apt-get install git

# Fedora
sudo dnf install git
```

## Verify Git Installation

After installing Git, verify it's working:
```bash
git --version
```

## Repository Information

- **Repository URL**: https://github.com/athompson36/ambi-glass
- **Branch**: main
- **Remote**: origin

## What's Being Committed

The following changes are included in this commit:

1. **New Plugin Source Code**
   - `Plugins/AmbiIRverb/` - Complete JUCE plugin source

2. **New UI Components**
   - `UI/IRTestView.swift` - IR reverb audition interface
   - `UI/IRTestHost.swift` - AVAudioEngine host

3. **New Presets**
   - `Resources/Presets/*.ambipreset` - Reverb presets

4. **Updated Documentation**
   - `README.md` - Added AmbiIRverb features
   - `DOCS/ARCHITECTURE.md` - Added plugin architecture
   - `DOCS/UI_GUIDE.md` - Added IR Test view documentation
   - `DOCS/PLUGIN_INTEGRATION.md` - New integration guide
   - `CHANGELOG.md` - Documented integration

## Troubleshooting

### Git not found
- Install Git (see above)
- Add Git to your system PATH
- Restart your terminal

### Authentication Issues
- Use GitHub CLI: `gh auth login`
- Or set up SSH keys: https://docs.github.com/en/authentication/connecting-to-github-with-ssh
- Or use Personal Access Token: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token

### Remote Already Exists
If you get "remote origin already exists", you can:
- Update it: `git remote set-url origin https://github.com/athompson36/ambi-glass.git`
- Or remove and re-add: `git remote remove origin && git remote add origin https://github.com/athompson36/ambi-glass.git`

