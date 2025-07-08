# -----------------------------------------------------------------------------
# Script: remove_gitignored.ps1
#
# Description:
# This script removes files from Git's index (cache) that are now covered by
# .gitignore rules. This is useful for cleaning up accidentally tracked files
# that should be ignored.
#
# The script performs the following operations:
# 1. Removes all files from Git's index: git rm -r --cached .
# 2. Re-adds files respecting .gitignore: git add .
# 3. Creates a commit with the changes
#
# This effectively removes any files that are now ignored by .gitignore
# from being tracked by Git, while keeping them in the working directory.
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
    Write-Host "❌ Not in a git repository. Please navigate to a git repository and try again."
    exit 1
}

# --- Check if .gitignore exists ---
if (-not (Test-Path ".gitignore")) {
    Write-Host "⚠️  No .gitignore file found in the current directory."
    Write-Host "   This operation is most effective when you have a .gitignore file."
    Write-Host ""
    $confirm = Read-Host "🤔 Do you want to continue anyway? [y/N]"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "❌ Operation cancelled."
        exit 0
    }
    Write-Host ""
}

Write-Host ""
Write-Host "🧹 Remove Gitignored Files Tool"
Write-Host "==============================="
Write-Host ""
Write-Host "This will remove files from Git's index that are now covered by .gitignore."
Write-Host ""
Write-Host "📋 What this does:"
Write-Host "   1. Removes all files from Git's index (git rm -r --cached .)"
Write-Host "   2. Re-adds files respecting .gitignore rules (git add .)"
Write-Host "   3. Creates a commit with the changes"
Write-Host ""
Write-Host "⚠️  Important notes:"
Write-Host "   - Files will remain in your working directory"
Write-Host "   - Only files that are now ignored will be removed from tracking"
Write-Host "   - This will create a new commit"
Write-Host ""

# --- Show current status ---
Write-Host "📊 Current Git status:"
$gitStatus = git status --porcelain
$gitStatusLines = $gitStatus -split "`n" | Where-Object { $_ -ne "" }
$gitStatusLines | Select-Object -First 10 | ForEach-Object { Write-Host $_ }
if ($gitStatusLines.Count -gt 10) {
    Write-Host "   ... and $($gitStatusLines.Count - 10) more files"
}
Write-Host ""

# --- Check for uncommitted changes ---
if ($gitStatusLines.Count -gt 0) {
    Write-Host "⚠️  You have uncommitted changes in your working directory."
    Write-Host "   It's recommended to commit or stash these changes first."
    Write-Host ""
    $confirm = Read-Host "🤔 Do you want to continue anyway? [y/N]"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "❌ Operation cancelled."
        exit 0
    }
    Write-Host ""
}

# --- Show what will be removed ---
Write-Host "🔍 Analyzing what will be removed..."
Write-Host ""

# Get list of currently tracked files that would be ignored
$trackedFiles = git ls-files
$trackedIgnoredFiles = $trackedFiles | git check-ignore --stdin 2>$null

if ($trackedIgnoredFiles) {
    Write-Host "📋 Files that will be removed from tracking:"
    $trackedIgnoredFiles | Select-Object -First 10 | ForEach-Object { Write-Host $_ }
    if ($trackedIgnoredFiles.Count -gt 10) {
        Write-Host "   ... and $($trackedIgnoredFiles.Count - 10) more files"
    }
    Write-Host ""
} else {
    Write-Host "✅ No tracked files are currently ignored by .gitignore."
    Write-Host "   This operation won't make any changes."
    Write-Host ""
    $confirm = Read-Host "🤔 Do you want to continue anyway? [y/N]"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "❌ Operation cancelled."
        exit 0
    }
    Write-Host ""
}

# --- Confirmation ---
$confirm = Read-Host "🚀 Do you want to proceed with removing ignored files? [y/N]"
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "❌ Operation cancelled."
    exit 0
}

Write-Host ""
Write-Host "🔄 Starting removal process..."

# --- Step 1: Remove all files from index ---
Write-Host "📤 Step 1: Removing all files from Git's index..."
git rm -r --cached .
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully removed all files from index."
} else {
    Write-Host "❌ Failed to remove files from index."
    exit 1
}

# --- Step 2: Re-add files respecting .gitignore ---
Write-Host "📥 Step 2: Re-adding files respecting .gitignore..."
git add .
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully re-added files respecting .gitignore."
} else {
    Write-Host "❌ Failed to re-add files."
    exit 1
}

# --- Check what changed ---
Write-Host ""
Write-Host "📊 Changes made:"
git status --porcelain
Write-Host ""

# --- Step 3: Commit changes ---
$newStatus = git status --porcelain
if ($newStatus) {
    Write-Host "💾 Step 3: Creating commit..."
    
    # Generate commit message
    $removedCount = ($newStatus -split "`n" | Where-Object { $_ -match "^D" }).Count
    $addedCount = ($newStatus -split "`n" | Where-Object { $_ -match "^A" }).Count
    $modifiedCount = ($newStatus -split "`n" | Where-Object { $_ -match "^M" }).Count
    
    $commitMsg = "Remove ignored files from Git tracking"
    if ($removedCount -gt 0) {
        $commitMsg = "$commitMsg (removed $removedCount files)"
    }
    if ($addedCount -gt 0) {
        $commitMsg = "$commitMsg, re-added $addedCount files"
    }
    if ($modifiedCount -gt 0) {
        $commitMsg = "$commitMsg, modified $modifiedCount files"
    }
    
    Write-Host "📝 Commit message: $commitMsg"
    Write-Host ""
    
    $confirm = Read-Host "👉 Do you want to commit these changes? [y/N]"
    if ($confirm -match "^[Yy]$") {
        git commit -m "$commitMsg"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Successfully committed changes."
            Write-Host ""
            Write-Host "🎉 Operation completed successfully!"
            Write-Host "📋 Summary:"
            Write-Host "   - Removed ignored files from Git tracking"
            Write-Host "   - Files remain in your working directory"
            Write-Host "   - Changes committed to repository"
        } else {
            Write-Host "❌ Failed to commit changes."
            exit 1
        }
    } else {
        Write-Host "ℹ️  Changes staged but not committed."
        Write-Host "   You can review the changes with 'git status' and commit manually."
    }
} else {
    Write-Host "✅ No changes to commit - all files are already properly ignored."
}

Write-Host ""
Write-Host "💡 Tip: You can now push these changes to share the cleanup with your team." 