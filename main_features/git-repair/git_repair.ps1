# -----------------------------------------------------------------------------
# Script: git_repair.ps1
# Description: Detect and repair corrupted Git repositories
# Platform: Windows PowerShell 5.1 compatible
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Function to check if current directory is a git repository
function Test-GitRepo {
    try {
        $null = git rev-parse --git-dir 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Function to detect git corruption
# Returns $true if corruption detected, $false if healthy
function Test-GitCorruption {
    # Run git fsck to check for corruption
    $output = git fsck --full 2>&1 | Out-String
    
    # Check for common corruption patterns
    if ($output -match "(far too short|invalid object|broken link|missing blob|missing tree|missing commit|dangling|corrupt)") {
        return $true
    }
    
    # Try to access the tree
    try {
        $null = git ls-tree HEAD 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $true
        }
    } catch {
        return $true
    }
    
    # Check pack files directly
    $packDir = ".git\objects\pack"
    if (Test-Path $packDir) {
        Get-ChildItem -Path $packDir -Filter "*.pack" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Length -lt 1000) {
                return $true
            }
        }
    }
    
    # Check submodule pack files
    $modulesDir = ".git\modules"
    if (Test-Path $modulesDir) {
        Get-ChildItem -Path $modulesDir -Recurse -Filter "*.pack" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Length -lt 1000) {
                return $true
            }
        }
    }
    
    return $false
}

# Function to check command output for corruption errors
function Test-OutputForCorruption {
    param([string]$Output)
    
    return $Output -match "(far too short to be a packfile|invalid object|Error building trees|broken link|missing blob|missing tree|fatal: unable to read tree)"
}

# Script-level variables for backup tracking
$script:BackupMethod = ""
$script:BackupDir = ""
$script:StashName = ""

# Function to check if there are uncommitted changes
function Test-UncommittedChanges {
    git diff --quiet 2>$null
    if ($LASTEXITCODE -ne 0) { return $true }
    
    git diff --cached --quiet 2>$null
    if ($LASTEXITCODE -ne 0) { return $true }
    
    $untracked = git ls-files --others --exclude-standard 2>$null
    if ($untracked) { return $true }
    
    return $false
}

# Function to show current changes summary
function Show-ChangesSummary {
    Write-Host "Current uncommitted changes:" -ForegroundColor Cyan
    Write-Host ""
    
    # Show staged files
    $staged = git diff --cached --name-only 2>$null
    if ($staged) {
        Write-Host "Staged files:" -ForegroundColor Green
        $staged | ForEach-Object { Write-Host "   + $_" }
        Write-Host ""
    }
    
    # Show modified files
    $modified = git diff --name-only 2>$null
    if ($modified) {
        Write-Host "Modified files:" -ForegroundColor Yellow
        $modified | ForEach-Object { Write-Host "   * $_" }
        Write-Host ""
    }
    
    # Show untracked files
    $untracked = git ls-files --others --exclude-standard 2>$null
    if ($untracked) {
        Write-Host "Untracked files:" -ForegroundColor Blue
        $untracked | ForEach-Object { Write-Host "   ? $_" }
        Write-Host ""
    }
}

# Function to backup using git stash (preferred method)
function Backup-WithStash {
    $script:StashName = "git-repair-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    Write-Host "Creating git stash with name: $($script:StashName)" -ForegroundColor Cyan
    Write-Host ""
    
    # Include untracked files in stash
    $stashOutput = git stash push -u -m $script:StashName 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Changes stashed successfully!" -ForegroundColor Green
        Write-Host ""
        
        # Show stash info
        Write-Host "Stash details:" -ForegroundColor Cyan
        git stash show "stash@{0}" --stat 2>$null
        Write-Host ""
        
        $script:BackupMethod = "stash"
        return $true
    } else {
        Write-Host "Failed to create stash." -ForegroundColor Red
        return $false
    }
}

