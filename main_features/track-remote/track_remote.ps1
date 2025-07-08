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
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value -Scope Global
        }
    }
} else {
    Write-Host "❌ .env file not found at $EnvFile" -ForegroundColor Red
    exit 1
}

# --- Git update check ---
& "$RootDir\global_functions\check_for_updates.ps1"

# --- Check if we're in a git repository ---
try {
    $null = git rev-parse --git-dir 2>$null
} catch {
    Write-Host "❌ Not in a git repository. Please navigate to a git repository and try again." -ForegroundColor Red
    exit 1
}

# --- Check if there are any commits ---
try {
    $null = git rev-parse HEAD 2>$null
} catch {
    Write-Host "❌ No commits found in this repository. Please make at least one commit first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📡 Track Remote Branch Tool" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This tool will help you track remote branches locally by creating"
Write-Host "local branches that track the selected remote branches."
Write-Host ""

# --- Get current branch ---
$CurrentBranch = git branch --show-current
Write-Host "📍 Current branch: $CurrentBranch" -ForegroundColor Yellow
Write-Host ""

# --- Step 1: Fetch all remote branches ---
Write-Host "📥 Step 1: Fetching all remote branches..." -ForegroundColor Cyan
Write-Host ""

# Fetch all branches from all remotes
$fetchResult = git fetch --all --prune 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully fetched all remote branches." -ForegroundColor Green
} else {
    Write-Host "❌ Failed to fetch remote branches." -ForegroundColor Red
    Write-Host $fetchResult -ForegroundColor Red
    exit 1
}

Write-Host ""

# --- Step 2: Get all remote branches ---
Write-Host "📋 Step 2: Analyzing remote branches..." -ForegroundColor Cyan
Write-Host ""

# Get all remote branches (excluding HEAD)
$RemoteBranches = git branch -r --format='%(refname:short)' | Where-Object { $_ -notmatch 'HEAD$' } | ForEach-Object { $_ -replace '^origin/', '' }

