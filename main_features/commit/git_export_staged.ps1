# Get the script directories.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$PSScriptRoot\..\.." | Select-Object -ExpandProperty Path

$ExportDir         = Join-Path $ScriptDir "git_export_staged"
$ChangedFilesDir   = Join-Path $ExportDir "changed_files"
$DiffFile          = Join-Path $ExportDir "last_staged_commit_diff.txt"
$AllInOneDir       = Join-Path $ExportDir "all_in_one"
$AiMessageFile     = Join-Path $AllInOneDir "ai_message.txt"
$CommitMsgFile     = Join-Path $ScriptDir "commit_message_prompt.txt"


# Git update check.
& "$RootDir\global_functions\check_for_updates.ps1"

# Load .env file.
. "$RootDir\global_functions\load_dotenv.ps1"
Load-DotEnv

# Ensure the export directory exists and is empty.
if (Test-Path $ExportDir) {
    Remove-Item -Recurse -Force $ExportDir
}
New-Item -ItemType Directory -Path $ChangedFilesDir -Force | Out-Null
New-Item -ItemType Directory -Path $AllInOneDir -Force | Out-Null


# Check if any files are staged.
$StagedFiles = git diff --cached --name-only
if (-not $StagedFiles) {
    Write-Host "WARNING: No staged files to export."
    exit 1
}


# Export each staged file to flat folder.
foreach ($file in $StagedFiles) {
    $TargetPath = Join-Path $ExportDir (Split-Path $file -Leaf)
    try {
        git show ":$file" > $TargetPath
    } catch {
        Write-Host "WARNING: Could not export file: $file"
    }
}


# Save the diff to a file.
git diff --staged > $DiffFile


# Copy commit_message_prompt.txt if available.
if (Test-Path $CommitMsgFile) {
    Copy-Item $CommitMsgFile -Destination $ExportDir
}


# Prompt for Project Task ID.
$TaskID = Read-Host "INPUT: Enter related Project Task ID (or press Enter to skip)"
if (-not $TaskID) {
    $TaskID = '===== STYLE INSTRUCTION - HIGH PRIORITY ===== Please ignore any template that starts with [ID-XY | ...]. Instead, format the message like this: [Categories] Affected files or feature: more details of the change. Do not include any dummy or placeholder task ID.'
}

# Compose the AI message prompt file.
Remove-Item -Force $AiMessageFile -ErrorAction SilentlyContinue
"" | Out-File $AiMessageFile

# Add the Task ID / Style instruction at the very top.
Add-Content $AiMessageFile $TaskID
Add-Content $AiMessageFile ""

# Add commit message and other prompts.
Add-Content $AiMessageFile "===== COMMIT MESSAGE PROMPT ====="
if (Test-Path $CommitMsgFile) {
    Get-Content $CommitMsgFile | Add-Content $AiMessageFile
} else {
    Add-Content $AiMessageFile "(no commit_message_prompt.txt found)"
}
Add-Content $AiMessageFile "===== STAGED DIFF ====="
Get-Content $DiffFile | Add-Content $AiMessageFile

Add-Content $AiMessageFile "===== STAGED FILE CONTENTS ====="
foreach ($file in $StagedFiles) {
    $basename = Split-Path $file -Leaf
    $flatPath = Join-Path $ChangedFilesDir $basename
    if (Test-Path $flatPath) {
        Add-Content $AiMessageFile "--- $basename ---"
        Get-Content $flatPath | Add-Content $AiMessageFile
        Add-Content $AiMessageFile ""
    }
}


# Call the appropriate post-export handler.
$AI_MODE = $env:AI_MODE
Write-Host "AI Mode: -> $AI_MODE"
if ($AI_MODE -eq "api") {
    & "$ScriptDir\handle_export_api.ps1"
} else {
    if ($AI_MODE -eq "manual") {
        & "$ScriptDir\handle_export_manual.ps1"
    } else
    {
        & "$ScriptDir\handle_export_manual.ps1"
    }
}
