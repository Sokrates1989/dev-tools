# -----------------------------------------------------------------------------
# Script: ui_utils.ps1
# Description: Utility functions for UI operations in commit scripts
# Platform: Windows PowerShell 5.1 compatible
# -----------------------------------------------------------------------------

# Function to show commit message options menu
function Show-CommitOptions {
    param(
        [string]$CommitMessage
    )
    
    Write-Host ""
    Write-Host "[OK] AI suggested commit command:"
    Write-Host "--------------------------"
    Write-Host $CommitMessage

    Write-Host ""
    Write-Host "Options:"
    Write-Host "[Enter] Accept as is"
    Write-Host "[E] Edit manually"
    Write-Host "[R] Regenerate message"
    Write-Host "[C] Chat with AI"
    Write-Host ""
}

# Function to edit commit message using Notepad
function Edit-CommitMessage {
    param(
        [string]$CommitMessage
    )
    
    # Create temp file with .txt extension
    $tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) `
    -ChildPath ("commit_msg_{0}.txt" -f ([System.Guid]::NewGuid().ToString()))

    # Write content safely
    Set-Content -Path $tempFile -Value $CommitMessage -Encoding UTF8 -Force

    # Start editor
    Write-Host ""
    Write-Host "Opening Notepad so you can edit the commit message..."
    $notepadProcess = Start-Process -FilePath "notepad.exe" -ArgumentList $tempFile -PassThru
    $notepadProcess.WaitForExit()

    # Read content back
    $finalCommitMessage = Get-Content -Path $tempFile -Raw -Encoding UTF8
    Remove-Item $tempFile -Force

    return $finalCommitMessage
}

# Function to validate commit message format
function Test-CommitMessageFormat {
    param(
        [string]$CommitMessage
    )
    
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        Write-Host "Commit message is empty. Please rerun the script or commit manually."
        return $false
    }
    
    $commitMessage = $CommitMessage.Trim()

    # Regex: Must match pattern exactly
    $pattern = '^git commit -m "([^"]+)"$'
    if ($commitMessage -notmatch $pattern) {
        Write-Host "Invalid commit command!"
        Write-Host 'The command must follow this structure:'
        Write-Host 'git commit -m "Your message here"'
        return $false
    }
    
    return $true
}

# Function to check if output indicates git corruption
function Test-GitCorruptionOutput {
    param([string]$Output)
    
    return $Output -match "(far too short to be a packfile|invalid object|Error building trees|broken link|missing blob|missing tree|fatal: unable to read tree)"
}

# Function to offer git repair
function Invoke-GitRepairOffer {
    Write-Host ""
    Write-Host "Git repository corruption detected!" -ForegroundColor Red
    Write-Host ""
    Write-Host "This error typically occurs when pack files in your .git directory are corrupted."
    Write-Host ""
    
    # Check if dev-tools repair is available
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $repairScript = Join-Path (Split-Path -Parent (Split-Path -Parent $scriptDir)) "git-repair\git_repair.ps1"
    
    if (Test-Path $repairScript) {
        $repairConfirm = Read-Host "Would you like to attempt automatic repair? [Y/n]"
        if ($repairConfirm -notmatch "^[Nn]$") {
            Write-Host ""
            . $repairScript
            return Repair-GitRepo "."
        }
    } else {
        Write-Host "To repair this repository, you can run:"
        Write-Host "  dev-tools --repair"
        Write-Host ""
        Write-Host "Or manually:"
        Write-Host "  1. Backup your uncommitted changes"
        Write-Host "  2. Remove corrupted pack files from .git\objects\pack\"
        Write-Host "  3. Run: git fetch --all"
        Write-Host "  4. Run: git gc --prune=now"
    }
    return $false
}

# Function to handle commit execution
function Invoke-CommitExecution {
    param(
        [string]$CommitCommand
    )
    
    Write-Host ""
    Write-Host "Final commit message:"
    Write-Host "--------------------------"
    Write-Host "$CommitCommand"

    # Auto commit?
    $confirm = Read-Host "Do you want to run this commit command now? [y/N]"
    if ($confirm -match "^[Yy]$") {
        # Capture output and exit code
        $commitOutput = Invoke-Expression "$CommitCommand 2>&1" | Out-String
        $commitExitCode = $LASTEXITCODE
        
        # Display the output
        Write-Host $commitOutput
        
        # Check if commit failed
        if ($commitExitCode -ne 0) {
            Write-Host ""
            Write-Host "Commit failed (exit code: $commitExitCode)" -ForegroundColor Red
            
            # Check if it's a corruption error
            if (Test-GitCorruptionOutput $commitOutput) {
                $repairResult = Invoke-GitRepairOffer
                if ($repairResult) {
                    Write-Host ""
                    Write-Host "Staging all changes before retrying the commit (git add -A)..." -ForegroundColor Cyan
                    git add -A 2>$null | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Warning: 'git add -A' reported errors. Please check 'git status' before retrying." -ForegroundColor Yellow
                    }
                    Write-Host ""

                    # Check for any remaining repaired/broken repos next to this repo
                    $currentPath = Get-Location
                    $parentDir = Split-Path -Parent $currentPath
                    $repoName = Split-Path -Leaf $currentPath

                    $leftoverDirs = @()
                    $leftoverDirs += Get-ChildItem -Path $parentDir -Directory -Filter "$repoName-broken-*" -ErrorAction SilentlyContinue
                    $leftoverDirs += Get-ChildItem -Path $parentDir -Directory -Filter "$repoName-repaired-*" -ErrorAction SilentlyContinue

                    # Also include git repair backup directories from temp
                    if ($env:TEMP) {
                        $leftoverDirs += Get-ChildItem -Path $env:TEMP -Directory -Filter "git-repair-backup-*" -ErrorAction SilentlyContinue
                    }

                    if ($leftoverDirs.Count -gt 0) {
                        Write-Host "The following repaired/broken repositories are still present:" 
                        foreach ($d in $leftoverDirs) {
                            Write-Host "  - $($d.FullName)"
                        }
                        Write-Host ""
                        Write-Host "You can remove them manually later with:" 
                        foreach ($d in $leftoverDirs) {
                            Write-Host "  Remove-Item -Recurse -Force `"$($d.FullName)`"" -ForegroundColor Cyan
                        }
                        Write-Host ""
                        $cleanupConfirm = Read-Host "Type 'remove' to delete ALL of these repair/broken directories now. Otherwise press Enter to keep them"
                        if ($cleanupConfirm -eq "remove") {
                            Write-Host "Removing repair/broken directories..." -ForegroundColor Cyan
                            foreach ($d in $leftoverDirs) {
                                Remove-Item -Path $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
                            }
                            Write-Host "Cleanup completed." -ForegroundColor Green
                        }
                        Write-Host ""
                    }

                    $retryConfirm = Read-Host "Retry the commit now? [Y/n]"
                    if ($retryConfirm -notmatch "^[Nn]$") {
                        Invoke-CommitExecution $CommitCommand
                    }
                }
            } else {
                Write-Host "Please check the error message above and resolve the issue."
            }
            return
        }
        
        Write-Host "Commit executed." -ForegroundColor Green
        Write-Host ""

        # Auto push?
        $pushConfirm = Read-Host "Do you want to push the commit to the remote now? [y/N]"
        if ($pushConfirm -match "^[Yy]$") {
            Write-Host "Pushing changes to remote..."
            $pushStdOutFile = [System.IO.Path]::GetTempFileName()
            $pushStdErrFile = [System.IO.Path]::GetTempFileName()

            try {
                $startProcessParams = @{
                    FilePath = "git"
                    ArgumentList = @("push")
                    NoNewWindow = $true
                    Wait = $true
                    PassThru = $true
                    RedirectStandardOutput = $pushStdOutFile
                    RedirectStandardError = $pushStdErrFile
                }

                $pushProcess = Start-Process @startProcessParams

                $pushExitCode = $pushProcess.ExitCode

                $pushStdOut = ""
                $pushStdErr = ""

                if (Test-Path $pushStdOutFile) {
                    $pushStdOut = Get-Content -Path $pushStdOutFile -Raw -ErrorAction SilentlyContinue
                }

                if (Test-Path $pushStdErrFile) {
                    $pushStdErr = Get-Content -Path $pushStdErrFile -Raw -ErrorAction SilentlyContinue
                }

                $pushOutputParts = @()
                if (-not [string]::IsNullOrWhiteSpace($pushStdOut)) {
                    $pushOutputParts += $pushStdOut.TrimEnd()
                }
                if (-not [string]::IsNullOrWhiteSpace($pushStdErr)) {
                    $pushOutputParts += $pushStdErr.TrimEnd()
                }

                $pushOutput = $pushOutputParts -join [Environment]::NewLine
            }
            finally {
                Remove-Item -Path $pushStdOutFile -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $pushStdErrFile -Force -ErrorAction SilentlyContinue
            }

            Write-Host $pushOutput
            
            if ($pushExitCode -eq 0) {
                Write-Host "Push successful." -ForegroundColor Green
            } else {
                Write-Host "Push failed. Please check your Git configuration or network." -ForegroundColor Red
                
                # Check for corruption in push output too
                if (Test-GitCorruptionOutput $pushOutput) {
                    Invoke-GitRepairOffer
                }
            }
        } else {
            Write-Host "Push skipped. You can run 'git push' later manually."
        }
    } else {
        Write-Host "Commit not executed. You can run it manually:"
        Write-Host $CommitCommand
    }
}

# Function to get user choice for commit options
function Get-UserChoice {
    return Read-Host "Choose an option"
}

# Function to get chat instructions from user
function Get-ChatInstructions {
    Write-Host ""
    Write-Host "Enter your message to chat with the AI about the commit message:"
    Write-Host "Example: 'Make it more concise' or 'Add more technical details' or any other instruction."
    Write-Host ""
    
    return Read-Host "Chat message to AI"
} 