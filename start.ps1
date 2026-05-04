param (
    [switch]$c,  # commit
    [switch]$commit,  # commit
    [switch]$cc,  # commit external
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
    [switch]$stash,  # stash
    [switch]$f,  # repair
    [switch]$fix,  # repair
    [switch]$repair,  # repair
    [switch]$cfg,  # settings/config
    [switch]$settings,  # settings/config
    [switch]$config  # settings/config
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

$gnuStyleArgument = if ($args.Count -gt 0) { $args[0].ToLower() } else { $null }
if ($gnuStyleArgument) {
    switch ($gnuStyleArgument) {
        "--c" { & "$RootDir\main_features\commit\git_export_staged.ps1"; return }
        "--commit" { & "$RootDir\main_features\commit\git_export_staged.ps1"; return }
        "--cm" { & "$RootDir\main_features\commit\git_export_staged.ps1"; return }
        "--cc" { & "$RootDir\main_features\commit\create_commit_with_external_ai.ps1"; return }
        "--m" { & "$RootDir\main_features\merge\git_export_merge.ps1"; return }
        "--merge" { & "$RootDir\main_features\merge\git_export_merge.ps1"; return }
        "--me" { & "$RootDir\main_features\merge\git_export_merge.ps1"; return }
        "--l" { & "$RootDir\main_features\git\git_log_explorer.ps1"; return }
        "--log" { & "$RootDir\main_features\git\git_log_explorer.ps1"; return }
        "--lg" { & "$RootDir\main_features\git\git_log_explorer.ps1"; return }
        "--r" { & "$RootDir\main_features\readme\show_readme_instructions.ps1"; return }
        "--readme" { & "$RootDir\main_features\readme\show_readme_instructions.ps1"; return }
        "--rd" { & "$RootDir\main_features\readme\show_readme_instructions.ps1"; return }
        "--u" { & "$RootDir\global_functions\perform_auto_update.ps1"; & "$RootDir\start.ps1"; return }
        "--update" { & "$RootDir\global_functions\perform_auto_update.ps1"; & "$RootDir\start.ps1"; return }
        "--x" { & "$RootDir\main_features\git\reset_local_changes.ps1"; return }
        "--reset" { & "$RootDir\main_features\git\reset_local_changes.ps1"; return }
        "--re" { & "$RootDir\main_features\git\reset_local_changes.ps1"; return }
        "--revert" { & "$RootDir\main_features\git\reset_local_changes.ps1"; return }
        "--a" { & "$RootDir\main_features\amend\git_amend.ps1"; return }
        "--amend" { & "$RootDir\main_features\amend\git_amend.ps1"; return }
        "--am" { & "$RootDir\main_features\amend\git_amend.ps1"; return }
        "--i" { & "$RootDir\main_features\remove-gitignored\remove_gitignored.ps1"; return }
        "--remove-gitignored" { & "$RootDir\main_features\remove-gitignored\remove_gitignored.ps1"; return }
        "--rg" { & "$RootDir\main_features\remove-gitignored\remove_gitignored.ps1"; return }
        "--b" { & "$RootDir\main_features\branch-cleanup\branch_cleanup.ps1"; return }
        "--branch-cleanup" { & "$RootDir\main_features\branch-cleanup\branch_cleanup.ps1"; return }
        "--bc" { & "$RootDir\main_features\branch-cleanup\branch_cleanup.ps1"; return }
        "--s" { & "$RootDir\main_features\sync-branches\sync_branches.ps1"; return }
        "--sync-branches" { & "$RootDir\main_features\sync-branches\sync_branches.ps1"; return }
        "--sb" { & "$RootDir\main_features\sync-branches\sync_branches.ps1"; return }
        "--t" { & "$RootDir\main_features\track-remote\track_remote.ps1"; return }
        "--track-remote" { & "$RootDir\main_features\track-remote\track_remote.ps1"; return }
        "--tr" { & "$RootDir\main_features\track-remote\track_remote.ps1"; return }
        "--n" { & "$RootDir\main_features\create-branch\create_branch.ps1"; return }
        "--create-branch" { & "$RootDir\main_features\create-branch\create_branch.ps1"; return }
        "--nb" { & "$RootDir\main_features\create-branch\create_branch.ps1"; return }
        "--cnb" { & "$RootDir\main_features\create-branch\create_branch.ps1"; return }
        "--stash" { & "$RootDir\main_features\stash\stash_manager.ps1"; return }
        "--st" { & "$RootDir\main_features\stash\stash_manager.ps1"; return }
        "--f" { & "$RootDir\main_features\git-repair\git_repair.ps1"; return }
        "--fix" { & "$RootDir\main_features\git-repair\git_repair.ps1"; return }
        "--repair" { & "$RootDir\main_features\git-repair\git_repair.ps1"; return }
        "--cfg" { & "$RootDir\main_features\settings\edit_settings.ps1"; return }
        "-cfg" { & "$RootDir\main_features\settings\edit_settings.ps1"; return }
        "--settings" { & "$RootDir\main_features\settings\edit_settings.ps1"; return }
        "--config" { & "$RootDir\main_features\settings\edit_settings.ps1"; return }
    }
}

# === Quick flag execution ===
if ($c -or $commit) {
    & "$RootDir\main_features\commit\git_export_staged.ps1"
    return
}
if ($cc) {
    & "$RootDir\main_features\commit\create_commit_with_external_ai.ps1"
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
if ($f -or $fix -or $repair) {
    & "$RootDir\main_features\git-repair\git_repair.ps1"
    return
}
if ($cfg -or $settings -or $config) {
    & "$RootDir\main_features\settings\edit_settings.ps1"
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
Write-Host "cc) Commit style instructions for external AI    [--cc | -cc]"
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
Write-Host ""
Write-Host "Repair & Maintenance (13):"
Write-Host "13) Repair Corrupted Git Repository  [--repair | --fix | -f]"
Write-Host ""
Write-Host "Configuration (14):"
Write-Host "14) Edit Settings / Config (.env)    [--settings | --cfg | -cfg]"
if ($updateAvailable -eq "1") {
    Write-Host "u) Update Dev Tools now"
}
Write-Host "q) Exit"
Write-Host ""

$choice = Read-Host "Enter your choice [1-14, cc, u, q, or option name]"

# Convert choice to lowercase for easier matching
$choiceLower = $choice.ToLower()

switch ($choiceLower) {
    { $_ -match "^(1|commit|--commit|-c|c)$" } { & "$RootDir\main_features\commit\git_export_staged.ps1" }
    { $_ -match "^(cc|--cc|-cc|commit-external|external-commit)$" } { & "$RootDir\main_features\commit\create_commit_with_external_ai.ps1" }
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
    { $_ -match "^(13|repair|--repair|fix|--fix|-f|f)$" } { & "$RootDir\main_features\git-repair\git_repair.ps1" }
    { $_ -match "^(14|settings|--settings|cfg|--cfg|-cfg|config|--config)$" } { & "$RootDir\main_features\settings\edit_settings.ps1" }
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
        Write-Host "Valid options: 1-14, cc, u, q, or option names like 'commit', '--cc', '--log', '-r', 'stash', 'repair', 'settings', etc."
    }
}
