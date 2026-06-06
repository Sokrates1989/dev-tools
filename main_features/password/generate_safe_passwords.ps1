<#
.SYNOPSIS
    Generates deployment-safe production passwords for Docker secret templates.

.DESCRIPTION
    Uses the operating system cryptographic random number generator with
    rejection sampling to create high-entropy passwords. The default output
    matches the secrets.env template used by the Python API deployment
    workflow, while direct script flags can generate a single password or a
    numbered custom set.

.NOTES
    Dependencies:
      - PowerShell 5.1+ or PowerShell 7+
      - .NET cryptographic RandomNumberGenerator
#>

param(
    [int]$Length = 48,
    [int]$Count = 0,
    [switch]$Single,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#
# Password policy constants.
# The special alphabet avoids quotes, backslashes, whitespace, shell expansion,
# command separators, comment markers, brackets, and equals signs so generated
# values can be pasted directly into unquoted secrets.env lines.
#
$script:UpperChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
$script:LowerChars = "abcdefghijklmnopqrstuvwxyz"
$script:DigitChars = "0123456789"
$script:SpecialChars = "@%+-_:,."
$script:SafeAlphabet = "$script:UpperChars$script:LowerChars$script:DigitChars$script:SpecialChars"
$script:DefaultSecretNames = @(
    "DB_PASSWORD",
    "ADMIN_API_KEY",
    "BACKUP_RESTORE_API_KEY",
    "BACKUP_DELETE_API_KEY",
    "DB_UI_ADMIN_PASSWORD"
)
$script:SecureRandom = [System.Security.Cryptography.RandomNumberGenerator]::Create()

<#
.SYNOPSIS
    Prints command-line usage for the password generator.

.DESCRIPTION
    Shows supported direct-script options. The launcher normally calls this
    script with no arguments to produce secrets.env-compatible output.

.OUTPUTS
    System.Void. Writes usage text to the console.
#>
function Show-PasswordGeneratorHelp {
    Write-Host "Safe Password Generator"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  dev-tools --password"
    Write-Host "  generate_safe_passwords.ps1 [-Length 64] [-Single]"
    Write-Host "  generate_safe_passwords.ps1 [-Length 64] [-Count 3]"
    Write-Host ""
    Write-Host "Defaults:"
    Write-Host "  Length: 48 characters"
    Write-Host "  Output: DB_PASSWORD, ADMIN_API_KEY, BACKUP_RESTORE_API_KEY,"
    Write-Host "          BACKUP_DELETE_API_KEY, DB_UI_ADMIN_PASSWORD"
}

<#
.SYNOPSIS
    Returns an unbiased cryptographic random integer below a maximum value.

.DESCRIPTION
    Reads four random bytes from the .NET cryptographic random number generator
    and uses rejection sampling so every index in the target alphabet has equal
    probability. This avoids modulo bias in password character selection.

.PARAMETER MaxExclusive
    Exclusive upper bound for the returned integer. Must be greater than zero.

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
    Uses Get-SecureRandomInteger to pick an unbiased index from the supplied
    character set. The caller controls which category or alphabet is used.

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
    Checks whether a password satisfies the generator complexity policy.

.DESCRIPTION
    Verifies that a generated password contains uppercase, lowercase, digit, and
    approved special characters. This guarantees every emitted password uses the
    full intended character-class mix.

.PARAMETER Password
    Password string to validate.

.OUTPUTS
    System.Boolean. True when the password contains all required categories.
#>
function Test-SafePasswordComplexity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    $hasUpper = $Password.IndexOfAny($script:UpperChars.ToCharArray()) -ge 0
    $hasLower = $Password.IndexOfAny($script:LowerChars.ToCharArray()) -ge 0
    $hasDigit = $Password.IndexOfAny($script:DigitChars.ToCharArray()) -ge 0
    $hasSpecial = $Password.IndexOfAny($script:SpecialChars.ToCharArray()) -ge 0

    return $hasUpper -and $hasLower -and $hasDigit -and $hasSpecial
}

<#
.SYNOPSIS
    Generates one safe high-entropy password.

.DESCRIPTION
    Builds a password from the approved dotenv-safe alphabet using a
    cryptographic RNG. It retries only if the random draw misses one of the
    required character classes, which is rare at the default length.

.PARAMETER PasswordLength
    Number of characters to generate. Minimum is 16; default caller value is 48.

.OUTPUTS
    System.String. A generated password that satisfies the complexity policy.

.EXCEPTION
    Throws when PasswordLength is less than 16.
#>
function New-SafePassword {
    param(
        [Parameter(Mandatory = $true)]
        [int]$PasswordLength
    )

    if ($PasswordLength -lt 16) {
        throw "Password length must be at least 16 characters."
    }

    do {
        $builder = [System.Text.StringBuilder]::new($PasswordLength)
        for ($index = 0; $index -lt $PasswordLength; $index++) {
            [void]$builder.Append((Get-SecureRandomCharacter -Characters $script:SafeAlphabet))
        }

        $password = $builder.ToString()
    } while (-not (Test-SafePasswordComplexity -Password $password))

    return $password
}

<#
.SYNOPSIS
    Returns the secret names that should be generated for this invocation.

.DESCRIPTION
    Selects either the default secrets.env template keys, one PASSWORD entry, or
    a numbered PASSWORD_N set based on direct-script options.

.PARAMETER RequestedCount
    Optional custom count. A value less than one means the default template keys
    should be used unless Single is set.

.PARAMETER SinglePassword
    When set, returns a single PASSWORD entry.

.OUTPUTS
    System.String[]. Secret names to print with generated values.
#>
function Get-PasswordOutputNames {
    param(
        [int]$RequestedCount,
        [bool]$SinglePassword
    )

    if ($SinglePassword) {
        return @("PASSWORD")
    }

    if ($RequestedCount -gt 0) {
        $names = @()
        for ($index = 1; $index -le $RequestedCount; $index++) {
            $names += "PASSWORD_$index"
        }
        return $names
    }

    return $script:DefaultSecretNames
}

<#
.SYNOPSIS
    Writes generated passwords as secrets.env-compatible key-value lines.

.DESCRIPTION
    Emits a short policy header followed by unquoted KEY=value lines that can be
    pasted into the deployment repository's secrets.env file.

.PARAMETER Names
    Secret keys to emit.

.PARAMETER PasswordLength
    Number of characters in each generated password.

.OUTPUTS
    System.Void. Writes generated secrets to the console.
#>
function Write-GeneratedPasswords {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Names,
        [Parameter(Mandatory = $true)]
        [int]$PasswordLength
    )

    Write-Host "# Safe production secrets"
    Write-Host "# Length: $PasswordLength"
    Write-Host "# Alphabet: A-Z a-z 0-9 $script:SpecialChars"
    Write-Host "# Avoided: quotes, backslashes, whitespace, #, $, &, |, ;, <, >, brackets, equals"
    Write-Host ""

    foreach ($name in $Names) {
        $password = New-SafePassword -PasswordLength $PasswordLength
        Write-Host "$name=$password"
    }
}

try {
    if ($Help) {
        Show-PasswordGeneratorHelp
        return
    }

    $outputNames = Get-PasswordOutputNames -RequestedCount $Count -SinglePassword $Single.IsPresent
    Write-GeneratedPasswords -Names $outputNames -PasswordLength $Length
}
finally {
    if ($null -ne $script:SecureRandom) {
        $script:SecureRandom.Dispose()
    }
}
