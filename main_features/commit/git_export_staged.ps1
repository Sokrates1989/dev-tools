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

# Load utilities
. (Join-Path $ScriptDir "utils\version_utils.ps1")
. (Join-Path $ScriptDir "utils\file_content_utils.ps1")

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

# Ask for JIRA Task ID (single-step input)
Write-Host ""
$jiraInput = Read-Host " Enter JIRA task ID (e.g. FA-123, or press Enter for none)"
if (-not $jiraInput -or $jiraInput -match '^[Nn]$') {
    $jiraId = $null
}
else {
    $jiraId = $jiraInput
}

# Create file to pass variables to handle_export_api
$varsFile = Join-Path $ExportDir ".commit_vars"
@"
JIRA_ID=$jiraId
IMAGE_VERSION=$imageVersion
VERSION_FILES_STAGED=$versionFilesStaged
"@ | Out-File -FilePath $varsFile -Encoding UTF8

# Style instruction for AI (high priority)
$TaskID = '===== STYLE INSTRUCTION - HIGH PRIORITY ===== Summarize ALL staged changes in a single one-line git commit command. Use the format from the COMMIT MESSAGE PROMPT. Use a short feature or area name instead of listing individual filenames (e.g. "Docker Swarm prep" instead of "README.md, build-image/README.md, docs/ARCHITECTURE.md, docs/DOCKER_DEPLOYMENT.md, docs/QUICK_START.md"). If there is no clear single area, omit the area label and start directly with the description. Never invent or output dummy task IDs; always leave JIRA_ID_PLACEHOLDER exactly as shown. Choose the Category so it reflects the overall nature of all staged changes; do not use the Documentation category when there are significant script, setup, build, deployment, or code changes. Use Documentation when the changes are documentation-focused (docs/README/usage text and related screenshots/images/diagrams) and there are no behavior or tooling changes; prefer Setup, Env, or Git for setup/tooling changes and Functionality, New Feature, or BugFix for behavior changes.'

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
Add-Content $AiMessageFile ""

# Generate files summary first
Add-Content $AiMessageFile "===== FILES SUMMARY ====="
$filesSummary = Get-FilesSummary -Files $StagedFiles
Add-Content $AiMessageFile $filesSummary
Add-Content $AiMessageFile ""

Add-Content $AiMessageFile "===== STAGED DIFF ====="
$smartDiff = Get-SmartDiffContent -DiffFile $DiffFile
Add-Content $AiMessageFile $smartDiff
Add-Content $AiMessageFile ""

Add-Content $AiMessageFile "===== STAGED FILE CONTENTS ====="
Add-Content $AiMessageFile "(Binary and large files show metadata only)"
Add-Content $AiMessageFile ""
foreach ($file in $StagedFiles) {
    $basename = Split-Path $file -Leaf
    Add-Content $AiMessageFile "--- $basename ---"
    $smartContent = Get-SmartFileContent -FilePath $file
    Add-Content $AiMessageFile $smartContent
    Add-Content $AiMessageFile ""
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