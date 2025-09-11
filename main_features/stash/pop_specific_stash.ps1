# -----------------------------------------------------------------------------
# Script: pop_specific_stash.ps1
#
# Description:
# Pops (applies and removes) a specific stash by index or reference.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "Pop Specific Stash – Dev Tools"
Write-Host "================================="

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "[INFO] No stashes found to pop."
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

$stashInput = Read-Host "Enter stash index or reference to pop"

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

# Show the selected stash
Write-Host ""
Write-Host "Selected stash to pop:"
$selectedStash = $stashList | Where-Object { $_ -match "^$([regex]::Escape($stashRef)):" }
Write-Host "  $selectedStash"
Write-Host ""

# Show current working directory status
Write-Host "Current working directory status:"
$gitStatus = git status --porcelain
$hasChanges = $gitStatus -and ($gitStatus | Measure-Object).Count -gt 0

if (-not $hasChanges) {
    Write-Host "[OK] Working directory is clean."
} else {
    Write-Host "[WARNING] Working directory has uncommitted changes:"
    $gitStatus | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "[WARNING] Popping stash may conflict with current changes."
}

Write-Host ""
$confirm = Read-Host "Pop stash $stashRef? (This applies and removes the stash) (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "[CANCELLED] Pop operation cancelled."
    exit 1
}

# Pop the specified stash
Write-Host ""
Write-Host "Popping stash $stashRef..."
git stash pop $stashRef

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Successfully popped stash $stashRef."
    Write-Host ""
    $remainingStashes = git stash list
    $remainingCount = if ($remainingStashes) { ($remainingStashes | Measure-Object).Count } else { 0 }
    
    if ($remainingCount -gt 0) {
        Write-Host "Remaining stashes: $remainingCount"
        $remainingStashes | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" }
        if ($remainingCount -gt 3) {
            Write-Host "  ... and $($remainingCount - 3) more stashes"
        }
    } else {
        Write-Host "[INFO] No more stashes remaining."
    }
} else {
    Write-Host "[ERROR] Failed to pop stash. There may be conflicts."
    Write-Host ""
    Write-Host "[INFO] Tips for resolving conflicts:"
    Write-Host "  • Check 'git status' for conflicted files"
    Write-Host "  • Resolve conflicts manually and commit"
    Write-Host "  • The stash has been removed from the stash list even if conflicts occurred"
    exit 1
}
