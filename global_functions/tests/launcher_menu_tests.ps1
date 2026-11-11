<#
.SYNOPSIS
    Validates launcher menu numbering, mnemonics, and direct shortcut parity.

.DESCRIPTION
    Checks both locale catalogs and dispatch tables. Uses disposable feature
    stubs to verify PowerShell help routing without running feature workflows.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..") |
    Select-Object -ExpandProperty Path
$powerShellLauncher = [System.IO.File]::ReadAllText(
    (Join-Path $repositoryRoot "start.ps1"))
$bashLauncher = [System.IO.File]::ReadAllText(
    (Join-Path $repositoryRoot "start.sh"))

<#
.SYNOPSIS
    Loads one launcher properties file into a key-value map.

.PARAMETER Path
    UTF-8 locale catalog to load.

.OUTPUTS
    System.Collections.Hashtable containing every non-comment property.
#>
function Get-LauncherTestMessages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $messages = @{}
    foreach ($line in [System.IO.File]::ReadAllLines(
            $Path, [System.Text.Encoding]::UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }

        $parts = $line -split "=", 2
        if ($parts.Count -eq 2) {
            $messages[$parts[0]] = $parts[1]
        }
    }
    return $messages
}

<#
.SYNOPSIS
    Verifies one localized menu row's number, mnemonic, and direct flag.

.PARAMETER Messages
    Loaded locale map containing the row.

.PARAMETER Row
    Expected row contract.

.PARAMETER Locale
    Locale name used in failure messages.
#>
function Assert-LauncherMenuRow {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Messages,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Row,
        [Parameter(Mandatory = $true)]
        [string]$Locale
    )

    if (-not $Messages.ContainsKey($Row.Key)) {
        throw "Missing $Locale launcher menu key: $($Row.Key)"
    }

    $parts = $Messages[$Row.Key] -split ";", 4
    if ($parts.Count -ne 4) {
        throw "$Locale launcher row '$($Row.Key)' is not a four-field menu record."
    }
    if ($parts[0] -cne $Row.Number -or $parts[1] -cne $Row.Mnemonic) {
        throw "$Locale launcher row '$($Row.Key)' does not use '$($Row.Number) | $($Row.Mnemonic))'."
    }
    if (-not $parts[3].Contains($Row.Flag)) {
        throw "$Locale launcher row '$($Row.Key)' does not advertise $($Row.Flag)."
    }
}

