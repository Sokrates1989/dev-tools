# -----------------------------------------------------------------------------
# Script: sync_branches.ps1
#
# Description:
# This script fully fetches all remote branches and offers to pull changes
# for each local branch. It provides a comprehensive way to keep your local
# repository in sync with the remote repository.
#
# The script:
# 1. Fetches all remote branches and updates remote tracking
# 2. Identifies all local branches
# 3. Shows the status of each local branch (ahead, behind, up-to-date)
# 4. Offers to pull changes for each branch individually
# 5. Provides detailed feedback on the sync process
# -----------------------------------------------------------------------------

# --- Resolve paths ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir\..\.." | Select-Object -ExpandProperty Path

# Load environment variables.
. "$RootDir\global_functions\load_dotenv.ps1"
Load-DotEnv

# --- Git update check ---
& "$RootDir\global_functions\check_for_updates.ps1"

# --- Check if we're in a git repository ---
try {
    $null = git rev-parse --git-dir 2>$null
} catch {
    Write-Host "[ERROR] Not in a git repository. Please navigate to a git repository and try again."
    exit 1
}

# --- Check if there are any commits ---
try {
    $null = git rev-parse HEAD 2>$null
} catch {
    Write-Host "[ERROR] No commits found in this repository. Please make at least one commit first."
    exit 1
}

Write-Host ""
Write-Host "Branch Sync Tool"
Write-Host "=================="
Write-Host ""
Write-Host "This tool will fetch all remote branches and help you sync your local branches."
Write-Host ""

# --- Get current branch ---
$CurrentBranch = git branch --show-current
Write-Host "Current branch: $CurrentBranch"
Write-Host ""

# --- Step 1: Fetch all remote branches ---
Write-Host "Step 1: Fetching all remote branches..."
Write-Host ""

# Fetch all branches from all remotes
git fetch --all --prune
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Successfully fetched all remote branches."
} else {
    Write-Host "[ERROR] Failed to fetch remote branches."
    exit 1
}

# Update remote tracking branches
git remote update --prune
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Successfully updated remote tracking branches."
} else {
    Write-Host "[WARNING] Failed to update some remote tracking branches."
}

Write-Host ""

# --- Step 2: Get all local branches ---
Write-Host "Step 2: Analyzing local branches..."
Write-Host ""

$LocalBranches = git branch --format='%(refname:short)'
$BranchCount = ($LocalBranches -split "`n" | Where-Object { $_ -ne "" }).Count

Write-Host "Found $BranchCount local branch(es):"
Write-Host ""

# --- Step 3: Analyze each branch ---
$BranchesToSync = @()
$BranchesUpToDate = @()
$BranchesAhead = @()
$BranchesBehind = @()
$BranchesDiverged = @()
$BranchesNoRemote = @()

foreach ($branch in $LocalBranches) {
    if ([string]::IsNullOrWhiteSpace($branch)) { continue }
    
    Write-Host "Analyzing: $branch"
    
    # Check if branch has a remote tracking branch
    $RemoteBranch = ""
    try {
        $RemoteBranch = git rev-parse --abbrev-ref --symbolic-full-name "$branch@{upstream}" 2>$null
    } catch {
        $RemoteBranch = ""
    }
    
    if ([string]::IsNullOrWhiteSpace($RemoteBranch)) {
        Write-Host "   [WARNING] No remote tracking branch found"
        $BranchesNoRemote += $branch
        Write-Host ""
        continue
    }
    
    # Get the status of the branch relative to its remote
    $LocalCommit = git rev-parse $branch
    $RemoteCommit = git rev-parse $RemoteBranch
    
    if ($LocalCommit -eq $RemoteCommit) {
        Write-Host "   [OK] Up to date"
        $BranchesUpToDate += $branch
    } else {
        # Check if ahead, behind, or diverged
        $LocalAhead = 0
        $RemoteAhead = 0
        
        try {
            $LocalAhead = git rev-list --count "$RemoteBranch..$branch" 2>$null
        } catch {
            $LocalAhead = 0
        }
        
        try {
            $RemoteAhead = git rev-list --count "$branch..$RemoteBranch" 2>$null
        } catch {
            $RemoteAhead = 0
        }
        
        if ($LocalAhead -gt 0 -and $RemoteAhead -eq 0) {
            Write-Host "   [AHEAD] Ahead by $LocalAhead commit(s)"
            $BranchesAhead += $branch
        } elseif ($LocalAhead -eq 0 -and $RemoteAhead -gt 0) {
            Write-Host "   [BEHIND] Behind by $RemoteAhead commit(s)"
            $BranchesBehind += $branch
            $BranchesToSync += $branch
        } elseif ($LocalAhead -gt 0 -and $RemoteAhead -gt 0) {
            Write-Host "   [DIVERGED] Diverged (local: +$LocalAhead, remote: +$RemoteAhead)"
            $BranchesDiverged += $branch
            $BranchesToSync += $branch
        } else {
            Write-Host "   [OK] Up to date"
            $BranchesUpToDate += $branch
        }
    }
    
    Write-Host ""
}

