# -----------------------------------------------------------------------------
# Script: sync_check.ps1
# Description: Checks if current branch is in sync with remote and offers sync options
# Platform: Windows PowerShell 5.1 compatible
# -----------------------------------------------------------------------------

param(
    [string]$BranchToCheck
)

# --- Get current branch ---
$CurrentBranch = git branch --show-current
if (-not $CurrentBranch) {
    Write-Host "Could not detect current Git branch." -ForegroundColor Red
    exit 1
}

if ($BranchToCheck -and $BranchToCheck -ne $CurrentBranch) {
    # Ensure working tree is clean before switching
    git diff --quiet 2>$null
    $hasWorkingChanges = ($LASTEXITCODE -ne 0)
    git diff --cached --quiet 2>$null
    $hasStagedChanges = ($LASTEXITCODE -ne 0)

    if ($hasWorkingChanges -or $hasStagedChanges) {
        Write-Host "You have uncommitted changes. Please commit or stash them before checking another branch." -ForegroundColor Red
        exit 1
    }

    Write-Host "Switching to branch '$BranchToCheck' for sync check..." -ForegroundColor Cyan
    git checkout $BranchToCheck | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to checkout branch '$BranchToCheck'." -ForegroundColor Red
        exit 1
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    $result = $LASTEXITCODE

    Write-Host "Switching back to original branch '$CurrentBranch'..." -ForegroundColor Cyan
    git checkout $CurrentBranch | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to switch back to original branch '$CurrentBranch'." -ForegroundColor Red
        exit 1
    }

    exit $result
}

# --- Check if current branch has a remote tracking branch ---
try {
    $null = git rev-parse --verify "origin/$CurrentBranch" 2>$null
} catch {
    Write-Host "Current branch '$CurrentBranch' has no remote tracking branch." -ForegroundColor Yellow
    Write-Host "   This is normal for new branches that haven't been pushed yet." -ForegroundColor Yellow
    Write-Host "   Proceeding with operation..." -ForegroundColor Green
    exit 0
}

# --- Fetch latest remote information ---
Write-Host "Fetching latest remote information..." -ForegroundColor Cyan
$fetchResult = git fetch origin $CurrentBranch 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to fetch remote information for branch '$CurrentBranch'." -ForegroundColor Red
    Write-Host "   Please check your network connection and remote configuration." -ForegroundColor Yellow
    exit 1
}

# --- Check branch status ---
$LocalCommit = git rev-parse HEAD
$RemoteCommit = git rev-parse "origin/$CurrentBranch"

if ($LocalCommit -eq $RemoteCommit) {
    Write-Host "Branch '$CurrentBranch' is up-to-date with remote." -ForegroundColor Green
    exit 0
}

# --- Check if local is ahead, behind, or diverged ---
$LocalAhead = git rev-list --count "origin/$CurrentBranch"..HEAD 2>$null
if ($LASTEXITCODE -ne 0) { $LocalAhead = 0 }

$RemoteAhead = git rev-list --count HEAD.."origin/$CurrentBranch" 2>$null
if ($LASTEXITCODE -ne 0) { $RemoteAhead = 0 }

Write-Host ""
Write-Host "Branch '$CurrentBranch' is not in sync with remote:" -ForegroundColor Yellow

if ($LocalAhead -gt 0 -and $RemoteAhead -eq 0) {
    Write-Host "   Local is $LocalAhead commit(s) ahead of remote" -ForegroundColor Blue
    Write-Host "   You can push your changes: git push" -ForegroundColor Cyan
} elseif ($LocalAhead -eq 0 -and $RemoteAhead -gt 0) {
    Write-Host "   Local is $RemoteAhead commit(s) behind remote" -ForegroundColor Yellow
    Write-Host "   You should pull remote changes: git pull" -ForegroundColor Cyan
} elseif ($LocalAhead -gt 0 -and $RemoteAhead -gt 0) {
    Write-Host "   Local and remote have diverged" -ForegroundColor Red
    Write-Host "   Local is $LocalAhead commit(s) ahead" -ForegroundColor Blue
    Write-Host "   Remote is $RemoteAhead commit(s) ahead" -ForegroundColor Yellow
    Write-Host "   You need to merge or rebase: git pull --rebase" -ForegroundColor Cyan
}

Write-Host ""

