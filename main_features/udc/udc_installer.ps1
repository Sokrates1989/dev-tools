<#
.SYNOPSIS
    Prints the standalone Ubuntu installer for pasting into an SSH session.
#>

$ErrorActionPreference = 'Stop'
$rootDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $rootDir 'global_functions/update_manager.ps1')
Initialize-DevToolsUpdateMessages -RootDir $rootDir

if ($args.Count -gt 0) {
    switch ($args[0]) {
        '--help' {
            Get-DevToolsUpdateMessage -Key 'launcher.udc.usage_powershell'
            Get-DevToolsUpdateMessage -Key 'launcher.udc.description_powershell'
            exit 0
        }
        '--print' { }
        default {
            [Console]::Error.WriteLine((Get-DevToolsUpdateMessage -Key 'launcher.udc.unknown_option' -Arguments @($args[0])))
            [Console]::Error.WriteLine((Get-DevToolsUpdateMessage -Key 'launcher.udc.usage_powershell'))
            exit 2
        }
    }
}

$messages = foreach ($language in @('en', 'de')) {
    $catalog = Join-Path $rootDir "locales/$language.properties"
    foreach ($line in Get-Content -LiteralPath $catalog -Encoding UTF8) {
        if ($line.StartsWith('udc.', [StringComparison]::Ordinal)) {
            "$language.$line"
        }
    }
}
foreach ($line in Get-Content -LiteralPath (Join-Path $PSScriptRoot 'install_udc.sh') -Encoding UTF8) {
    if ($line -ceq '# UDC_MESSAGES') {
        $messages
    } else {
        $line
    }
}
exit 0
