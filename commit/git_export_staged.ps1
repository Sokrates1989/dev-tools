# -----------------------------------------------------------------------------
# Script: git_export_staged.ps1
#
# Description:
# 1. Saves the current staged diff (`git diff --staged`) into "last_staged_commit_diff.txt"
# 2. Copies all staged files into a flat folder named "changed_files"
# 3. Opens the export folder in File Explorer
#
# Platform: Windows PowerShell
# -----------------------------------------------------------------------------

# Function to show export usage instructions
function Show-ExportInstructions {
    Write-Host ""
    Write-Host "📂 Export folder will open in File Explorer."
    Write-Host "🔍 To see hidden files (like .gitignore): enable 'Hidden items' in the 'View' tab."
    Write-Host ""
    Write-Host "🤖 Copy the content of the opened folder to your preferred AI tool."
    Write-Host ""
    Write-Host "📝 Add the related Project Task ID (if available), or just write: \"no task ID\""
    Write-Host ""
}

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

# Exit early if no staged files found.
if (-not $files) {
    Write-Host "⚠️  No staged files found. Please stage changes with 'git add' before running this script."
    exit
}

# Copy each file (flattened into destination folder).
foreach ($file in $files) {
    if (Test-Path $file) {
        Copy-Item $file -Destination (Join-Path $destDir (Split-Path $file -Leaf))
    }
}

# Output summary.
Write-Host ""
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

# Show instructions and wait before opening the folder.
Write-Host ""
Write-Host "🖼️  Preparing export view..."
Show-ExportInstructions
Read-Host "🚀 Press Enter to open the folder now..."
Start-Process "explorer.exe" $parentDir
