<#
.SYNOPSIS
    Provides the localized PowerShell workflow for cls setup.

.DESCRIPTION
    Presents detected platform information, handles existing definitions and
    confirmation, and prints manual or parent-shell activation instructions.
#>

$script:ClsMessages = @{}

<#
.SYNOPSIS
    Loads the English or German cls message catalog.

.PARAMETER FeatureDirectory
    cls feature directory containing the locales folder.
#>
function Initialize-ClsMessages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureDirectory
    )

    $requestedLocale = $env:DEV_TOOLS_LOCALE
    if ([string]::IsNullOrWhiteSpace($requestedLocale)) {
        $requestedLocale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    }
    $language = if ($requestedLocale -match "^de([_-]|$)") { "de" } else { "en" }
    $localePath = Join-Path $FeatureDirectory "locales\$language.properties"
    $script:ClsMessages = @{}

    foreach ($line in [System.IO.File]::ReadAllLines($localePath, [System.Text.Encoding]::UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }
        $parts = $line -split "=", 2
        if ($parts.Count -eq 2) {
            $script:ClsMessages[$parts[0]] = $parts[1]
        }
    }
}

<#
.SYNOPSIS
    Returns a localized cls message with ordered placeholder replacement.

.PARAMETER Key
    Stable message-catalog key.

.PARAMETER Arguments
    Values replacing %s placeholders from left to right.

.OUTPUTS
    System.String. Formatted localized message.
#>
function Get-ClsMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [object[]]$Arguments = @()
    )

    if (-not $script:ClsMessages.ContainsKey($Key)) {
        throw "Missing cls message key: $Key"
    }
    $remaining = $script:ClsMessages[$Key]
    $formatted = ""
    foreach ($argument in $Arguments) {
        $placeholderIndex = $remaining.IndexOf("%s", [System.StringComparison]::Ordinal)
        if ($placeholderIndex -lt 0) {
            throw "cls message key '$Key' has too few placeholders."
        }
        $formatted += $remaining.Substring(0, $placeholderIndex) + [string]$argument
        $remaining = $remaining.Substring($placeholderIndex + 2)
    }
    return "$formatted$remaining"
}

<#
.SYNOPSIS
    Prompts for confirmation with no as the default.

.PARAMETER Prompt
    Localized question including the y/N indicator.

.OUTPUTS
    System.Boolean. True only for an explicit yes response.
#>
function Read-ClsYesNoChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    while ($true) {
        $answer = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $false
        }
        switch ($answer.Trim().ToLowerInvariant()) {
            { $_ -in @("y", "yes", "j", "ja") } { return $true }
            { $_ -in @("n", "no", "nein") } { return $false }
            default { Write-Host (Get-ClsMessage -Key "prompt.invalid") -ForegroundColor Yellow }
        }
    }
}

<#
.SYNOPSIS
    Prints exact manual profile configuration and reload instructions.

.PARAMETER ProfilePath
    PowerShell profile path the user can edit.
#>
function Show-ClsManualInstructions {
    param(
        [string]$ProfilePath
    )

    Write-Host ""
    Write-Host (Get-ClsMessage -Key "manual.heading")
    Write-Host ""
    if (-not [string]::IsNullOrWhiteSpace($ProfilePath)) {
        Write-Host (Get-ClsMessage -Key "manual.add_to" -Arguments $ProfilePath)
        Write-Host ""
    }
    else {
        Write-Host (Get-ClsMessage -Key "manual.choose_profile")
        Write-Host ""
    }
    Write-Host (Get-ClsManagedBlock)
    if (-not [string]::IsNullOrWhiteSpace($ProfilePath)) {
        Write-Host ""
        Write-Host (Get-ClsMessage -Key "manual.reload")
        Write-Host ""
        Write-Host "  $(Get-ClsReloadCommand)"
    }
}

<#
.SYNOPSIS
    Prints the parent-shell activation instructions after installation.
#>
function Show-ClsActivation {
    Write-Host ""
    Write-Host (Get-ClsMessage -Key "success.activate")
    Write-Host ""
    Write-Host "  $(Get-ClsReloadCommand)"
    Write-Host ""
    Write-Host (Get-ClsMessage -Key "success.future")
    Write-Host ""
    Write-Host (Get-ClsMessage -Key "success.run")
    Write-Host ""
    Write-Host "  cls"
}

<#
.SYNOPSIS
    Coordinates detection, conflict handling, confirmation, and installation.

.PARAMETER ProfilePath
    Optional explicit profile path for disposable tests and controlled callers.
