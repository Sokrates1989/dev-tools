# -----------------------------------------------------------------------------
# Script: drop_latest_stash.ps1
#
# Description:
# Drops (permanently deletes) the latest stash without applying it.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "🗑️  Drop Latest Stash – Dev Tools"
Write-Host "================================="

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "📦 No stashes found to drop."
    Write-Host ""
    Write-Host "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
}

# Show the latest stash
Write-Host ""
Write-Host "📦 Latest stash to drop:"
$latestStash = $stashList | Select-Object -First 1
Write-Host "  $latestStash"
Write-Host ""

Write-Host "⚠️  Warning: This will permanently delete the stash without applying it."
Write-Host ""
$confirm = Read-Host "🗑️  Drop the latest stash permanently? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "❌ Drop operation cancelled."
    exit 1
}

# Drop the latest stash
Write-Host ""
Write-Host "🗑️  Dropping latest stash..."
git stash drop stash@{0}

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully dropped latest stash."
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
    Write-Host "❌ Failed to drop stash."
    exit 1
}
