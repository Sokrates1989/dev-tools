<#
.SYNOPSIS
    Runs disposable regression tests for PowerShell cls setup and launcher wiring.

.DESCRIPTION
    Uses only temporary profile paths and never reads or modifies the developer's
    actual PowerShell profile.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$testScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$featureDirectory = Split-Path -Parent $testScriptDirectory
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $featureDirectory)

. "$featureDirectory\cls_core.ps1"
. "$featureDirectory\cls_ui.ps1"

function Assert-Equal {
    param([object]$Expected, [object]$Actual, [string]$Context)
    if ([string]$Expected -ne [string]$Actual) {
        throw "$Context. Expected '$Expected', received '$Actual'."
    }
}

function Assert-Contains {
    param([string]$Expected, [string]$Actual, [string]$Context)
    if (-not $Actual.Contains($Expected)) {
        throw "$Context. Missing text: $Expected"
    }
}

function Assert-FileContent {
    param([string]$Path, [string]$Expected, [string]$Context)
    $actual = [System.IO.File]::ReadAllText($Path)
    Assert-Equal -Expected $Expected -Actual $actual -Context $Context
}

$temporaryParent = [System.IO.Path]::GetTempPath()
$testRoot = Join-Path $temporaryParent "dev-tools-cls-tests-$([Guid]::NewGuid().ToString('N'))"
$previousLocale = $env:DEV_TOOLS_LOCALE

