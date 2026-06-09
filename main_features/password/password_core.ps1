<#
.SYNOPSIS
    Core cryptographic password generation helpers.

.DESCRIPTION
    Contains password alphabets, random number generation, complexity checks,
    and password creation functions used by the interactive password tool.

.NOTES
    Dependencies:
      - PowerShell 5.1+ or PowerShell 7+
      - .NET cryptographic RandomNumberGenerator
#>

Set-StrictMode -Version Latest

#
# Password policy constants.
# Safe specials avoid quotes, backslashes, whitespace, shell expansion,
# separators, comments, brackets, and equals signs.
#
$script:UpperChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
$script:LowerChars = "abcdefghijklmnopqrstuvwxyz"
$script:DigitChars = "0123456789"
$script:SafeSpecialChars = "_.-"
$script:MinimumPasswordLength = 16
$script:DefaultPasswordLength = 64
$script:DefaultPasswordCount = 1
$script:SecureRandom = [System.Security.Cryptography.RandomNumberGenerator]::Create()

<#
.SYNOPSIS
    Returns an unbiased cryptographic random integer below a maximum value.

.DESCRIPTION
    Uses rejection sampling over four CSPRNG bytes so every alphabet index has
    equal probability and modulo bias is avoided.

.PARAMETER MaxExclusive
    Exclusive upper bound for the returned integer.

.OUTPUTS
    System.Int32. A value in the range [0, MaxExclusive).

.EXCEPTION
    Throws when MaxExclusive is less than one.
#>
function Get-SecureRandomInteger {
    param(
        [Parameter(Mandatory = $true)]
        [int]$MaxExclusive
    )

    if ($MaxExclusive -lt 1) {
        throw "MaxExclusive must be greater than zero."
    }

    $bytes = New-Object byte[] 4
    $uint32Range = [uint64]([uint32]::MaxValue) + 1
    $usableLimit = $uint32Range - ($uint32Range % [uint64]$MaxExclusive)

    do {
        $script:SecureRandom.GetBytes($bytes)
        $value = [BitConverter]::ToUInt32($bytes, 0)
    } while ([uint64]$value -ge $usableLimit)

    return [int]([uint64]$value % [uint64]$MaxExclusive)
}

<#
.SYNOPSIS
    Selects one cryptographically random character from a character set.

.DESCRIPTION
    Picks one unbiased index from the supplied character set.

.PARAMETER Characters
    Non-empty string containing the allowed characters.

.OUTPUTS
    System.String. A single-character string from Characters.

.EXCEPTION
    Throws when Characters is empty.
#>
function Get-SecureRandomCharacter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Characters
    )

    if ([string]::IsNullOrEmpty($Characters)) {
        throw "Characters must not be empty."
    }

    $index = Get-SecureRandomInteger -MaxExclusive $Characters.Length
    return $Characters[$index].ToString()
}

<#
.SYNOPSIS
    Builds the allowed alphabet for the selected password policy.

.DESCRIPTION
    Combines uppercase, lowercase, digit, and optionally safe special
    characters.

.PARAMETER IncludeSpecialCharacters
    When true, appends safe special characters to the alphanumeric alphabet.

.OUTPUTS
    System.String. The complete allowed character alphabet.
#>
function Get-PasswordAlphabet {
    param(
        [bool]$IncludeSpecialCharacters
    )

    $alphabet = "$script:UpperChars$script:LowerChars$script:DigitChars"
    if ($IncludeSpecialCharacters) {
        $alphabet = "$alphabet$script:SafeSpecialChars"
    }

    return $alphabet
}

<#
.SYNOPSIS
    Checks whether a password satisfies the selected complexity policy.

.DESCRIPTION
    Requires uppercase, lowercase, digit, and optionally approved special
    characters.

.PARAMETER Password
    Password string to validate.

.PARAMETER IncludeSpecialCharacters
    Whether a safe special character is required.

.OUTPUTS
    System.Boolean. True when all required categories are present.
#>
function Test-SafePasswordComplexity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Password,
        [bool]$IncludeSpecialCharacters
    )

    $hasUpper = $Password.IndexOfAny($script:UpperChars.ToCharArray()) -ge 0
    $hasLower = $Password.IndexOfAny($script:LowerChars.ToCharArray()) -ge 0
    $hasDigit = $Password.IndexOfAny($script:DigitChars.ToCharArray()) -ge 0
    $hasSpecial = $Password.IndexOfAny($script:SafeSpecialChars.ToCharArray()) -ge 0

    if ($IncludeSpecialCharacters) {
        return $hasUpper -and $hasLower -and $hasDigit -and $hasSpecial
    }

    return $hasUpper -and $hasLower -and $hasDigit
}

<#
.SYNOPSIS
    Generates one safe high-entropy password.

.DESCRIPTION
    Creates a password from the selected alphabet using CSPRNG-backed unbiased
    character selection and retries until required character classes appear.

.PARAMETER PasswordLength
    Number of characters to generate. Must be at least 16.

.PARAMETER IncludeSpecialCharacters
    Whether to include and require approved special characters.

.OUTPUTS
    System.String. A generated password value.

.EXCEPTION
    Throws when PasswordLength is less than the configured minimum.
#>
function New-SafePassword {
    param(
        [Parameter(Mandatory = $true)]
        [int]$PasswordLength,
        [bool]$IncludeSpecialCharacters
    )

    if ($PasswordLength -lt $script:MinimumPasswordLength) {
        throw "Password length must be at least $script:MinimumPasswordLength characters."
    }

    $alphabet = Get-PasswordAlphabet -IncludeSpecialCharacters $IncludeSpecialCharacters

    do {
        $builder = [System.Text.StringBuilder]::new($PasswordLength)
        for ($index = 0; $index -lt $PasswordLength; $index++) {
            [void]$builder.Append((Get-SecureRandomCharacter -Characters $alphabet))
        }

        $password = $builder.ToString()
    } while (-not (Test-SafePasswordComplexity -Password $password -IncludeSpecialCharacters $IncludeSpecialCharacters))

    return $password
}

<#
.SYNOPSIS
    Generates the requested number of passwords.

.DESCRIPTION
    Returns password values only, without labels or secrets.env syntax.

.PARAMETER PasswordLength
    Number of characters in each generated password.

.PARAMETER PasswordCount
    Number of passwords to generate.

.PARAMETER IncludeSpecialCharacters
    Whether generated passwords should include safe special characters.

.OUTPUTS
    System.String[]. Generated password values.
#>
function New-SafePasswordSet {
    param(
        [Parameter(Mandatory = $true)]
        [int]$PasswordLength,
        [Parameter(Mandatory = $true)]
        [int]$PasswordCount,
        [bool]$IncludeSpecialCharacters
    )

    $passwords = @()
    for ($index = 0; $index -lt $PasswordCount; $index++) {
        $passwords += New-SafePassword -PasswordLength $PasswordLength -IncludeSpecialCharacters $IncludeSpecialCharacters
    }

    return $passwords
}

<#
.SYNOPSIS
    Releases the cryptographic random number generator.

.DESCRIPTION
    Disposes the module-level RandomNumberGenerator instance when the entrypoint
    finishes.

.OUTPUTS
    System.Void. No value is returned.
#>
function Clear-PasswordGeneratorRandom {
    if ($null -ne $script:SecureRandom) {
        $script:SecureRandom.Dispose()
        $script:SecureRandom = $null
    }
}
