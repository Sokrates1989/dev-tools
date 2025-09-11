# -----------------------------------------------------------------------------
# Script: stash_manager.ps1
#
# Description:
# Interactive stash management tool for Git repositories.
# Provides a persistent menu-driven interface for common stash operations.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir\..\.." | Select-Object -ExpandProperty Path

# Load utility functions
. "$ScriptDir\stash_utils.ps1"

# Load environment variables if available
$EnvFile = "$RootDir\.env"
if (Test-Path $EnvFile) {
    . "$RootDir\global_functions\load_dotenv.ps1"
    Load-DotEnv
}

# --- Git update check ---
& "$RootDir\global_functions\check_for_updates.ps1"

# Check if we're in a git repository
if (-not (Test-GitRepository)) {
    exit 1
}

# Function to perform stash operation
function Invoke-StashOperation {
    param([string]$Operation)
    
    switch ($Operation) {
        "stash_all" {
            Write-Host ""
            Write-Host "[STASH] Stash All Changes (Including Untracked)"
            Write-Host "=========================================="
            
            # Check if there are changes
            $modifiedFiles = git diff --name-only
            $stagedFiles = git diff --cached --name-only
            $untrackedFiles = git ls-files --others --exclude-standard
            
            $hasModified = $modifiedFiles -and ($modifiedFiles | Measure-Object).Count -gt 0
            $hasStaged = $stagedFiles -and ($stagedFiles | Measure-Object).Count -gt 0
            $hasUntracked = $untrackedFiles -and ($untrackedFiles | Measure-Object).Count -gt 0
            
            if (-not $hasModified -and -not $hasStaged -and -not $hasUntracked) {
                Write-Host "[OK] No changes to stash. Working directory is clean."
                return
            }
            
            # Show what will be stashed
            Write-Host ""
            Write-Host "Changes that will be stashed:"
            Write-Host ""
            if ($hasModified) {
                Write-Host "[MODIFIED] Modified files:"
                $modifiedFiles | ForEach-Object { Write-Host "  $_" }
                Write-Host ""
            }
            if ($hasStaged) {
                Write-Host "[STAGED] Staged files:"
                $stagedFiles | ForEach-Object { Write-Host "  $_" }
                Write-Host ""
            }
            if ($hasUntracked) {
                Write-Host "[UNTRACKED] Untracked files:"
                $untrackedFiles | ForEach-Object { Write-Host "  $_" }
            }
            
            if (Confirm-DestructiveAction "Stash all changes including untracked files?") {
                Write-Host ""
                Write-Host "Stashing changes..."
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                git stash push --include-untracked -m "Stash created on $timestamp"
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Successfully stashed all changes including untracked files."
                } else {
                    Write-Host "[ERROR] Failed to stash changes."
                }
            } else {
                Write-Host "[CANCELLED] Stash operation cancelled."
            }
        }
        "stash_tracked" {
            Write-Host ""
            Write-Host "[STASH] Stash Tracked Changes Only"
            Write-Host "============================="
            
            # Check if there are tracked changes
            $modifiedFiles = git diff --name-only
            $stagedFiles = git diff --cached --name-only
            
            $hasModified = $modifiedFiles -and ($modifiedFiles | Measure-Object).Count -gt 0
            $hasStaged = $stagedFiles -and ($stagedFiles | Measure-Object).Count -gt 0
            
            if (-not $hasModified -and -not $hasStaged) {
                Write-Host "[OK] No tracked changes to stash."
                $untrackedFiles = git ls-files --others --exclude-standard
                if ($untrackedFiles -and ($untrackedFiles | Measure-Object).Count -gt 0) {
                    Write-Host ""
                    Write-Host "[UNTRACKED] Untracked files found (will NOT be stashed):"
                    $untrackedFiles | ForEach-Object { Write-Host "  $_" }
                    Write-Host ""
                    Write-Host "[INFO] Tip: Use 'Stash all changes' to include untracked files."
                }
                return
            }
            
            # Show what will be stashed
            Write-Host ""
            Write-Host "Tracked changes that will be stashed:"
            Write-Host ""
            if ($hasModified) {
                Write-Host "[MODIFIED] Modified files:"
                $modifiedFiles | ForEach-Object { Write-Host "  $_" }
                Write-Host ""
            }
            if ($hasStaged) {
                Write-Host "[STAGED] Staged files:"
                $stagedFiles | ForEach-Object { Write-Host "  $_" }
            }
            
            if (Confirm-DestructiveAction "Stash tracked changes only?") {
                Write-Host ""
                Write-Host "Stashing tracked changes..."
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                git stash push -m "Tracked changes stash created on $timestamp"
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Successfully stashed tracked changes."
                } else {
                    Write-Host "[ERROR] Failed to stash changes."
                }
            } else {
                Write-Host "[CANCELLED] Stash operation cancelled."
            }
        }
        "stash_custom" {
            Write-Host ""
            Write-Host "[STASH] Stash with Custom Message"
            Write-Host "============================"
            
            # Check if there are changes
            $modifiedFiles = git diff --name-only
            $stagedFiles = git diff --cached --name-only
            $untrackedFiles = git ls-files --others --exclude-standard
            
            $hasModified = $modifiedFiles -and ($modifiedFiles | Measure-Object).Count -gt 0
            $hasStaged = $stagedFiles -and ($stagedFiles | Measure-Object).Count -gt 0
            $hasUntracked = $untrackedFiles -and ($untrackedFiles | Measure-Object).Count -gt 0
            
            if (-not $hasModified -and -not $hasStaged -and -not $hasUntracked) {
                Write-Host "[OK] No changes to stash. Working directory is clean."
                return
            }
            
            # Show what will be stashed
            Write-Host ""
            Write-Host "Changes that will be stashed:"
            Write-Host ""
            if ($hasModified) {
                Write-Host "[MODIFIED] Modified files:"
                $modifiedFiles | ForEach-Object { Write-Host "  $_" }
                Write-Host ""
            }
            if ($hasStaged) {
                Write-Host "[STAGED] Staged files:"
                $stagedFiles | ForEach-Object { Write-Host "  $_" }
                Write-Host ""
            }
            
            # Check for untracked files
            $stashFlags = ""
            if ($hasUntracked) {
                Write-Host "[UNTRACKED] Untracked files found:"
                $untrackedFiles | ForEach-Object { Write-Host "  $_" }
                Write-Host ""
                
                $includeUntracked = Read-Host "Include untracked files in stash? (yes/no)"
                if ($includeUntracked -eq "yes") {
                    $stashFlags = "--include-untracked"
                } else {
                    Write-Host "[INFO] Untracked files will NOT be stashed."
                }
            }
            
            Write-Host ""
            $customMessage = Read-Host "Enter a custom message for this stash"
            
            if ([string]::IsNullOrWhiteSpace($customMessage)) {
                Write-Host "[WARNING] No message provided. Using default message."
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $customMessage = "Custom stash created on $timestamp"
            }
            
            Write-Host ""
            Write-Host "Stashing changes with message: '$customMessage'"
            
            if ($stashFlags) {
                git stash push $stashFlags -m $customMessage
            } else {
                git stash push -m $customMessage
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Successfully stashed changes with custom message."
            } else {
                Write-Host "[ERROR] Failed to stash changes."
            }
        }
    }
}