# --- Show recent commits for context ---
if ($RemoteAhead -gt 0) {
    Write-Host "Recent remote commits you don't have:" -ForegroundColor Yellow
    $remoteCommits = git log --oneline HEAD.."origin/$CurrentBranch" 2>$null
    $remoteCommits | Select-Object -First 5 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    if ($RemoteAhead -gt 5) {
        Write-Host "   ... and $($RemoteAhead - 5) more commits" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($LocalAhead -gt 0) {
    Write-Host "Your recent commits not on remote:" -ForegroundColor Blue
    $localCommits = git log --oneline "origin/$CurrentBranch"..HEAD 2>$null
    $localCommits | Select-Object -First 5 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    if ($LocalAhead -gt 5) {
        Write-Host "   ... and $($LocalAhead - 5) more commits" -ForegroundColor Gray
    }
    Write-Host ""
}

# --- Offer sync options ---
Write-Host "Sync options:" -ForegroundColor Cyan
Write-Host ""

$options = @()

if ($RemoteAhead -gt 0) {
    Write-Host "1) Pull remote changes (git pull)" -ForegroundColor Green
    Write-Host "2) Pull with rebase (git pull --rebase)" -ForegroundColor Green
    $options += 1, 2
}

if ($LocalAhead -gt 0) {
    Write-Host "3) Push local changes (git push)" -ForegroundColor Blue
    $options += 3
}

if ($LocalAhead -gt 0 -and $RemoteAhead -gt 0) {
    Write-Host "4) Force push (git push --force-with-lease) - USE WITH CAUTION" -ForegroundColor Red
    $options += 4
}

Write-Host "5) Skip sync and continue anyway" -ForegroundColor Yellow
Write-Host "6) Cancel operation" -ForegroundColor Red

$options += 5, 6

Write-Host ""
$choice = Read-Host "Choose an option [1-6]"

switch ($choice) {
    1 {
        if ($RemoteAhead -gt 0) {
            Write-Host "Pulling remote changes..." -ForegroundColor Cyan
            $pullResult = git pull origin $CurrentBranch 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully pulled remote changes." -ForegroundColor Green
                exit 0
            } else {
                Write-Host "Failed to pull remote changes." -ForegroundColor Red
                Write-Host "   You may need to resolve conflicts manually." -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "Invalid option for current branch status." -ForegroundColor Red
            exit 1
        }
    }
    2 {
        if ($RemoteAhead -gt 0) {
            Write-Host "Pulling remote changes with rebase..." -ForegroundColor Cyan
            $pullResult = git pull --rebase origin $CurrentBranch 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully pulled remote changes with rebase." -ForegroundColor Green
                exit 0
            } else {
                Write-Host "Failed to pull remote changes with rebase." -ForegroundColor Red
                Write-Host "   You may need to resolve conflicts manually." -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "Invalid option for current branch status." -ForegroundColor Red
            exit 1
        }
    }
    3 {
        if ($LocalAhead -gt 0) {
            Write-Host "Pushing local changes..." -ForegroundColor Cyan
            $pushResult = git push origin $CurrentBranch 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully pushed local changes." -ForegroundColor Green
                exit 0
            } else {
                Write-Host "Failed to push local changes." -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Invalid option for current branch status." -ForegroundColor Red
            exit 1
        }
    }
    4 {
        if ($LocalAhead -gt 0 -and $RemoteAhead -gt 0) {
            Write-Host "WARNING: Force push will overwrite remote changes!" -ForegroundColor Red
            Write-Host "   This can cause data loss if others have pushed changes." -ForegroundColor Yellow
            $confirm = Read-Host "Are you absolutely sure? Type 'yes' to confirm"
            if ($confirm -eq "yes") {
                Write-Host "Force pushing local changes..." -ForegroundColor Cyan
                $pushResult = git push --force-with-lease origin $CurrentBranch 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully force pushed local changes." -ForegroundColor Green
                    exit 0
                } else {
                    Write-Host "Failed to force push local changes." -ForegroundColor Red
                    exit 1
                }
            } else {
                Write-Host "Force push cancelled." -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "Invalid option for current branch status." -ForegroundColor Red
            exit 1
        }
    }
    5 {
        Write-Host "Proceeding without syncing. This may cause merge conflicts later." -ForegroundColor Yellow
        exit 0
    }
    6 {
        Write-Host "Operation cancelled." -ForegroundColor Red
        exit 1
    }
    default {
        Write-Host "Invalid choice. Please select a valid option." -ForegroundColor Red
        exit 1
    }
} 