# -----------------------------------------------------------------------------
# Script: git_export_merge.ps1
#
# Description:
# PowerShell version of the merge commit message assistant. This script helps
# users merge branches with AI-generated commit messages, handling conflicts
# and providing guidance for resolution.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir\..\.." | Select-Object -ExpandProperty Path
$MergeDir = Join-Path $ScriptDir "git_export_merge"
$AllInOneDir = Join-Path $MergeDir "all_in_one"
$AiMessageFile = Join-Path $AllInOneDir "ai_message.txt"
$MergeMsgFile = Join-Path $ScriptDir "merge_message_prompt.txt"

# Create directories
if (-not (Test-Path $AllInOneDir)) {
    New-Item -ItemType Directory -Path $AllInOneDir -Force | Out-Null
}

# Load environment variables
. "$RootDir\global_functions\load_dotenv.ps1"
Load-DotEnv

# --- Git update check ---
& "$RootDir\global_functions\check_for_updates.ps1"

# --- Sync check before merge ---
Write-Host "Checking if branch is in sync with remote..." -ForegroundColor Cyan
$syncResult = & "$RootDir\global_functions\sync_check.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Sync check failed. Please resolve sync issues before merging." -ForegroundColor Red
    exit 1
}

# Detect uncommitted files
$null = git diff --quiet 2>$null
$hasWorkingChanges = ($LASTEXITCODE -ne 0)
$null = git diff --cached --quiet 2>$null
$hasStagedChanges = ($LASTEXITCODE -ne 0)

if ($hasWorkingChanges -or $hasStagedChanges) {
    Write-Host "[WARNING] You have uncommitted changes in your working directory." -ForegroundColor Yellow
    Write-Host "[INFO] Please commit or stash your changes before proceeding with the merge." -ForegroundColor Cyan
    exit 1
}

# --- Detect current branch ---
$CurrentBranch = git branch --show-current
if (-not $CurrentBranch) {
    Write-Host "[ERROR] Could not detect current Git branch." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Merge Commit Message Assistant" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "You are currently on branch: $CurrentBranch" -ForegroundColor Yellow
Write-Host ""

# --- List other local branches ---
$AvailableBranches = git for-each-ref --format='%(refname:short)' refs/heads | Where-Object { $_ -ne $CurrentBranch }

if (-not $AvailableBranches) {
    Write-Host "[WARNING] No other branches available to merge." -ForegroundColor Yellow
    exit 0
}

# --- Prompt for target branch ---
Write-Host "Select a branch to merge:" -ForegroundColor Cyan
$branchOptions = @()
$branchIndex = 1
foreach ($branch in $AvailableBranches) {
    Write-Host "$branchIndex) $branch" -ForegroundColor White
    $branchOptions += $branch
    $branchIndex++
}

Write-Host ""
$choice = Read-Host "Enter your choice [1-$($branchOptions.Count)]"

# Validate choice
if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $branchOptions.Count) {
    $TargetBranch = $branchOptions[[int]$choice - 1]
} else {
    Write-Host "[ERROR] Invalid selection. Please try again." -ForegroundColor Red
    exit 1
}

Write-Host "" 
Write-Host "Checking if target branch '$TargetBranch' is in sync with remote..." -ForegroundColor Cyan

