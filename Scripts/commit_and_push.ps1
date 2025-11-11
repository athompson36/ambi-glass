# PowerShell script to commit and push AmbiIRverb integration to GitHub
# Run this script from the project root directory

Write-Host "AmbiIRverb Integration - Git Commit & Push" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if git is available
try {
    $gitVersion = git --version
    Write-Host "Git found: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Git is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Git from https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host "Or add Git to your PATH environment variable" -ForegroundColor Yellow
    exit 1
}

# Check if this is a git repository
if (-not (Test-Path ".git")) {
    Write-Host "Initializing git repository..." -ForegroundColor Yellow
    git init
    git branch -M main
}

# Check remote
$remote = git remote get-url origin -ErrorAction SilentlyContinue
if (-not $remote) {
    Write-Host "Setting up remote origin..." -ForegroundColor Yellow
    git remote add origin https://github.com/athompson36/ambi-glass.git
} else {
    Write-Host "Remote origin: $remote" -ForegroundColor Green
}

# Show status
Write-Host ""
Write-Host "Current git status:" -ForegroundColor Cyan
git status

# Add all files
Write-Host ""
Write-Host "Adding all files..." -ForegroundColor Yellow
git add .

# Commit
Write-Host ""
Write-Host "Creating commit..." -ForegroundColor Yellow
$commitMessage = @"
Merge AmbiIRverb plugin integration

- Integrated AmbiIRverb JUCE plugin source code into Plugins/AmbiIRverb/
- Added IR reverb audition UI (IRTestView, IRTestHost)
- Integrated reverb presets (.ambipreset files) into Resources/Presets/
- Updated documentation (README, ARCHITECTURE, UI_GUIDE, PLUGIN_INTEGRATION)
- Updated CHANGELOG with integration details

See DOCS/PLUGIN_INTEGRATION.md for integration details.
"@

git commit -m $commitMessage

# Push to GitHub
Write-Host ""
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push -u origin main

Write-Host ""
Write-Host "✅ Successfully pushed to GitHub!" -ForegroundColor Green
Write-Host "Repository: https://github.com/athompson36/ambi-glass" -ForegroundColor Cyan

