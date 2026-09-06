<#
.SYNOPSIS
    Runs the interactive PowerShell cls terminal-cleaner setup workflow.
#>

param(
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

. "$ScriptDirectory\cls_core.ps1"
. "$ScriptDirectory\cls_ui.ps1"

Initialize-ClsMessages -FeatureDirectory $ScriptDirectory
if ($Help) {
    Show-ClsHelp
    return
}

Invoke-ClsSetup