Write-Host "Fetching latest remote information for '$TargetBranch'..." -ForegroundColor Cyan
$fetchTargetOutput = git fetch origin $TargetBranch 2>&1
if ($LASTEXITCODE -ne 0) {
    $fetchTargetText = ($fetchTargetOutput | Out-String)
    if ($fetchTargetText -match "couldn't find remote ref") {
        Write-Host "[WARNING] Target branch '$TargetBranch' has no remote tracking branch. Skipping remote sync check." -ForegroundColor Yellow
    } else {
        Write-Host "[ERROR] Failed to fetch remote information for branch '$TargetBranch'." -ForegroundColor Red
        Write-Host $fetchTargetText
        exit 1
    }
} else {
    $null = git rev-parse --verify "origin/$TargetBranch" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARNING] Target branch '$TargetBranch' has no remote tracking branch. Skipping remote sync check." -ForegroundColor Yellow
    } else {
        $targetLocalAhead = git rev-list --count "origin/$TargetBranch..$TargetBranch" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $targetLocalAhead) { $targetLocalAhead = 0 } else { $targetLocalAhead = [int]$targetLocalAhead }

        $targetRemoteAhead = git rev-list --count "$TargetBranch..origin/$TargetBranch" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $targetRemoteAhead) { $targetRemoteAhead = 0 } else { $targetRemoteAhead = [int]$targetRemoteAhead }

        if ($targetRemoteAhead -gt 0) {
            Write-Host "" 

            if ($targetLocalAhead -eq 0) {
                Write-Host "[WARNING] Target branch '$TargetBranch' is behind remote by $targetRemoteAhead commit(s)." -ForegroundColor Yellow
                $confirmUpdate = Read-Host " Switch to '$TargetBranch' and pull updates now? [Y/n]"
                if ($confirmUpdate -match '^[Nn]$') {
                    Write-Host "[ERROR] Aborting merge." -ForegroundColor Red
                    exit 1
                }

                Write-Host " Switching to '$TargetBranch'..." -ForegroundColor Cyan
                git checkout $TargetBranch
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[ERROR] Failed to checkout '$TargetBranch'." -ForegroundColor Red
                    exit 1
                }

                Write-Host " Pulling remote changes..." -ForegroundColor Cyan
                git pull --ff-only origin $TargetBranch
                $pullExitCode = $LASTEXITCODE

                Write-Host " Switching back to '$CurrentBranch'..." -ForegroundColor Cyan
                git checkout $CurrentBranch
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[ERROR] Failed to switch back to '$CurrentBranch'." -ForegroundColor Red
                    exit 1
                }

                if ($pullExitCode -ne 0) {
                    Write-Host "[ERROR] Failed to update '$TargetBranch'." -ForegroundColor Red
                    exit 1
                }

                Write-Host "[OK] Target branch updated." -ForegroundColor Green
            } else {
                Write-Host "[WARNING] Target branch '$TargetBranch' has diverged from remote (local: +$targetLocalAhead, remote: +$targetRemoteAhead)." -ForegroundColor Yellow
                $confirmSync = Read-Host " Switch to '$TargetBranch' and try to sync it now? [Y/n]"
                if ($confirmSync -match '^[Nn]$') {
                    Write-Host "[ERROR] Aborting merge." -ForegroundColor Red
                    exit 1
                }

                $syncTargetResult = & "$RootDir\global_functions\sync_check.ps1" $TargetBranch
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[ERROR] Target branch sync failed. Please resolve sync issues before merging." -ForegroundColor Red
                    exit 1
                }

                $fetchTargetResultAfter = git fetch origin $TargetBranch 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[ERROR] Failed to fetch remote information for branch '$TargetBranch'." -ForegroundColor Red
                    exit 1
                }

                $targetRemoteAheadAfter = git rev-list --count "$TargetBranch..origin/$TargetBranch" 2>$null
                if ($LASTEXITCODE -ne 0 -or -not $targetRemoteAheadAfter) { $targetRemoteAheadAfter = 0 } else { $targetRemoteAheadAfter = [int]$targetRemoteAheadAfter }
                if ($targetRemoteAheadAfter -gt 0) {
                    Write-Host "[ERROR] Target branch is still behind remote. Aborting merge." -ForegroundColor Red
                    exit 1
                }
            }
        }
    }
}

# 1. Detect if there's anything at all to merge
$diffResult = git diff --quiet $CurrentBranch $TargetBranch 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] '$TargetBranch' is already fully merged into '$CurrentBranch'. No changes to merge." -ForegroundColor Green
    $switchAfterMerge = Read-Host " Do you want to switch to '$TargetBranch' now? [y/N]"
    if ($switchAfterMerge -match "^[Yy]$") {
        Write-Host " Switching to '$TargetBranch'..." -ForegroundColor Cyan
        git checkout $TargetBranch
        & $MyInvocation.MyCommand.Definition
    } else {
        Write-Host "[INFO] Staying on '$CurrentBranch'." -ForegroundColor Gray
    }
    exit 0
}