# --- Step 4: Display summary ---
Write-Host "Branch Status Summary:"
Write-Host ""

if ($BranchesUpToDate.Count -gt 0) {
    Write-Host "[OK] Up to date ($($BranchesUpToDate.Count)):"
    foreach ($branch in $BranchesUpToDate) {
        Write-Host "   $branch"
    }
    Write-Host ""
}

if ($BranchesAhead.Count -gt 0) {
    Write-Host "[AHEAD] Ahead of remote ($($BranchesAhead.Count)):"
    foreach ($branch in $BranchesAhead) {
        Write-Host "   $branch"
    }
    Write-Host ""
}

if ($BranchesBehind.Count -gt 0) {
    Write-Host "[BEHIND] Behind remote ($($BranchesBehind.Count)):"
    foreach ($branch in $BranchesBehind) {
        Write-Host "   $branch"
    }
    Write-Host ""
}

if ($BranchesDiverged.Count -gt 0) {
    Write-Host "[DIVERGED] Diverged from remote ($($BranchesDiverged.Count)):"
    foreach ($branch in $BranchesDiverged) {
        Write-Host "   $branch"
    }
    Write-Host ""
}

if ($BranchesNoRemote.Count -gt 0) {
    Write-Host "[WARNING] No remote tracking ($($BranchesNoRemote.Count)):"
    foreach ($branch in $BranchesNoRemote) {
        Write-Host "   $branch"
    }
    Write-Host ""
}

# --- Step 5: Offer to sync branches ---
if ($BranchesToSync.Count -eq 0) {
    Write-Host "[OK] All branches are up to date!"
    exit 0
}

Write-Host "Branches that can be synced: $($BranchesToSync.Count)"
Write-Host ""

$confirm = Read-Host "Do you want to sync these branches? [y/N]"
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "[CANCELLED] Sync cancelled."
    exit 0
}

Write-Host ""

# --- Step 6: Sync each branch ---
$SyncedBranches = @()
$FailedSyncs = @()

foreach ($branch in $BranchesToSync) {
    Write-Host "Processing: $branch"
    
    # Check if this is the current branch
    if ($branch -eq $CurrentBranch) {
        Write-Host "   [INFO] This is your current branch"
        $confirmPull = Read-Host "   Pull changes for current branch '$branch'? [y/N]"
    } else {
        $confirmPull = Read-Host "   Pull changes for branch '$branch'? [y/N]"
    }
    
    if ($confirmPull -match "^[Yy]$") {
        Write-Host "   Pulling changes..."
        
        # Switch to the branch if it's not the current one
        if ($branch -ne $CurrentBranch) {
            git checkout $branch
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   [OK] Switched to $branch"
            } else {
                Write-Host "   [ERROR] Failed to switch to $branch"
                $FailedSyncs += "$branch (switch failed)"
                Write-Host ""
                continue
            }
        }
        
        # Pull the changes
        git pull
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   [OK] Successfully pulled changes for $branch"
            $SyncedBranches += $branch
        } else {
            Write-Host "   [ERROR] Failed to pull changes for $branch"
            $FailedSyncs += "$branch (pull failed)"
        }
        
        # Switch back to original branch if needed
        if ($branch -ne $CurrentBranch) {
            git checkout $CurrentBranch
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   [OK] Switched back to $CurrentBranch"
            } else {
                Write-Host "   [WARNING] Failed to switch back to $CurrentBranch"
            }
        }
    } else {
        Write-Host "   [SKIPPED] Skipped $branch"
    }
    
    Write-Host ""
}

# --- Step 7: Final summary ---
Write-Host "[OK] Branch sync completed!"
Write-Host ""

if ($SyncedBranches.Count -gt 0) {
    Write-Host "[OK] Successfully synced branches:"
    foreach ($branch in $SyncedBranches) {
        Write-Host "   $branch"
    }
    Write-Host ""
}

if ($FailedSyncs.Count -gt 0) {
    Write-Host "[ERROR] Failed syncs:"
    foreach ($failure in $FailedSyncs) {
        Write-Host "   [WARNING] $failure"
    }
    Write-Host ""
}

if ($BranchesAhead.Count -gt 0) {
    Write-Host "[INFO] Tip: You have $($BranchesAhead.Count) branch(es) ahead of remote."
    Write-Host "   Consider pushing these changes when ready."
    Write-Host ""
}

if ($BranchesNoRemote.Count -gt 0) {
    Write-Host "[INFO] Tip: You have $($BranchesNoRemote.Count) branch(es) without remote tracking."
    Write-Host "   Consider setting up remote tracking with: git branch --set-upstream-to=origin/<branch> <branch>"
    Write-Host ""
}

Write-Host "[OK] Your repository is now up to date!" 