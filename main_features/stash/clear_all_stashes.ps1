# -----------------------------------------------------------------------------
# Script: clear_all_stashes.ps1
#
# Description:
# Clears (permanently deletes) all stashes without applying them.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "Clear All Stashes – Dev Tools"
Write-Host "================================="

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "[INFO] No stashes found to clear."
    Write-Host ""
    Write-Host "[INFO] Tip: Create a stash first using one of the stash operations."
    exit 0
}

# Show all stashes that will be cleared
Write-Host ""
Write-Host "All stashes that will be permanently deleted:"
Write-Host ""
$stashList | ForEach-Object -Begin { $index = 1 } -Process {
    Write-Host "$index) $_"
    $index++
}

Write-Host ""
Write-Host "[WARNING] This will permanently delete ALL $stashCount stashes without applying them."
Write-Host "[WARNING] This action cannot be undone!"
Write-Host ""
$confirm = Read-Host "Clear all stashes permanently? Type 'DELETE ALL' to confirm"

if ($confirm -ne "DELETE ALL") {
    Write-Host "[CANCELLED] Clear operation cancelled."
    Write-Host "[INFO] You must type 'DELETE ALL' exactly to confirm this destructive operation."
    exit 1
}

# Clear all stashes
Write-Host ""
Write-Host "Clearing all stashes..."
git stash clear

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Successfully cleared all stashes."
    Write-Host "[INFO] No stashes remaining."
} else {
    Write-Host "[ERROR] Failed to clear stashes."
    exit 1
}
