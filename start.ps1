param(
    [string]$Command
)

Write-Host ""


# --- Git update check ---
& "$PSScriptRoot\check_for_updates.ps1"

# --- Argument-based quick start ---
switch ($Command) {
    "--commit" { & "$PSScriptRoot\commit\git_export_staged.ps1"; return }
    "-c"       { & "$PSScriptRoot\commit\git_export_staged.ps1"; return }

    "--log"    { & "$PSScriptRoot\git\git_log_explorer.ps1"; return }
    "-l"       { & "$PSScriptRoot\git\git_log_explorer.ps1"; return }

    "--readme" { & "$PSScriptRoot\readme\show_readme_instructions.ps1"; return }
    "-r"       { & "$PSScriptRoot\readme\show_readme_instructions.ps1"; return }

    default {
        if ($Command) {
            Write-Host "❌ Unknown argument: $Command"
            Write-Host ""
            Write-Host "Usage:"
            Write-Host "  --commit | -c   → Run git_export_staged"
            Write-Host "  --log    | -l   → Run git_log_explorer"
            Write-Host "  --readme | -r   → Show README creation instructions"
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
Write-Host "3) Show README creation instructions [--readme | -r]"
Write-Host "q) Exit"
Write-Host ""

# --- Git update check ---
& "$PSScriptRoot\check_for_updates.ps1"

$choice = Read-Host "Enter your choice [1-3 or q]"

switch ($choice) {
    "1" {
        & "$PSScriptRoot\commit\git_export_staged.ps1"
    }
    "2" {
        & "$PSScriptRoot\git\git_log_explorer.ps1"
    }
    "3" {
        & "$PSScriptRoot\readme\show_readme_instructions.ps1"
    }
    "q" | "Q" {
        Write-Host "👋 Bye!"
        exit
    }
    default {
        Write-Host "❌ Invalid choice."
    }
}
