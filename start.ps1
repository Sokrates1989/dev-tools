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
    [switch]$pw,  # safe password generator
    [switch]$password,  # safe password generator
    [switch]$cls,  # cls terminal cleaner
    [switch]$help,  # help
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
$originalArguments = @($args)
if ($originalArguments.Count -eq 0) {
    foreach ($parameterName in $PSBoundParameters.Keys) {
        if ($PSBoundParameters[$parameterName]) {
            $originalArguments += "-$parameterName"
        }
    }
}

#
# Startup update guard.
# Every normal launcher invocation checks once before dispatch. An accepted
# update replays the original command through the updated dispatcher.
#
. "$RootDir\global_functions\update_manager.ps1"
Initialize-DevToolsUpdateMessages -RootDir $RootDir

<#
.SYNOPSIS
    Prints the complete top-level command reference.
#>
function Show-DevToolsHelp {
    Write-Host (Get-DevToolsUpdateMessage -Key "launcher.help.usage")
    Write-Host (Get-DevToolsUpdateMessage -Key "launcher.help.description")
    Write-Host ""
    foreach ($key in @(
            "launcher.help.core_heading",
            "launcher.help.commit",
            "launcher.help.cc",
            "launcher.help.merge",
            "launcher.help.amend",
            "launcher.help.stash",
            "launcher.help.branch_heading",
            "launcher.help.create_branch",
            "launcher.help.track_remote",
            "launcher.help.sync_branches",
            "launcher.help.branch_cleanup",
            "launcher.help.cleanup_heading",
            "launcher.help.log",
            "launcher.help.remove_gitignored",
            "launcher.help.reset",
            "launcher.help.repair",
            "launcher.help.security_heading",
            "launcher.help.password",
            "launcher.help.github_notifications",
            "launcher.help.configuration_heading",
            "launcher.help.settings",
            "launcher.help.cls",
            "launcher.help.readme",
            "launcher.help.general_heading",
            "launcher.help.update",
            "launcher.help.help",
            "launcher.help.quit",
            "launcher.help.examples_heading",
            "launcher.help.example_menu",
            "launcher.help.example_shortcut",
            "launcher.help.cls_note")) {
        Write-Host (Get-DevToolsUpdateMessage -Key $key)
        if ($key -in @(
                "launcher.help.stash",
                "launcher.help.branch_cleanup",
                "launcher.help.repair",
                "launcher.help.github_notifications",
                "launcher.help.readme",
                "launcher.help.quit")) {
            Write-Host ""
        }
    }
}

<#
.SYNOPSIS
    Formats one localized menu heading or structured action row.

.PARAMETER Key
    Locale-catalog key whose action rows use number;mnemonic;label;flags.

.OUTPUTS
    System.String containing an aligned menu line.
#>
function Format-DevToolsMenuLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $message = Get-DevToolsUpdateMessage -Key $Key
    $parts = $message -split ";", 4
    if ($parts.Count -ne 4 -or $parts[0] -notmatch "^\d+$") {
        return $message
    }

    $selector = "{0,2} | {1})" -f $parts[0], $parts[1]
    $description = "$selector $($parts[2])"
    return "$($description.PadRight(62))[$($parts[3])]"
}

<#
.SYNOPSIS
    Prints the localized PowerShell launcher menu.
