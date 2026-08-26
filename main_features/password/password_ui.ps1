<#
.SYNOPSIS
    Interactive prompts and delivery helpers for password generation.

.DESCRIPTION
    Contains the menu flow for choosing password policy, count, and delivery,
    plus clipboard, file, and terminal output handlers.

.NOTES
    Dependencies:
      - password_core.ps1 must be dot-sourced first.
      - Set-Clipboard for clipboard delivery.
      - System.Windows.Forms for clearing clipboard contents when available.
#>

Set-StrictMode -Version Latest

$script:PasswordMessages = @{}

<#
.SYNOPSIS
    Loads password-generator messages for the active locale.

.DESCRIPTION
    Selects German for a de locale and English otherwise. The
    PASSWORD_GENERATOR_LOCALE environment variable can override locale
    detection with en or de for deterministic CLI use and testing.

.OUTPUTS
    System.Void. Populates the module-level password message catalog.
#>
function Initialize-PasswordMessages {
    $requestedLocale = $env:PASSWORD_GENERATOR_LOCALE
    if ([string]::IsNullOrWhiteSpace($requestedLocale)) {
        $requestedLocale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    }

    $language = if ($requestedLocale -match "^de([_-]|$)") { "de" } else { "en" }
    $localePath = Join-Path $PSScriptRoot "locales\$language.properties"
    $script:PasswordMessages = @{}

    foreach ($line in [System.IO.File]::ReadAllLines($localePath, [System.Text.Encoding]::UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }

        $parts = $line -split "=", 2
        if ($parts.Count -eq 2) {
            $script:PasswordMessages[$parts[0]] = $parts[1]
        }
    }
}

<#
.SYNOPSIS
    Returns a localized password-generator message.

.DESCRIPTION
    Resolves a message key and replaces each %s placeholder in order with the
    supplied arguments.

.PARAMETER Key
    Stable message-catalog key.

.PARAMETER Arguments
    Optional values used to replace %s placeholders from left to right.

.OUTPUTS
    System.String. The formatted localized message.

.EXCEPTION
    Throws when the key is missing or too few placeholders are available.
#>
function Get-PasswordMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [object[]]$Arguments = @()
    )

    if (-not $script:PasswordMessages.ContainsKey($Key)) {
        throw "Missing password message key: $Key"
    }

    $remaining = $script:PasswordMessages[$Key]
    $formatted = ""
    foreach ($argument in $Arguments) {
        $placeholderIndex = $remaining.IndexOf("%s", [System.StringComparison]::Ordinal)
        if ($placeholderIndex -lt 0) {
            throw "Password message key '$Key' has too few placeholders."
        }

        $formatted += $remaining.Substring(0, $placeholderIndex) + [string]$argument
        $remaining = $remaining.Substring($placeholderIndex + 2)
    }

    return "$formatted$remaining"
}

Initialize-PasswordMessages

<#
.SYNOPSIS
    Prints command-line usage for the password generator.

.DESCRIPTION
    Shows the launcher flags and summarizes the interactive defaults.

.OUTPUTS
    System.Void. Writes usage text to the console.
#>
function Show-PasswordGeneratorHelp {
    $balancedSpecialCharacters = Get-SpecialCharacterSet -Preset $script:DefaultSpecialCharacterPreset

    Write-Host (Get-PasswordMessage -Key "title")
    Write-Host ""
    Write-Host (Get-PasswordMessage -Key "usage")
    Write-Host (Get-PasswordMessage -Key "usage_password")
    Write-Host (Get-PasswordMessage -Key "usage_pw")
    Write-Host ""
    Write-Host (Get-PasswordMessage -Key "interactive_defaults")
    Write-Host (Get-PasswordMessage -Key "default_characters" -Arguments $balancedSpecialCharacters)
    Write-Host (Get-PasswordMessage -Key "default_special_preset")
    Write-Host (Get-PasswordMessage -Key "default_length" -Arguments $script:DefaultPasswordLength)
    Write-Host (Get-PasswordMessage -Key "default_count" -Arguments $script:DefaultPasswordCount)
    Write-Host (Get-PasswordMessage -Key "default_delivery")
}

<#
.SYNOPSIS
    Prompts for a yes/no answer with a default value.

.DESCRIPTION
    Repeats the prompt until the user presses Enter for the default or enters a
    recognized yes/no value.

.PARAMETER Prompt
    Question shown to the user, without the default suffix.

.PARAMETER DefaultYes
    When true, pressing Enter means yes; otherwise it means no.

.OUTPUTS
    System.Boolean. True for yes, false for no.