#>
function Invoke-ClsSetup {
    param(
        [string]$ProfilePath
    )

    $resolvedProfile = Get-ClsProfilePath -ProfilePath $ProfilePath
    Write-Host ""
    Write-Host (Get-ClsMessage -Key "title")
    Write-Host (Get-ClsMessage -Key "divider")
    Write-Host ""
    Write-Host ("{0,-8} {1}" -f (Get-ClsMessage -Key "summary.os"), (Get-ClsOperatingSystem))
    Write-Host ("{0,-8} {1}" -f (Get-ClsMessage -Key "summary.shell"), "PowerShell")
    $profileDisplay = if ([string]::IsNullOrWhiteSpace($resolvedProfile)) { Get-ClsMessage -Key "summary.unavailable" } else { $resolvedProfile }
    Write-Host ("{0,-8} {1}" -f (Get-ClsMessage -Key "summary.profile"), $profileDisplay)
    Write-Host ""
    Write-Host (Get-ClsMessage -Key "description.first")
    Write-Host (Get-ClsMessage -Key "description.second")
    Write-Host (Get-ClsMessage -Key "description.ed3")
    Write-Host ""
    Write-Host (Get-ClsMessage -Key "config.heading")
    Write-Host ""
    Write-Host (Get-ClsManagedBlock)

    if ([string]::IsNullOrWhiteSpace($resolvedProfile)) {
        Write-Host ""
        Write-Host (Get-ClsMessage -Key "unsupported.profile") -ForegroundColor Yellow
        Show-ClsManualInstructions -ProfilePath ""
        return
    }

    $profileState = Get-ClsProfileState -ProfilePath $resolvedProfile
    if ($profileState -eq "malformed") {
        Write-Host ""
        Write-Host (Get-ClsMessage -Key "error.malformed") -ForegroundColor Red
        Show-ClsManualInstructions -ProfilePath $resolvedProfile
        return
    }

    $forceAppend = $false
    $existingKind = Get-ExistingClsKind -ProfilePath $resolvedProfile
    if ($existingKind -in @("profile", "command")) {
        Write-Host ""
        Write-Host (Get-ClsMessage -Key "conflict.detected") -ForegroundColor Yellow
        $prompt = Get-ClsMessage -Key "prompt.override"
        $forceAppend = $profileState -in @("current", "stale")
    }
    elseif ($profileState -eq "current") {
        Write-Host ""
        Write-Host (Get-ClsMessage -Key "already_installed") -ForegroundColor Green
        Write-Host (Get-ClsMessage -Key "existing.profile" -Arguments $resolvedProfile)
        Show-ClsActivation
        return
    }
    elseif ($profileState -eq "stale") {
        $prompt = Get-ClsMessage -Key "prompt.update"
    }
    else {
        if ($existingKind -eq "builtin-clear-host") {
            Write-Host ""
            Write-Host (Get-ClsMessage -Key "powershell.clear_host")
            $prompt = Get-ClsMessage -Key "prompt.install"
        }
        elseif ($existingKind -ne "none") {
            Write-Host ""
            Write-Host (Get-ClsMessage -Key "conflict.detected") -ForegroundColor Yellow
            $prompt = Get-ClsMessage -Key "prompt.override"
        }
        else {
            $prompt = Get-ClsMessage -Key "prompt.install"
        }
    }

    if (-not (Read-ClsYesNoChoice -Prompt $prompt)) {
        Write-Host ""
        Write-Host (Get-ClsMessage -Key "declined")
        Show-ClsManualInstructions -ProfilePath $resolvedProfile
        return
    }

    try {
        [void](Set-ClsManagedBlock -ProfilePath $resolvedProfile -ForceAppend:$forceAppend)
    }
    catch {
        Write-Host ""
        if ($_.Exception.Message -eq "A stale managed block in a linked profile must be updated manually.") {
            Write-Host (Get-ClsMessage -Key "error.symlink_update") -ForegroundColor Red
        }
        else {
            Write-Host (Get-ClsMessage -Key "error.write" -Arguments $resolvedProfile) -ForegroundColor Red
        }
        Show-ClsManualInstructions -ProfilePath $resolvedProfile
        return
    }

    Write-Host ""
    Write-Host (Get-ClsMessage -Key "success.installed") -ForegroundColor Green
    Show-ClsActivation
}

<#
.SYNOPSIS
    Prints focused help for the cls setup command.
#>
function Show-ClsHelp {
    Write-Host (Get-ClsMessage -Key "help.usage")
    Write-Host ""
    Write-Host (Get-ClsMessage -Key "help.description")
    Write-Host (Get-ClsMessage -Key "help.supported")
    Write-Host (Get-ClsMessage -Key "description.ed3")
}
