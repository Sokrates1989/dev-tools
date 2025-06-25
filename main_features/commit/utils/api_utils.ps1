# -----------------------------------------------------------------------------
# Script: api_utils.ps1
# Description: Utility functions for API operations in commit scripts
# Platform: Windows PowerShell 5.1 compatible
# -----------------------------------------------------------------------------

# Function to send API request
function Send-ApiRequest {
    param(
        [array]$Messages,
        [string]$ApiUrl,
        [string]$ApiProvider,
        [string]$ApiKey,
        [string]$Deployment,
        [string]$Version,
        [double]$Temperature,
        [int]$MaxTokens
    )
    
    $payloadObject = @{
        messages    = $Messages
        temperature = $Temperature
        max_tokens  = $MaxTokens
    }

    # If using OpenAI.com API, include "model".
    if ($ApiProvider -eq "openai") {
        $payloadObject.model = $Deployment
    }

    # Convert to JSON
    $payload = $payloadObject | ConvertTo-Json -Depth 10 -Compress

    # Workaround for PowerShell 5.1 JSON body encoding issue
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
    $bytes = $utf8NoBomEncoding.GetBytes($payload)

    # Determine if OpenAI.com or Azure OpenAI is used.
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    if ($ApiProvider -eq "openai") {
        $fullUrl = "$ApiUrl/chat/completions"
        $headers.Add("Authorization", "Bearer $ApiKey")
    } else {
        $fullUrl = "$ApiUrl/openai/deployments/$Deployment/chat/completions?api-version=$Version"
        $headers.Add("api-key", $ApiKey)
    }

    $headers.Add("Content-Type", "application/json")

    # Send request.
    $response = Invoke-RestMethod -Uri $fullUrl -Method Post -Headers $headers -Body $bytes
    return $response
}

# Function to extract commit message from response
function Get-CommitMessage {
    param(
        $Response
    )
    
    if ($Response.choices) {
        $rawCommitLine = $Response.choices[0].message.content
        # Remove Markdown code block formatting (```bash ... ```)
        $suggestedMessage = $rawCommitLine -replace '```[a-z]*', '' -replace '```', ''
        return $suggestedMessage.Trim()
    }
    return $null
}

# Function to validate API configuration
function Test-ApiConfiguration {
    param(
        [string]$ApiKey,
        [string]$ApiProvider,
        [string]$ApiUrl
    )
    
    if (-not $ApiKey) {
        Write-Host "API_KEY is not set in .env file. Aborting."
        return $false
    }
    
    if ($ApiProvider -notin @("openai", "azure")) {
        Write-Host "Invalid API_PROVIDER in .env: $ApiProvider. Must be 'openai' or 'azure'."
        return $false
    }
    
    if (-not $ApiUrl) {
        Write-Host "API_BASE is not set in .env file. Aborting."
        return $false
    }
    
    return $true
}

# Function to build conversation messages for different scenarios
function New-ConversationMessages {
    param(
        [string]$UserContent,
        [string]$SystemPrompt = "You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git commit messages.",
        [string]$PreviousMessage = $null,
        [string]$AdditionalPrompt = $null
    )
    
    $messages = @(
        @{ role = "system"; content = $SystemPrompt },
        @{ role = "user"; content = $UserContent }
    )
    
    if ($PreviousMessage) {
        $messages += @{ role = "assistant"; content = $PreviousMessage }
    }
    
    if ($AdditionalPrompt) {
        $messages += @{ role = "user"; content = $AdditionalPrompt }
    }
    
    return $messages
} 