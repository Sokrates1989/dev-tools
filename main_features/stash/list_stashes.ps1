# -----------------------------------------------------------------------------
# Script: list_stashes.ps1
#
# Description:
# Lists all available stashes with enhanced formatting.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "📜 List All Stashes – Dev Tools"
Write-Host "==============================="

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "📦 No stashes found."
    Write-Host ""
    Write-Host "💡 Tip: Create a stash using one of the stash operations."
    exit 0
}

Write-Host ""
Write-Host "📦 Found $stashCount stash(es):"
Write-Host ""

# List all stashes with enhanced formatting
# Note: PowerShell doesn't support git's color formatting as well as bash
# So we'll use a simpler but clear format
$stashList | ForEach-Object -Begin { $index = 1 } -Process {
    # Parse the stash entry
    if ($_ -match '^(stash@\{[0-9]+\}): (.+)$') {
        $stashRef = $matches[1]
        $stashMessage = $matches[2]
        Write-Host "  $index) $stashRef - $stashMessage"
        $index++
    } else {
        Write-Host "  $_"
    }
}

Write-Host ""
Write-Host "💡 Tips:"
Write-Host "  • Use 'Show content of specific stash' to view stash details"
Write-Host "  • Use 'Apply specific stash' to apply a stash by its index (e.g., stash@{0})"
Write-Host "  • Use 'Drop specific stash' to remove a stash by its index"
