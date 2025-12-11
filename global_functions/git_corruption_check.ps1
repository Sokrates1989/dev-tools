# -----------------------------------------------------------------------------
# Script: git_corruption_check.ps1
# Description: Shared utilities for detecting and handling git corruption
# Usage: Dot-source this file in other scripts to get corruption detection
# Platform: PowerShell compatible (Windows/Mac/Linux)
# -----------------------------------------------------------------------------

# Function to check if output indicates git corruption
# Usage: if (Test-GitCorruptionInOutput $output) { ... }
function Test-GitCorruptionInOutput {
    param([string]$Output)
    
    $corruptionPatterns = @(
        "far too short to be a packfile",
        "invalid object",
        "Error building trees",
        "broken link",
        "missing blob",
        "missing tree",
        "fatal: unable to read tree",
        "unable to read"
    )
    
    foreach ($pattern in $corruptionPatterns) {
        if ($Output -match [regex]::Escape($pattern)) {
            return $true
        }
    }
    return $false
}

# Function to show git corruption error message and repair instructions
# Usage: Show-GitCorruptionMessage
function Show-GitCorruptionMessage {
    Write-Host ""
    Write-Host "Warning: Git repository corruption detected!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This error typically occurs when pack files in your .git directory are corrupted."
    Write-Host ""
    Write-Host "To repair this repository, you can run:"
    Write-Host "  dev-tools --repair" -ForegroundColor Cyan
    Write-Host "  or: dev-tools -f" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or manually:"
    Write-Host "  1. Backup your uncommitted changes"
    Write-Host "  2. Remove corrupted pack files from .git/objects/pack/"
    Write-Host "  3. Run: git fetch --all"
    Write-Host "  4. Run: git gc --prune=now"
    Write-Host ""
}

# Function to offer to run dev-tools repair
# Usage: $result = Invoke-GitRepairOffer
# Returns: $true if repair was run successfully, $false otherwise
function Invoke-GitRepairOffer {
    Write-Host ""
    $repairConfirm = Read-Host "Would you like to attempt automatic repair using dev-tools? [Y/n]"
    
    if ($repairConfirm -notmatch "^[Nn]$") {
        # Try to find dev-tools
        $devToolsPath = $null
        
        # Check if dev-tools command exists
        $devToolsCmd = Get-Command "dev-tools" -ErrorAction SilentlyContinue
        if ($devToolsCmd) {
            Write-Host ""
            Write-Host "Running: dev-tools --repair"
            & dev-tools --repair
            return ($LASTEXITCODE -eq 0)
        }
        
        # Try to find the script in common locations
        $scriptDir = Split-Path -Parent $PSScriptRoot
        $possiblePaths = @(
            "$scriptDir\main_features\git-repair\git_repair.ps1",
            "$PSScriptRoot\..\main_features\git-repair\git_repair.ps1"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $devToolsPath = $path
                break
            }
        }
        
        if ($devToolsPath) {
            Write-Host ""
            Write-Host "Running: $devToolsPath"
            & $devToolsPath
            return ($LASTEXITCODE -eq 0)
        }
        
        Write-Host ""
        Write-Host "dev-tools command not found in PATH." -ForegroundColor Red
        Show-GitCorruptionMessage
        return $false
    }
    return $false
}

# Function to check git command output and handle corruption
# Usage: $result = Test-GitCommandResult -ExitCode $code -Output $output -OperationName "Git operation"
# Returns: $true if no error, $false if error (with corruption handling if applicable)
function Test-GitCommandResult {
    param(
        [int]$ExitCode,
        [string]$Output,
        [string]$OperationName = "Git operation"
    )
    
    if ($ExitCode -ne 0) {
        Write-Host ""
        Write-Host "$OperationName failed (exit code: $ExitCode)" -ForegroundColor Red
        
        if (Test-GitCorruptionInOutput $Output) {
            Show-GitCorruptionMessage
            Invoke-GitRepairOffer
            return $false
        }
        
        return $false
    }
    
    return $true
}

# Function to run a git command with corruption detection
# Usage: $result = Invoke-GitWithCorruptionCheck -Command "git status" -OperationName "Git status"
# Returns: exit code of the command (after potential repair)
function Invoke-GitWithCorruptionCheck {
    param(
        [string]$Command,
        [string]$OperationName = "Git operation"
    )
    
    $output = Invoke-Expression "$Command 2>&1" | Out-String
    $exitCode = $LASTEXITCODE
    
    Write-Host $output
    
    if (-not (Test-GitCommandResult -ExitCode $exitCode -Output $output -OperationName $OperationName)) {
        return 1
    }
    
    return 0
}
