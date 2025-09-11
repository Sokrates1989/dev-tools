# -----------------------------------------------------------------------------
# Script: stash_all_untracked.ps1
#
# Description:
# Stashes all changes including untracked files.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "Stash All Changes (Including Untracked) – Dev Tools"
Write-Host "====================================================="

# Check if there are any changes to stash
$modifiedFiles = git diff --name-only
$stagedFiles = git diff --cached --name-only
$untrackedFiles = git ls-files --others --exclude-standard

$hasModified = $modifiedFiles -and ($modifiedFiles | Measure-Object).Count -gt 0
$hasStaged = $stagedFiles -and ($stagedFiles | Measure-Object).Count -gt 0
$hasUntracked = $untrackedFiles -and ($untrackedFiles | Measure-Object).Count -gt 0

if (-not $hasModified -and -not $hasStaged -and -not $hasUntracked) {
    Write-Host "[OK] No changes to stash. Working directory is clean."
    exit 0
}

# Show what will be stashed
Write-Host ""
Write-Host "Changes that will be stashed:"
Write-Host ""

if ($hasModified) {
    Write-Host "Modified files:"
    $modifiedFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

if ($hasStaged) {
    Write-Host "Staged files:"
    $stagedFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

if ($hasUntracked) {
    Write-Host "Untracked files:"
    $untrackedFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

# Confirm action
$confirm = Read-Host "Stash all changes including untracked files? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "[CANCELLED] Stash operation cancelled."
    exit 1
}

# Perform stash with untracked files
Write-Host ""
Write-Host "Stashing changes..."
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
git stash push --include-untracked -m "Stash created on $timestamp"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Successfully stashed all changes including untracked files."
    Write-Host ""
    Write-Host "Current stash list:"
    $stashList = git stash list
    $stashList | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" }
    
    $totalStashes = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }
    if ($totalStashes -gt 3) {
        Write-Host "  ... and $($totalStashes - 3) more stashes"
    }
} else {
    Write-Host "[ERROR] Failed to stash changes."
    exit 1
}