#>
function Read-YesNoChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [bool]$DefaultYes = $true
    )

    $suffix = if ($DefaultYes) { "Y/n" } else { "y/N" }

    while ($true) {
        $answer = Read-Host (Get-PasswordMessage -Key "prompt_with_default" -Arguments $Prompt, $suffix)
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $DefaultYes
        }

        switch ($answer.Trim().ToLowerInvariant()) {
            { $_ -in @("y", "yes") } { return $true }
            { $_ -in @("n", "no") } { return $false }
            default { Write-Host (Get-PasswordMessage -Key "yes_no_invalid") -ForegroundColor Yellow }
        }
    }
}

<#
.SYNOPSIS
    Prompts for an integer with range validation.

.DESCRIPTION
    Repeats the prompt until the user presses Enter for the default or enters an
    integer inside the accepted range.

.PARAMETER Prompt
    Question shown to the user, without the default suffix.

.PARAMETER DefaultValue
    Value returned when the user presses Enter.

.PARAMETER MinimumValue
    Lowest accepted integer value.

.PARAMETER MaximumValue
    Highest accepted integer value.

.OUTPUTS
    System.Int32. The selected integer.
#>
function Read-IntegerChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [Parameter(Mandatory = $true)]
        [int]$DefaultValue,
        [Parameter(Mandatory = $true)]
        [int]$MinimumValue,
        [Parameter(Mandatory = $true)]
        [int]$MaximumValue
    )

    while ($true) {
        $answer = Read-Host (Get-PasswordMessage -Key "prompt_with_default" -Arguments $Prompt, $DefaultValue)
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $DefaultValue
        }

        $parsed = 0
        if ([int]::TryParse($answer.Trim(), [ref]$parsed) -and
            $parsed -ge $MinimumValue -and
            $parsed -le $MaximumValue) {
            return $parsed
        }

        Write-Host (Get-PasswordMessage -Key "integer_range" -Arguments $MinimumValue, $MaximumValue) -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
    Prompts for a special-character compatibility preset.

.DESCRIPTION
    Presents numbered and lettered none, minimum, balanced, high, and all
    choices. Pressing Enter selects balanced, the recommended default.

.OUTPUTS
    System.String. One of "none", "minimum", "balanced", "high", or "all".
#>
function Read-SpecialCharacterPreset {
    while ($true) {
        Write-Host ""
        Write-Host (Get-PasswordMessage -Key "special_menu_title")
        Write-Host (Get-PasswordMessage -Key "special_option_none")
        Write-Host (Get-PasswordMessage -Key "special_option_minimum")
        Write-Host (Get-PasswordMessage -Key "special_option_balanced")
        Write-Host (Get-PasswordMessage -Key "special_option_high")
        Write-Host (Get-PasswordMessage -Key "special_option_all")

        $answer = Read-Host (Get-PasswordMessage -Key "special_prompt")
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $script:DefaultSpecialCharacterPreset
        }

        switch ($answer.Trim().ToLowerInvariant()) {
            { $_ -in @("1", "n", "none") } { return "none" }
            { $_ -in @("2", "m", "minimum") } { return "minimum" }
            { $_ -in @("3", "b", "balanced") } { return "balanced" }
            { $_ -in @("4", "h", "high") } { return "high" }
            { $_ -in @("5", "a", "all") } { return "all" }
            default { Write-Host (Get-PasswordMessage -Key "special_invalid") -ForegroundColor Yellow }
        }
    }
}

<#
.SYNOPSIS
    Prompts for the password delivery method.

.DESCRIPTION
    Presents clipboard, file, and terminal options. Clipboard is the recommended
    default because it avoids terminal scrollback and plaintext files.

.OUTPUTS
    System.String. One of "clipboard", "file", or "terminal".
#>
function Read-DeliveryChoice {
    while ($true) {
        Write-Host ""
        Write-Host (Get-PasswordMessage -Key "delivery_title")
        Write-Host (Get-PasswordMessage -Key "delivery_clipboard")
        Write-Host (Get-PasswordMessage -Key "delivery_file")
        Write-Host (Get-PasswordMessage -Key "delivery_terminal")

        $answer = Read-Host (Get-PasswordMessage -Key "delivery_prompt")
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return "clipboard"
        }

        switch ($answer.Trim()) {
            "1" { return "clipboard" }
            "2" { return "file" }
            "3" { return "terminal" }
            default { Write-Host (Get-PasswordMessage -Key "delivery_invalid") -ForegroundColor Yellow }
        }
    }
}

<#
.SYNOPSIS
    Removes generated password material from the clipboard.

.DESCRIPTION
    Uses the Windows Forms clipboard API to clear the clipboard entirely. If the
    host cannot load or use that API, the function overwrites the clipboard with
    a single space so the generated secret is no longer retained.

.OUTPUTS
    System.Boolean. True when the clipboard was cleared or overwritten.
