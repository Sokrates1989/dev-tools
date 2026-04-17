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
& "$RootDir\global_functions\sync_check.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Sync check failed. Please resolve sync issues before committing." -ForegroundColor Red
    exit 1
}

# Load .env file.
. "$RootDir\global_functions\load_dotenv.ps1"
Load-DotEnv
$effectiveAiMode = if ($env:DEV_TOOLS_FORCE_AI_MODE) { $env:DEV_TOOLS_FORCE_AI_MODE } else { $env:AI_MODE }

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

$styleInstruction = 'Follow the COMMIT MESSAGE PROMPT section exactly and output a single one-line git commit command.'

# Prepare commit message prompt content
$commitPromptContent = ""
if (Test-Path $CommitMsgFile) {
    $commitPromptContent = Get-Content $CommitMsgFile -Raw
} else {
    $commitPromptContent = "(no commit_message_prompt.txt found)"
}

# Generate files summary
$filesSummary = Get-FilesSummary -Files $StagedFiles

# Get diff content
$smartDiff = Get-SmartDiffContent -DiffFile $DiffFile

# Collect file contents with sizes for token-aware building
$fileContentsArray = @()
foreach ($file in $StagedFiles) {
    $basename = Split-Path $file -Leaf
    $smartContent = Get-SmartFileContent -FilePath $file
    $fileSize = if (Test-Path $file) { (Get-Item $file).Length } else { 0 }
    $fileContentsArray += @{
        name = $basename
        content = "--- $basename ---`n$smartContent"
        size = $fileSize
    }
}

# Build token-aware content
$sections = @{
    style_instruction = $styleInstruction
    commit_prompt = "===== COMMIT MESSAGE PROMPT =====`n$commitPromptContent"
    files_summary = "===== FILES SUMMARY =====`n$filesSummary"
    diff = $smartDiff
    files = $fileContentsArray
}

$tokenAwareResult = Build-TokenAwareContent -Sections $sections

# Compose the AI message prompt file with token-aware content
Remove-Item -Force $AiMessageFile -ErrorAction SilentlyContinue
"" | Out-File $AiMessageFile

# Write the content in proper order
Add-Content $AiMessageFile "===== STYLE INSTRUCTION - HIGH PRIORITY ====="
Add-Content $AiMessageFile $styleInstruction
Add-Content $AiMessageFile ""

Add-Content $AiMessageFile "===== COMMIT MESSAGE PROMPT ====="
Add-Content $AiMessageFile $commitPromptContent
Add-Content $AiMessageFile ""

Add-Content $AiMessageFile "===== FILES SUMMARY ====="
Add-Content $AiMessageFile $filesSummary
Add-Content $AiMessageFile ""

Add-Content $AiMessageFile "===== STAGED DIFF ====="
Add-Content $AiMessageFile $tokenAwareResult.DiffContent
Add-Content $AiMessageFile ""

Add-Content $AiMessageFile "===== STAGED FILE CONTENTS ====="
Add-Content $AiMessageFile "(Binary and large files show metadata only)"
if ($tokenAwareResult.Omitted.Count -gt 0) {
    Add-Content $AiMessageFile "(Some files omitted to stay within token limit - see placeholders below)"
}
Add-Content $AiMessageFile ""

foreach ($fileEntry in $tokenAwareResult.FileContents) {
    Add-Content $AiMessageFile $fileEntry.content
    Add-Content $AiMessageFile ""
}

# Show token estimate
$estimatedTokens = $tokenAwareResult.TotalTokens
$maxTokens = Get-TokenBudgetFromEnv
Write-Host "Estimated tokens: ~$estimatedTokens / $maxTokens" -ForegroundColor Gray

# Call the appropriate post-export handler.
Write-Host "AI Mode: -> $effectiveAiMode"
if ($effectiveAiMode -eq "api") {
    & "$ScriptDir\handle_export_api.ps1"
} else {
    if ($effectiveAiMode -eq "manual") {
        & "$ScriptDir\handle_export_manual.ps1"
    } else
    {
        & "$ScriptDir\handle_export_manual.ps1"
    }
}