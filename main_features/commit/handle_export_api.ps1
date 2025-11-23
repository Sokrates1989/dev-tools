# -----------------------------------------------------------------------------
# Script: handle_export_api.ps1
# Description: Sends exported commit data to AI API using settings from .env
# Platform: Windows PowerShell 5.1 compatible
# -----------------------------------------------------------------------------

# --- Resolve paths ---
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$AllInOneFile = Join-Path $scriptDir "git_export_staged\all_in_one\ai_message.txt"

# Load environment variables
$envFile = Join-Path $rootDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+?)\s*=\s*(.+?)\s*$') {
            $name = $matches[1]
            $value = $matches[2]
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}
else {
    Write-Host "ERROR: .env file not found at $envFile" -ForegroundColor Red
    exit 1
}

# Load commit variables from git_export_staged
$varsFile = Join-Path $scriptDir "git_export_staged\.commit_vars"
$jiraId = $null
$imageVersion = $null
$versionFilesStaged = $null

if (Test-Path $varsFile) {
    Get-Content $varsFile | ForEach-Object {
        if ($_ -match '^\s*JIRA_ID=(.*)$') {
            $jiraId = $matches[1].Trim()
        }
        elseif ($_ -match '^\s*IMAGE_VERSION=(.*)$') {
            $imageVersion = $matches[1].Trim()
        }
        elseif ($_ -match '^\s*VERSION_FILES_STAGED=(.*)$') {
            $versionFilesStaged = $matches[1].Trim()
        }
    }
}

# Load settings.
. "$rootDir\global_functions\load_dotenv.ps1"
Load-DotEnv

# Load utility functions
. "$scriptDir\utils\api_utils.ps1"
. "$scriptDir\utils\ui_utils.ps1"

# Extract API settings
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

# Validate prerequisites
if (-not (Test-Path $AllInOneFile)) {
    Write-Host "Missing AI message file: $AllInOneFile"
    return
}

if (-not (Test-ApiConfiguration -ApiKey $apiKey -ApiProvider $apiProvider -ApiUrl $apiUrl)) {
    return
}

# Compose the initial prompt.
$content = Get-Content $AllInOneFile -Raw -Encoding UTF8
# Properly escape special characters for JSON
$escapedContent = $content -replace '\\', '\\\\' `
                             -replace '"', '\"' `
                             -replace "`r", '' `
                             -replace "`n", '\n'

# Build initial messages
$messages = New-ConversationMessages -UserContent $escapedContent

# Send initial request
Write-Host "Sending prompt to $apiProvider..."
$response = Send-ApiRequest -Messages $messages -ApiUrl $apiUrl -ApiProvider $apiProvider -ApiKey $apiKey -Deployment $deployment -Version $version -Temperature $temperature -MaxTokens $maxToken
$suggestedMessage = Get-CommitMessage -Response $response

# Function to replace placeholders
function Update-CommitPlaceholders {
    param(
        [string]$Message,
        [string]$JiraId,
        [string]$Version
    )
    
    # Replace VERSION_PLACEHOLDER first
    if ($Version) {
        $Message = $Message -replace 'VERSION_PLACEHOLDER', $Version
    } else {
        # Remove VERSION_PLACEHOLDER and the pipe separator
        $Message = $Message -replace '\s*VERSION_PLACEHOLDER\s*\|\s*', ''
        $Message = $Message -replace '\s*\|\s*VERSION_PLACEHOLDER\s*', ''
    }
    
    # Replace JIRA_ID_PLACEHOLDER
    if ($JiraId) {
        $Message = $Message -replace 'JIRA_ID_PLACEHOLDER', $JiraId
    } else {
        # Remove JIRA_ID_PLACEHOLDER and the pipe separator
        $Message = $Message -replace '\s*JIRA_ID_PLACEHOLDER\s*\|\s*', ''
        $Message = $Message -replace '\s*\|\s*JIRA_ID_PLACEHOLDER\s*', ''
    }
    
    return $Message
}

if ($suggestedMessage) {
    # Replace placeholders in initial message
    $suggestedMessage = Update-CommitPlaceholders -Message $suggestedMessage -JiraId $jiraId -Version $imageVersion
    # Main interaction loop
    do {
        Show-CommitOptions -CommitMessage $suggestedMessage
        $choice = Get-UserChoice

        switch ($choice) {
            "" {
                # Accept as-is
                $finalCommitMessage = $suggestedMessage
                $continueLoop = $false
            }
            { $_ -match "^[Ee]$" } {
                # Edit manually
                $editedMessage = Edit-CommitMessage -CommitMessage $suggestedMessage
                
                if (-not (Test-CommitMessageFormat -CommitMessage $editedMessage)) {
                    return
                }
                
                $finalCommitMessage = $editedMessage
                $continueLoop = $false
            }
            { $_ -match "^[Rr]$" } {
                # Regenerate message
                Write-Host ""
                Write-Host "Regenerating commit message..."
                
                # Add context that previous output was not accepted
                $regenerateMessages = New-ConversationMessages -UserContent $escapedContent -PreviousMessage $suggestedMessage -AdditionalPrompt "The previous commit message was not accepted. Please generate a different commit message with a different approach or style."
                
                $response = Send-ApiRequest -Messages $regenerateMessages -ApiUrl $apiUrl -ApiProvider $apiProvider -ApiKey $apiKey -Deployment $deployment -Version $version -Temperature $temperature -MaxTokens $maxToken
                $newSuggestedMessage = Get-CommitMessage -Response $response
                
                if (-not $newSuggestedMessage) {
                    Write-Host "Failed to regenerate commit message. Please try again."
                    return
                }
                
                # Replace placeholders in regenerated message
                $suggestedMessage = Update-CommitPlaceholders -Message $newSuggestedMessage -JiraId $jiraId -Version $imageVersion
                $continueLoop = $true
            }
            { $_ -match "^[Cc]$" } {
                # Chat with AI
                $chatPrompt = Get-ChatInstructions
                
                if ([string]::IsNullOrWhiteSpace($chatPrompt)) {
                    Write-Host "No chat message provided. Keeping current message."
                    $continueLoop = $true
                } else {
                    Write-Host ""
                    Write-Host "Chatting with AI..."
                    
                    # Add chat context
                    $chatMessages = New-ConversationMessages -UserContent $escapedContent -PreviousMessage $suggestedMessage -AdditionalPrompt $chatPrompt
                    
                    $response = Send-ApiRequest -Messages $chatMessages -ApiUrl $apiUrl -ApiProvider $apiProvider -ApiKey $apiKey -Deployment $deployment -Version $version -Temperature $temperature -MaxTokens $maxToken
                    $newSuggestedMessage = Get-CommitMessage -Response $response
                    
                    if (-not $newSuggestedMessage) {
                        Write-Host "Failed to chat with AI. Please try again."
                        return
                    }
                    
                    # Replace placeholders in chat response
                    $suggestedMessage = Update-CommitPlaceholders -Message $newSuggestedMessage -JiraId $jiraId -Version $imageVersion
                    $continueLoop = $true
                }
            }
            default {
                Write-Host "Invalid option. Please choose [Enter], [E], [R], or [C]."
                $continueLoop = $true
            }
        }
    } while ($continueLoop)

    # Show version files that were staged if any
    if ($versionFilesStaged) {
        Write-Host ""
        Write-Host "Version files included in this commit: $versionFilesStaged" -ForegroundColor Cyan
    }
    
    # Execute the commit
    Invoke-CommitExecution -CommitCommand $finalCommitMessage
} else {
    Write-Host "API response did not return expected output."
}
