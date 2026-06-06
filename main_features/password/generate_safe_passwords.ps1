<#
.SYNOPSIS
    Entrypoint for the safe production password generator.

.DESCRIPTION
    Loads the password generator core and interactive UI modules, then runs the
    menu workflow unless help was requested.

.NOTES
    Dependencies:
      - password_core.ps1
      - password_ui.ps1
#>

param(
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

#
# Module loading.
# Core owns cryptographic generation; UI owns prompts and delivery behavior.
#
. "$ScriptDir\password_core.ps1"
. "$ScriptDir\password_ui.ps1"

try {
    if ($Help) {
        Show-PasswordGeneratorHelp
        return
    }

    Invoke-SafePasswordGenerator
}
finally {
    Clear-PasswordGeneratorRandom
}
