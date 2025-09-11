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
    [switch]$revert,  # reset
    [switch]$a,  # amend
    [switch]$amend,  # amend
    [switch]$i,  # remove-gitignored
    [switch]$remove_gitignored,  # remove-gitignored
    [switch]$b,  # branch-cleanup
    [switch]$branch_cleanup,  # branch-cleanup
    [switch]$s,  # sync-branches
    [switch]$sync_branches,  # sync-branches
    [switch]$m,  # merge
    [switch]$merge,  # merge
    [switch]$t,  # track-remote
    [switch]$track_remote,  # track-remote
    [switch]$n,  # create-branch
    [switch]$create_branch,  # create-branch
    [switch]$st,  # stash
    [switch]$stash  # stash
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
if ($a -or $amend) {
    & "$RootDir\main_features\amend\git_amend.ps1"
    return
}
if ($i -or $remove_gitignored) {
    & "$RootDir\main_features\remove-gitignored\remove_gitignored.ps1"
    return
}
if ($b -or $branch_cleanup) {
    & "$RootDir\main_features\branch-cleanup\branch_cleanup.ps1"
    return
}
if ($s -or $sync_branches) {
    & "$RootDir\main_features\sync-branches\sync_branches.ps1"
    return
}
if ($m -or $merge) {
    & "$RootDir\main_features\merge\git_export_merge.ps1"
    return
}
if ($t -or $track_remote) {
    & "$RootDir\main_features\track-remote\track_remote.ps1"
    return
}
if ($n -or $create_branch) {
    & "$RootDir\main_features\create-branch\create_branch.ps1"
    return
}
if ($st -or $stash) {
    & "$RootDir\main_features\stash\stash_manager.ps1"
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
Write-Host "Core Operations (1-4):"
Write-Host "1) Commit Message Helper"
Write-Host "2) Merge commit assistant"
Write-Host "3) Show README creation instructions"
Write-Host "4) Git Stash Manager                 [--stash | -st]"
Write-Host ""
Write-Host "Branch Management (5-8):"
Write-Host "5) Clean Up Merged Branches"
Write-Host "6) Sync All Branches"
Write-Host "7) Track Remote Branches             [--track-remote | -t]"
Write-Host "8) Create New Branch                  [--create-branch | -n]"
Write-Host ""
Write-Host "Debug & Investigation (9-10):"
Write-Host "9) Git log explorer                  [--log    | -l]"
Write-Host "10) Amend Last Commit                 [--amend  | -a]"
Write-Host ""
Write-Host "Cleanup & Reset (11-12):"
Write-Host "11) Remove Gitignored Files"
Write-Host "12) Reset Local Git Changes"
if ($updateAvailable -eq "1") {
    Write-Host "u) Update Dev Tools now"
}
Write-Host "q) Exit"
Write-Host ""

$choice = Read-Host "Enter your choice [1-12, u, q, or option name]"

# Convert choice to lowercase for easier matching
$choiceLower = $choice.ToLower()

switch ($choiceLower) {
    { $_ -match "^(1|commit|--commit|-c|c)$" } { & "$RootDir\main_features\commit\git_export_staged.ps1" }
    { $_ -match "^(2|merge|--merge|-m|m)$" } { & "$RootDir\main_features\merge\git_export_merge.ps1" }
    { $_ -match "^(3|readme|--readme|-r|r)$" } { & "$RootDir\main_features\readme\show_readme_instructions.ps1" }
    { $_ -match "^(4|stash|--stash|-st|st)$" } { & "$RootDir\main_features\stash\stash_manager.ps1" }
    { $_ -match "^(5|branch-cleanup|--branch-cleanup|-b|b|cleanup|--cleanup)$" } { & "$RootDir\main_features\branch-cleanup\branch_cleanup.ps1" }
    { $_ -match "^(6|sync-branches|--sync-branches|-s|s|sync|--sync)$" } { & "$RootDir\main_features\sync-branches\sync_branches.ps1" }
    { $_ -match "^(7|track-remote|--track-remote|-t|t|track|--track)$" } { & "$RootDir\main_features\track-remote\track_remote.ps1" }
    { $_ -match "^(8|create-branch|--create-branch|-n|n|new-branch|newbranch)$" } { & "$RootDir\main_features\create-branch\create_branch.ps1" }
    { $_ -match "^(9|log|--log|-l|l)$" } { & "$RootDir\main_features\git\git_log_explorer.ps1" }
    { $_ -match "^(10|amend|--amend|-a|a)$" } { & "$RootDir\main_features\amend\git_amend.ps1" }
    { $_ -match "^(11|remove-gitignored|--remove-gitignored|-i|i|gitignored|--gitignored)$" } { & "$RootDir\main_features\remove-gitignored\remove_gitignored.ps1" }
    { $_ -match "^(12|reset|--reset|-x|x|revert|--revert)$" } { & "$RootDir\main_features\git\reset_local_changes.ps1" }
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
        Write-Host "Valid options: 1-12, u, q, or option names like 'commit', '--log', '-r', 'stash', etc."
    }
}
