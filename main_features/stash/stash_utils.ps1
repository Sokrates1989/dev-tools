# -----------------------------------------------------------------------------
# Script: stash_utils.ps1
#
# Description:
# Common utility functions for stash operations.
# These functions can be reused across different stash scripts.
# PowerShell 5.1 compatible version.
# -----------------------------------------------------------------------------

# Function to check if we're in a git repository
function Test-GitRepository {
    try {
        $null = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Not a git repository"
        }
        return $true
    } catch {
        Write-Host "❌ Error: Not in a Git repository."
        Write-Host "Please navigate to a Git repository and try again."
        return $false
    }
}

# Function to get stash count
function Get-StashCount {
    $stashList = git stash list
    if ($stashList) {
        return ($stashList | Measure-Object).Count
    } else {
        return 0
    }
}

# Function to display repository status
function Show-RepositoryStatus {
    Write-Host "📋 Current Repository Status:"
    $repoPath = git rev-parse --show-toplevel
    $repoName = Split-Path -Leaf $repoPath
    $currentBranch = git branch --show-current
    Write-Host "Repository: $repoName"
    Write-Host "Branch: $currentBranch"
    Write-Host ""
}

# Function to display stash count and latest stash
function Show-StashSummary {
    $stashCount = Get-StashCount
    Write-Host "📦 Current Stash Count: $stashCount"
    if ($stashCount -gt 0) {
        $latestStash = git stash list | Select-Object -First 1
        Write-Host "Latest stash: $latestStash"
    }
    Write-Host ""
}

# Function to list all stashes with numbered format
function Show-StashesNumbered {
    $stashList = git stash list
    if (-not $stashList) {
        return $false
    }
    
    $stashList | ForEach-Object -Begin { $index = 1 } -Process {
        Write-Host "$index) $_"
        $index++
    }
    return $true
}

# Function to validate stash input and convert to reference
function Get-ValidatedStashRef {
    param(
        [string]$Input,
        [int]$StashCount
    )
    
    if ($Input -match '^\d+$') {
        # User entered a number, convert to stash reference
        $stashIndex = [int]$Input - 1
        if ($stashIndex -lt 0 -or $stashIndex -ge $StashCount) {
            Write-Host "❌ Invalid stash index. Please enter a number between 1 and $StashCount."
            return $null
        }
        return "stash@{$stashIndex}"
    } elseif ($Input -match '^stash@\{\d+\}$') {
        # User entered a stash reference
        if ($Input -match 'stash@\{(\d+)\}') {
            $stashIndex = [int]$matches[1]
            if ($stashIndex -ge $StashCount) {
                Write-Host "❌ Invalid stash reference. Stash $Input does not exist."
                return $null
            }
        }
        return $Input
    } else {
        Write-Host "❌ Invalid input. Please enter a number or stash reference like 'stash@{0}'."
        return $null
    }
}

# Function to get stash info by reference
function Get-StashInfo {
    param([string]$StashRef)
    
    $stashList = git stash list
    return $stashList | Where-Object { $_ -match "^$([regex]::Escape($StashRef)):" }
}

# Function to show working directory status
function Show-WorkingDirectoryStatus {
    Write-Host "📋 Current working directory status:"
    $gitStatus = git status --porcelain
    $hasChanges = $gitStatus -and ($gitStatus | Measure-Object).Count -gt 0
    
    if (-not $hasChanges) {
        Write-Host "✅ Working directory is clean."
    } else {
        Write-Host "⚠️  Working directory has uncommitted changes:"
        $gitStatus | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
        Write-Host "⚠️  Warning: Stash operations may conflict with current changes."
    }
}

# Function to wait for user to continue
function Wait-ForContinue {
    Write-Host ""
    Read-Host "🔁 Press Enter to continue"
}

# Function to confirm destructive action
function Confirm-DestructiveAction {
    param([string]$Message)
    
    Write-Host ""
    $confirm = Read-Host "$Message (yes/no)"
    return $confirm -eq "yes"
}
