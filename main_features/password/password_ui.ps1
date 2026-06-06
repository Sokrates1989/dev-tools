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

<#
.SYNOPSIS
    Prints command-line usage for the password generator.

.DESCRIPTION
    Shows the launcher flags and summarizes the interactive defaults.

.OUTPUTS
    System.Void. Writes usage text to the console.
#>
function Show-PasswordGeneratorHelp {
    Write-Host "Safe Password Generator"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  dev-tools --password"
    Write-Host "  dev-tools --pw"
    Write-Host ""
    Write-Host "Interactive defaults:"
    Write-Host "  Characters: A-Z, a-z, 0-9, and safe specials ($script:SafeSpecialChars)"
    Write-Host "  Length:     $script:DefaultPasswordLength"
    Write-Host "  Count:      $script:DefaultPasswordCount"
    Write-Host "  Delivery:   Clipboard (recommended)"
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

    $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }

    while ($true) {
        $answer = Read-Host "$Prompt $suffix"
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $DefaultYes
        }

        switch ($answer.Trim().ToLowerInvariant()) {
            { $_ -in @("y", "yes") } { return $true }
            { $_ -in @("n", "no") } { return $false }
            default { Write-Host "Please enter yes or no." -ForegroundColor Yellow }
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
        $answer = Read-Host "$Prompt [$DefaultValue]"
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $DefaultValue
        }

        $parsed = 0
        if ([int]::TryParse($answer.Trim(), [ref]$parsed) -and
            $parsed -ge $MinimumValue -and
            $parsed -le $MaximumValue) {
            return $parsed
        }

        Write-Host "Enter a number from $MinimumValue to $MaximumValue." -ForegroundColor Yellow
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
        Write-Host "How should the password be shown?"
        Write-Host "1) Copy to clipboard (Recommended: avoids terminal history and plaintext files)"
        Write-Host "2) Save to a plaintext file"
        Write-Host "3) Echo to CLI output"

        $answer = Read-Host "Choose delivery method [1]"
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return "clipboard"
        }

        switch ($answer.Trim()) {
            "1" { return "clipboard" }
            "2" { return "file" }
            "3" { return "terminal" }
            default { Write-Host "Choose 1, 2, or 3." -ForegroundColor Yellow }
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
    Write-Host "Copied $($Passwords.Count) password(s) to the clipboard." -ForegroundColor Green
    Write-Host "Paste them into the target secret manager now."

    $shouldClearClipboard = Read-YesNoChoice -Prompt "Clear clipboard after you have pasted them? (recommended)" -DefaultYes $true
    if ($shouldClearClipboard -and (Clear-PasswordClipboard)) {
        Write-Host "Clipboard cleared." -ForegroundColor Green
    }
    elseif ($shouldClearClipboard) {
        Write-Host "Could not clear the clipboard automatically. Please clear it manually." -ForegroundColor Yellow
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
    Write-Host "Warning: this writes plaintext passwords to disk." -ForegroundColor Yellow

    $path = Read-Host "File path [generated-passwords.txt]"
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = "generated-passwords.txt"
    }

    $Passwords | Set-Content -Path $path -Encoding UTF8
    Write-Host "Saved $($Passwords.Count) password(s) to $path." -ForegroundColor Green
    Write-Host "Delete or move this file into your secure secret storage as soon as possible."
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
    Write-Host "Generated password(s):"
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
    Write-Host "Safe Password Generator"
    Write-Host "======================="
    Write-Host ""
    Write-Host "Special characters use this safe set: $script:SafeSpecialChars"
    Write-Host "Excluded: quotes, backslashes, whitespace, #, $, &, |, ;, <, >, brackets, equals"
    Write-Host ""

    $includeSpecial = Read-YesNoChoice -Prompt "Include safe special characters?" -DefaultYes $true
    $passwordLength = Read-IntegerChoice -Prompt "Password length" -DefaultValue $script:DefaultPasswordLength -MinimumValue $script:MinimumPasswordLength -MaximumValue 4096
    $passwordCount = Read-IntegerChoice -Prompt "Number of passwords to generate" -DefaultValue $script:DefaultPasswordCount -MinimumValue 1 -MaximumValue 100
    $passwords = New-SafePasswordSet -PasswordLength $passwordLength -PasswordCount $passwordCount -IncludeSpecialCharacters $includeSpecial

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
            Write-Host "Delivery failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Please choose another delivery method." -ForegroundColor Yellow
        }
    }
}
