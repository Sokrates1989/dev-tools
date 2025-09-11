# -----------------------------------------------------------------------------
# Script: show_specific_stash.ps1
#
# Description:
# Shows the content of a specific stash by index or reference.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "Show Specific Stash Content – Dev Tools"
Write-Host "=========================================="

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "[INFO] No stashes found to show."
    Write-Host ""
    Write-Host "[INFO] Tip: Create a stash first using one of the stash operations."
    exit 0
}

# Show all available stashes
Write-Host ""
Write-Host "Available stashes:"
Write-Host ""
$stashList | ForEach-Object -Begin { $index = 1 } -Process {
    Write-Host "$index) $_"
    $index++
}

Write-Host ""
Write-Host "You can specify stash by:"
Write-Host "  • Index number (e.g., 1, 2, 3)"
Write-Host "  • Stash reference (e.g., stash@{0}, stash@{1})"
Write-Host ""

$stashInput = Read-Host "Enter stash index or reference to show"

# Validate and convert input
$stashRef = ""
if ($stashInput -match '^\d+$') {
    # User entered a number, convert to stash reference
    $stashIndex = [int]$stashInput - 1
    if ($stashIndex -lt 0 -or $stashIndex -ge $stashCount) {
        Write-Host "[ERROR] Invalid stash index. Please enter a number between 1 and $stashCount."
        exit 1
    }
    $stashRef = "stash@{$stashIndex}"
} elseif ($stashInput -match '^stash@\{\d+\}$') {
    # User entered a stash reference
    $stashRef = $stashInput
    # Extract index to validate
    if ($stashInput -match 'stash@\{(\d+)\}') {
        $stashIndex = [int]$matches[1]
        if ($stashIndex -ge $stashCount) {
            Write-Host "[ERROR] Invalid stash reference. Stash $stashInput does not exist."
            exit 1
        }
    }
} else {
    Write-Host "[ERROR] Invalid input. Please enter a number or stash reference like 'stash@{0}'."
    exit 1
}

# Show the selected stash info
Write-Host ""
Write-Host "Selected stash:"
$selectedStash = $stashList | Where-Object { $_ -match "^$([regex]::Escape($stashRef)):" }
Write-Host "  $selectedStash"
Write-Host ""

Write-Host "Stash content:"
Write-Host "=================="
Write-Host ""

# Show the stash content with diff
git stash show -p $stashRef

Write-Host ""
Write-Host "[INFO] Tips:"
Write-Host "  • Use 'Apply specific stash' to apply this stash to your working directory"
Write-Host "  • Use 'Pop specific stash' to apply and remove this stash"
Write-Host "  • Use 'Drop specific stash' to remove this stash without applying"
