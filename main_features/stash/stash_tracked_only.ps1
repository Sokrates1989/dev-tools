# -----------------------------------------------------------------------------
# Script: stash_tracked_only.ps1
#
# Description:
# Stashes only tracked changes, leaving untracked files.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "📦 Stash Tracked Changes Only – Dev Tools"
Write-Host "========================================="

# Check if there are any tracked changes to stash
$modifiedFiles = git diff --name-only
$stagedFiles = git diff --cached --name-only

$hasModified = $modifiedFiles -and ($modifiedFiles | Measure-Object).Count -gt 0
$hasStaged = $stagedFiles -and ($stagedFiles | Measure-Object).Count -gt 0

if (-not $hasModified -and -not $hasStaged) {
    Write-Host "✅ No tracked changes to stash."
    
    # Check if there are untracked files
    $untrackedFiles = git ls-files --others --exclude-standard
    if ($untrackedFiles -and ($untrackedFiles | Measure-Object).Count -gt 0) {
        Write-Host ""
        Write-Host "📄 Untracked files found (will NOT be stashed):"
        $untrackedFiles | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
        Write-Host "💡 Tip: Use 'Stash all changes (including untracked)' to include untracked files."
    }
    exit 0
}

# Show what will be stashed
Write-Host ""
Write-Host "📋 Tracked changes that will be stashed:"
Write-Host ""

if ($hasModified) {
    Write-Host "🔄 Modified files:"
    $modifiedFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

if ($hasStaged) {
    Write-Host "📁 Staged files:"
    $stagedFiles | ForEach-Object { Write-Host "  $_" }
}

# Show untracked files that won't be stashed
$untrackedFiles = git ls-files --others --exclude-standard
if ($untrackedFiles -and ($untrackedFiles | Measure-Object).Count -gt 0) {
    Write-Host ""
    Write-Host "📄 Untracked files (will NOT be stashed):"
    $untrackedFiles | ForEach-Object { Write-Host "  $_" }
}
Write-Host ""

# Confirm action
$confirm = Read-Host "💾 Stash tracked changes only? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "❌ Stash operation cancelled."
    exit 1
}

# Perform stash of tracked files only
Write-Host ""
Write-Host "📦 Stashing tracked changes..."
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
git stash push -m "Tracked changes stash created on $timestamp"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully stashed tracked changes."
    Write-Host ""
    Write-Host "📦 Current stash list:"
    $stashList = git stash list
    $stashList | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" }
    
    $totalStashes = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }
    if ($totalStashes -gt 3) {
        Write-Host "  ... and $($totalStashes - 3) more stashes"
    }
} else {
    Write-Host "❌ Failed to stash changes."
    exit 1
}