$commonRows = @(
    [pscustomobject]@{ Key = "launcher.menu.commit"; Number = "1"; Mnemonic = "cm"; Flag = "--cm" }
    [pscustomobject]@{ Key = "launcher.menu.commit_external"; Number = "2"; Mnemonic = "cc"; Flag = "--cc" }
    [pscustomobject]@{ Key = "launcher.menu.merge"; Number = "3"; Mnemonic = "me"; Flag = "--me" }
    [pscustomobject]@{ Key = "launcher.menu.amend"; Number = "4"; Mnemonic = "am"; Flag = "--am" }
    [pscustomobject]@{ Key = "launcher.menu.stash"; Number = "5"; Mnemonic = "st"; Flag = "--st" }
    [pscustomobject]@{ Key = "launcher.menu.create_branch"; Number = "6"; Mnemonic = "nb"; Flag = "--nb" }
    [pscustomobject]@{ Key = "launcher.menu.track_remote"; Number = "7"; Mnemonic = "tr"; Flag = "--tr" }
    [pscustomobject]@{ Key = "launcher.menu.sync_branches"; Number = "8"; Mnemonic = "sb"; Flag = "--sb" }
    [pscustomobject]@{ Key = "launcher.menu.branch_cleanup"; Number = "9"; Mnemonic = "bc"; Flag = "--bc" }
    [pscustomobject]@{ Key = "launcher.menu.log"; Number = "10"; Mnemonic = "lg"; Flag = "--lg" }
    [pscustomobject]@{ Key = "launcher.menu.remove_gitignored"; Number = "11"; Mnemonic = "rg"; Flag = "--rg" }
    [pscustomobject]@{ Key = "launcher.menu.reset"; Number = "12"; Mnemonic = "re"; Flag = "--re" }
    [pscustomobject]@{ Key = "launcher.menu.repair"; Number = "13"; Mnemonic = "rp"; Flag = "--rp" }
    [pscustomobject]@{ Key = "launcher.menu.password"; Number = "14"; Mnemonic = "pw"; Flag = "--pw" }
    [pscustomobject]@{ Key = "launcher.menu.exit"; Number = "0"; Mnemonic = "q"; Flag = "--q" }
)
$powerShellRows = @(
    [pscustomobject]@{ Key = "launcher.powershell.menu.github_notifications"; Number = "15"; Mnemonic = "gn"; Flag = "--gn" }
    [pscustomobject]@{ Key = "launcher.powershell.menu.settings"; Number = "16"; Mnemonic = "cfg"; Flag = "--cfg" }
    [pscustomobject]@{ Key = "launcher.powershell.menu.cls"; Number = "17"; Mnemonic = "cls"; Flag = "--cls" }
    [pscustomobject]@{ Key = "launcher.powershell.menu.udc"; Number = "22"; Mnemonic = "udc"; Flag = "--udc" }
    [pscustomobject]@{ Key = "launcher.powershell.menu.readme"; Number = "18"; Mnemonic = "rd"; Flag = "--rd" }
    [pscustomobject]@{ Key = "launcher.powershell.menu.update"; Number = "19"; Mnemonic = "u"; Flag = "--u" }
    [pscustomobject]@{ Key = "launcher.powershell.menu.help"; Number = "20"; Mnemonic = "h"; Flag = "--h" }
    [pscustomobject]@{ Key = "launcher.powershell.menu.deploy_key"; Number = "21"; Mnemonic = "dk"; Flag = "--dk" }
)
$bashRows = @(
    [pscustomobject]@{ Key = "launcher.menu.deploy_key"; Number = "15"; Mnemonic = "dk"; Flag = "--dk" }
    [pscustomobject]@{ Key = "launcher.menu.github_notifications"; Number = "16"; Mnemonic = "gn"; Flag = "--gn" }
    [pscustomobject]@{ Key = "launcher.menu.settings"; Number = "17"; Mnemonic = "cfg"; Flag = "--cfg" }
    [pscustomobject]@{ Key = "launcher.menu.cls"; Number = "18"; Mnemonic = "cls"; Flag = "--cls" }
    [pscustomobject]@{ Key = "launcher.menu.udc"; Number = "22"; Mnemonic = "udc"; Flag = "--udc" }
    [pscustomobject]@{ Key = "launcher.menu.readme"; Number = "19"; Mnemonic = "rd"; Flag = "--rd" }
    [pscustomobject]@{ Key = "launcher.menu.update"; Number = "20"; Mnemonic = "u"; Flag = "--u" }
    [pscustomobject]@{ Key = "launcher.menu.help"; Number = "21"; Mnemonic = "h"; Flag = "--h" }
)

$englishMessages = Get-LauncherTestMessages -Path (
    Join-Path $repositoryRoot "locales\en.properties")
$germanMessages = Get-LauncherTestMessages -Path (
    Join-Path $repositoryRoot "locales\de.properties")

foreach ($locale in @(
        [pscustomobject]@{ Name = "English"; Messages = $englishMessages }
        [pscustomobject]@{ Name = "German"; Messages = $germanMessages })) {
    foreach ($row in @($commonRows + $powerShellRows + $bashRows)) {
        Assert-LauncherMenuRow -Messages $locale.Messages -Row $row -Locale $locale.Name
    }
}

foreach ($row in @($commonRows + $powerShellRows)) {
    if (-not $powerShellLauncher.Contains('"' + $row.Key + '"')) {
        throw "PowerShell menu does not render $($row.Key)."
    }

    $routePattern = '\{ \$_ -match "\^\(' +
        [regex]::Escape($row.Number) + '\|[^"\r\n]*' +
        [regex]::Escape($row.Mnemonic) + '[^"\r\n]*\)\$" \}'
    if ($powerShellLauncher -notmatch $routePattern) {
        throw "PowerShell launcher does not route $($row.Number) and $($row.Mnemonic) together."
    }
    if (-not $powerShellLauncher.Contains('"' + $row.Flag + '"')) {
        throw "PowerShell launcher does not directly route $($row.Flag)."
    }
}

foreach ($row in @($commonRows + $bashRows)) {
    if (-not $bashLauncher.Contains($row.Key)) {
        throw "Bash menu does not render $($row.Key)."
    }

    $routePattern = "(?m)^\s*$([regex]::Escape($row.Number))\|[^\r\n]*" +
        [regex]::Escape('"' + $row.Mnemonic + '"') + "[^\r\n]*\)"
    if ($bashLauncher -notmatch $routePattern) {
        throw "Bash launcher does not route $($row.Number) and $($row.Mnemonic) together."
    }
    if (-not $bashLauncher.Contains($row.Flag)) {
        throw "Bash launcher does not directly route $($row.Flag)."
    }
}

