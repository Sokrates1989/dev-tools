# -----------------------------------------------------------------------------
# Script: pop_latest_stash.ps1
#
# Description:
# Pops (applies and removes) the latest stash.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "🔄 Pop Latest Stash – Dev Tools"
Write-Host "==============================="

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "📦 No stashes found to pop."
    Write-Host ""
    Write-Host "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
}

# Show the latest stash
Write-Host ""
Write-Host "📦 Latest stash to pop:"
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
    Write-Host "⚠️  Warning: Popping stash may conflict with current changes."
}

Write-Host ""
$confirm = Read-Host "🔄 Pop the latest stash? (This applies and removes the stash) (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "❌ Pop operation cancelled."
    exit 1
}

# Pop the latest stash
Write-Host ""
Write-Host "🔄 Popping latest stash..."
git stash pop

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully popped latest stash."
    Write-Host ""
    $remainingStashes = git stash list
    $remainingCount = if ($remainingStashes) { ($remainingStashes | Measure-Object).Count } else { 0 }
    
    if ($remainingCount -gt 0) {
        Write-Host "📦 Remaining stashes: $remainingCount"
        $remainingStashes | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" }
        if ($remainingCount -gt 3) {
            Write-Host "  ... and $($remainingCount - 3) more stashes"
        }
    } else {
        Write-Host "📦 No more stashes remaining."
    }
} else {
    Write-Host "❌ Failed to pop stash. There may be conflicts."
    Write-Host ""
    Write-Host "💡 Tips for resolving conflicts:"
    Write-Host "  • Check 'git status' for conflicted files"
    Write-Host "  • Resolve conflicts manually and commit"
    Write-Host "  • The stash remains in the stash list until conflicts are resolved"
    exit 1
}
