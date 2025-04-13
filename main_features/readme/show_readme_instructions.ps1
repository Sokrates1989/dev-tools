# -----------------------------------------------------------------------------
# Script: show_readme_instructions.ps1
# Description: Guides the user through the process of generating a professional README with an AI assistant.
# Platform: Windows PowerShell 5.1 compatible
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$PSScriptRoot\..\.." | Select-Object -ExpandProperty Path
$InstructionsDir = Join-Path $ScriptDir "readme\instructions"

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

# Prompt to open the folder
Read-Host "Press Enter to open the README instructions folder in Explorer..."
Start-Process "explorer.exe" $InstructionsDir

Write-Host ""
Write-Host "Done! The folder is now open. Copy the contents into your AI chat to begin."
