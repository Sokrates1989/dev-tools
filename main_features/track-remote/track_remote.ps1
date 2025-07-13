# -----------------------------------------------------------------------------
# Script: track_remote.ps1
#
# Description:
# This script lists all remote branches that are not yet tracked locally
# and allows the user to choose which ones to track by creating local
# branches with the same names.
#
# The script:
# 1. Fetches all remote branches to ensure up-to-date information
# 2. Identifies all remote branches
# 3. Compares with local branches to find untracked remote branches
# 4. Presents a list of untracked remote branches for selection
# 5. Creates local tracking branches for selected remote branches
# 6. Provides detailed feedback on the tracking process
# -----------------------------------------------------------------------------

# --- Resolve paths ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir\..\.." | Select-Object -ExpandProperty Path

# Load environment variables.
$EnvFile = Join-Path $RootDir ".env"
if (-not (Test-Path $EnvFile)) {
    Write-Host ".env file not found at $EnvFile" -ForegroundColor Red
    exit 1
}

# Load environment variables.
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^([^#][^=]+)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        Set-Variable -Name $name -Value $value -Scope Global
    }
}

# --- Git update check ---
& "$RootDir\global_functions\check_for_updates.ps1"

# --- Check if we're in a git repository ---
try {
    $null = git rev-parse --git-dir 2>$null
} catch {
    Write-Host "Not in a git repository. Please navigate to a git repository and try again." -ForegroundColor Red
    exit 1
}

# --- Check if there are any commits ---
try {
    $null = git rev-parse HEAD 2>$null
} catch {
    Write-Host "No commits found in this repository. Please make at least one commit first." -ForegroundColor Red
    exit 1
}

Write-Host "Track Remote Branch Tool" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host ""

# --- Get current branch ---
$CurrentBranch = git branch --show-current
Write-Host "📍 Current branch: $CurrentBranch" -ForegroundColor Yellow
Write-Host ""

# --- Step 1: Fetch all remote branches ---
Write-Host "Step 1: Fetching remote branches..." -ForegroundColor Cyan
Write-Host ""

# Fetch all branches from all remotes
$fetchResult = git fetch origin 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to fetch remote branches." -ForegroundColor Red
    exit 1
}
Write-Host "Remote branches fetched successfully." -ForegroundColor Green

# --- Step 2: Get all remote branches ---
Write-Host "Step 2: Found $($remoteBranches.Count) remote branches:" -ForegroundColor Cyan
$remoteBranches | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

# --- Step 3: Get all local branches ---
Write-Host "Step 3: Checking which remote branches are already tracked..." -ForegroundColor Cyan

$untrackedBranches = @()
foreach ($remoteBranch in $remoteBranches) {
    $branchName = $remoteBranch.Replace("origin/", "")
    if ($localBranches -notcontains $branchName) {
        $untrackedBranches += $remoteBranch
    }
}

if ($untrackedBranches.Count -eq 0) {
    Write-Host "All remote branches are already tracked locally." -ForegroundColor Green
    exit 0
}

Write-Host "You can track these remote branches locally." -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "Do you want to track untracked remote branches? [y/N]"
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "Operation cancelled." -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "Step 4: Finding untracked remote branches..." -ForegroundColor Cyan

$branchesToTrack = @()
foreach ($branch in $untrackedBranches) {
    $branchName = $branch.Replace("origin/", "")
    Write-Host "  $branchName" -ForegroundColor Gray
    $track = Read-Host "    Track this branch? [y/N]"
    if ($track -match "^[Yy]$") {
        $branchesToTrack += $branch
    }
}

if ($branchesToTrack.Count -eq 0) {
    Write-Host "No valid branches selected." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Selected branches to track:" -ForegroundColor Cyan
$branchesToTrack | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }

$finalConfirm = Read-Host "Proceed with tracking these branches? [y/N]"
if ($finalConfirm -notmatch "^[Yy]$") {
    Write-Host "Operation cancelled." -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "Step 5: Tracking selected branches..." -ForegroundColor Cyan

$currentBranch = git branch --show-current
$failedBranches = @()

foreach ($branch in $branchesToTrack) {
    $branchName = $branch.Replace("origin/", "")
    Write-Host "  Creating local branch '$branchName'..." -ForegroundColor Cyan
    
    # Create local branch tracking the remote branch
    $result = git checkout -b $branchName $branch 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    Successfully tracked '$branchName'" -ForegroundColor Green
    } else {
        Write-Host "   Failed to create local branch '$branchName'" -ForegroundColor Red
        $failedBranches += $branchName
    }
}

# Switch back to original branch
Write-Host ""
Write-Host "Switching back to original branch..." -ForegroundColor Cyan
git checkout $currentBranch | Out-Null

Write-Host ""
if ($failedBranches.Count -gt 0) {
    Write-Host "Failed to track branches:" -ForegroundColor Red
    $failedBranches | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
} else {
    Write-Host "Successfully tracked all selected branches!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Tip: You can now switch to these branches using:" -ForegroundColor Cyan
    $branchesToTrack | ForEach-Object { 
        $branchName = $_.Replace("origin/", "")
        Write-Host "  git checkout $branchName" -ForegroundColor Gray 
    }
    
    $remaining = $untrackedBranches.Count - $branchesToTrack.Count
    if ($remaining -gt 0) {
        Write-Host ""
        Write-Host "Tip: You still have $remaining untracked remote branch(es)." -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "Your local repository now has access to the tracked remote branches!" -ForegroundColor Green
} 