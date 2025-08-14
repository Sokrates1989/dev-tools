# -----------------------------------------------------------------------------
# Script: show_latest_stash.ps1
#
# Description:
# Shows the content of the latest stash.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "🔍 Show Latest Stash Content – Dev Tools"
Write-Host "========================================"

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "📦 No stashes found to show."
    Write-Host ""
    Write-Host "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
}

# Show the latest stash info
Write-Host ""
Write-Host "📦 Latest stash:"
$latestStash = $stashList | Select-Object -First 1
Write-Host "  $latestStash"
Write-Host ""

Write-Host "📋 Stash content:"
Write-Host "=================="
Write-Host ""

# Show the stash content with diff
git stash show -p stash@{0}

Write-Host ""
Write-Host "💡 Tips:"
Write-Host "  • Use 'Apply latest stash' to apply this stash to your working directory"
Write-Host "  • Use 'Pop latest stash' to apply and remove this stash"
Write-Host "  • Use 'Drop latest stash' to remove this stash without applying"
