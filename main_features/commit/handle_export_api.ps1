# -----------------------------------------------------------------------------
# Script: handle_export_api.ps1
# Description: Sends exported commit data to AI API using settings from .env
# Platform: Windows PowerShell 5.1 compatible
# -----------------------------------------------------------------------------

# Paths.
$RootDir = Resolve-Path "$PSScriptRoot\..\.." | Select-Object -ExpandProperty Path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ParentDir = Join-Path $ScriptDir "git_export_staged"
$AllInOneFile = Join-Path $ParentDir "all_in_one\ai_message.txt"

# Load settings.
. "$RootDir\global_functions\load_dotenv.ps1"
Load-DotEnv
$apiUrl = $env:API_BASE
# Remove any trailing slash from the base URL.
if ($apiUrl.EndsWith("/")) {
    $apiUrl = $apiUrl.Substring(0, $apiUrl.Length - 1)
}
$apiProvider = $env:API_PROVIDER
$apiKey = $env:API_KEY
$deployment = $env:DEPLOYMENT
$version = $env:API_VERSION
[double]$temperature = [double]$env:TEMPERATURE
[int]$maxToken = [int]$env:MAX_TOKENS

# Validate.
if (-not (Test-Path $AllInOneFile)) {
    Write-Host "Missing AI message file: $AllInOneFile"
    return
}

if (-not $apiKey) {
    Write-Host "API_KEY is not set in .env file. Aborting."
    return
}

# Compose the prompt.
$content = [string](Get-Content $AllInOneFile -Raw -Encoding UTF8)
$messages = @(
    @{
        role    = "system"
        content = "You are a helpful assistant that writes clean, concise and context-aware Git merge commit messages."
    },
    @{
        role    = "user"
        content = $content
    }
)
$payloadObject = @{
    messages    = $messages
    temperature = $temperature
    max_tokens  = $maxToken
}

# If using OpenAI.com API, include "model".
if ($apiProvider -eq "openai") {
    $payloadObject.model = $deployment  # Reuse DEPLOYMENT for the model name (e.g., "gpt-4o")
}

# Convert to JSON – IMPORTANT: preserve formatting
$payload = $payloadObject | ConvertTo-Json -Depth 5 -Compress

# Determine if OpenAI.com or Azure OpenAI is used.
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
if ($apiProvider -eq "openai") {
    $fullUrl = "$apiUrl/chat/completions"
    $headers.Add("Authorization", "Bearer $apiKey")
} else {
    $fullUrl = "$apiUrl/openai/deployments/$deployment/chat/completions?api-version=$version"
    $headers.Add("api-key", $apiKey)
}

$headers.Add("Content-Type", "application/json")


# Send request.
$response = Invoke-RestMethod -Uri $fullUrl -Method Post -Headers $headers -Body $payload

# Output response.
if ($response.choices) {
    $message = $response.choices[0].message.content
    Write-Host ""
    Write-Host "Suggested commit message:"
    Write-Host "--------------------------"
    Write-Host $message
} else {
    Write-Host "API response did not return expected output."
}
