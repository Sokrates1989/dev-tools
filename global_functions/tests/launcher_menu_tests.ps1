<#
.SYNOPSIS
    Validates launcher menu numbering, mnemonics, and direct shortcut parity.

.DESCRIPTION
    Checks both locale catalogs plus the PowerShell and Bash dispatch tables
    without invoking any feature that could modify a repository or user state.
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
    [pscustomobject]@{ Key = "launcher.powershell.menu.readme"; Number = "18"; Mnemonic = "rd"; Flag = "--rd" }
    [pscustomobject]@{ Key = "launcher.powershell.menu.update"; Number = "19"; Mnemonic = "u"; Flag = "--u" }
    [pscustomobject]@{ Key = "launcher.powershell.menu.help"; Number = "20"; Mnemonic = "h"; Flag = "--h" }
)
$bashRows = @(
    [pscustomobject]@{ Key = "launcher.menu.deploy_key"; Number = "15"; Mnemonic = "dk"; Flag = "--dk" }
    [pscustomobject]@{ Key = "launcher.menu.github_notifications"; Number = "16"; Mnemonic = "gn"; Flag = "--gn" }
    [pscustomobject]@{ Key = "launcher.menu.settings"; Number = "17"; Mnemonic = "cfg"; Flag = "--cfg" }
    [pscustomobject]@{ Key = "launcher.menu.cls"; Number = "18"; Mnemonic = "cls"; Flag = "--cls" }
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

$englishKeys = @($englishMessages.Keys | Sort-Object)
$germanKeys = @($germanMessages.Keys | Sort-Object)
$separator = [Environment]::NewLine
if (($englishKeys -join $separator) -cne ($germanKeys -join $separator)) {
    throw "English and German launcher locale key sets differ."
}

Write-Output "Launcher menu contract tests passed."
