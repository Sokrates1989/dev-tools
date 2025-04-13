param (
    [switch]$c,  # commit
    [switch]$commit,  # commit
    [switch]$l,  # log
    [switch]$log,  # log
    [switch]$r,  # readme
    [switch]$readme,  # readme
    [switch]$u,   # update
    [switch]$update  # update
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir" | Select-Object -ExpandProperty Path

# === Quick flag execution ===
if ($c -or $commit) {
    & "$RootDir\main_features\commit\git_export_staged.ps1"
    return
}
if ($l -or $log) {
    & "$RootDir\main_features\git\git_log_explorer.ps1"
    return
}
if ($r -or $readme) {
    & "$RootDir\main_features\readme\show_readme_instructions.ps1"
    return
}
if ($u -or $update) {
    & "$RootDir\global_functions\perform_auto_update.ps1"
    & "$RootDir\start.ps1"
    return
}



# Git update check (optional)
& "$RootDir\global_functions\check_for_updates.ps1"
$updateAvailable = & "$RootDir\global_functions\check_for_updates_flag.ps1"

# === Interactive Menu ===
Write-Host ""
Write-Host "Dev Tools Launcher"
Write-Host "==================="
Write-Host "Choose a tool to run:"
Write-Host ""
Write-Host "1) Export staged Git changes"
Write-Host "2) Git log explorer"
Write-Host "3) Show README instructions"
if ($updateAvailable -eq "1") {
    Write-Host "u) Update Dev Tools now"
}
Write-Host "q) Exit"
Write-Host ""

$choice = Read-Host "Enter your choice [1-3, u, q]"

switch ($choice) {
    "1" { & "$RootDir\main_features\commit\git_export_staged.ps1" }
    "2" { & "$RootDir\main_features\git\git_log_explorer.ps1" }
    "3" { & "$RootDir\main_features\readme\show_readme_instructions.ps1" }
    "u" {
        if ($updateAvailable -eq "1") {
            & "$RootDir\global_functions\perform_auto_update.ps1"
            & "$RootDir\start.ps1"
        } else {
            Write-Host "Already up to date."
        }
    }
    { $_ -match "^[qQ]$" } { Write-Host "Goodbye."; exit }
    default { Write-Host "Invalid choice." }
}
