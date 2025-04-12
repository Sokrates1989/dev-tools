param(
    [string]$Command
)

Write-Host ""


# --- Git update check ---
& "$PSScriptRoot\global_functions\check_for_updates.ps1"

# --- Argument-based quick start ---
switch ($Command) {
    "--update" { & "$PSScriptRoot\global_functions\perform_auto_update.ps1"; return }
    "-u"       { & "$PSScriptRoot\global_functions\perform_auto_update.ps1"; return }

    "--commit" { & "$PSScriptRoot\main_features\commit\git_export_staged.ps1"; return }
    "-c"       { & "$PSScriptRoot\main_features\commit\git_export_staged.ps1"; return }

    "--log"    { & "$PSScriptRoot\main_features\git\git_log_explorer.ps1"; return }
    "-l"       { & "$PSScriptRoot\main_features\git\git_log_explorer.ps1"; return }

    "--readme" { & "$PSScriptRoot\main_features\readme\show_readme_instructions.ps1"; return }
    "-r"       { & "$PSScriptRoot\main_features\readme\show_readme_instructions.ps1"; return }

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

$UpdateAvailable = & "$PSScriptRoot\check_for_updates_flag.ps1"
if ($UpdateAvailable -eq "1") {
    Write-Host "u) 🔄 Update Dev Tools now            [--update | -u]"
}
Write-Host "q) Exit"
Write-Host ""

# --- Git update check ---
& "$PSScriptRoot\check_for_updates.ps1"

$choice = Read-Host "Enter your choice [1-3 or q]"

switch ($choice) {
    "u" {
        if ($env:DEVTOOLS_UPDATE_AVAILABLE -eq "1") {
            & "$PSScriptRoot\global_functions\perform_auto_update.ps1"
        } else {
            Write-Host "✅ Already up to date with the latest version of Dev Tools."
        }
    }

    "1" {
        & "$PSScriptRoot\main_features\commit\git_export_staged.ps1"
    }
    "2" {
        & "$PSScriptRoot\main_features\git\git_log_explorer.ps1"
    }
    "3" {
        & "$PSScriptRoot\main_features\readme\show_readme_instructions.ps1"
    }
    "q" | "Q" {
        Write-Host "👋 Bye!"
        exit
    }
    default {
        Write-Host "❌ Invalid choice."
    }
}
