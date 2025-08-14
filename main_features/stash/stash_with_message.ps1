# -----------------------------------------------------------------------------
# Script: stash_with_message.ps1
#
# Description:
# Stashes changes with a custom message.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "📦 Stash with Custom Message – Dev Tools"
Write-Host "========================================"

# Check if there are any changes to stash
$modifiedFiles = git diff --name-only
$stagedFiles = git diff --cached --name-only
$untrackedFiles = git ls-files --others --exclude-standard

$hasModified = $modifiedFiles -and ($modifiedFiles | Measure-Object).Count -gt 0
$hasStaged = $stagedFiles -and ($stagedFiles | Measure-Object).Count -gt 0
$hasUntracked = $untrackedFiles -and ($untrackedFiles | Measure-Object).Count -gt 0

if (-not $hasModified -and -not $hasStaged -and -not $hasUntracked) {
    Write-Host "✅ No changes to stash. Working directory is clean."
    exit 0
}

# Show what will be stashed
Write-Host ""
Write-Host "📋 Changes that will be stashed:"
Write-Host ""

if ($hasModified) {
    Write-Host "🔄 Modified files:"
    $modifiedFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

if ($hasStaged) {
    Write-Host "📁 Staged files:"
    $stagedFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

# Check for untracked files
$stashFlags = ""
if ($hasUntracked) {
    Write-Host "📄 Untracked files found:"
    $untrackedFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    
    $includeUntracked = Read-Host "📦 Include untracked files in stash? (yes/no)"
    if ($includeUntracked -eq "yes") {
        $stashFlags = "--include-untracked"
    } else {
        Write-Host "📄 Untracked files will NOT be stashed."
    }
}

Write-Host ""
$customMessage = Read-Host "💬 Enter a custom message for this stash"

if ([string]::IsNullOrWhiteSpace($customMessage)) {
    Write-Host "❌ No message provided. Using default message."
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $customMessage = "Custom stash created on $timestamp"
}

Write-Host ""
Write-Host "📦 Stashing changes with message: '$customMessage'"

# Perform stash with custom message
if ($stashFlags) {
    git stash push $stashFlags -m $customMessage
} else {
    git stash push -m $customMessage
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully stashed changes with custom message."
    Write-Host ""
    Write-Host "📦 Current stash list:"
    $stashList = git stash list
    $stashList | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" }
    
    $totalStashes = if ($stashList) { ($stashList | Measure-Object).Count } else { 0 }
    if ($totalStashes -gt 3) {
        Write-Host "  ... and $($totalStashes - 3) more stashes"
    }
} else {
    Write-Host "❌ Failed to stash changes."
    exit 1
}
