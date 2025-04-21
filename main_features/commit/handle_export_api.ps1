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
$content = Get-Content $AllInOneFile -Raw -Encoding UTF8
# Properly escape special characters for JSON
$escapedContent = $content -replace '\\', '\\\\' `
                             -replace '"', '\"' `
                             -replace "`r", '' `
                             -replace "`n", '\n'

$messages = @(
    @{ role = "system"; content = "You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git commit messages." },
    @{ role = "user"; content = $escapedContent }
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

# Convert to JSON
$payload = $payloadObject | ConvertTo-Json -Depth 10 -Compress


# Workaround for PowerShell 5.1 JSON body encoding issue
$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
$bytes = $utf8NoBomEncoding.GetBytes($payload)

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
$response = Invoke-RestMethod -Uri $fullUrl -Method Post -Headers $headers -Body $bytes

# Output response.
if ($response.choices) {
    $rawCommitLine = $response.choices[0].message.content

    # Remove Markdown code block formatting (```bash ... ```)
    $suggestedMessage = $rawCommitLine -replace '```[a-z]*', '' -replace '```', ''
    $suggestedMessage = $suggestedMessage.Trim()

    # Show suggested commit mesage.
    Write-Host ""
    Write-Host "Suggested commit message:"
    Write-Host "--------------------------"
    Write-Host $suggestedMessage

    # Ask the user whether to edit or accept the suggested message
    Write-Host ""
    $editChoice = Read-Host "Press [E] to edit the commit message, or press Enter to accept as is"

    if ($editChoice -match "^[Ee]$") {
        # Sauberer Temp-Dateipfad mit .txt-Endung
        $tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath ("commit_msg_{0}.txt" -f ([System.Guid]::NewGuid().ToString()))

        # Inhalt sicher schreiben
        Set-Content -Path $tempFile -Value $suggestedMessage -Encoding UTF8 -Force

        # Editor starten
        Write-Host ""
        Write-Host "Opening Notepad so you can edit the commit message..."
        $notepadProcess = Start-Process -FilePath "notepad.exe" -ArgumentList $tempFile -PassThru
        $notepadProcess.WaitForExit()


        # Inhalt auslesen.
        $finalCommitMessage = Get-Content -Path $tempFile -Raw -Encoding UTF8
        Remove-Item $tempFile -Force

        # Validate final commit message.
        if ([string]::IsNullOrWhiteSpace($finalCommitMessage)) {
            Write-Host "Commit message is empty. Please rerun the script or commit manually."
            return
        }
        $finalCommitMessage = $finalCommitMessage.Trim()

        # Regex: Must match pattern exactly
        $pattern = '^git commit -m "([^"]+)"$'
        if ($finalCommitMessage -notmatch $pattern) {
            Write-Host "Invalid commit command!"
            Write-Host 'The command must follow this structure:'
            Write-Host 'git commit -m "Your message here"'
            return
        }


    } else {
        # Accept as-is
        $finalCommitMessage = $suggestedMessage
    }


    Write-Host ""
    Write-Host "Final commit message:"
    Write-Host "--------------------------"
    Write-Host "$finalCommitMessage"

    # Auto commit?
    $confirm = Read-Host "Do you want to run this commit command now? [y/N]"
    if ($confirm -match "^[Yy]$") {
        Invoke-Expression $finalCommitMessage
        Write-Host "Commit executed."
        Write-Host ""

        # Auto push?
        $pushConfirm = Read-Host "Do you want to push the commit to the remote now? [y/N]"
        if ($pushConfirm -match "^[Yy]$") {
            Write-Host "Pushing changes to remote..."
            git push
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Push successful."
            } else {
                Write-Host "Push failed. Please check your Git configuration or network."
            }
        } else {
            Write-Host "Push skipped. You can run 'git push' later manually."
        }
    } else {
        Write-Host "Commit not executed. You can run it manually:"
        Write-Host $finalCommitMessage
    }
} else {
    Write-Host "API response did not return expected output."
}