# Function to backup to files (fallback method)
function Backup-WithFiles {
    $script:BackupDir = Join-Path $env:TEMP "git-repair-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
    
    Write-Host "Backing up changed files to: $($script:BackupDir)" -ForegroundColor Cyan
    Write-Host ""
    
    # Get all changed files
    $changedFiles = @()
    $changedFiles += git diff --name-only 2>$null
    $changedFiles += git diff --cached --name-only 2>$null
    $changedFiles += git ls-files --others --exclude-standard 2>$null
    
    $changedFiles | Where-Object { $_ -and (Test-Path $_) } | ForEach-Object {
        $destPath = Join-Path $script:BackupDir $_
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item $_ $destPath -Force
        Write-Host "   + $_" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Files backed up to: $($script:BackupDir)" -ForegroundColor Green
    
    $script:BackupMethod = "files"
    return $true
}

# Function to show verification instructions
function Show-VerificationInstructions {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  VERIFY YOUR BACKUP BEFORE CONTINUING" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($script:BackupMethod -eq "stash") {
        Write-Host "Your changes were saved using git stash." -ForegroundColor Green
        Write-Host ""
        Write-Host "To verify your stash (open a NEW terminal and run):"
        Write-Host "  git stash list                    " -ForegroundColor Cyan -NoNewline
        Write-Host "# See all stashes"
        Write-Host "  git stash show -p 'stash@{0}'     " -ForegroundColor Cyan -NoNewline
        Write-Host "# View stash contents"
        Write-Host ""
        Write-Host "To restore your changes after repair:"
        Write-Host "  git stash pop                     " -ForegroundColor Cyan -NoNewline
        Write-Host "# Apply and remove stash"
        Write-Host "  git stash apply                   " -ForegroundColor Cyan -NoNewline
        Write-Host "# Apply but keep stash"
        Write-Host ""
        Write-Host "Or use dev-tools:"
        Write-Host "  dev-tools --stash                 " -ForegroundColor Cyan -NoNewline
        Write-Host "# Interactive stash manager"
        Write-Host ""
    } else {
        Write-Host "Your changes were saved to: $($script:BackupDir)" -ForegroundColor Green
        Write-Host ""
        Write-Host "To verify your backup (open a NEW terminal and run):"
        Write-Host "  dir $($script:BackupDir)" -ForegroundColor Cyan
        Write-Host "  Get-ChildItem -Recurse $($script:BackupDir)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "To restore your changes after repair:"
        Write-Host "  Copy-Item -Recurse $($script:BackupDir)\* ." -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Function to repair git repository
function Repair-GitRepo {
    param([string]$RepoPath = ".")
    
    $originalDir = Get-Location
    Set-Location $RepoPath
    
    if (-not (Test-GitRepo)) {
        Write-Host "Not a git repository: $RepoPath" -ForegroundColor Red
        Set-Location $originalDir
        return $false
    }
    
    # Reset backup tracking
    $script:BackupMethod = ""
    $script:BackupDir = ""
    $script:StashName = ""
    
    Write-Host ""
    Write-Host "Git Repository Repair Tool" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Repository: $(Get-Location)" -ForegroundColor Yellow
    Write-Host ""
    
    # Step 1: Check for uncommitted changes and backup
    Write-Host "Step 1: Checking for uncommitted changes..." -ForegroundColor Cyan
    Write-Host ""
    
    if (Test-UncommittedChanges) {
        Write-Host "You have uncommitted changes that need to be backed up first." -ForegroundColor Yellow
        Write-Host ""
        
        # Show what will be backed up
        Show-ChangesSummary
        
        # Ask user for backup method (default: file backup, stash as advanced option)
        Write-Host "How would you like to backup your changes?" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1) File Backup (recommended) - Copies files to temp directory"
        Write-Host "     + Works even if git is severely corrupted"
        Write-Host "     + Independent of git internals (robust when packs are broken)"
        Write-Host ""
        Write-Host "  2) Git Stash (advanced) - Uses git's native stash feature"
        Write-Host "     + Preserves staged/unstaged state"
        Write-Host "     + Managed by dev-tools --stash"
        Write-Host "     ! May fail if git cannot read corrupted pack files" -ForegroundColor Yellow
        Write-Host ""
        
        $backupChoice = Read-Host "Choose backup method [1/2] (default: 1)"
        Write-Host ""
        
        $backupSuccess = $false
        
        if ($backupChoice -eq "2") {
            # Explicit stash choice, with fallback to file backup
            $backupSuccess = Backup-WithStash
            if (-not $backupSuccess) {
                Write-Host "Stash failed, falling back to file backup..." -ForegroundColor Yellow
                Write-Host ""
                $backupSuccess = Backup-WithFiles
            }
        } else {
            # Default: robust file backup
            $backupSuccess = Backup-WithFiles
        }
        
        if (-not $backupSuccess) {
            Write-Host "Failed to backup changes. Aborting repair." -ForegroundColor Red
            Set-Location $originalDir
            return $false
        }
        
        # Show verification instructions
        Show-VerificationInstructions
        
        # CRITICAL: Require explicit confirmation before proceeding
        Write-Host "IMPORTANT: The next steps will modify your git repository!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Before continuing, please verify your backup is correct."
        Write-Host "You can open a NEW terminal to check using the commands above."
        Write-Host ""
        $verifyConfirm = Read-Host "Have you verified your changes are backed up correctly? Type 'yes' to continue"
        
        if ($verifyConfirm -ne "yes") {
            Write-Host ""
            Write-Host "Repair cancelled. Your changes are still backed up." -ForegroundColor Yellow
            if ($script:BackupMethod -eq "stash") {
                Write-Host "To restore: git stash pop"
            } else {
                Write-Host "Your backup is in: $($script:BackupDir)"
            }
            Set-Location $originalDir
            return $false
        }
        Write-Host ""
    } else {
        Write-Host "No uncommitted changes detected. Safe to proceed." -ForegroundColor Green
        Write-Host ""
        
        # Still ask for confirmation before destructive operations
        $proceedConfirm = Read-Host "Proceed with repository repair? Type 'yes' to continue"
        if ($proceedConfirm -ne "yes") {
            Write-Host "Repair cancelled."
            Set-Location $originalDir
            return $false
        }
        Write-Host ""
    }
    
    # Step 2: Get remote URL
    Write-Host "Step 2: Getting remote URL..." -ForegroundColor Cyan
    $remoteUrl = git remote get-url origin 2>$null
    
    if (-not $remoteUrl) {
        Write-Host "No remote 'origin' found. Cannot auto-repair without a remote." -ForegroundColor Red
        Set-Location $originalDir
        return $false
    }
    Write-Host "   Remote URL: $remoteUrl"
    Write-Host ""
    
    # Step 3: Get current branch
    Write-Host "Step 3: Getting current branch..." -ForegroundColor Cyan
    $currentBranch = git branch --show-current 2>$null
    if (-not $currentBranch) {
        $currentBranch = "main"
        Write-Host "Could not detect current branch, will use: $currentBranch" -ForegroundColor Yellow
    } else {
        Write-Host "   Current branch: $currentBranch"
    }
    Write-Host ""
    
    # Step 4: Remove corrupted pack files
    Write-Host "Step 4: Removing corrupted pack files..." -ForegroundColor Cyan
    $removedPacks = 0
    
    $packDir = ".git\objects\pack"
    if (Test-Path $packDir) {
        Get-ChildItem -Path $packDir -Filter "*.pack" -ErrorAction SilentlyContinue | ForEach-Object {
            $packFile = $_.FullName
            $size = $_.Length
            $isCorrupt = $false
            
            if ($size -lt 1000) {
                # Very small packs are almost always corrupted
                $isCorrupt = $true
            } else {
                # Use git verify-pack on the corresponding index to detect broken packs
                $idxFile = $packFile -replace '\.pack$', '.idx'
                if (Test-Path $idxFile) {
                    git verify-pack -v $idxFile 2>$null | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        $isCorrupt = $true
                    }
                }
            }
            
            if ($isCorrupt) {
                $packBase = $packFile -replace '\.pack$', ''
                Write-Host "   Removing corrupted pack: $($_.Name) ($size bytes)"
                Remove-Item $packFile -Force -ErrorAction SilentlyContinue
                Remove-Item "$packBase.idx" -Force -ErrorAction SilentlyContinue
                Remove-Item "$packBase.rev" -Force -ErrorAction SilentlyContinue
                $removedPacks++
            }
        }
    }
    
    # Also fix submodule pack files
    $modulesDir = ".git\modules"
    if (Test-Path $modulesDir) {
        Get-ChildItem -Path $modulesDir -Recurse -Filter "*.pack" -ErrorAction SilentlyContinue | ForEach-Object {
            $packFile = $_.FullName
            $size = $_.Length
            $isCorrupt = $false
            
            if ($size -lt 1000) {
                $isCorrupt = $true
            } else {
                $idxFile = $packFile -replace '\.pack$', '.idx'
                if (Test-Path $idxFile) {
                    git verify-pack -v $idxFile 2>$null | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        $isCorrupt = $true
                    }
                }
            }
            
            if ($isCorrupt) {
                $packBase = $packFile -replace '\.pack$', ''
                Write-Host "   Removing corrupted submodule pack: $packFile ($size bytes)"
                Remove-Item $packFile -Force -ErrorAction SilentlyContinue
                Remove-Item "$packBase.idx" -Force -ErrorAction SilentlyContinue
                Remove-Item "$packBase.rev" -Force -ErrorAction SilentlyContinue
                $removedPacks++
            }
        }
    }
    
    if ($removedPacks -eq 0) {
        Write-Host "   No obviously corrupted pack files found."
    } else {
        Write-Host "   Removed $removedPacks corrupted pack file(s)." -ForegroundColor Green
    }
    Write-Host ""
    
    # Step 5: Re-fetch from remote
    Write-Host "Step 5: Re-fetching objects from remote..." -ForegroundColor Cyan
    $fetchOutput = git fetch --all --prune 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Fetch completed successfully." -ForegroundColor Green
    } else {
        Write-Host "   Fetch had issues, trying alternative approach..." -ForegroundColor Yellow
        
        # Remove all pack files and re-fetch
        Write-Host "   Removing all pack files and re-fetching..."
        Get-ChildItem -Path ".git\objects\pack" -Filter "*.pack" -ErrorAction SilentlyContinue | Remove-Item -Force
        Get-ChildItem -Path ".git\objects\pack" -Filter "*.idx" -ErrorAction SilentlyContinue | Remove-Item -Force
        
        git fetch --all 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   Re-fetch completed." -ForegroundColor Green
        } else {
            Write-Host "   Re-fetch failed. Manual intervention may be needed." -ForegroundColor Red
        }
    }
    Write-Host ""
    
    # Step 6: Run git gc to clean up
    Write-Host "Step 6: Running garbage collection..." -ForegroundColor Cyan
    $gcOutput = git gc --prune=now 2>&1 | Out-String
    if ($gcOutput) { Write-Host $gcOutput }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Garbage collection completed." -ForegroundColor Green
    } else {
        Write-Host "   git gc reported errors. The repository may still be corrupted; a final verification step will check." -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Step 7: Reset submodules if present
    if (Test-Path ".gitmodules") {
        Write-Host "Step 7: Repairing submodules..." -ForegroundColor Cyan
        
        git submodule deinit --all -f 2>$null
        if (Test-Path ".git\modules") {
            Remove-Item -Path ".git\modules\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        git submodule update --init --recursive 2>&1 | Out-Null
        
        Write-Host "   Submodules repaired." -ForegroundColor Green
        Write-Host ""
    }
    
    # Step 8: Verify repair
    Write-Host "Step 8: Verifying repair..." -ForegroundColor Cyan
    Write-Host "   Running a deep integrity check (git fsck --full). This can take up to a few minutes on large or heavily corrupted repositories..." -ForegroundColor Yellow
    $stillCorrupted = $false
    if (Test-GitCorruption) {
        $stillCorrupted = $true
    }

    if ($stillCorrupted) {
        Write-Host "Repository still appears corrupted." -ForegroundColor Red
        Write-Host ""

        # Optional: try a hard reset to the remote branch before giving up
        if ($currentBranch) {
            Write-Host "We can try to reset your local branch to match origin/$currentBranch." -ForegroundColor Yellow
            Write-Host "This will DISCARD local commits on this branch, but your working tree changes are backed up." -ForegroundColor Yellow
            $resetConfirm = Read-Host "Attempt reset to 'origin/$currentBranch' and re-run verification? Type 'yes' to continue"
            if ($resetConfirm -eq "yes") {
                Write-Host ""
                Write-Host "Resetting local branch to origin/$currentBranch..."
                git reset --hard "origin/$currentBranch" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    git clean -fd 2>$null
                    Write-Host "Running git gc after reset..."
                    $gcOutput = git gc --prune=now 2>&1 | Out-String
                    if ($gcOutput) { Write-Host $gcOutput }
                } else {
                    Write-Host "Failed to reset to origin/$currentBranch. Skipping reset-based repair." -ForegroundColor Yellow
                }
                Write-Host ""
                Write-Host "Re-running corruption check after reset..."
                if (-not (Test-GitCorruption)) {
                    $stillCorrupted = $false
                }
            }
            Write-Host ""
        }
    }

    if ($stillCorrupted) {
        Write-Host "Manual repair may be needed. Options:" 
        Write-Host "  1. Clone fresh: git clone $remoteUrl <new-dir>"
        if ($script:BackupMethod -eq "stash") {
            Write-Host "  2. Restore your stash in new clone"
        } elseif ($script:BackupDir) {
            Write-Host "  2. Copy your changes from: $($script:BackupDir)"
        }
        Write-Host ""
        
        $autoClone = Read-Host "Would you like me to clone a fresh copy of this repository into a new directory now? [y/N]"
        if ($autoClone -match "^[Yy]$") {
            $currentPath = Get-Location
            $parentDir = Split-Path -Parent $currentPath
            $repoName = Split-Path -Leaf $currentPath
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $newDir = Join-Path $parentDir "$repoName-repaired-$timestamp"
            Write-Host ""
            Write-Host "Cloning into: $newDir"
            git clone $remoteUrl $newDir
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Fresh clone created at: $newDir" -ForegroundColor Green
                
                if ($script:BackupMethod -eq "files" -and $script:BackupDir) {
                    Write-Host ""
                    Write-Host "Restoring your backed-up files into the repaired clone..." -ForegroundColor Cyan
                    Get-ChildItem -Path $script:BackupDir -Recurse -File | ForEach-Object {
                        $relativePath = $_.FullName.Substring($script:BackupDir.Length + 1)
                        $destPath = Join-Path $newDir $relativePath
                        $destDir = Split-Path $destPath -Parent
                        if (-not (Test-Path $destDir)) {
                            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                        }
                        Copy-Item $_.FullName $destPath -Force
                    }
                    Write-Host "Backup files copied into: $newDir" -ForegroundColor Green
                } elseif ($script:BackupMethod -eq "stash") {
                    Write-Host ""
                    Write-Host "Your changes are stored in a git stash in the OLD repository." -ForegroundColor Yellow
                    Write-Host "You can review them there using:"
                    Write-Host "  git stash list"
                    Write-Host "  git stash show -p"
                    Write-Host ""
                    Write-Host "To apply the stash onto the repaired clone, you can for example run from the OLD repo:" -ForegroundColor Yellow
                    Write-Host "  cd `"$currentPath`""
                    Write-Host "  git stash list   # find the '$script:StashName' entry"
                    Write-Host "  `$env:GIT_DIR = `"$currentPath/.git`"; `$env:GIT_WORK_TREE = `"$newDir`"; git stash apply <stash-ref>" -ForegroundColor Cyan
                    Write-Host "  `$env:GIT_DIR = `$null; `$env:GIT_WORK_TREE = `$null" -ForegroundColor Cyan
                    Write-Host ""
                }

                Write-Host "" 
                Write-Host "Next steps to verify the repaired repository:" -ForegroundColor Cyan
                Write-Host "  1) Open a new PowerShell or cmd and run:"
                Write-Host "       cd `"$newDir`""
                Write-Host "  2) Check git status and corruption:"
                Write-Host "       git status"
                Write-Host "       git fsck --full"
                Write-Host "  3) Verify your application / scripts run as expected."
                Write-Host ""
                $replaceConfirm = Read-Host "If everything works and no git errors are present, type 'replace' to replace the old repo in-place. Otherwise press Enter to keep both"

                if ($replaceConfirm -eq "replace") {
                    $oldDir = $currentPath
                    $repairedName = Split-Path -Leaf $newDir
                    $brokenName = "$repoName-broken-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

                    Write-Host "" 
                    Write-Host "Archiving old repo as: $parentDir\$brokenName"
                    Write-Host "Copying repaired repo into new working location at: $parentDir\$repoName"
                    Set-Location $parentDir
                    Rename-Item -Path $repoName -NewName $brokenName
                    if (-not (Test-Path $repoName)) {
                        New-Item -ItemType Directory -Path $repoName -Force | Out-Null
                    }
                    Copy-Item -Path (Join-Path $repairedName '*') -Destination $repoName -Recurse -Force
                    Write-Host "Replacement completed." -ForegroundColor Green
                    Write-Host "Old broken repo: $parentDir\$brokenName"
                    Write-Host "New working repo: $parentDir\$repoName"

                    Write-Host ""
                    Write-Host "To work in the new repository from a new shell, you can run:" 
                    Write-Host "  cd `"$parentDir\$repoName`""
                    Write-Host ""
                    Write-Host "Please verify the new repository is working correctly (git status, git fsck --full, run your application)."
                    $removeConfirm = Read-Host "If everything is fine and you no longer need the archived repo, type 'remove' to delete '$parentDir\$brokenName'. Otherwise press Enter to keep it"
                    if ($removeConfirm -eq "remove") {
                        Write-Host "Running final validation checks in new repo before removing archived repo..."
                        $newRepoPath = Join-Path $parentDir $repoName
                        $validationOk = $false
                        Push-Location $newRepoPath
                        git status 2>$null | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            git fsck --full 2>$null | Out-Null
                            if ($LASTEXITCODE -eq 0) {
                                $validationOk = $true
                            }
                        }
                        Pop-Location

                        if ($validationOk) {
                            Write-Host "Final validation passed. Removing archived broken repo: $parentDir\$brokenName"
                            Remove-Item -Path (Join-Path $parentDir $brokenName) -Recurse -Force -ErrorAction SilentlyContinue
                            Write-Host "Archived broken repo removed." -ForegroundColor Green
                        } else {
                            Write-Host "Final validation failed or reported git errors. Archived repo will NOT be removed." -ForegroundColor Yellow
                            Write-Host "You can inspect the new repo at: $newRepoPath and the archived repo at: $parentDir\$brokenName"
                        }
                    } else {
                        Write-Host "Archived broken repo kept at: $parentDir\$brokenName"
                    }

                    # Show summary of remaining repair-related directories
                    Write-Host ""
                    Write-Host "Repair summary:" -ForegroundColor Cyan
                    Write-Host "  New working repo: $parentDir\$repoName"
                    if (Test-Path (Join-Path $parentDir $brokenName)) {
                        Write-Host "  Archived broken repo: $parentDir\$brokenName"
                    }
                    if (Test-Path (Join-Path $parentDir $repairedName)) {
                        Write-Host "  Repaired clone still present at: $parentDir\$repairedName"
                        Write-Host "  You can remove it later with:" -ForegroundColor Yellow
                        Write-Host "    Remove-Item -Recurse -Force `"$parentDir\$repairedName`"" -ForegroundColor Cyan
                    }

                    $originalDir = Join-Path $parentDir $repoName
                    Set-Location $originalDir
                    return $true
                }
            } else {
                Write-Host "Failed to clone fresh repository automatically." -ForegroundColor Red
            }
        }
        Set-Location $originalDir
        return $false
    } else {
        Write-Host "Repository appears healthy!" -ForegroundColor Green
    }
    Write-Host ""
    
    # Step 9: Restore changes if backed up
    if ($script:BackupMethod) {
        Write-Host "Step 9: Restoring your changes..." -ForegroundColor Cyan
        Write-Host ""
        
        if ($script:BackupMethod -eq "stash") {
            Write-Host "Your changes are in the git stash."
            Write-Host ""
            $restoreConfirm = Read-Host "Apply stash now to restore your changes? [Y/n]"
            if ($restoreConfirm -notmatch "^[Nn]$") {
                Write-Host "Applying stash..."
                $stashOutput = git stash pop 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Changes restored from stash." -ForegroundColor Green
                } else {
                    Write-Host "Stash apply had conflicts. Use 'git stash show' to see changes." -ForegroundColor Yellow
                }
            } else {
                Write-Host "Stash preserved. Restore later with: git stash pop"
            }
        } else {
            Write-Host "Your changes are backed up in: $($script:BackupDir)"
            Write-Host ""
            $restoreConfirm = Read-Host "Restore backed-up files now? [Y/n]"
            if ($restoreConfirm -notmatch "^[Nn]$") {
                Write-Host "Restoring files..."
                Get-ChildItem -Path $script:BackupDir -Recurse -File | ForEach-Object {
                    $relativePath = $_.FullName.Substring($script:BackupDir.Length + 1)
                    $destPath = Join-Path (Get-Location) $relativePath
                    $destDir = Split-Path $destPath -Parent
                    if (-not (Test-Path $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }
                    Copy-Item $_.FullName $destPath -Force
                }
                Write-Host "Files restored." -ForegroundColor Green
            } else {
                Write-Host "Files preserved in: $($script:BackupDir)"
            }
        }
    }
    
    Write-Host ""
    Write-Host "Git repository repair completed!" -ForegroundColor Green
    Write-Host ""
    
    Set-Location $originalDir
    return $true
}

