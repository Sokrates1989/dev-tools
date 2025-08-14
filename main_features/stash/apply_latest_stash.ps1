# -----------------------------------------------------------------------------
# Script: apply_latest_stash.ps1
#
# Description:
# Applies the latest stash while keeping it in the stash list.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "🔄 Apply Latest Stash – Dev Tools"
Write-Host "================================="

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "📦 No stashes found to apply."
    Write-Host ""
    Write-Host "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
}

# Show the latest stash
Write-Host ""
Write-Host "📦 Latest stash to apply:"
$latestStash = $stashList | Select-Object -First 1
Write-Host "  $latestStash"
Write-Host ""

# Show current working directory status
Write-Host "📋 Current working directory status:"
$gitStatus = git status --porcelain
$hasChanges = $gitStatus -and ($gitStatus | Measure-Object).Count -gt 0

if (-not $hasChanges) {
    Write-Host "✅ Working directory is clean."
} else {
    Write-Host "⚠️  Working directory has uncommitted changes:"
    $gitStatus | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "⚠️  Warning: Applying stash may conflict with current changes."
}

Write-Host ""
$confirm = Read-Host "🔄 Apply the latest stash? (This keeps the stash in the stash list) (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "❌ Apply operation cancelled."
    exit 1
}

# Apply the latest stash
Write-Host ""
Write-Host "🔄 Applying latest stash..."
git stash apply

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully applied latest stash."
    Write-Host ""
    Write-Host "📦 Stash remains in the stash list:"
    $remainingLatest = git stash list | Select-Object -First 1
    Write-Host "  $remainingLatest"
    Write-Host ""
    Write-Host "💡 Tip: Use 'Pop latest stash' to apply and remove the stash in one operation."
} else {
    Write-Host "❌ Failed to apply stash. There may be conflicts."
    Write-Host ""
    Write-Host "💡 Tips for resolving conflicts:"
    Write-Host "  • Check 'git status' for conflicted files"
    Write-Host "  • Resolve conflicts manually and commit"
    Write-Host "  • Use 'git stash drop' to remove the stash if no longer needed"
    exit 1
}
