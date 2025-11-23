# -----------------------------------------------------------------------------
# Script: handle_export_merge_api.ps1
#
# Description:
# PowerShell version of the API handler for merge commit message generation.
# Sends merge context to AI API to generate a commit message.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir\..\.." | Select-Object -ExpandProperty Path
$AiMessageFile = $args[0]
$TargetBranch = $args[1]

# Load environment variables
. "$RootDir\global_functions\load_dotenv.ps1"
Load-DotEnv

# Load shared API utilities from commit feature
. "$RootDir\main_features\commit\utils\api_utils.ps1"

# --- Prerequisite checks ---
if (-not (Test-Path $AiMessageFile)) {
    Write-Host "[ERROR] Cannot find AI message file: $AiMessageFile" -ForegroundColor Red
    exit 1
}

# --- Extract API settings ---
$apiUrl = $env:API_BASE
# Remove any trailing slash from the base URL
if ($apiUrl.EndsWith("/")) {
    $apiUrl = $apiUrl.Substring(0, $apiUrl.Length - 1)
}
$apiProvider = $env:API_PROVIDER
$apiKey = $env:API_KEY
$deployment = $env:DEPLOYMENT
$version = $env:API_VERSION
[double]$temperature = [double]$env:TEMPERATURE
[int]$maxTokens = [int]$env:MAX_TOKENS

# --- Compose request body ---
Write-Host "[INFO] Sending prompt to $apiProvider..." -ForegroundColor Cyan

$content = Get-Content $AiMessageFile -Raw -Encoding UTF8

# Properly escape special characters for JSON (same as commit flow)
$escapedContent = $content -replace '\\', '\\\\' `
                             -replace '"', '\"' `
                             -replace "`r", '' `
                             -replace "`n", '\n'

$systemPrompt = "You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git merge commit messages."

# Build messages array using shared helper
$messages = New-ConversationMessages -UserContent $escapedContent -SystemPrompt $systemPrompt

# Send request via shared API helper
try {
    # Write-Host "[DEBUG] Calling API at: $apiUrl" -ForegroundColor Gray
    $response = Send-ApiRequest -Messages $messages -ApiUrl $apiUrl -ApiProvider $apiProvider -ApiKey $apiKey -Deployment $deployment -Version $version -Temperature $temperature -MaxTokens $maxTokens
    # Write-Host "[DEBUG] Received response" -ForegroundColor Gray
} catch {
    Write-Host "[ERROR] API request failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    if ($_.Exception.Response) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                if ($body) {
                    Write-Host "[INFO] Response body:" -ForegroundColor Yellow
                    Write-Host $body
                }
            }
        } catch {
            # ignore secondary errors while reading error body
        }
    }
    exit 1
}

# --- Extract and validate response ---
if (-not $response) {
    Write-Host "[ERROR] No response received from API" -ForegroundColor Red
    exit 1
}

$rawSuggestedMessage = Get-CommitMessage -Response $response

if ($rawSuggestedMessage -notmatch '^\[MERGE \|.+->.+\]') {
    Write-Host "[ERROR] AI response doesn't match expected format." -ForegroundColor Red
    Write-Host "[INFO] Received: $rawSuggestedMessage" -ForegroundColor Yellow
    exit 1
}

# --- Handle merge command ---
if ($rawSuggestedMessage) {
    Write-Host ""
    Write-Host "[OK] AI suggested merge message:" -ForegroundColor Green
    Write-Host $rawSuggestedMessage -ForegroundColor White

    # Let user edit or accept
    $finalMessage = Read-Host "Press Enter to accept or edit the message"
    if (-not $finalMessage) {
        $finalMessage = $rawSuggestedMessage
    }

    if ($finalMessage) {
        Write-Host ""
        Write-Host "[INFO] Final merge command:" -ForegroundColor Cyan
        Write-Host "git merge --no-ff `"$TargetBranch`" -m `"$finalMessage`"" -ForegroundColor White
        
        $confirm = Read-Host "Do you want to run this commit command now? [y/N]"
        if ($confirm -match "^[Yy]$") {
            git merge --no-ff $TargetBranch -m $finalMessage
            Write-Host "[OK] Merge successfully executed." -ForegroundColor Green

            $pushConfirm = Read-Host "Do you want to push the changes now? [y/N]"
            if ($pushConfirm -match "^[Yy]$") {
                git push
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Changes pushed." -ForegroundColor Green
                } else {
                    Write-Host "[ERROR] Push failed." -ForegroundColor Red
                }
            } else {
                Write-Host "[INFO] Skipped pushing. You can push manually anytime with 'git push'." -ForegroundColor Gray
            }
        } else {
            Write-Host "[INFO] Merge not executed. You can run it manually:" -ForegroundColor Yellow
            Write-Host "git merge --no-ff `"$TargetBranch`" -m `"$finalMessage`"" -ForegroundColor White
        }
    }
} else {
    Write-Host "[WARNING] Could not extract commit command from AI response." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[INFO] Full AI response:" -ForegroundColor Cyan
    $response | ConvertTo-Json -Depth 10
} 