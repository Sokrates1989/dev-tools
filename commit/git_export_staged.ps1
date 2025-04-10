# -----------------------------------------------------------------------------
# Script: git_export_staged.ps1
#
# Description:
# 1. Saves the current staged diff (`git diff --staged`) into "last_staged_commit_diff.txt"
# 2. Copies all staged files into a flat folder named "changed_files"
#
# Platform: Windows PowerShell
# -----------------------------------------------------------------------------

# Get the script directory.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Define parent and sub paths.
$parentDir = Join-Path $ScriptDir "git_export_staged"
$destDir = Join-Path $parentDir "changed_files"
$diffFile = Join-Path $parentDir "last_staged_commit_diff.txt"

# Clean up previous outputs.
Remove-Item -Recurse -Force $destDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Remove-Item -Force $diffFile -ErrorAction SilentlyContinue

# Export the staged diff to a file.
git diff --staged > $diffFile

# Get list of staged files.
$files = git diff --name-only --cached

# Copy each file (flattened into destination folder).
foreach ($file in $files) {
    if (Test-Path $file) {
        Copy-Item $file -Destination (Join-Path $destDir (Split-Path $file -Leaf))
    }
}


# Output summary.
Write-Host "✅ Copied staged files to: $destDir"
Get-ChildItem $destDir | ForEach-Object { Write-Host $_.Name }
Write-Host ""
Write-Host "📝 Staged diff saved to: $diffFile"

# Copy commit_message_prompt.txt if it exists.
$commitMsgFile = Join-Path $ScriptDir "commit_message_prompt.txt"
if (Test-Path $commitMsgFile) {
    Copy-Item $commitMsgFile -Destination $parentDir
    Write-Host "📝 Copied commit_message_prompt.txt to export folder."
}

# Open parent folder in Windows Explorer.
Start-Process "explorer.exe" $parentDir

# User info to show hidden files.
Write-Host ""
Write-Host "💡 Tip: Always show hidden files (like .gitignore) to avoid confusion."
Write-Host "👉 Windows: In Explorer, go to 'View' and check 'Hidden items'."
