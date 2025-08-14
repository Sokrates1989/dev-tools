# -----------------------------------------------------------------------------
# Script: drop_specific_stash.ps1
#
# Description:
# Drops (permanently deletes) a specific stash by index or reference without applying it.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "🗑️  Drop Specific Stash – Dev Tools"
Write-Host "==================================="

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "📦 No stashes found to drop."
    Write-Host ""
    Write-Host "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
}

# Show all available stashes
Write-Host ""
Write-Host "📦 Available stashes:"
Write-Host ""
$stashList | ForEach-Object -Begin { $index = 1 } -Process {
    Write-Host "$index) $_"
    $index++
}

Write-Host ""
Write-Host "💡 You can specify stash by:"
Write-Host "  • Index number (e.g., 1, 2, 3)"
Write-Host "  • Stash reference (e.g., stash@{0}, stash@{1})"
Write-Host ""

$stashInput = Read-Host "🔍 Enter stash index or reference to drop"

# Validate and convert input
$stashRef = ""
if ($stashInput -match '^\d+$') {
    # User entered a number, convert to stash reference
    $stashIndex = [int]$stashInput - 1
    if ($stashIndex -lt 0 -or $stashIndex -ge $stashCount) {
        Write-Host "❌ Invalid stash index. Please enter a number between 1 and $stashCount."
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
            Write-Host "❌ Invalid stash reference. Stash $stashInput does not exist."
            exit 1
        }
    }
} else {
    Write-Host "❌ Invalid input. Please enter a number or stash reference like 'stash@{0}'."
    exit 1
}

# Show the selected stash
Write-Host ""
Write-Host "📦 Selected stash to drop:"
$selectedStash = $stashList | Where-Object { $_ -match "^$([regex]::Escape($stashRef)):" }
Write-Host "  $selectedStash"
Write-Host ""

Write-Host "⚠️  Warning: This will permanently delete the stash without applying it."
Write-Host ""
$confirm = Read-Host "🗑️  Drop stash $stashRef permanently? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "❌ Drop operation cancelled."
    exit 1
}

# Drop the specified stash
Write-Host ""
Write-Host "🗑️  Dropping stash $stashRef..."
git stash drop $stashRef

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully dropped stash $stashRef."
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
