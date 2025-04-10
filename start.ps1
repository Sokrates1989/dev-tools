param(
    [string]$Command
)

Write-Host ""

# --- Argument-based quick start ---
switch ($Command) {
    "--commit" { & "$PSScriptRoot\commit\git_export_staged.ps1"; return }
    "-c"       { & "$PSScriptRoot\commit\git_export_staged.ps1"; return }
    "--log"    { & "$PSScriptRoot\git\git_log_explorer.ps1"; return }
    "-l"       { & "$PSScriptRoot\git\git_log_explorer.ps1"; return }
    default {
        if ($Command) {
            Write-Host "❌ Unknown argument: $Command"
            Write-Host ""
            Write-Host "Usage:"
            Write-Host "  --commit | -c   → Run git_export_staged"
            Write-Host "  --log    | -l   → Run git_log_explorer"
            return
        }
    }
}

# --- Interactive Menu ---
Write-Host "🛠️  Dev Tools Launcher"
Write-Host "======================"
Write-Host "Choose a tool to run (you can also use these flags directly):"
Write-Host ""
Write-Host "1) Export staged Git changes         [--commit | -c]"
Write-Host "2) Git log explorer                  [--log    | -l]"
Write-Host "q) Exit"
Write-Host ""

$choice = Read-Host "Enter your choice [1-2 or q]"

switch ($choice) {
    "1" {
        & "$PSScriptRoot\commit\git_export_staged.ps1"
    }
    "2" {
        & "$PSScriptRoot\git\git_log_explorer.ps1"
    }
    "q" { Write-Host "👋 Bye!"; exit }
    "Q" { Write-Host "👋 Bye!"; exit }
    default {
        Write-Host "❌ Invalid choice."
    }
}

Write-Host ""
Write-Host "💡 Tip: Always show hidden files (like .gitignore) to avoid confusion."
Write-Host "👉 Windows: In Explorer, go to 'View' and enable 'Hidden items'."
