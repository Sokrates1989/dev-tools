# -----------------------------------------------------------------------------
# Script: show_readme_instructions.ps1
# Description: Guides the user through the process of generating a professional README with an AI assistant.
# Platform: Windows PowerShell 5.1 compatible
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$PSScriptRoot\..\.." | Select-Object -ExpandProperty Path
$InstructionsDir = Join-Path $ScriptDir "instructions"

# --- Git update check ---
& "$RootDir\global_functions\check_for_updates.ps1"

Write-Host ""
Write-Host "README Creation Instructions"
Write-Host "============================="
Write-Host ""
Write-Host "Step 1: Open your preferred AI assistant:"
Write-Host "   - ChatGPT, DeepSeek, Gemini, Claude, etc."
Write-Host ""
Write-Host "Step 2: Tell the AI what this README should be about."
Write-Host "   Example:"
Write-Host "     Create a professional README for a backend service that handles user registration and login."
Write-Host ""
Write-Host "Step 3: Copy the contents of the folder that will be opened next:"
Write-Host "   Includes:"
Write-Host "     - ai_instructions.txt: contains formatting guidance"
Write-Host "     - template.md: a customizable README scaffold"
Write-Host ""
Write-Host "Step 4: Paste both files into your AI chat."
Write-Host ""
Write-Host "Step 5: Optionally upload or paste any relevant files the AI should consider:"
Write-Host "   - Source code files"
Write-Host "   - Configuration files (e.g., .env, Dockerfile)"
Write-Host "   - Architecture diagrams"
Write-Host ""
Write-Host "Step 6: After receiving the generated README:"
Write-Host "   - Replace all occurrences of ';;;' with '```' (triple backticks)"
Write-Host "     This ensures correct markdown formatting."
Write-Host ""
Write-Host "The more context and examples you provide, the better the resulting README."
Write-Host ""

# --- Git update check again ---
& "$RootDir\global_functions\check_for_updates.ps1"

# Read instruction files content for clipboard/terminal options
$aiInstructionsFile = Join-Path $InstructionsDir "ai_instructions.txt"
$templateFile = Join-Path $InstructionsDir "template.md"
$combinedContent = ""

try {
    $aiInstructions = Get-Content -Path $aiInstructionsFile -Raw -ErrorAction Stop
    $template = Get-Content -Path $templateFile -Raw -ErrorAction Stop
    $combinedContent = "=== AI INSTRUCTIONS ===`n`n$aiInstructions`n`n=== README TEMPLATE ===`n`n$template"
}
catch {
    Write-Host "Warning: Could not read instruction files: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "I will now attempt all 4 methods to make the README instructions accessible:"
Write-Host ""

# Method 1: Open instructions folder in Explorer
Write-Host "1) Opening instructions folder in Explorer..."
$explorerSuccess = $false
try {
    Start-Process "explorer.exe" $InstructionsDir -ErrorAction Stop
    Write-Host "   Instructions folder opened in Explorer." -ForegroundColor Green
    $explorerSuccess = $true
}
catch {
    Write-Host "   Failed to open Explorer: $_" -ForegroundColor Red
    Write-Host "   Folder path: $InstructionsDir" -ForegroundColor Yellow
}

# Method 2: Open ai_instructions.txt with default editor
Write-Host "2) Opening ai_instructions.txt with default editor..."
$editorSuccess = $false
try {
    Start-Process -FilePath $aiInstructionsFile -ErrorAction Stop
    Write-Host "   AI instructions file opened with default editor." -ForegroundColor Green
    $editorSuccess = $true
}
catch {
    Write-Host "   Failed to open with editor: $_" -ForegroundColor Red
    Write-Host "   File path: $aiInstructionsFile" -ForegroundColor Yellow
}

# Method 3: Copy all instructions to clipboard with verification
Write-Host "3) Copying instructions to clipboard..."
$clipboardSuccess = $false
$clipboardMethod = ""
try {
    if (Get-Command "clip.exe" -ErrorAction SilentlyContinue) {
        $combinedContent | clip.exe
        $clipboardMethod = "Windows clip.exe"
        
        # Verify clipboard content
        Start-Sleep -Milliseconds 100
        try {
            if (Get-Command "Get-Clipboard" -ErrorAction SilentlyContinue) {
                $clipboardTest = Get-Clipboard -ErrorAction Stop
                if ($clipboardTest -and $clipboardTest.Trim() -eq $combinedContent.Trim()) {
                    Write-Host "   Instructions successfully copied to clipboard ($clipboardMethod) - VERIFIED!" -ForegroundColor Green
                    $clipboardSuccess = $true
                }
                else {
                    Write-Host "   Clipboard copy attempted but verification failed." -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "   Instructions copied to clipboard ($clipboardMethod) - verification not available." -ForegroundColor Green
                $clipboardSuccess = $true
            }
        }
        catch {
            Write-Host "   Instructions copied to clipboard ($clipboardMethod) - verification failed: $_" -ForegroundColor Yellow
        }
    }
    elseif (Get-Command "Set-Clipboard" -ErrorAction SilentlyContinue) {
        Set-Clipboard -Value $combinedContent -ErrorAction Stop
        $clipboardMethod = "PowerShell Set-Clipboard"
        
        # Verify clipboard content
        Start-Sleep -Milliseconds 100
        try {
            $clipboardTest = Get-Clipboard -ErrorAction Stop
            if ($clipboardTest -and $clipboardTest.Trim() -eq $combinedContent.Trim()) {
                Write-Host "   Instructions successfully copied to clipboard ($clipboardMethod) - VERIFIED!" -ForegroundColor Green
                $clipboardSuccess = $true
            }
            else {
                Write-Host "   Clipboard copy attempted but verification failed." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "   Instructions copied to clipboard ($clipboardMethod) - verification failed: $_" -ForegroundColor Yellow
        }
    }
    else {
        throw "No clipboard method available"
    }
}
catch {
    Write-Host "   Failed to copy to clipboard: $_" -ForegroundColor Red
    Write-Host "   You can manually copy from terminal display below." -ForegroundColor Yellow
}

# Method 4: Display all instructions in terminal
Write-Host "4) Displaying all instructions in terminal..."
$terminalSuccess = $false
if ($combinedContent) {
    Write-Host "   Instructions displayed in terminal below:" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== README INSTRUCTIONS ==="
    Write-Host $combinedContent
    Write-Host "=== END OF INSTRUCTIONS ==="
    $terminalSuccess = $true
}
else {
    Write-Host "   Could not read instruction files content." -ForegroundColor Red
    Write-Host "   Folder path: $InstructionsDir" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=== ATTEMPT SUMMARY ==="
Write-Host "Folder open:    $(if ($explorerSuccess) { 'SUCCESS' } else { 'FAILED' })"
Write-Host "Editor open:    $(if ($editorSuccess) { 'SUCCESS' } else { 'FAILED' })"
Write-Host "Clipboard copy: $(if ($clipboardSuccess) { 'SUCCESS - VERIFIED' } else { 'FAILED' })"
Write-Host "Terminal display: $(if ($terminalSuccess) { 'SUCCESS' } else { 'FAILED' })"

if ($clipboardSuccess) {
    Write-Host ""
    Write-Host "EXCELLENT! The README instructions are now in your clipboard." -ForegroundColor Green
    Write-Host "You can paste them directly into your external AI chat." -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Clipboard copy failed, but you can:" -ForegroundColor Yellow
    Write-Host "- Copy the content from the terminal display above" -ForegroundColor Yellow
    Write-Host "- Use the folder path to open manually: $InstructionsDir" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done! Use the README instructions with your external AI."