# Function to run a quick check and offer repair if needed
function Invoke-QuickCheckAndOfferRepair {
    if (-not (Test-GitRepo)) {
        return $true  # Not a git repo, nothing to check
    }
    
    if (Test-GitCorruption) {
        Write-Host ""
        Write-Host "Git repository corruption detected!" -ForegroundColor Red
        Write-Host ""
        $repairConfirm = Read-Host "Would you like to attempt automatic repair? [Y/n]"
        if ($repairConfirm -notmatch "^[Nn]$") {
            return Repair-GitRepo "."
        } else {
            Write-Host ""
            Write-Host "You can repair manually later with: dev-tools --repair"
            return $false
        }
    }
    
    return $true
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host ""
    Write-Host "Git Repository Repair Tool" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-GitRepo)) {
        Write-Host "Not in a git repository." -ForegroundColor Red
        Write-Host "Please run this from within a git repository."
        exit 1
    }
    
    Write-Host "Checking for repository corruption..." -ForegroundColor Cyan
    Write-Host "   Running an integrity scan (git fsck --full and pack checks). This can take up to a few minutes on large or heavily corrupted repositories..." -ForegroundColor Yellow
    Write-Host ""
    
    if (Test-GitCorruption) {
        Write-Host "Repository corruption detected!" -ForegroundColor Red
        Write-Host ""
        $confirm = Read-Host "Would you like to attempt automatic repair? [Y/n]"
        if ($confirm -notmatch "^[Nn]$") {
            Repair-GitRepo "."
        } else {
            Write-Host "Repair cancelled."
            exit 1
        }
    } else {
        Write-Host "No corruption detected. Repository appears healthy." -ForegroundColor Green
        Write-Host ""
        $forceRepair = Read-Host "Run repair anyway? (This can fix minor issues) [y/N]"
        if ($forceRepair -match "^[Yy]$") {
            Repair-GitRepo "."
        }
    }
}