if (-not $RemoteBranches) {
    Write-Host "❌ No remote branches found." -ForegroundColor Red
    Write-Host "   Make sure you have a remote configured and remote branches exist." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found remote branches:"
foreach ($branch in $RemoteBranches) {
    if ($branch) {
        Write-Host "   🌐 $branch" -ForegroundColor Blue
    }
}
Write-Host ""

# --- Step 3: Get all local branches ---
Write-Host "📋 Step 3: Analyzing local branches..." -ForegroundColor Cyan
Write-Host ""

$LocalBranches = git branch --format='%(refname:short)'

Write-Host "Found local branches:"
foreach ($branch in $LocalBranches) {
    if ($branch) {
        Write-Host "   📁 $branch" -ForegroundColor Green
    }
}
Write-Host ""

# --- Step 4: Find untracked remote branches ---
Write-Host "🔍 Step 4: Finding untracked remote branches..." -ForegroundColor Cyan
Write-Host ""

$UntrackedRemoteBranches = @()
$TrackedBranches = @()

foreach ($remoteBranch in $RemoteBranches) {
    # Check if a local branch with the same name exists
    if ($LocalBranches -contains $remoteBranch) {
        $TrackedBranches += $remoteBranch
    } else {
        $UntrackedRemoteBranches += $remoteBranch
    }
}

# --- Step 5: Display results ---
if ($TrackedBranches.Count -gt 0) {
    Write-Host "✅ Already tracked locally ($($TrackedBranches.Count)):" -ForegroundColor Green
    foreach ($branch in $TrackedBranches) {
        Write-Host "   📁 $branch" -ForegroundColor Green
    }
    Write-Host ""
}

if ($UntrackedRemoteBranches.Count -eq 0) {
    Write-Host "🎉 All remote branches are already tracked locally!" -ForegroundColor Green
    exit 0
}

Write-Host "🌐 Untracked remote branches ($($UntrackedRemoteBranches.Count)):" -ForegroundColor Yellow
for ($i = 0; $i -lt $UntrackedRemoteBranches.Count; $i++) {
    Write-Host "   $($i+1))) $($UntrackedRemoteBranches[$i])" -ForegroundColor Blue
}
Write-Host ""

# --- Step 6: Offer to track branches ---
Write-Host "🔄 You can track these remote branches locally." -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "🤔 Do you want to track any of these branches? [y/N]"
if ($confirm -notmatch '^[Yy]$') {
    Write-Host "❌ Operation cancelled." -ForegroundColor Red
    exit 0
}

Write-Host ""

# --- Step 7: Select branches to track ---
$TrackedBranchesNew = @()
$FailedTracks = @()

Write-Host "📋 Select branches to track (enter numbers or branch names separated by spaces, or 'all' for all):" -ForegroundColor Cyan
Write-Host ""

$selection = Read-Host "Enter your selection"

# Parse the selection
$SelectedIndices = @()

if ($selection -eq "all" -or $selection -eq "ALL") {
    # Select all branches
    for ($i = 0; $i -lt $UntrackedRemoteBranches.Count; $i++) {
        $SelectedIndices += $i
    }
} else {
    # Parse individual selections (numbers or branch names)
    $items = $selection -split '\s+'
    foreach ($item in $items) {
        if ($item -match '^\d+$') {
            # Handle numeric selection
            $index = [int]$item - 1
            if ($index -ge 0 -and $index -lt $UntrackedRemoteBranches.Count) {
                $SelectedIndices += $index
            } else {
                Write-Host "⚠️  Invalid selection: $item (out of range)" -ForegroundColor Yellow
            }
        } else {
            # Handle branch name selection
            $found = $false
            for ($i = 0; $i -lt $UntrackedRemoteBranches.Count; $i++) {
                if ($UntrackedRemoteBranches[$i] -eq $item) {
                    $SelectedIndices += $i
                    $found = $true
                    break
                }
            }
            if (-not $found) {
                Write-Host "⚠️  Invalid selection: $item (branch not found in untracked list)" -ForegroundColor Yellow
            }
        }
    }
}

if ($SelectedIndices.Count -eq 0) {
    Write-Host "❌ No valid branches selected." -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "🔄 Selected branches to track:" -ForegroundColor Cyan
foreach ($index in $SelectedIndices) {
    Write-Host "   🌐 $($UntrackedRemoteBranches[$index])" -ForegroundColor Blue
}
Write-Host ""

$confirmTrack = Read-Host "👉 Confirm tracking these branches? [y/N]"
if ($confirmTrack -notmatch '^[Yy]$') {
    Write-Host "❌ Operation cancelled." -ForegroundColor Red
    exit 0
}

Write-Host ""

# --- Step 8: Track selected branches ---
Write-Host "🔄 Step 5: Tracking selected branches..." -ForegroundColor Cyan
Write-Host ""

foreach ($index in $SelectedIndices) {
    $remoteBranch = $UntrackedRemoteBranches[$index]
    
    Write-Host "📋 Processing: $remoteBranch" -ForegroundColor Yellow
    
    # Create local branch tracking the remote branch
    $checkoutResult = git checkout -b $remoteBranch "origin/$remoteBranch" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Successfully created local branch '$remoteBranch' tracking 'origin/$remoteBranch'" -ForegroundColor Green
        $TrackedBranchesNew += $remoteBranch
    } else {
        Write-Host "   ❌ Failed to create local branch '$remoteBranch'" -ForegroundColor Red
        Write-Host "   Error: $checkoutResult" -ForegroundColor Red
        $FailedTracks += $remoteBranch
    }
    
    Write-Host ""
}

# --- Step 9: Switch back to original branch ---
$CurrentBranchAfter = git branch --show-current
if ($CurrentBranch -ne $CurrentBranchAfter) {
    Write-Host "🔄 Switching back to original branch..." -ForegroundColor Cyan
    $switchResult = git checkout $CurrentBranch 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Switched back to $CurrentBranch" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Warning: Failed to switch back to $CurrentBranch" -ForegroundColor Yellow
        Write-Host "Error: $switchResult" -ForegroundColor Yellow
    }
    Write-Host ""
}

# --- Step 10: Final summary ---
Write-Host "🎉 Remote branch tracking completed!" -ForegroundColor Green
Write-Host ""

if ($TrackedBranchesNew.Count -gt 0) {
    Write-Host "✅ Successfully tracked branches:" -ForegroundColor Green
    foreach ($branch in $TrackedBranchesNew) {
        Write-Host "   📁 $branch" -ForegroundColor Green
    }
    Write-Host ""
}

if ($FailedTracks.Count -gt 0) {
    Write-Host "❌ Failed to track branches:" -ForegroundColor Red
    foreach ($branch in $FailedTracks) {
        Write-Host "   ⚠️  $branch" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($TrackedBranchesNew.Count -gt 0) {
    Write-Host "💡 Tip: You can now switch to these branches using:" -ForegroundColor Cyan
    foreach ($branch in $TrackedBranchesNew) {
        Write-Host "   git checkout $branch" -ForegroundColor White
    }
    Write-Host ""
}

$remaining = $UntrackedRemoteBranches.Count - $SelectedIndices.Count
if ($remaining -gt 0) {
    Write-Host "💡 Tip: You still have $remaining untracked remote branch(es)." -ForegroundColor Cyan
    Write-Host "   Run this tool again to track the remaining branches." -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "🔄 Your local repository now has access to the tracked remote branches!" -ForegroundColor Green 