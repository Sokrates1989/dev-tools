# -----------------------------------------------------------------------------
# Script: branch_cleanup.ps1
#
# Description:
# This script identifies local branches (other than main and dev) that are
# fully merged with either main or dev, and offers to remove them both
# locally and remotely with user confirmation for each branch.
#
# The script:
# 1. Checks if we're in a git repository
# 2. Identifies local branches other than main and dev
# 3. Checks which branches are fully merged with main or dev
# 4. Asks for confirmation to remove each branch locally and remotely
# 5. Performs the removal with detailed feedback
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
Write-Host "Branch Cleanup Tool"
Write-Host "====================="
Write-Host ""
Write-Host "This tool will identify and remove local branches that are fully merged"
Write-Host "with either main or dev branches (excluding main and dev themselves)."
Write-Host ""

# --- Get current branch ---
$CurrentBranch = git branch --show-current
Write-Host "Current branch: $CurrentBranch"
Write-Host ""

# --- Check if main and dev branches exist ---
$MainExists = $false
$DevExists = $false

try {
    $null = git show-ref --verify --quiet refs/heads/main 2>$null
    $MainExists = $true
} catch {
    $MainExists = $false
}

try {
    $null = git show-ref --verify --quiet refs/heads/dev 2>$null
    $DevExists = $true
} catch {
    $DevExists = $false
}

if (-not $MainExists -and -not $DevExists) {
    Write-Host "[ERROR] Neither 'main' nor 'dev' branches exist in this repository."
    Write-Host "   This tool requires at least one of these branches to exist."
    exit 1
}

Write-Host "Available merge targets:"
if ($MainExists) {
    Write-Host "   [OK] main"
}
if ($DevExists) {
    Write-Host "   [OK] dev"
}
Write-Host ""

# --- Get all local branches ---
$LocalBranches = git branch --format='%(refname:short)'

# --- Filter out main and dev branches ---
$CandidateBranches = @()
foreach ($branch in $LocalBranches) {
    if ($branch -ne "main" -and $branch -ne "dev") {
        $CandidateBranches += $branch
    }
}

if ($CandidateBranches.Count -eq 0) {
    Write-Host "[OK] No branches to check (only main and dev exist)."
    exit 0
}

Write-Host "Checking $($CandidateBranches.Count) local branches for merge status..."
Write-Host ""

# --- Check merge status for each branch ---
$MergedBranches = @()
$UnmergedBranches = @()

foreach ($branch in $CandidateBranches) {
    $IsMerged = $false
    $MergedInto = ""
    
    # Check if merged into main
    if ($MainExists) {
        $mergedIntoMain = git branch --merged main
        if ($mergedIntoMain -match "^\s*$branch$") {
            $IsMerged = $true
            $MergedInto = "main"
        }
    }
    
    # Check if merged into dev (if not already found merged into main)
    if (-not $IsMerged -and $DevExists) {
        $mergedIntoDev = git branch --merged dev
        if ($mergedIntoDev -match "^\s*$branch$") {
            $IsMerged = $true
            $MergedInto = "dev"
        }
    }
    
    if ($IsMerged) {
        $MergedBranches += "$branch|$MergedInto"
    } else {
        $UnmergedBranches += $branch
    }
}

# --- Display results ---
if ($MergedBranches.Count -eq 0) {
    Write-Host "[OK] No fully merged branches found."
    Write-Host ""
    if ($UnmergedBranches.Count -gt 0) {
        Write-Host "Unmerged branches:"
        foreach ($branch in $UnmergedBranches) {
            Write-Host "   [WARNING] $branch"
        }
        Write-Host ""
        Write-Host "[INFO] These branches still have unmerged changes."
    }
    exit 0
}

Write-Host "[OK] Found $($MergedBranches.Count) fully merged branch(es):"
foreach ($branchInfo in $MergedBranches) {
    $parts = $branchInfo -split '\|'
    $branch = $parts[0]
    $mergedInto = $parts[1]
    Write-Host "   [MERGED] $branch (merged into $mergedInto)"
}
Write-Host ""

if ($UnmergedBranches.Count -gt 0) {
    Write-Host "[WARNING] Unmerged branches (will be preserved):"
    foreach ($branch in $UnmergedBranches) {
        Write-Host "   [UNMERGED] $branch"
    }
    Write-Host ""
}

# --- Check if current branch is in the merged list ---
$CurrentBranchMerged = $false
foreach ($branchInfo in $MergedBranches) {
    $parts = $branchInfo -split '\|'
    $branch = $parts[0]
    if ($branch -eq $CurrentBranch) {
        $CurrentBranchMerged = $true
        break
    }
}

if ($CurrentBranchMerged) {
    Write-Host "[WARNING] You are currently on a merged branch ($CurrentBranch)."
    Write-Host "   You should switch to main or dev before removing branches."
    Write-Host ""
    $confirm = Read-Host "Do you want to switch to main first? [Y/n]"
    if ($confirm -ne "n" -and $confirm -ne "N") {
        if ($MainExists) {
            Write-Host "Switching to main branch..."
            git checkout main
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERROR] Failed to switch to main branch."
                exit 1
            }
            Write-Host "[OK] Switched to main branch."
        } elseif ($DevExists) {
            Write-Host "Switching to dev branch..."
            git checkout dev
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERROR] Failed to switch to dev branch."
                exit 1
            }
            Write-Host "[OK] Switched to dev branch."
        }
        Write-Host ""
    } else {
        Write-Host "[ERROR] Operation cancelled. Please switch branches manually and try again."
        exit 0
    }
}