# Function to show interactive stash list and operations
function Show-StashListInteractive {
    $stashCount = Get-StashCount
    
    if ($stashCount -eq 0) {
        Write-Host ""
        Write-Host "[INFO] No stashes found."
        Write-Host ""
        Write-Host "[INFO] Tip: Create a stash using one of the stash operations."
        return
    }
    
    while ($true) {
        Write-Host ""
        Write-Host "Interactive Stash List - Dev Tools"
        Write-Host "====================================="
        Write-Host ""
        Write-Host "Found $stashCount stash(es):"
        Write-Host ""
        
        if (-not (Show-StashesNumbered)) {
            Write-Host "[INFO] No stashes found."
            return
        }
        
        Write-Host ""
        Write-Host "Choose an action:"
        Write-Host ""
        Write-Host "View Operations:"
        Write-Host "v) View content of a specific stash"
        Write-Host "s) Show stash summary"
        Write-Host ""
        Write-Host "Apply/Pop Operations:"
        Write-Host "a) Apply a specific stash (keep in stash)"
        Write-Host "p) Pop a specific stash (remove from stash)"
        Write-Host ""
        Write-Host "Cleanup Operations:"
        Write-Host "d) Drop a specific stash"
        Write-Host "c) Clear all stashes"
        Write-Host ""
        Write-Host "b) Back to main stash menu"
        Write-Host "q) Exit stash manager"
        Write-Host ""
        
        $choice = Read-Host "Enter your choice [v, s, a, p, d, c, b, q]"
        
        switch ($choice) {
            "v" {
                Write-Host ""
                $stashInput = Read-Host "Enter stash number or reference to view"
                $stashRef = Get-ValidatedStashRef -Input $stashInput -StashCount $stashCount
                if ($stashRef) {
                    Write-Host ""
                    Write-Host "Selected stash:"
                    Get-StashInfo -StashRef $stashRef
                    Write-Host ""
                    Write-Host "Stash content:"
                    Write-Host "=================="
                    git stash show -p $stashRef
                }
                Wait-ForContinue
            }
            "s" {
                Write-Host ""
                Show-StashSummary
                Wait-ForContinue
            }
            "a" {
                Write-Host ""
                $stashInput = Read-Host "Enter stash number or reference to apply"
                $stashRef = Get-ValidatedStashRef -Input $stashInput -StashCount $stashCount
                if ($stashRef) {
                    Write-Host ""
                    Write-Host "Selected stash:"
                    Get-StashInfo -StashRef $stashRef
                    Write-Host ""
                    Show-WorkingDirectoryStatus
                    
                    if (Confirm-DestructiveAction "Apply stash $stashRef? (This keeps the stash in the stash list)") {
                        Write-Host ""
                        Write-Host "Applying stash $stashRef..."
                        git stash apply $stashRef
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "[OK] Successfully applied stash $stashRef."
                            Write-Host ""
                            Write-Host "[INFO] Stash remains in the stash list."
                        } else {
                            Write-Host "[ERROR] Failed to apply stash. There may be conflicts."
                            Write-Host ""
                            Write-Host "[INFO] Tips for resolving conflicts:"
                            Write-Host "  • Check 'git status' for conflicted files"
                            Write-Host "  • Resolve conflicts manually and commit"
                        }
                    } else {
                        Write-Host "[CANCELLED] Apply operation cancelled."
                    }
                }
                Wait-ForContinue
            }
            "p" {
                Write-Host ""
                $stashInput = Read-Host "Enter stash number or reference to pop"
                $stashRef = Get-ValidatedStashRef -Input $stashInput -StashCount $stashCount
                if ($stashRef) {
                    Write-Host ""
                    Write-Host "Selected stash:"
                    Get-StashInfo -StashRef $stashRef
                    Write-Host ""
                    Show-WorkingDirectoryStatus
                    
                    if (Confirm-DestructiveAction "Pop stash $stashRef? (This applies and removes the stash)") {
                        Write-Host ""
                        Write-Host "Popping stash $stashRef..."
                        git stash pop $stashRef
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "[OK] Successfully popped stash $stashRef."
                            # Update stash count after popping
                            $stashCount = Get-StashCount
                            if ($stashCount -eq 0) {
                                Write-Host "[INFO] No more stashes remaining."
                                Wait-ForContinue
                                return
                            }
                        } else {
                            Write-Host "[ERROR] Failed to pop stash. There may be conflicts."
                            Write-Host ""
                            Write-Host "[INFO] Tips for resolving conflicts:"
                            Write-Host "  • Check 'git status' for conflicted files"
                            Write-Host "  • Resolve conflicts manually and commit"
                        }
                    } else {
                        Write-Host "[CANCELLED] Pop operation cancelled."
                    }
                }
                Wait-ForContinue
            }
            "d" {
                Write-Host ""
                $stashInput = Read-Host "Enter stash number or reference to drop"
                $stashRef = Get-ValidatedStashRef -Input $stashInput -StashCount $stashCount
                if ($stashRef) {
                    Write-Host ""
                    Write-Host "Selected stash:"
                    Get-StashInfo -StashRef $stashRef
                    Write-Host ""
                    Write-Host "[WARNING] This will permanently delete the stash without applying it."
                    
                    if (Confirm-DestructiveAction "Drop stash $stashRef permanently?") {
                        Write-Host ""
                        Write-Host "Dropping stash $stashRef..."
                        git stash drop $stashRef
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "[OK] Successfully dropped stash $stashRef."
                            # Update stash count after dropping
                            $stashCount = Get-StashCount
                            if ($stashCount -eq 0) {
                                Write-Host "[INFO] No more stashes remaining."
                                Wait-ForContinue
                                return
                            }
                        } else {
                            Write-Host "[ERROR] Failed to drop stash."
                        }
                    } else {
                        Write-Host "[CANCELLED] Drop operation cancelled."
                    }
                }
                Wait-ForContinue
            }
            "c" {
                if ($stashCount -eq 0) {
                    Write-Host "[INFO] No stashes to clear."
                    Wait-ForContinue
                    continue
                }
                
                Write-Host ""
                Write-Host "All stashes that will be permanently deleted:"
                Write-Host ""
                Show-StashesNumbered
                Write-Host ""
                Write-Host "[WARNING] This will permanently delete ALL $stashCount stashes without applying them."
                Write-Host "[WARNING] This action cannot be undone!"
                Write-Host ""
                $confirm = Read-Host "Clear all stashes permanently? Type 'DELETE ALL' to confirm"
                
                if ($confirm -eq "DELETE ALL") {
                    Write-Host ""
                    Write-Host "Clearing all stashes..."
                    git stash clear
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[OK] Successfully cleared all stashes."
                        Write-Host "[INFO] No stashes remaining."
                        Wait-ForContinue
                        return
                    } else {
                        Write-Host "[ERROR] Failed to clear stashes."
                    }
                } else {
                    Write-Host "[CANCELLED] Clear operation cancelled."
                    Write-Host "[INFO] You must type 'DELETE ALL' exactly to confirm this destructive operation."
                }
                Wait-ForContinue
            }
            { $_ -in @("b", "B") } {
                return
            }
            { $_ -in @("q", "Q", "quit", "exit") } {
                Write-Host "Exiting stash manager."
                exit 0
            }
            default {
                Write-Host "[ERROR] Invalid choice. Try again."
                Wait-ForContinue
            }
        }
    }
}

