# -----------------------------------------------------------------------------
# Script: git_export_staged.ps1
#
# Description:
# 1. Saves the current staged diff (`git diff --staged`) into "last_staged_commit_diff.txt"
# 2. Copies all staged files into a flat folder named "changed_files"
# 3. Creates a combined export file for AI tools
# 4. Opens the export folder in File Explorer
# -----------------------------------------------------------------------------

# Function to show export usage instructions
function Show-ExportInstructions {
    Write-Host ""
    Write-Host "Export folder will open in File Explorer."
    Write-Host "To see hidden files (like .gitignore), enable 'Hidden items' in the 'View' tab."
    Write-Host ""
    Write-Host "Copy the content of the opened folder to your preferred AI tool."
    Write-Host "Alternatively, use the single combined file:"
    Write-Host "  $allInOneFile"
    Write-Host ""
    Write-Host "The shared commit strategy is included in:"
    Write-Host "  $commitPromptFile"
    Write-Host ""
    Write-Host "Add the related Project Task ID (if available), or just write: no task ID"
    Write-Host ""
}

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Define parent and sub paths
$parentDir = Join-Path $ScriptDir "git_export_staged"
$destDir = Join-Path $parentDir "changed_files"
$diffFile = Join-Path $parentDir "last_staged_commit_diff.txt"
$allInOneDir = Join-Path $parentDir "all_in_one"
$allInOneFile = Join-Path $allInOneDir "ai_message.txt"
$commitPromptFile = Join-Path $parentDir "commit_message_prompt.txt"

# Git update check
$RootDir = Resolve-Path "$PSScriptRoot\..\.." | Select-Object -ExpandProperty Path
& "$RootDir\global_functions\check_for_updates.ps1"

if (-not (Test-Path $destDir) -or -not (Test-Path $diffFile) -or -not (Test-Path $allInOneFile) -or -not (Test-Path $commitPromptFile)) {
    Write-Host "Commit export files are missing. Please run the commit export first."
    exit
}

# Output summary
Write-Host ""
Write-Host "Exported staged files available in: $destDir"
Get-ChildItem $destDir | ForEach-Object { Write-Host $_.Name }
Write-Host ""
Write-Host "Staged diff available at: $diffFile"
Write-Host "Combined AI message available at: $allInOneFile"

# Show instructions and wait before opening the folder
Write-Host ""
Write-Host "Preparing export view..."
Show-ExportInstructions

# Re-run update check to catch any new changes
& "$RootDir\global_functions\check_for_updates.ps1"

Read-Host "Press Enter to open the folder now..."
Start-Process "explorer.exe" $parentDir
