# -----------------------------------------------------------------------------
# Script: show_readme_instructions.ps1
#
# Description:
#   Guides the user through the process of generating a professional README
#   with the help of an AI assistant.
# -----------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Join-Path $ScriptDir ".." | Resolve-Path | Select-Object -ExpandProperty Path
$InstructionsDir = Join-Path $RootDir "readme\instructions"

# --- Git update check ---
$RootDir = Join-Path $PSScriptRoot ".." | Resolve-Path | Select-Object -ExpandProperty Path
& "$RootDir\check_for_updates.ps1"

Write-Host ""
Write-Host "📘 README Creation Instructions"
Write-Host "==============================="
Write-Host ""
Write-Host "🧠 Step 1: Open your preferred AI assistant:"
Write-Host "   → ChatGPT, DeepSeek, Gemini, Claude, etc."
Write-Host ""
Write-Host "💬 Step 2: Tell the AI what this README should be about."
Write-Host "   Example:"
Write-Host "     'Create a professional README for a backend service that handles user registration and login.'"
Write-Host ""
Write-Host "📎 Step 3: Copy the contents of the folder that will be opened next:"
Write-Host "   → This includes two useful files:"
Write-Host "     • ai_instructions.txt – contains formatting guidance"
Write-Host "     • template.md – a customizable README scaffold"
Write-Host ""
Write-Host "🗂️ Step 4: Paste both files into your AI chat."
Write-Host ""
Write-Host "📄 Step 5: Optionally, upload or paste any relevant files the AI should consider:"
Write-Host "   • source code files"
Write-Host "   • configuration files (e.g. .env, Dockerfile)"
Write-Host "   • architecture diagrams"
Write-Host ""
Write-Host "✏️ Step 6: After receiving the generated README:"
Write-Host "   → Replace all occurrences of ';;;' with '```' (triple backticks)"
Write-Host "     This ensures correct markdown formatting."
Write-Host ""
Write-Host "💡 The more context and examples you provide, the better the resulting README."
Write-Host ""

# --- Git update check ---
$RootDir = Join-Path $PSScriptRoot ".." | Resolve-Path | Select-Object -ExpandProperty Path
& "$RootDir\check_for_updates.ps1"

# Prompt before opening
Read-Host "📂 Press Enter to open the README instructions folder in Explorer..."
Start-Process "explorer.exe" $InstructionsDir

Write-Host ""
Write-Host "✅ Once the folder is opened, copy and paste the contents into your AI chat to begin."