#>
function Show-DevToolsMenu {
    foreach ($key in @(
            "launcher.menu.title",
            "launcher.menu.divider",
            "launcher.menu.description",
            "",
            "launcher.menu.git_heading",
            "launcher.menu.commit",
            "launcher.menu.commit_external",
            "launcher.menu.merge",
            "launcher.menu.amend",
            "launcher.menu.stash",
            "",
            "launcher.menu.branch_heading",
            "launcher.menu.create_branch",
            "launcher.menu.track_remote",
            "launcher.menu.sync_branches",
            "launcher.menu.branch_cleanup",
            "",
            "launcher.menu.recovery_heading",
            "launcher.menu.log",
            "launcher.menu.remove_gitignored",
            "launcher.menu.reset",
            "launcher.menu.repair",
            "",
            "launcher.powershell.menu.security_heading",
            "launcher.menu.password",
            "launcher.powershell.menu.github_notifications",
            "",
            "launcher.powershell.menu.setup_heading",
            "launcher.powershell.menu.settings",
            "launcher.powershell.menu.cls",
            "launcher.powershell.menu.readme",
            "",
            "launcher.powershell.menu.general_heading",
            "launcher.powershell.menu.update",
            "launcher.powershell.menu.help",
            "launcher.menu.exit")) {
        if ([string]::IsNullOrEmpty($key)) {
            Write-Host ""
        }
        else {
            Write-Host (Format-DevToolsMenuLine -Key $key)
        }
    }
}
$skipUpdateGuard = $env:DEV_TOOLS_UPDATE_REPLAYED -eq "1"
if ($skipUpdateGuard) {
    Remove-Item Env:\DEV_TOOLS_UPDATE_REPLAYED -ErrorAction SilentlyContinue
}

$isExplicitUpdate = $gnuStyleArgument -in @("--u", "--update") -or $u -or $update
$updateAvailable = $false
if (-not $skipUpdateGuard -and -not $isExplicitUpdate) {
    $updateResult = Invoke-DevToolsStartupUpdateCheck -RootDir $RootDir
    $updateAvailable = $updateResult.UpdateAvailable

    if ($updateResult.Updated) {
        $env:DEV_TOOLS_UPDATE_REPLAYED = "1"
        & "$RootDir\start.ps1" @originalArguments
        return
    }
}

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
        "--u" { Initialize-DevToolsUpdateMessages -RootDir $RootDir; if (Invoke-DevToolsUpdate -RootDir $RootDir) { & "$RootDir\start.ps1" }; return }
        "--update" { Initialize-DevToolsUpdateMessages -RootDir $RootDir; if (Invoke-DevToolsUpdate -RootDir $RootDir) { & "$RootDir\start.ps1" }; return }
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
        "--rp" { & "$RootDir\main_features\git-repair\git_repair.ps1"; return }
        "--pw" { & "$RootDir\main_features\password\generate_safe_passwords.ps1"; return }
        "--password" { & "$RootDir\main_features\password\generate_safe_passwords.ps1"; return }
        "--github-notifications" { & "$RootDir\main_features\github-notifications\github_notifications.ps1"; exit $LASTEXITCODE }
        "--gh-notifications" { & "$RootDir\main_features\github-notifications\github_notifications.ps1"; exit $LASTEXITCODE }
        "--gn" { & "$RootDir\main_features\github-notifications\github_notifications.ps1"; exit $LASTEXITCODE }
        "--cls" { & "$RootDir\main_features\cls\cls_installer.ps1"; return }
        "--help" { Show-DevToolsHelp; return }
        "--h" { Show-DevToolsHelp; return }
        "-h" { Show-DevToolsHelp; return }
        "help" { Show-DevToolsHelp; return }
        "--quit" { Write-Host (Get-DevToolsUpdateMessage -Key "launcher.menu.exit_message"); return }
        "--q" { Write-Host (Get-DevToolsUpdateMessage -Key "launcher.menu.exit_message"); return }
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
    Initialize-DevToolsUpdateMessages -RootDir $RootDir
    if (Invoke-DevToolsUpdate -RootDir $RootDir) {
        & "$RootDir\start.ps1"
    }
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
if ($pw -or $password) {
    & "$RootDir\main_features\password\generate_safe_passwords.ps1"
    return
}
if ($cls) {
    & "$RootDir\main_features\cls\cls_installer.ps1"
    return
}
if ($help) {
    Show-DevToolsHelp
    return
}
if ($cfg -or $settings -or $config) {
    & "$RootDir\main_features\settings\edit_settings.ps1"
    return
}

# === Interactive Menu ===
Write-Host ""
Show-DevToolsMenu
Write-Host ""

$choice = [string](Read-Host (Get-DevToolsUpdateMessage -Key "launcher.powershell.menu.choice_prompt"))

# Convert choice to lowercase for easier matching
$choiceLower = $choice.ToLower()

