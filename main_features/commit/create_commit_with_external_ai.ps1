$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$PromptFile = Join-Path $ScriptDir "commit_message_prompt.txt"

if (-not (Test-Path $PromptFile)) {
    Write-Host "Commit style guide not found: $PromptFile"
    exit 1
}

Write-Host ""
Write-Host "Commit Style Guide for External AI"
Write-Host "=================================="
Write-Host "Create styled commit message with external AI!"
Write-Host "=================================="
Write-Host ""
Write-Host "1) Open your AI (ChatGPT, Claude, etc.)"
Write-Host ""
Write-Host "2) (optional) Tell the AI what Jira Task ID or code version should be added to the commit message, if desired." -ForegroundColor Yellow
Write-Host "   (use these exact words. JIRA_ID_PLACEHOLDER , VERSION_PLACEHOLDER)" -ForegroundColor Yellow
Write-Host ""
Write-Host "3) I will now attempt to copy the instructions to your clipboard."
Write-Host ""
do {
    $continueInput = Read-Host "Press Enter to begin"
}
while ($continueInput -ne "")
Write-Host ""
Write-Host ""

# Read the prompt content once for multiple uses
$promptContent = ""
try {
    $promptContent = Get-Content -Path $PromptFile -Raw -ErrorAction Stop
}
catch {
    Write-Host "Warning: Could not read the prompt file: $_" -ForegroundColor Yellow
}

# Try clipboard copy with better error handling
$clipboardSuccess = $false
Write-Host "Attempting to copy instructions to clipboard..."

# Get key content markers for verification
$originalLength = $promptContent.Length
$keyPhrases = @(
    "STYLE INSTRUCTION - HIGH PRIORITY",
    "PLACEHOLDER HANDLING - CRITICAL",
    "OUTPUT FORMAT",
    "git commit -m",
    "PLACEHOLDER DECISION RULES",
    "EXAMPLES",
    "New Feature"
)

# Try clip.exe first (most reliable on Windows)
try {
    if (Get-Command "clip.exe" -ErrorAction SilentlyContinue) {
        # Ensure content is properly encoded for Windows clipboard
        $utf8Content = [System.Text.Encoding]::UTF8.GetBytes($promptContent)
        $content = [System.Text.Encoding]::UTF8.GetString($utf8Content)
        
        # Copy to clipboard
        $content | clip.exe
        
        # Wait for clipboard to process
        Start-Sleep -Milliseconds 1000
        
        # Verify the copy
        try {
            if (Get-Command "Get-Clipboard" -ErrorAction SilentlyContinue) {
                $clipboardTest = Get-Clipboard -ErrorAction Stop
                $clipboardLength = $clipboardTest.Length
                
                # Basic length check
                if ($clipboardLength -gt 100 -and $clipboardLength -gt ($originalLength * 0.7)) {
                    # Check for key phrases
                    $foundPhrases = 0
                    foreach ($phrase in $keyPhrases) {
                        if ($clipboardTest.Contains($phrase)) {
                            $foundPhrases++
                        }
                    }
                    
                    # More lenient check - if we find most key phrases, consider it successful
                    if ($foundPhrases -ge ($keyPhrases.Count * 0.5)) {
                        Write-Host "SUCCESS! Instructions copied to clipboard." -ForegroundColor Green
                        $clipboardSuccess = $true
                    }
                    else {
                        Write-Host "Clipboard copy may have succeeded but verification unclear." -ForegroundColor Yellow
                        $clipboardSuccess = $true
                    }
                }
                else {
                    Write-Host "Clipboard content seems incomplete." -ForegroundColor Yellow
                }
            }
            else {
                # No Get-Clipboard available, assume success
                Write-Host "SUCCESS! Instructions copied to clipboard." -ForegroundColor Green
                $clipboardSuccess = $true
            }
        }
        catch {
            Write-Host "Clipboard verification failed, assuming success." -ForegroundColor Yellow
            $clipboardSuccess = $true
        }
    }
}
catch {
    Write-Host "Failed to copy with clip.exe." -ForegroundColor Red
}

# If clip.exe failed, try Set-Clipboard
if (-not $clipboardSuccess) {
    try {
        if (Get-Command "Set-Clipboard" -ErrorAction SilentlyContinue) {
            Set-Clipboard -Value $promptContent -ErrorAction Stop
            Start-Sleep -Milliseconds 1000
            
            Write-Host "SUCCESS! Instructions copied to clipboard." -ForegroundColor Green
            $clipboardSuccess = $true
        }
    }
    catch {
        Write-Host "Failed to copy with Set-Clipboard." -ForegroundColor Red
    }
}

# If clipboard succeeded, we're done
if ($clipboardSuccess) {
    Write-Host ""
    Write-Host "Paste into your external AI and ask for a commit message!" -ForegroundColor Green
    exit 0
}

# If clipboard failed, offer file access methods
Write-Host ""
Write-Host "Clipboard failed. Opening file access methods..." -ForegroundColor Yellow
Write-Host ""

# Method 1: Reveal file in Explorer
Write-Host "1) Revealing file in Explorer..."
try {
    Start-Process "explorer.exe" -ArgumentList "/select,`"$PromptFile`"" -ErrorAction Stop
    Write-Host "   File revealed in Explorer." -ForegroundColor Green
}
catch {
    Write-Host "   Failed to reveal in Explorer: $_" -ForegroundColor Red
}

# Method 2: Auto-open with default editor
Write-Host "2) Opening with default editor..."
try {
    Start-Process -FilePath $PromptFile -ErrorAction Stop
    Write-Host "   File opened with default editor." -ForegroundColor Green
}
catch {
    Write-Host "   Failed to open with editor: $_" -ForegroundColor Red
}

# Method 3: Display in terminal
Write-Host "3) Displaying in terminal..."
if ($promptContent) {
    Write-Host "   Content displayed in terminal below:" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== COMMIT STYLE GUIDE ==="
    Write-Host $promptContent
    Write-Host "=== END OF GUIDE ==="
}
else {
    Write-Host "   Could not read the prompt file content." -ForegroundColor Red
    Write-Host "   File path: $PromptFile" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Copy the content manually and paste into your external AI." -ForegroundColor Yellow

Write-Host ""
Write-Host "Done! Use the commit style guide with your external AI."
