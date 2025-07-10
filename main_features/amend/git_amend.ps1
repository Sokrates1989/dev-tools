# -----------------------------------------------------------------------------
# Script: git_amend.ps1
#
# Description:
# This script allows users to amend the last commit with two options:
# 1. Amend without changing the commit message (git commit --amend --no-edit)
# 2. Amend with a new commit message by regenerating it using the existing
#    commit functionality after temporarily removing the last commit
#
# The script checks if the commit has been pushed to remote and warns the user
# if it has been pushed.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir\..\.." | Select-Object -ExpandProperty Path
$CommitScriptDir = Join-Path $ScriptDir "..\commit"

# Load environment variables.
. "$RootDir\global_functions\load_dotenv.ps1"
Load-DotEnv

# --- Git update check ---
& "$RootDir\global_functions\check_for_updates.ps1"

# --- Check if we're in a git repository ---
try {
    $null = git rev-parse --git-dir 2>$null
} catch {
    Write-Host "❌ Not in a git repository. Please navigate to a git repository and try again."
    exit 1
}

# --- Check if there are any commits ---
try {
    $null = git rev-parse HEAD 2>$null
} catch {
    Write-Host "❌ No commits found in this repository. Please make at least one commit first."
    exit 1
}

# --- Check if there are any staged files ---
$StagedFiles = git diff --name-only --cached

# Exit early if no staged files.
if ([string]::IsNullOrEmpty($StagedFiles)) {
    Write-Host "⚠️  No staged files found. Please stage some changes with 'git add' before running this script."
    Write-Host ""
    Write-Host "💡 Amending without new staged changes is pointless since there's nothing new to amend."
    Write-Host "   Stage your changes first, then run this script again."
    exit 0
}

# --- Get the last commit hash and check if it's been pushed ---
$LastCommitHash = git rev-parse HEAD
$LastCommitMsg = git log -1 --pretty=format:"%s"
$BranchName = git branch --show-current

Write-Host ""
Write-Host "🔄 Git Amend Tool"
Write-Host "================="
Write-Host ""
Write-Host "📝 Last commit: $LastCommitHash"
Write-Host "📄 Message: $LastCommitMsg"
Write-Host "🌿 Branch: $BranchName"
Write-Host ""

# --- Check if the commit has been pushed ---
$RemoteBranches = git branch -r
if ($RemoteBranches -match "origin/$BranchName") {
    # Remote branch exists, check if local is ahead
    $LocalCommits = git rev-list HEAD --not origin/$BranchName --count
    if ($LocalCommits -eq 0) {
        Write-Host "❌ Cannot amend: This commit has already been pushed to the remote repository."
        Write-Host ""
        Write-Host "🔄 Instead of amending, you should create a new commit:"
        Write-Host "   1. Stage any additional changes: git add ."
        Write-Host "   2. Create a new commit with the existing commit functionality"
        Write-Host "   3. Push the new commit to remote"
        Write-Host ""
        Write-Host "💡 This approach is safer and won't rewrite history."
        Write-Host ""
        $confirm = Read-Host "🚀 Would you like to create a new commit instead? [y/N]"
        if ($confirm -match "^[Yy]$") {
            Write-Host ""
            Write-Host "🚀 Redirecting to commit functionality..."
            Write-Host ""
            & "$CommitScriptDir\git_export_staged.ps1"
        } else {
            Write-Host "❌ Operation cancelled."
        }
        exit 0
    }
}

# --- Show amend options ---
Write-Host "Choose an amend option:"
Write-Host ""
Write-Host "1) 🔄 Amend without changing commit message"
Write-Host "2) ✏️  Amend with new commit message (regenerate)"
Write-Host "3) ❌ Cancel"
Write-Host ""

$choice = Read-Host "Enter your choice [1-3]"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "🔄 Amending commit without changing message..."
        Write-Host "Command: git commit --amend --no-edit"
        Write-Host ""
        $confirm = Read-Host "👉 Do you want to proceed? [y/N]"
        if ($confirm -match "^[Yy]$") {
            git commit --amend --no-edit
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Commit amended successfully!"
                Write-Host ""
                $NewCommitHash = git rev-parse HEAD
                $NewCommitMsg = git log -1 --pretty=format:"%s"
                Write-Host "📝 New commit hash: $NewCommitHash"
                Write-Host "📄 Message: $NewCommitMsg"
            } else {
                Write-Host "❌ Failed to amend commit."
                exit 1
            }
        } else {
            Write-Host "❌ Amend cancelled."
        }
    }
    "2" {
        Write-Host ""
        Write-Host "✏️  Amending with new commit message..."
        Write-Host ""
        Write-Host "This will:"
        Write-Host "1. Temporarily remove the last commit (keeping changes staged)"
        Write-Host "2. Use the existing commit functionality to generate a new message"
        Write-Host "3. Create a new commit with the new message"
        Write-Host ""
        $confirm = Read-Host "👉 Do you want to proceed? [y/N]"
        if ($confirm -match "^[Yy]$") {
            Write-Host ""
            Write-Host "🔄 Temporarily removing last commit..."
            
            # Store the current staged changes
            git reset --soft HEAD~1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Last commit removed. Changes are now staged."
                Write-Host ""
                Write-Host "🚀 Now using the commit functionality to generate a new message..."
                Write-Host ""
                
                # Call the existing commit functionality
                & "$CommitScriptDir\git_export_staged.ps1"
            } else {
                Write-Host "❌ Failed to remove last commit."
                exit 1
            }
        } else {
            Write-Host "❌ Amend cancelled."
        }
    }
    "3" {
        Write-Host "❌ Amend cancelled."
    }
    default {
        Write-Host "❌ Invalid choice. Please select 1, 2, or 3."
        exit 1
    }
} 