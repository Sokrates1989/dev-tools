# -----------------------------------------------------------------------------
# Script: apply_specific_stash.ps1
#
# Description:
# Applies a specific stash by index or reference while keeping it in the stash list.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "🔄 Apply Specific Stash – Dev Tools"
Write-Host "==================================="

# Check if there are any stashes
$stashList = git stash list
$stashCount = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }

if ($stashCount -eq 0) {
    Write-Host "📦 No stashes found to apply."
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

$stashInput = Read-Host "🔍 Enter stash index or reference to apply"

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
Write-Host "📦 Selected stash to apply:"
$selectedStash = $stashList | Where-Object { $_ -match "^$([regex]::Escape($stashRef)):" }
Write-Host "  $selectedStash"
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
$confirm = Read-Host "🔄 Apply stash $stashRef? (This keeps the stash in the stash list) (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "❌ Apply operation cancelled."
    exit 1
}

# Apply the specified stash
Write-Host ""
Write-Host "🔄 Applying stash $stashRef..."
git stash apply $stashRef

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully applied stash $stashRef."
    Write-Host ""
    Write-Host "📦 Stash remains in the stash list:"
    Write-Host "  $selectedStash"
    Write-Host ""
    Write-Host "💡 Tip: Use 'Drop specific stash' to remove the stash if no longer needed."
} else {
    Write-Host "❌ Failed to apply stash. There may be conflicts."
    Write-Host ""
    Write-Host "💡 Tips for resolving conflicts:"
    Write-Host "  • Check 'git status' for conflicted files"
    Write-Host "  • Resolve conflicts manually and commit"
    Write-Host "  • Use 'git stash drop $stashRef' to remove the stash if no longer needed"
    exit 1
}
