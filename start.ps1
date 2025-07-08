param (
    [switch]$c,  # commit
    [switch]$commit,  # commit
    [switch]$l,  # log
    [switch]$log,  # log
    [switch]$r,  # readme
    [switch]$readme,  # readme
    [switch]$u,   # update
    [switch]$update,  # update
    [switch]$x,  # reset
    [switch]$reset,  # reset
    [switch]$revert  # reset
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir" | Select-Object -ExpandProperty Path


# Automatically unblock all .ps1 files under the dev-tools directory (Windows only)
Get-ChildItem -Path "$RootDir" -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Unblock-File -Path $_.FullName
    } catch {
        # Continue silently if it fails (e.g. on already unblocked or non-Windows systems)
    }
}

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
if ($x -or $reset -or $revert) {
    & "$RootDir\main_features\git\reset_local_changes.ps1"
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
Write-Host "4) Forget all local changes and reset branch"
if ($updateAvailable -eq "1") {
    Write-Host "u) Update Dev Tools now"
}
Write-Host "q) Exit"
Write-Host ""

$choice = Read-Host "Enter your choice [1-4, u, q, or option name]"

# Convert choice to lowercase for easier matching
$choiceLower = $choice.ToLower()

switch ($choiceLower) {
    { $_ -match "^(1|commit|--commit|-c|c)$" } { & "$RootDir\main_features\commit\git_export_staged.ps1" }
    { $_ -match "^(2|log|--log|-l|l)$" } { & "$RootDir\main_features\git\git_log_explorer.ps1" }
    { $_ -match "^(3|readme|--readme|-r|r)$" } { & "$RootDir\main_features\readme\show_readme_instructions.ps1" }
    { $_ -match "^(4|reset|--reset|-x|x|revert|--revert)$" } { & "$RootDir\main_features\git\reset_local_changes.ps1" }
    { $_ -match "^(u|update|--update|-u)$" } {
        if ($updateAvailable -eq "1") {
            & "$RootDir\global_functions\perform_auto_update.ps1"
            & "$RootDir\start.ps1"
        } else {
            Write-Host "Already up to date."
        }
    }
    { $_ -match "^(q|quit|exit)$" } { Write-Host "Goodbye."; exit }
    default { 
        Write-Host "Invalid choice: $choice"
        Write-Host "Valid options: 1-4, u, q, or option names like 'commit', '--log', '-r', etc."
    }
}
