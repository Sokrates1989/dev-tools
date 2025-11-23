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

# --- Sync check before commit ---
Write-Host "Checking if branch is in sync with remote..." -ForegroundColor Cyan
$syncResult = & "$RootDir\global_functions\sync_check.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Sync check failed. Please resolve sync issues before committing." -ForegroundColor Red
    exit 1
}

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

# Load version utilities
. (Join-Path $ScriptDir "utils\version_utils.ps1")

# Initialize variables for replacements
$jiraId = $null
$imageVersion = $null
$versionFilesStaged = $null

# Detect CI/CD setup
$hasCiCd = Test-CiCdSetup

if ($hasCiCd) {
    Write-Host ""
    Write-Host " CI/CD configuration detected in this repository" -ForegroundColor Cyan
    
    # Get current version info
    $versionInfo = Get-CurrentVersion
    
    # Check if .ci.env is staged for commit
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if ($repoRoot) {
        $repoRoot = $repoRoot -replace '/', '\'
        $ciEnvPath = Join-Path $repoRoot ".ci.env"
        
        # Check if .ci.env is in staged files
        $ciEnvStaged = git diff --cached --name-only | Where-Object { $_ -eq ".ci.env" }
        
        if ($ciEnvStaged) {
            Write-Host ""
            Write-Host "NOTE: .ci.env is staged and will be committed" -ForegroundColor Cyan
            
            # Get old and new version from git diff
            $diffOutput = git diff --cached $ciEnvPath 2>$null | Out-String
            $oldVersion = $null
            $newVersion = $null
            
            # Match lines with IMAGE_VERSION, handling BOM and special characters
            if ($diffOutput -match '(?m)^\-IMAGE_VERSION=([^\r\n]+)') {
                $oldVersion = $Matches[1].Trim()
            }
            if ($diffOutput -match '(?m)^\+[^\r\n]*IMAGE_VERSION=([^\r\n]+)') {
                $newVersion = $Matches[1].Trim()
            }
            
            if ($oldVersion -and $newVersion -and $oldVersion -ne $newVersion) {
                Write-Host "  Version change: $oldVersion -> $newVersion" -ForegroundColor Green
                
                # Ask user if they want to accept this staged version
                Write-Host ""
                $acceptStaged = Read-Host " Accept this staged version change? [Y/n]"
                if ($acceptStaged -notmatch '^[Nn]$') {
                    # User accepts the staged version
                    $imageVersion = $newVersion
                    Write-Host "  Using staged version: $imageVersion" -ForegroundColor Cyan
                    
                    # Update .env to match .ci.env to keep them in sync
                    $envFile = Join-Path $repoRoot ".env"
                    if (Test-Path $envFile) {
                        $envContent = Get-Content $envFile -ErrorAction SilentlyContinue
                        $envHasVersion = $envContent | Where-Object { $_ -match '^IMAGE_VERSION=' }
                        
                        if ($envHasVersion) {
                            # Update existing IMAGE_VERSION in .env
                            $updated = $false
                            $newEnvContent = @()
                            foreach ($line in $envContent) {
                                if (-not $updated -and $line -match '^IMAGE_VERSION=') {
                                    $newEnvContent += "IMAGE_VERSION=$imageVersion"
                                    $updated = $true
                                }
                                else {
                                    $newEnvContent += $line
                                }
                            }
                            $newEnvContent | Set-Content -Path $envFile -Encoding UTF8
                            Write-Host "  Synced .env to version: $imageVersion" -ForegroundColor Gray
                        }
                    }
                }
                else {
                    # User wants to change the version
                    Write-Host ""
                    Write-Host "Current IMAGE_VERSION:" -ForegroundColor Cyan
                    $envDisplay = if ($versionInfo.EnvVersion) { $versionInfo.EnvVersion } else { "<not set>" }
                    $ciEnvDisplay = if ($versionInfo.CiEnvVersion) { $versionInfo.CiEnvVersion } else { "<not set>" }
                    Write-Host "  - .env    : $envDisplay" -ForegroundColor Gray
                    Write-Host "  - .ci.env : $ciEnvDisplay" -ForegroundColor Gray
                    
                    $newVersionChoice = Invoke-VersionUpdatePrompt -VersionInfo $versionInfo
                    if ($newVersionChoice) {
                        # Update version in files and stage them
                        $versionFilesStaged = Update-RepoVersion -NewVersion $newVersionChoice
                        if ($versionFilesStaged) {
                            $imageVersion = $newVersionChoice
                            Write-Host ""
                            Write-Host " Version updated to: $imageVersion" -ForegroundColor Green
                        }
                    }
                }
            }
            elseif ($newVersion) {
                Write-Host "  Current staged version: $newVersion" -ForegroundColor Gray
                # Use the staged version for commit message
                $imageVersion = $newVersion
            }
        }
        else {
            # No staged .ci.env, show normal prompt
            Write-Host ""
            Write-Host "Current IMAGE_VERSION:" -ForegroundColor Cyan
            $envDisplay = if ($versionInfo.EnvVersion) { $versionInfo.EnvVersion } else { "<not set>" }
            $ciEnvDisplay = if ($versionInfo.CiEnvVersion) { $versionInfo.CiEnvVersion } else { "<not set>" }
            Write-Host "  - .env    : $envDisplay" -ForegroundColor Gray
            Write-Host "  - .ci.env : $ciEnvDisplay" -ForegroundColor Gray
            
            if ($versionInfo.Version) {
                Write-Host "  Base version: $($versionInfo.Version) (from $($versionInfo.Source))" -ForegroundColor Green
            }
            else {
                Write-Host "  No version found - will default to 0.0.0" -ForegroundColor Yellow
            }
            
            Write-Host ""
            $updateVersion = Read-Host " Do you want to update IMAGE_VERSION? [y/N]"
            if ($updateVersion -match '^[Yy]$') {
                $newVersionChoice = Invoke-VersionUpdatePrompt -VersionInfo $versionInfo
                
                if ($newVersionChoice) {
                    # Update version in files and stage them
                    $versionFilesStaged = Update-RepoVersion -NewVersion $newVersionChoice
                    if ($versionFilesStaged) {
                        $imageVersion = $newVersionChoice
                        Write-Host ""
                        Write-Host " Version updated to: $imageVersion" -ForegroundColor Green
                    }
                }
            }
        }
    }
    else {
        # No CI/CD, no version management needed
    }
}

# Ask for JIRA Task ID
Write-Host ""
$addJira = Read-Host " Do you want to add a JIRA task ID to the commit message? [y/N]"
if ($addJira -match '^[Yy]$') {
    $jiraId = Invoke-JiraIdPrompt
}

# Create file to pass variables to handle_export_api
$varsFile = Join-Path $ExportDir ".commit_vars"
@"
JIRA_ID=$jiraId
IMAGE_VERSION=$imageVersion
VERSION_FILES_STAGED=$versionFilesStaged
"@ | Out-File -FilePath $varsFile -Encoding UTF8

# Set TaskID for backwards compatibility
$TaskID = "JIRA_ID_PLACEHOLDER"

# Prompt for Project Task ID.
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

Add-Content $AiMessageFile $TaskID
Add-Content $AiMessageFile ""

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