# Main interactive loop
while ($true) {
    Write-Host ""
    Write-Host "Git Stash Manager - Dev Tools"
    Write-Host "================================="
    Write-Host ""
    
    Show-RepositoryStatus
    Show-StashSummary
    
    Write-Host "Choose a stash operation:"
    Write-Host ""
    Write-Host "Stash Operations:"
    Write-Host "1) Stash all changes (including untracked)"
    Write-Host "2) Stash only tracked changes"
    Write-Host "3) Stash with custom message"
    Write-Host ""
    Write-Host "Interactive Operations:"
    Write-Host "4) Interactive stash list (view, apply, pop, drop)"
    Write-Host ""
    Write-Host "Quick Operations:"
    Write-Host "5) Apply latest stash (keep in stash)"
    Write-Host "6) Pop latest stash (remove from stash)"
    Write-Host "7) Show content of latest stash"
    Write-Host ""
    Write-Host "b) Back to main menu"
    Write-Host "q) Exit"
    Write-Host ""
    
    $choice = Read-Host "Enter your choice [1-7, b, q]"
    
    switch ($choice) {
        "1" {
            Invoke-StashOperation "stash_all"
        }
        "2" {
            Invoke-StashOperation "stash_tracked"
        }
        "3" {
            Invoke-StashOperation "stash_custom"
        }
        "4" {
            Show-StashListInteractive
        }
        "5" {
            $stashCount = Get-StashCount
            if ($stashCount -eq 0) {
                Write-Host ""
                Write-Host "[INFO] No stashes found to apply."
            } else {
                Write-Host ""
                Write-Host "Latest stash to apply:"
                git stash list | Select-Object -First 1
                Write-Host ""
                Show-WorkingDirectoryStatus
                
                if (Confirm-DestructiveAction "Apply the latest stash? (This keeps the stash in the stash list)") {
                    Write-Host ""
                    Write-Host "Applying latest stash..."
                    git stash apply
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[OK] Successfully applied latest stash."
                    } else {
                        Write-Host "[ERROR] Failed to apply stash. There may be conflicts."
                    }
                } else {
                    Write-Host "[CANCELLED] Apply operation cancelled."
                }
            }
        }
        "6" {
            $stashCount = Get-StashCount
            if ($stashCount -eq 0) {
                Write-Host ""
                Write-Host "[INFO] No stashes found to pop."
            } else {
                Write-Host ""
                Write-Host "Latest stash to pop:"
                git stash list | Select-Object -First 1
                Write-Host ""
                Show-WorkingDirectoryStatus
                
                if (Confirm-DestructiveAction "Pop the latest stash? (This applies and removes the stash)") {
                    Write-Host ""
                    Write-Host "Popping latest stash..."
                    git stash pop
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "[OK] Successfully popped latest stash."
                    } else {
                        Write-Host "[ERROR] Failed to pop stash. There may be conflicts."
                    }
                } else {
                    Write-Host "[CANCELLED] Pop operation cancelled."
                }
            }
        }
        "7" {
            $stashCount = Get-StashCount
            if ($stashCount -eq 0) {
                Write-Host ""
                Write-Host "[INFO] No stashes found to show."
            } else {
                Write-Host ""
                Write-Host "Latest stash:"
                git stash list | Select-Object -First 1
                Write-Host ""
                Write-Host "Stash content:"
                Write-Host "=================="
                git stash show -p stash@{0}
            }
        }
        { $_ -in @("b", "B") } {
            & "$RootDir\start.ps1"
            break
        }
        { $_ -in @("q", "Q", "quit", "exit") } {
            Write-Host "Exiting stash manager."
            exit 0
        }
        default {
            Write-Host "[ERROR] Invalid choice. Try again."
        }
    }
    
    Write-Host ""
    Read-Host "Press Enter to return to the stash menu"
}
