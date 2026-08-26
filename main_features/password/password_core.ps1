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
# Presets trade compatibility for a progressively wider punctuation alphabet.
#
$script:UpperChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
$script:LowerChars = "abcdefghijklmnopqrstuvwxyz"
$script:DigitChars = "0123456789"
$script:SpecialCharacterPresets = [ordered]@{
    none = ""
    minimum = "_.-"
    balanced = "@%+-_:,."
    high = '@%+-_:,.!#$^&*?~=()'
    all = '!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'
}
$script:DefaultSpecialCharacterPreset = "balanced"
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
    Returns the special-character set assigned to a policy preset.

.DESCRIPTION
    Resolves none, minimum, balanced, high, or all to the exact punctuation
    alphabet used for password generation and complexity validation.

.PARAMETER Preset
    Special-character compatibility preset to resolve.

.OUTPUTS
    System.String. The preset's special-character set, or an empty string for
    none.
#>
function Get-SpecialCharacterSet {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("none", "minimum", "balanced", "high", "all")]
        [string]$Preset
    )

    return $script:SpecialCharacterPresets[$Preset]
}

<#
.SYNOPSIS
    Builds the allowed alphabet for the selected password policy.

.DESCRIPTION
    Combines uppercase, lowercase, digit, and the selected special-character
    set.

.PARAMETER SpecialCharacters
    Special characters to append. An empty string selects alphanumeric only.

.OUTPUTS
    System.String. The complete allowed character alphabet.
#>
function Get-PasswordAlphabet {
    param(
        [AllowEmptyString()]
        [string]$SpecialCharacters
    )

    $alphabet = "$script:UpperChars$script:LowerChars$script:DigitChars"
    if (-not [string]::IsNullOrEmpty($SpecialCharacters)) {
        $alphabet = "$alphabet$SpecialCharacters"
    }

    return $alphabet
}

<#
.SYNOPSIS
    Checks whether a password satisfies the selected complexity policy.

.DESCRIPTION
    Requires uppercase, lowercase, digit, and, when a non-empty set is
    supplied, at least one character from that special-character set.

.PARAMETER Password
    Password string to validate.

.PARAMETER SpecialCharacters
    Allowed special characters. When non-empty, one of them is required.

.OUTPUTS
    System.Boolean. True when all required categories are present.
#>
function Test-SafePasswordComplexity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Password,
        [AllowEmptyString()]
        [string]$SpecialCharacters
    )

    $hasUpper = $Password.IndexOfAny($script:UpperChars.ToCharArray()) -ge 0
    $hasLower = $Password.IndexOfAny($script:LowerChars.ToCharArray()) -ge 0
    $hasDigit = $Password.IndexOfAny($script:DigitChars.ToCharArray()) -ge 0
    if (-not [string]::IsNullOrEmpty($SpecialCharacters)) {
        $hasSpecial = $Password.IndexOfAny($SpecialCharacters.ToCharArray()) -ge 0
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

.PARAMETER SpecialCharacterPreset
    Compatibility preset controlling which special characters are allowed and
    required. The none preset requires only alphanumeric character classes.

.OUTPUTS
    System.String. A generated password value.

.EXCEPTION
    Throws when PasswordLength is less than the configured minimum.
#>
function New-SafePassword {
    param(
        [Parameter(Mandatory = $true)]
        [int]$PasswordLength,
        [Parameter(Mandatory = $true)]
        [ValidateSet("none", "minimum", "balanced", "high", "all")]
        [string]$SpecialCharacterPreset
    )

    if ($PasswordLength -lt $script:MinimumPasswordLength) {
        throw "Password length must be at least $script:MinimumPasswordLength characters."
    }

    $specialCharacters = Get-SpecialCharacterSet -Preset $SpecialCharacterPreset
    $alphabet = Get-PasswordAlphabet -SpecialCharacters $specialCharacters

    do {
        $builder = [System.Text.StringBuilder]::new($PasswordLength)
        for ($index = 0; $index -lt $PasswordLength; $index++) {
            [void]$builder.Append((Get-SecureRandomCharacter -Characters $alphabet))
        }

        $password = $builder.ToString()
    } while (-not (Test-SafePasswordComplexity -Password $password -SpecialCharacters $specialCharacters))

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

.PARAMETER SpecialCharacterPreset
    Compatibility preset controlling the allowed special characters.

.OUTPUTS
    System.String[]. Generated password values.
#>
function New-SafePasswordSet {
    param(
        [Parameter(Mandatory = $true)]
        [int]$PasswordLength,
        [Parameter(Mandatory = $true)]
        [int]$PasswordCount,
        [Parameter(Mandatory = $true)]
        [ValidateSet("none", "minimum", "balanced", "high", "all")]
        [string]$SpecialCharacterPreset
    )

    $passwords = @()
    for ($index = 0; $index -lt $PasswordCount; $index++) {
        $passwords += New-SafePassword -PasswordLength $PasswordLength -SpecialCharacterPreset $SpecialCharacterPreset
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
