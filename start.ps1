param(
    [string]$Command
)

Write-Host ""

# --- Argument-based quick start ---
switch ($Command) {
    "--commit" { & "$PSScriptRoot\commit\git_export_staged.ps1"; return }
    "-c"       { & "$PSScriptRoot\commit\git_export_staged.ps1"; return }
    default {
        if ($Command) {
            Write-Host "❌ Unknown argument: $Command"
            Write-Host "Use without arguments for menu, or use:"
            Write-Host "  --commit | -c   → Run git_export_staged"
            return
        }
    }
}

# --- Interactive Menu ---
Write-Host "🛠️  Dev Tools Launcher"
Write-Host "======================"
Write-Host "Choose a tool to run:"
Write-Host ""
Write-Host "1) Export staged Git changes (git_export_staged)"
Write-Host "2) Exit"
Write-Host ""

$choice = Read-Host "Enter your choice [1-2]"

switch ($choice) {
    "1" {
        & "$PSScriptRoot\commit\git_export_staged.ps1"
    }
    "2" {
        Write-Host "👋 Bye!"
        exit
    }
    default {
        Write-Host "❌ Invalid choice."
    }
}

Write-Host ""
Write-Host "💡 Tip: Always show hidden files (like .gitignore) to avoid confusion."
Write-Host "👉 Windows: In Explorer, go to 'View' and enable 'Hidden items'."