try {
    [void][System.IO.Directory]::CreateDirectory($testRoot)
    $env:DEV_TOOLS_LOCALE = "en"
    Initialize-ClsMessages -FeatureDirectory $featureDirectory

    $expectedBlock = @'
# dev-tools cls helper - begin.
function Clear-DevToolsTerminal {
    [Console]::Write("$([char]27)[H$([char]27)[2J$([char]27)[3J")
}
Set-Alias -Name cls -Value Clear-DevToolsTerminal -Scope Global -Force
# dev-tools cls helper - end.
'@.TrimEnd("`r", "`n")
    Assert-Equal -Expected $expectedBlock -Actual (Get-ClsManagedBlock) -Context "PowerShell configuration changed"
    Assert-Equal -Expected ". `$PROFILE" -Actual (Get-ClsReloadCommand) -Context "PowerShell reload command changed"

    $missingProfile = Join-Path $testRoot "missing\nested\profile.ps1"
    Assert-Equal -Expected "absent" -Actual (Get-ClsProfileState -ProfilePath $missingProfile) -Context "Missing profile state changed"
    Assert-Equal -Expected "installed" -Actual (Set-ClsManagedBlock -ProfilePath $missingProfile) -Context "First install status changed"
    Assert-Equal -Expected "current" -Actual (Get-ClsProfileState -ProfilePath $missingProfile) -Context "Installed block was not current"
    $firstInstallContent = [System.IO.File]::ReadAllText($missingProfile)
    Assert-Equal -Expected "current" -Actual (Set-ClsManagedBlock -ProfilePath $missingProfile) -Context "Repeated install status changed"
    Assert-FileContent -Path $missingProfile -Expected $firstInstallContent -Context "Repeated install changed the profile"
    Assert-Equal -Expected 1 -Actual ([regex]::Matches($firstInstallContent, [regex]::Escape($script:ClsManagedBegin)).Count) -Context "Repeated install duplicated the block"

    $preservedProfile = Join-Path $testRoot "preserved.ps1"
    $unrelatedContent = "`$env:EXISTING_VALUE = 'keep-me'`r`n"
    [System.IO.File]::WriteAllText($preservedProfile, $unrelatedContent, [System.Text.UTF8Encoding]::new($false))
    [void](Set-ClsManagedBlock -ProfilePath $preservedProfile)
    $preservedContent = [System.IO.File]::ReadAllText($preservedProfile)
    Assert-Contains -Expected $unrelatedContent -Actual $preservedContent -Context "Unrelated profile content was changed"
    if ($preservedContent -match "(?<!`r)`n") {
        throw "CRLF profile line endings were not preserved."
    }

    $staleProfile = Join-Path $testRoot "stale.ps1"
    $staleContent = @"
before
$script:ClsManagedBegin
Set-Alias cls Clear-Host
$script:ClsManagedEnd
after
"@
    [System.IO.File]::WriteAllText($staleProfile, $staleContent, [System.Text.UTF8Encoding]::new($false))
    Assert-Equal -Expected "stale" -Actual (Get-ClsProfileState -ProfilePath $staleProfile) -Context "Stale block was not detected"
    Assert-Equal -Expected "updated" -Actual (Set-ClsManagedBlock -ProfilePath $staleProfile) -Context "Stale update status changed"
    $updatedContent = [System.IO.File]::ReadAllText($staleProfile)
    Assert-Contains -Expected "before" -Actual $updatedContent -Context "Content before managed block was removed"
    Assert-Contains -Expected "after" -Actual $updatedContent -Context "Content after managed block was removed"
    Assert-Contains -Expected '[Console]::Write' -Actual $updatedContent -Context "Managed block was not updated"
    Assert-Equal -Expected 1 -Actual ([regex]::Matches($updatedContent, [regex]::Escape($script:ClsManagedBegin)).Count) -Context "Managed block update duplicated markers"

    $combinedProfile = Join-Path $testRoot "combined.ps1"
    $combinedOriginal = "$(Get-ClsManagedBlock)`nSet-Alias -Name cls -Value UserCleaner`n"
    [System.IO.File]::WriteAllText($combinedProfile, $combinedOriginal)
    Assert-Equal -Expected "profile" -Actual (Get-ExistingClsKind -ProfilePath $combinedProfile) -Context "A cls definition outside the managed block was not detected"
    Assert-Equal -Expected "updated" -Actual (Set-ClsManagedBlock -ProfilePath $combinedProfile -ForceAppend) -Context "Confirmed override status changed"
    $combinedContent = [System.IO.File]::ReadAllText($combinedProfile)
    Assert-Contains -Expected "Set-Alias -Name cls -Value UserCleaner" -Actual $combinedContent -Context "Confirmed override deleted the user cls definition"
    Assert-Equal -Expected 1 -Actual ([regex]::Matches($combinedContent, [regex]::Escape($script:ClsManagedBegin)).Count) -Context "Confirmed override duplicated the managed block"
    if ($combinedContent.LastIndexOf($script:ClsManagedBegin, [System.StringComparison]::Ordinal) -lt
        $combinedContent.LastIndexOf("Set-Alias -Name cls -Value UserCleaner", [System.StringComparison]::Ordinal)) {
        throw "Confirmed override did not move the managed block after the user definition."
    }

    $conflictProfile = Join-Path $testRoot "conflict.ps1"
    [System.IO.File]::WriteAllText($conflictProfile, "Set-Alias -Name cls -Value MyCleaner`n")
    Assert-Equal -Expected "profile" -Actual (Get-ExistingClsKind -ProfilePath $conflictProfile) -Context "Profile cls conflict was not detected"
    $emptyProfile = Join-Path $testRoot "empty.ps1"
    [System.IO.File]::WriteAllText($emptyProfile, "")
    Assert-Equal -Expected "builtin-clear-host" -Actual (Get-ExistingClsKind -ProfilePath $emptyProfile) -Context "PowerShell Clear-Host alias was not recognized"

    $declinedProfile = Join-Path $testRoot "declined.ps1"
    $declinedOriginal = "Write-Host 'unchanged'`n"
    [System.IO.File]::WriteAllText($declinedProfile, $declinedOriginal)
    function Read-ClsYesNoChoice { param([string]$Prompt) return $false }
    $declinedOutput = (& { Invoke-ClsSetup -ProfilePath $declinedProfile } 6>&1 | Out-String)
    Assert-FileContent -Path $declinedProfile -Expected $declinedOriginal -Context "Declining installation changed the profile"
    Assert-Contains -Expected "No profile changes were made." -Actual $declinedOutput -Context "Decline output changed"
    Assert-Contains -Expected $script:ClsManagedBegin -Actual $declinedOutput -Context "Manual block was not printed after decline"
    Assert-Contains -Expected ". `$PROFILE" -Actual $declinedOutput -Context "Manual reload command was not printed"

    $launcherContent = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot "start.ps1"))
    Assert-Contains -Expected '"--cls" { & "$RootDir\main_features\cls\cls_installer.ps1" -Help:$featureHelp; return }' -Actual $launcherContent -Context "--cls argument routing is missing"
    Assert-Contains -Expected '"^(17|cls|--cls)$"' -Actual $launcherContent -Context "Interactive cls menu routing is missing"
    Assert-Equal -Expected 3 -Actual ([regex]::Matches($launcherContent, [regex]::Escape('"$RootDir\main_features\cls\cls_installer.ps1"')).Count) -Context "PowerShell launcher routes do not share one cls implementation"
    Assert-Contains -Expected 'Show-DevToolsHelp' -Actual $launcherContent -Context "PowerShell help routing is missing"

    $englishKeys = Get-Content (Join-Path $featureDirectory "locales\en.properties") |
        Where-Object { $_ -match "^[^#].*=" } | ForEach-Object { ($_ -split "=", 2)[0] }
    $germanKeys = Get-Content (Join-Path $featureDirectory "locales\de.properties") |
        Where-Object { $_ -match "^[^#].*=" } | ForEach-Object { ($_ -split "=", 2)[0] }
    Assert-Equal -Expected ($englishKeys -join "`n") -Actual ($germanKeys -join "`n") -Context "cls locale key sets differ"

    $rootEnglishKeys = Get-Content (Join-Path $repositoryRoot "locales\en.properties") |
        Where-Object { $_ -match "^[^#].*=" } | ForEach-Object { ($_ -split "=", 2)[0] }
    $rootGermanKeys = Get-Content (Join-Path $repositoryRoot "locales\de.properties") |
        Where-Object { $_ -match "^[^#].*=" } | ForEach-Object { ($_ -split "=", 2)[0] }
    Assert-Equal -Expected ($rootEnglishKeys -join "`n") -Actual ($rootGermanKeys -join "`n") -Context "Launcher locale key sets differ"

    Write-Output "PowerShell cls terminal cleaner tests passed."
}
finally {
    if ($null -eq $previousLocale) {
        Remove-Item Env:\DEV_TOOLS_LOCALE -ErrorAction SilentlyContinue
    }
    else {
        $env:DEV_TOOLS_LOCALE = $previousLocale
    }

    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot.StartsWith([System.IO.Path]::GetFullPath($temporaryParent), [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTestRoot).StartsWith("dev-tools-cls-tests-")) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