# --- Process each merged branch ---
Write-Host "Ready to remove merged branches..."
Write-Host ""

$RemovedLocal = @()
$RemovedRemote = @()
$FailedRemovals = @()

foreach ($branchInfo in $MergedBranches) {
    $parts = $branchInfo -split '\|'
    $branch = $parts[0]
    $mergedInto = $parts[1]
    
    Write-Host "Processing: $branch (merged into $mergedInto)"
    Write-Host ""
    
    # Check if branch exists remotely
    $RemoteExists = $false
    try {
        $remoteBranches = git ls-remote --heads origin $branch
        if ($remoteBranches -match $branch) {
            $RemoteExists = $true
        }
    } catch {
        $RemoteExists = $false
    }
    
    # Ask for local removal
    $confirmLocal = Read-Host "Remove '$branch' locally? [y/N]"
    if ($confirmLocal -match "^[Yy]$") {
        Write-Host "Removing local branch '$branch'..."
        git branch -d $branch
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Successfully removed local branch '$branch'."
            $RemovedLocal += $branch
        } else {
            Write-Host "[ERROR] Failed to remove local branch '$branch'."
            $FailedRemovals += "local:$branch"
        }
    } else {
        Write-Host "[SKIP] Skipped local removal of '$branch'."
    }
    
    # Ask for remote removal (if branch exists remotely)
    if ($RemoteExists) {
        $confirmRemote = Read-Host "Remove '$branch' from remote (origin)? [y/N]"
        if ($confirmRemote -match "^[Yy]$") {
            Write-Host "Removing remote branch '$branch'..."
            git push origin --delete $branch
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Successfully removed remote branch '$branch'."
                $RemovedRemote += $branch
            } else {
                Write-Host "[ERROR] Failed to remove remote branch '$branch'."
                $FailedRemovals += "remote:$branch"
            }
        } else {
            Write-Host "[SKIP] Skipped remote removal of '$branch'."
        }
    } else {
        Write-Host "[INFO] Branch '$branch' doesn't exist on remote."
    }
    
    Write-Host ""
}

# --- Function to detect stale remote references ---
function Get-StaleRemoteBranches {
    param(
        [string]$RemoteName = "origin"
    )
    
    $staleBranches = @()
    
    try {
        # Run git fetch with prune dry-run to detect stale references
        $fetchOutput = git fetch $RemoteName --prune --dry-run 2>&1
        
        # Parse output to find what would be pruned
        foreach ($line in $fetchOutput) {
            if ($line -match "\[would prune\].*$RemoteName/(.+)") {
                $staleBranches += "$RemoteName/$($matches[1])"
            } elseif ($line -match "^\s*-\s*\[would prune\].*$RemoteName/(.+)") {
                $staleBranches += "$RemoteName/$($matches[1])"
            }
        }
    } catch {
        # If fetch fails, return empty array
    }
    
    return $staleBranches
}

# --- Summary ---
Write-Host "Branch cleanup completed!"
Write-Host ""

if ($RemovedLocal.Count -gt 0) {
    Write-Host "[OK] Successfully removed local branches:"
    foreach ($branch in $RemovedLocal) {
        Write-Host "   [REMOVED] $branch"
    }
    Write-Host ""
}

if ($RemovedRemote.Count -gt 0) {
    Write-Host "[OK] Successfully removed remote branches:"
    foreach ($branch in $RemovedRemote) {
        Write-Host "   [REMOTE] $branch"
    }
    Write-Host ""
}

if ($FailedRemovals.Count -gt 0) {
    Write-Host "[ERROR] Failed removals:"
    foreach ($failure in $FailedRemovals) {
        Write-Host "   [FAILED] $failure"
    }
    Write-Host ""
}

if ($RemovedLocal.Count -eq 0 -and $RemovedRemote.Count -eq 0) {
    Write-Host "[INFO] No branches were removed."
}

# --- Check for stale remote-tracking branches ---
Write-Host "Checking for stale remote-tracking references..."

# Get stale remote branches
$StaleRefs = Get-StaleRemoteBranches

if ($StaleRefs.Count -gt 0) {
    Write-Host ""
    Write-Host "Found stale remote-tracking references:"
    foreach ($ref in $StaleRefs) {
        Write-Host "   - $ref"
    }
    Write-Host ""
    Write-Host "[INFO] These are local cached references to remote branches that"
    Write-Host "   have been deleted. They can be safely cleaned up with:"
    Write-Host "   'git remote prune origin'"
    Write-Host ""
    
    # Ask user if they want to prune
    $choice = Read-Host "Clean up stale remote references now? [y/N]"
    if ($choice -match "^[Yy]$") {
        Write-Host "Running 'git remote prune origin'..."
        git remote prune origin
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Stale references cleaned up."
        } else {
            Write-Host "[ERROR] Failed to prune remote references."
        }
    } else {
        Write-Host "[INFO] Skipped. Run 'git remote prune origin' manually when needed."
    }
} else {
    Write-Host "[OK] Your remote-tracking references are already clean!"
} 