#>
function Clear-PasswordClipboard {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [System.Windows.Forms.Clipboard]::Clear()
        return $true
    }
    catch {
        try {
            Set-Clipboard -Value " "
            return $true
        }
        catch {
            return $false
        }
    }
}

<#
.SYNOPSIS
    Copies generated passwords to the system clipboard.

.DESCRIPTION
    Copies newline-separated passwords and offers to clear the clipboard after
    the user has pasted them. Clearing failures are reported as warnings because
    the original clipboard delivery has already succeeded.

.PARAMETER Passwords
    Password values to copy.

.OUTPUTS
    System.Void. Writes status messages to the console.

.EXCEPTION
    Throws if Set-Clipboard is unavailable or fails.
#>
function Copy-PasswordsToClipboard {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Passwords
    )

    $payload = $Passwords -join [Environment]::NewLine
    Set-Clipboard -Value $payload

    Write-Host ""
    Write-Host (Get-PasswordMessage -Key "clipboard_copied" -Arguments $Passwords.Count) -ForegroundColor Green
    Write-Host (Get-PasswordMessage -Key "clipboard_paste")

    $shouldClearClipboard = Read-YesNoChoice -Prompt (Get-PasswordMessage -Key "clipboard_clear_prompt") -DefaultYes $true
    if ($shouldClearClipboard -and (Clear-PasswordClipboard)) {
        Write-Host (Get-PasswordMessage -Key "clipboard_cleared") -ForegroundColor Green
    }
    elseif ($shouldClearClipboard) {
        Write-Host (Get-PasswordMessage -Key "clipboard_clear_failed") -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
    Saves generated passwords to a user-selected plaintext file.

.DESCRIPTION
    Writes one password value per line and warns that plaintext files must be
    moved into secure storage or deleted promptly.

.PARAMETER Passwords
    Password values to write.

.OUTPUTS
    System.Void. Writes status messages to the console.

.EXCEPTION
    Throws when writing fails.
#>
function Save-PasswordsToFile {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Passwords
    )

    Write-Host ""
    Write-Host (Get-PasswordMessage -Key "file_warning") -ForegroundColor Yellow

    $path = Read-Host (Get-PasswordMessage -Key "file_prompt")
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = "generated-passwords.txt"
    }

    $Passwords | Set-Content -Path $path -Encoding UTF8
    Write-Host (Get-PasswordMessage -Key "file_saved" -Arguments $Passwords.Count, $path) -ForegroundColor Green
    Write-Host (Get-PasswordMessage -Key "file_cleanup")
}

<#
.SYNOPSIS
    Prints generated passwords to the terminal.

.DESCRIPTION
    Echoes password values only, one per line. This is the least secure option
    because terminal scrollback may retain the values.

.PARAMETER Passwords
    Password values to print.

.OUTPUTS
    System.Void. Writes password values to the console.
#>
function Write-PasswordsToTerminal {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Passwords
    )

    Write-Host ""
    Write-Host (Get-PasswordMessage -Key "terminal_header")
    foreach ($password in $Passwords) {
        Write-Host $password
    }
}

<#
.SYNOPSIS
    Runs the interactive safe password generation workflow.

.DESCRIPTION
    Coordinates prompts, password generation, and selected delivery. If
    clipboard delivery fails, the user is asked to choose another method.

.OUTPUTS
    System.Void. Writes prompts, status, and optional password output.
#>
function Invoke-SafePasswordGenerator {
    Write-Host ""
    Write-Host (Get-PasswordMessage -Key "title")
    Write-Host (Get-PasswordMessage -Key "title_divider")
    Write-Host ""

    $specialCharacterPreset = Read-SpecialCharacterPreset
    $passwordLength = Read-IntegerChoice -Prompt (Get-PasswordMessage -Key "password_length") -DefaultValue $script:DefaultPasswordLength -MinimumValue $script:MinimumPasswordLength -MaximumValue 4096
    $passwordCount = Read-IntegerChoice -Prompt (Get-PasswordMessage -Key "password_count") -DefaultValue $script:DefaultPasswordCount -MinimumValue 1 -MaximumValue 100
    $passwords = New-SafePasswordSet -PasswordLength $passwordLength -PasswordCount $passwordCount -SpecialCharacterPreset $specialCharacterPreset

    while ($true) {
        $delivery = Read-DeliveryChoice

        try {
            switch ($delivery) {
                "clipboard" { Copy-PasswordsToClipboard -Passwords $passwords; return }
                "file" { Save-PasswordsToFile -Passwords $passwords; return }
                "terminal" { Write-PasswordsToTerminal -Passwords $passwords; return }
            }
        }
        catch {
            Write-Host (Get-PasswordMessage -Key "delivery_failed" -Arguments $_.Exception.Message) -ForegroundColor Red
            Write-Host (Get-PasswordMessage -Key "delivery_retry") -ForegroundColor Yellow
        }
    }
}