switch ($choiceLower) {
    { $_ -match "^(1|commit|--commit|-c|c|cm|--cm)$" } { & "$RootDir\main_features\commit\git_export_staged.ps1" }
    { $_ -match "^(2|cc|--cc|-cc|commit-external|external-commit)$" } { & "$RootDir\main_features\commit\create_commit_with_external_ai.ps1" }
    { $_ -match "^(3|merge|--merge|-m|m|me|--me)$" } { & "$RootDir\main_features\merge\git_export_merge.ps1" }
    { $_ -match "^(4|amend|--amend|-a|a|am|--am)$" } { & "$RootDir\main_features\amend\git_amend.ps1" }
    { $_ -match "^(5|stash|--stash|-st|st|--st)$" } { & "$RootDir\main_features\stash\stash_manager.ps1" }
    { $_ -match "^(6|create-branch|--create-branch|-n|n|nb|--nb|cnb|--cnb|new-branch|newbranch)$" } { & "$RootDir\main_features\create-branch\create_branch.ps1" }
    { $_ -match "^(7|track-remote|--track-remote|-t|t|tr|--tr|track|--track)$" } { & "$RootDir\main_features\track-remote\track_remote.ps1" }
    { $_ -match "^(8|sync-branches|--sync-branches|-s|s|sb|--sb|sync|--sync)$" } { & "$RootDir\main_features\sync-branches\sync_branches.ps1" }
    { $_ -match "^(9|branch-cleanup|--branch-cleanup|-b|b|bc|--bc|cleanup|--cleanup)$" } { & "$RootDir\main_features\branch-cleanup\branch_cleanup.ps1" }
    { $_ -match "^(10|log|--log|-l|l|lg|--lg)$" } { & "$RootDir\main_features\git\git_log_explorer.ps1" }
    { $_ -match "^(11|remove-gitignored|--remove-gitignored|-i|i|rg|--rg|gitignored|--gitignored)$" } { & "$RootDir\main_features\remove-gitignored\remove_gitignored.ps1" }
    { $_ -match "^(12|reset|--reset|-x|x|revert|--revert|re|--re)$" } { & "$RootDir\main_features\git\reset_local_changes.ps1" }
    { $_ -match "^(13|repair|--repair|rp|--rp|fix|--fix|-f|f)$" } { & "$RootDir\main_features\git-repair\git_repair.ps1" }
    { $_ -match "^(14|password|--password|pw|--pw)$" } { & "$RootDir\main_features\password\generate_safe_passwords.ps1" }
    { $_ -match "^(15|gn|--gn|github-notifications|--github-notifications|gh-notifications|--gh-notifications)$" } { & "$RootDir\main_features\github-notifications\github_notifications.ps1" }
    { $_ -match "^(16|settings|--settings|cfg|--cfg|-cfg|config|--config)$" } { & "$RootDir\main_features\settings\edit_settings.ps1" }
    { $_ -match "^(17|cls|--cls)$" } { & "$RootDir\main_features\cls\cls_installer.ps1" }
    { $_ -match "^(18|readme|--readme|-r|r|rd|--rd)$" } { & "$RootDir\main_features\readme\show_readme_instructions.ps1" }
    { $_ -match "^(19|u|update|--update|-u|--u)$" } {
        if ($updateAvailable) {
            if (Invoke-DevToolsUpdate -RootDir $RootDir) {
                & "$RootDir\start.ps1"
            }
        } else {
            Write-Host (Get-DevToolsUpdateMessage -Key "updates.current")
        }
    }
    { $_ -match "^(20|h|help|--help|-h|--h)$" } { Show-DevToolsHelp }
    { $_ -match "^(0|q|quit|--quit|--q|exit)$" } {
        Write-Host (Get-DevToolsUpdateMessage -Key "launcher.menu.exit_message")
        exit
    }
    default {
        Write-Host (Get-DevToolsUpdateMessage -Key "launcher.menu.invalid_choice" -Arguments @($choice))
        Write-Host (Get-DevToolsUpdateMessage -Key "launcher.powershell.menu.invalid_choices")
    }
}
