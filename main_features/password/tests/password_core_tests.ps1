<#
.SYNOPSIS
    Focused regression tests for password presets and complexity guarantees.

.DESCRIPTION
    Exercises every special-character preset, verifies generated character
    classes and allowed alphabets, checks menu aliases, and validates English
    and German catalog selection without printing generated passwords.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$passwordFeatureDirectory = Split-Path -Parent $PSScriptRoot
. (Join-Path $passwordFeatureDirectory "password_core.ps1")

$originalLocale = $env:PASSWORD_GENERATOR_LOCALE
$env:PASSWORD_GENERATOR_LOCALE = "en"
. (Join-Path $passwordFeatureDirectory "password_ui.ps1")

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Expected,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Actual,
        [Parameter(Mandatory = $true)]
        [string]$Context
    )

    if ($Expected -cne $Actual) {
        throw "$Context. Expected '$Expected', received '$Actual'."
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Context
    )

    if (-not $Condition) {
        throw $Context
    }
}

function Test-GeneratedPasswordPolicy {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Preset
    )

    $specialCharacters = Get-SpecialCharacterSet -Preset $Preset
    $alphabet = Get-PasswordAlphabet -SpecialCharacters $specialCharacters

    for ($sample = 0; $sample -lt 12; $sample++) {
        $password = New-SafePassword -PasswordLength $script:MinimumPasswordLength -SpecialCharacterPreset $Preset
        Assert-True -Condition ($password.Length -eq $script:MinimumPasswordLength) -Context "$Preset produced the wrong length"
        Assert-True -Condition (Test-SafePasswordComplexity -Password $password -SpecialCharacters $specialCharacters) -Context "$Preset missed a required character class"

        foreach ($character in $password.ToCharArray()) {
            Assert-True -Condition ($alphabet.Contains($character.ToString())) -Context "$Preset produced a character outside its alphabet"
        }
    }
}

try {
    $expectedPresets = [ordered]@{
        none = ""
        minimum = "_.-"
        balanced = "@%+-_:,."
        high = '@%+-_:,.!#$^&*?~=()'
        all = '!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'
    }

    foreach ($preset in $expectedPresets.Keys) {
        $actualCharacters = Get-SpecialCharacterSet -Preset $preset
        Assert-Equal -Expected $expectedPresets[$preset] -Actual $actualCharacters -Context "$preset preset characters changed"
        Test-GeneratedPasswordPolicy -Preset $preset
    }

    $passwordSet = @(New-SafePasswordSet -PasswordLength 24 -PasswordCount 3 -SpecialCharacterPreset "balanced")
    Assert-True -Condition ($passwordSet.Count -eq 3) -Context "Password set count changed"

    $menuCases = [ordered]@{
        "" = "balanced"
        "1" = "none"
        "n" = "none"
        "none" = "none"
        "2" = "minimum"
        "m" = "minimum"
        "minimum" = "minimum"
        "3" = "balanced"
        "b" = "balanced"
        "balanced" = "balanced"
        "4" = "high"
        "h" = "high"
        "high" = "high"
        "5" = "all"
        "a" = "all"
        "all" = "all"
    }

    function Read-Host {
        param([string]$Prompt)
        return $script:PasswordTestMenuAnswer
    }

    foreach ($menuAnswer in $menuCases.Keys) {
        $script:PasswordTestMenuAnswer = $menuAnswer
        $selection = Read-SpecialCharacterPreset 6>$null
        Assert-Equal -Expected $menuCases[$menuAnswer] -Actual $selection -Context "Menu alias '$menuAnswer' changed"
    }
    Remove-Item Function:\Read-Host

    $env:PASSWORD_GENERATOR_LOCALE = "de"
    Initialize-PasswordMessages
    Assert-Equal -Expected "Sicherer Passwortgenerator" -Actual (Get-PasswordMessage -Key "title") -Context "German locale selection failed"

    $env:PASSWORD_GENERATOR_LOCALE = "en"
    Initialize-PasswordMessages
    Assert-Equal -Expected "Safe Password Generator" -Actual (Get-PasswordMessage -Key "title") -Context "English locale selection failed"

    Write-Output "PowerShell password tests passed."
}
finally {
    if (Test-Path Function:\Read-Host) {
        Remove-Item Function:\Read-Host
    }

    if ($null -eq $originalLocale) {
        Remove-Item Env:\PASSWORD_GENERATOR_LOCALE -ErrorAction SilentlyContinue
    }
    else {
        $env:PASSWORD_GENERATOR_LOCALE = $originalLocale
    }

    Clear-PasswordGeneratorRandom
}