# 2. Use dry-run merge to detect conflicts
Write-Host ""
Write-Host "Checking if there are actual differences to merge..." -ForegroundColor Cyan
$mergeCheckOutput = git merge --no-commit --no-ff $TargetBranch 2>&1
$mergeExitCode = $LASTEXITCODE

# --- Handle merge result ---
if ($mergeCheckOutput -match "Already up to date.") {
    Write-Host "[OK] Branch '$TargetBranch' is already fully merged into '$CurrentBranch'. No merge commit needed." -ForegroundColor Green
    git merge --abort >$null 2>&1
    $switchAfterMerge = Read-Host " Do you want to switch to '$TargetBranch' now? [y/N]"
    if ($switchAfterMerge -match "^[Yy]$") {
        Write-Host " Switching to '$TargetBranch'..." -ForegroundColor Cyan
        git checkout $TargetBranch
        & $MyInvocation.MyCommand.Definition
    } else {
        Write-Host "[INFO] Staying on '$CurrentBranch'." -ForegroundColor Gray
    }
    exit 0
} elseif ($mergeCheckOutput -match "Automatic merge went well; stopped before committing as requested") {
    Write-Host "[OK] Automatic merge is possible. Proceeding to generate commit message..." -ForegroundColor Green
    # continue with AI message logic
} elseif ($mergeCheckOutput -match "Automatic merge failed; fix conflicts") {
    Write-Host ""
    Write-Host "[ERROR] Merge conflict detected!" -ForegroundColor Red

    # Show conflict summary
    $mergeCheckOutput | Where-Object { $_ -match "CONFLICT" } | ForEach-Object {
        Write-Host "[WARNING] $_" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Showing detailed conflicts (via 'git diff'):" -ForegroundColor Cyan
    Write-Host ""
    git diff

    # --- Suggest better direction if user is on main/dev/release etc. ---
    $shouldSwitchDirection = $false
    $mainlineBranchesRegex = "^(main|release|production|dev)$"
    
    # Are both mainline branches?
    if ($CurrentBranch -match $mainlineBranchesRegex -and $TargetBranch -match $mainlineBranchesRegex) {
        # Check if the direction is ok by applying some idea of hierarchy to the branches (dev is inferior to main e.g.)
        $lesserMainlineBranchesRegex = "^(dev)$"
        if ($TargetBranch -match $lesserMainlineBranchesRegex -and $CurrentBranch -notmatch $lesserMainlineBranchesRegex) {
            Write-Host "[WARNING] You're trying to merge a lesser mainline branch ('$TargetBranch') into a higher one ('$CurrentBranch')." -ForegroundColor Yellow
            $shouldSwitchDirection = $true
        }
    }

    # If just one is a mainline branch -> check if the direction is correct
    if ($CurrentBranch -match $mainlineBranchesRegex -and $TargetBranch -notmatch $mainlineBranchesRegex) {
        Write-Host ""
        Write-Host "[WARNING] You're trying to merge '$TargetBranch' into '$CurrentBranch' (a mainline branch)." -ForegroundColor Yellow
        $shouldSwitchDirection = $true
    }

    # Help user fix direction
    if ($shouldSwitchDirection) {
        Write-Host "[INFO] Consider resolving the conflict in '$TargetBranch' instead:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   → Checkout to '$TargetBranch'" -ForegroundColor White
        Write-Host "   → Run: dev-tools -m" -ForegroundColor White
        Write-Host "   → Resolve conflicts and commit" -ForegroundColor White
        Write-Host "   → Then redo the merge: dev-tools -m" -ForegroundColor White
        Write-Host ""

        $switchInstead = Read-Host "Switch to '$TargetBranch' now and merge '$CurrentBranch' into it instead? [y/N]"
        if ($switchInstead -match "^[Yy]$") {
            git merge --abort >$null 2>&1
            Write-Host "[INFO] Merge aborted. No changes were applied." -ForegroundColor Yellow
            Write-Host "Switching to '$TargetBranch'..." -ForegroundColor Cyan
            git checkout $TargetBranch
            Write-Host "[OK] Switching to '$TargetBranch'" -ForegroundColor Green
            git status
            Write-Host "please run merge assistant again now" -ForegroundColor Cyan
            exit 0
        }
    }

    Write-Host ""
    Write-Host "To resolve this merge, you have 2 options:" -ForegroundColor Cyan
    Write-Host "---------------------------------------------" -ForegroundColor Gray
    Write-Host "y)  Solve it manually:" -ForegroundColor White
    Write-Host "    a) Edit the conflicting files shown above." -ForegroundColor Gray
    Write-Host "    b) After resolving: git add <file>" -ForegroundColor Gray
    Write-Host "    c) Finish: git commit" -ForegroundColor Gray
    Write-Host "    d) Optionally rerun the merge assistant:" -ForegroundColor Gray
    Write-Host "       → dev-tools -m" -ForegroundColor Gray
    Write-Host ""
    Write-Host "n) Abort the merge if you want to discard:" -ForegroundColor White
    Write-Host "    Run: git merge --abort" -ForegroundColor Gray
    Write-Host ""

    # Prompt user: fix now or abort
    $fixConflicts = Read-Host "Do you want to resolve these conflicts now? [y/N]"

    if ($fixConflicts -match "^[Yy]$") {
        Write-Host "[INFO] You're now in a merge state. Resolve the conflicts as described above." -ForegroundColor Yellow
        Write-Host "Once done, run: git add <files> && dev-tools -c" -ForegroundColor Cyan
        Write-Host "[INFO] You can run 'git status' anytime for help." -ForegroundColor Cyan
        exit 0
    } else {
        git merge --abort >$null 2>&1
        Write-Host "[INFO] Merge aborted. No changes were applied." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "[WARNING] Unexpected merge output:" -ForegroundColor Yellow
    Write-Host $mergeCheckOutput -ForegroundColor Red
    git merge --abort >$null 2>&1
    Write-Host "merge aborted" -ForegroundColor Red
    exit 1
}

# Clean up the test merge state before proceeding to real merge
git merge --abort >$null 2>&1

# --- Write AI message file ---
$aiContent = @"
===== MERGE COMMIT MESSAGE PROMPT =====
You're about to merge branch '$TargetBranch' into '$CurrentBranch'.

$(if (Test-Path $MergeMsgFile) { Get-Content $MergeMsgFile } else { @"
Generate a concise and meaningful merge commit message summarizing the key changes adhering to this basic template strictly:
[MERGE | $TargetBranch -> $CurrentBranch] Merged feature: short summary of the change.
[WARNING] Respond ONLY with the final **message line** (no code block, no git command, no commentary)
"@ })

===== GIT LOG (last 100 commits from $TargetBranch not in $CurrentBranch) =====
$(git log --oneline "$CurrentBranch".."$TargetBranch" -n 100)

===== DIFF SUMMARY ($TargetBranch vs $CurrentBranch) =====
$(git diff --stat $CurrentBranch $TargetBranch)
"@

$aiContent | Out-File -FilePath $AiMessageFile -Encoding UTF8

# --- Decide execution based on AI_MODE ---
if ($env:AI_MODE -eq "api") {
    # Write-Host "[DEBUG] Merge assistant using API mode" -ForegroundColor Gray
    & "$ScriptDir\handle_export_merge_api.ps1" $AiMessageFile $TargetBranch
    # Write-Host "[DEBUG] Merge API handler finished" -ForegroundColor Gray
} else {
    # Write-Host "[DEBUG] Merge assistant using manual mode" -ForegroundColor Gray
    & "$ScriptDir\handle_export_merge_manual.ps1" $AiMessageFile $TargetBranch
    # Write-Host "[DEBUG] Merge manual handler finished" -ForegroundColor Gray
}

# --- Final update check ---
& "$RootDir\global_functions\check_for_updates.ps1"