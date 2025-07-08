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

# --- Prerequisite checks ---
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 'jq' is required but not installed. Please install it and try again." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $AiMessageFile)) {
    Write-Host "❌ Cannot find AI message file: $AiMessageFile" -ForegroundColor Red
    exit 1
}

# --- Build API URL ---
if ($env:API_PROVIDER -eq "openai") {
    $ApiUrl = "$env:API_BASE/chat/completions"
    $AuthHeader = "Authorization: Bearer $env:API_KEY"
} elseif ($env:API_PROVIDER -eq "azure") {
    $ApiUrl = "$env:API_BASE/openai/deployments/$env:DEPLOYMENT/chat/completions?api-version=$env:API_VERSION"
    $AuthHeader = "api-key: $env:API_KEY"
} else {
    Write-Host "❌ Invalid API_PROVIDER in .env: $env:API_PROVIDER" -ForegroundColor Red
    exit 1
}

# --- Compose and send request ---
Write-Host "🚀 Sending prompt to $env:API_PROVIDER..." -ForegroundColor Cyan

$messageContent = Get-Content $AiMessageFile -Raw
$requestBody = @{
    model = $env:DEPLOYMENT
    messages = @(
        @{
            role = "system"
            content = "You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git merge commit messages."
        }
        @{
            role = "user"
            content = $messageContent
        }
    )
    temperature = [double]$env:TEMPERATURE
    max_tokens = [int]$env:MAX_TOKENS
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Headers @{
    "Content-Type" = "application/json"
    "Authorization" = $AuthHeader
} -Body $requestBody

# --- Extract and validate response ---
$rawSuggestedMessage = $response.choices[0].message.content.Trim()

if ($rawSuggestedMessage -notmatch '^\[MERGE \|.+->.+\]') {
    Write-Host "❌ AI response doesn't match expected format." -ForegroundColor Red
    Write-Host "🔍 Received: $rawSuggestedMessage" -ForegroundColor Yellow
    exit 1
}

# --- Handle merge command ---
if ($rawSuggestedMessage) {
    Write-Host ""
    Write-Host "✅ AI suggested merge message:" -ForegroundColor Green
    Write-Host $rawSuggestedMessage -ForegroundColor White

    # Let user edit or accept
    $finalMessage = Read-Host "📝 Press Enter to accept or edit the message"
    if (-not $finalMessage) {
        $finalMessage = $rawSuggestedMessage
    }

    if ($finalMessage) {
        Write-Host ""
        Write-Host "🚀 Final merge command:" -ForegroundColor Cyan
        Write-Host "git merge --no-ff `"$TargetBranch`" -m `"$finalMessage`"" -ForegroundColor White
        
        $confirm = Read-Host "👉 Do you want to run this commit command now? [y/N]"
        if ($confirm -match "^[Yy]$") {
            git merge --no-ff $TargetBranch -m $finalMessage
            Write-Host "✅ Merge successfully executed." -ForegroundColor Green

            $pushConfirm = Read-Host "🚀 Do you want to push the changes now? [y/N]"
            if ($pushConfirm -match "^[Yy]$") {
                git push
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Changes pushed." -ForegroundColor Green
                } else {
                    Write-Host "❌ Push failed." -ForegroundColor Red
                }
            } else {
                Write-Host "ℹ️ Skipped pushing. You can push manually anytime with 'git push'." -ForegroundColor Gray
            }
        } else {
            Write-Host "ℹ️  not executed. You can run it manually:" -ForegroundColor Yellow
            Write-Host "git merge --no-ff `"$TargetBranch`" -m `"$finalMessage`"" -ForegroundColor White
        }
    }
} else {
    Write-Host "⚠️ Could not extract commit command from AI response." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🧠 Full AI response:" -ForegroundColor Cyan
    $response | ConvertTo-Json -Depth 10
} 