$bashDirectRoutes = [regex]::Match($bashLauncher,
    '(?ms)^if \[\[ \$# -gt 0 \]\]; then.*?^fi\s*$').Value
$powerShellDirectRoutes = [regex]::Match($powerShellLauncher,
    '(?ms)^if \(\$gnuStyleArgument\) \{.*?^\}\s*$').Value
$bashFlags = @([regex]::Matches($bashDirectRoutes, '(?m)^        (--[^\r\n]+)\)\r?$') |
    ForEach-Object { $_.Groups[1].Value -split '\|' } |
    Where-Object { $_ -like '--*' } | Sort-Object -Unique)
$powerShellFlags = @([regex]::Matches($powerShellDirectRoutes, '"(--[a-z][\w-]*)"') |
    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
if ($bashFlags.Count -eq 0 -or $powerShellFlags.Count -eq 0) {
    throw 'Could not read both direct dispatch tables.'
}
$flagDifferences = Compare-Object $bashFlags $powerShellFlags
if ($flagDifferences) {
    throw "Direct aliases differ between launchers: $($flagDifferences.InputObject -join ', ')"
}

$englishKeys = @($englishMessages.Keys | Sort-Object)
$germanKeys = @($germanMessages.Keys | Sort-Object)
$separator = [Environment]::NewLine
if (($englishKeys -join $separator) -cne ($germanKeys -join $separator)) {
    throw "English and German launcher locale key sets differ."
}

$fixtureParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $fixtureParent ('dev-tools-launcher-tests-' + [guid]::NewGuid())
$oldReplayMarker = $env:DEV_TOOLS_UPDATE_REPLAYED
try {
    $fixtureLauncher = Join-Path $fixtureRoot 'start.ps1'
    $null = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'global_functions')
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'start.ps1') -Destination $fixtureLauncher
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'locales') -Destination $fixtureRoot -Recurse
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'global_functions\update_manager.ps1') `
        -Destination (Join-Path $fixtureRoot 'global_functions')

    foreach ($feature in @(
            @{ Path = 'password\generate_safe_passwords.ps1'; Flags = @('--password', '--pw', '-pw') },
            @{ Path = 'cls\cls_installer.ps1'; Flags = @('--cls', '-cls') },
            @{ Path = 'udc\udc_installer.ps1'; Flags = @('--udc') },
            @{ Path = 'github-notifications\github_notifications.ps1'; Flags = @('--gn', '--gh-notifications', '--github-notifications') },
            @{ Path = 'deploy-key\deploy_key_manager.ps1'; Flags = @('--deploy-key', '--dk') })) {
        $stubPath = Join-Path $fixtureRoot "main_features\$($feature.Path)"
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $stubPath)
        Set-Content -LiteralPath $stubPath -Value @'
param([switch]$Help)
if (-not $Help -and ($args.Count -ne 1 -or $args[0] -cne '--help')) {
    throw 'The launcher failed to pass feature help.'
}
Write-Output $MyInvocation.MyCommand.Name
exit 0
'@

        foreach ($flag in $feature.Flags) {
            foreach ($helpFlag in @('--help', '--h', '-help', '-h', 'help')) {
                $env:DEV_TOOLS_UPDATE_REPLAYED = '1'
                $result = & $fixtureLauncher $flag $helpFlag
                if ($result -cne (Split-Path -Leaf $stubPath)) {
                    throw "$flag $helpFlag did not show feature help."
                }
            }
        }
    }

    $env:DEV_TOOLS_UPDATE_REPLAYED = '1'
    if ((& $fixtureLauncher -pw --help) -cne 'generate_safe_passwords.ps1') {
        throw 'A bound password switch followed by --help did not show feature help.'
    }
    $env:DEV_TOOLS_UPDATE_REPLAYED = '1'
    if ((& $fixtureLauncher --pw -h) -cne 'generate_safe_passwords.ps1') {
        throw 'A bound help switch did not show password help.'
    }
}
finally {
    $env:DEV_TOOLS_UPDATE_REPLAYED = $oldReplayMarker
    $resolvedFixture = Resolve-Path -LiteralPath $fixtureRoot -ErrorAction SilentlyContinue
    if ($resolvedFixture -and $resolvedFixture.ProviderPath -eq $fixtureRoot) {
        Remove-Item -LiteralPath $resolvedFixture.ProviderPath -Recurse -Force
    }
}

Write-Output "Launcher menu and help contract tests passed."
