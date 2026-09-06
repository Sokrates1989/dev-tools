<#
.SYNOPSIS
    Provides safe PowerShell profile persistence for the cls terminal cleaner.

.DESCRIPTION
    Generates and classifies the dev-tools-owned profile block, detects
    existing cls commands, and updates only the managed block after the caller
    has obtained confirmation.
#>

$script:ClsManagedBegin = "# dev-tools cls helper - begin."
$script:ClsManagedEnd = "# dev-tools cls helper - end."

<#
.SYNOPSIS
    Returns the current operating-system display name.

.OUTPUTS
    System.String. Windows, Linux, macOS, or the runtime platform name.
#>
function Get-ClsOperatingSystem {
    if ($env:DEV_TOOLS_CLS_OS) {
        return $env:DEV_TOOLS_CLS_OS
    }
    if ($env:OS -eq "Windows_NT") {
        return "Windows"
    }

    try {
        if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
                [System.Runtime.InteropServices.OSPlatform]::OSX)) {
            return "macOS"
        }
        if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
                [System.Runtime.InteropServices.OSPlatform]::Linux)) {
            return "Linux"
        }
    }
    catch {
        # Windows PowerShell 5.1 on older .NET installations may lack this API.
    }

    return [Environment]::OSVersion.Platform.ToString()
}

<#
.SYNOPSIS
    Resolves the current user's host-specific PowerShell profile.

.PARAMETER ProfilePath
    Optional explicit path used by disposable tests and controlled callers.

.OUTPUTS
    System.String. Profile path, or an empty string if it cannot be resolved.
#>
function Get-ClsProfilePath {
    param(
        [string]$ProfilePath
    )

    if (-not [string]::IsNullOrWhiteSpace($ProfilePath)) {
        return $ProfilePath
    }
    if (-not [string]::IsNullOrWhiteSpace($env:DEV_TOOLS_CLS_PROFILE_PATH)) {
        return $env:DEV_TOOLS_CLS_PROFILE_PATH
    }

    $profileValue = Get-Variable -Name PROFILE -ValueOnly -ErrorAction SilentlyContinue
    if ($null -eq $profileValue) {
        return ""
    }
    if ($profileValue.PSObject.Properties.Name -contains "CurrentUserCurrentHost") {
        return [string]$profileValue.CurrentUserCurrentHost
    }
    return [string]$profileValue
}

<#
.SYNOPSIS
    Returns the dev-tools-owned PowerShell profile block.

.OUTPUTS
    System.String. Function and forced cls alias definition using ANSI ED3.
#>
function Get-ClsManagedBlock {
    return @"
$script:ClsManagedBegin
function Clear-DevToolsTerminal {
    [Console]::Write("`$([char]27)[H`$([char]27)[2J`$([char]27)[3J")
}
Set-Alias -Name cls -Value Clear-DevToolsTerminal -Scope Global -Force
$script:ClsManagedEnd
"@.TrimEnd("`r", "`n")
}

<#
.SYNOPSIS
    Classifies the dev-tools-owned block in a PowerShell profile.

.PARAMETER ProfilePath
    Profile file to inspect without changing it.

.OUTPUTS
    System.String. absent, unmanaged, current, stale, or malformed.
#>
function Get-ClsProfileState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfilePath
    )

    if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
        return "absent"
    }

    $content = [System.IO.File]::ReadAllText($ProfilePath)
    $beginPattern = "(?m)^$([regex]::Escape($script:ClsManagedBegin))`r?$"
    $endPattern = "(?m)^$([regex]::Escape($script:ClsManagedEnd))`r?$"
    $beginMatches = [regex]::Matches($content, $beginPattern)
    $endMatches = [regex]::Matches($content, $endPattern)

    if ($beginMatches.Count -eq 0 -and $endMatches.Count -eq 0) {
        return "unmanaged"
    }
    if ($beginMatches.Count -ne 1 -or $endMatches.Count -ne 1) {
        return "malformed"
    }

    $blockPattern = "(?ms)^$([regex]::Escape($script:ClsManagedBegin))`r?`n.*?^$([regex]::Escape($script:ClsManagedEnd))`r?$"
    $blockMatch = [regex]::Match($content, $blockPattern)
    if (-not $blockMatch.Success) {
        return "malformed"
    }

    $normalizedExisting = $blockMatch.Value.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
    $normalizedExpected = (Get-ClsManagedBlock).Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
    if ($normalizedExisting -eq $normalizedExpected) {
        return "current"
    }
    return "stale"
}

<#
.SYNOPSIS
    Detects a non-dev-tools cls command in the profile or current session.

.PARAMETER ProfilePath
    PowerShell profile file to inspect when it exists.

.OUTPUTS
    System.String. none, builtin-clear-host, profile, or command.
#>
function Get-ExistingClsKind {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfilePath
    )

    if (Test-Path -LiteralPath $ProfilePath -PathType Leaf) {
        $content = [System.IO.File]::ReadAllText($ProfilePath)
        $managedPattern = "(?ms)^$([regex]::Escape($script:ClsManagedBegin))`r?`n.*?^$([regex]::Escape($script:ClsManagedEnd))`r?$"
        $content = [regex]::Replace($content, $managedPattern, "", 1)
        $definitionPattern = '(?im)^\s*(?:Set-Alias\s+(?:-Name\s+)?["'']?cls["'']?(?:\s|$)|New-Alias\s+(?:-Name\s+)?["'']?cls["'']?(?:\s|$)|function\s+(?:global:)?(?:cls|Clear-DevToolsTerminal)(?:\s|\{|$))'
        if ($content -match $definitionPattern) {
            return "profile"
        }
    }

    $alias = Get-Alias -Name cls -ErrorAction SilentlyContinue
    if ($null -ne $alias -and $alias.Definition -eq "Clear-Host") {
        return "builtin-clear-host"
    }
    $command = Get-Command -Name cls -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return "command"
    }
    $helperCommand = Get-Command -Name Clear-DevToolsTerminal -ErrorAction SilentlyContinue
    if ($null -ne $helperCommand) {
        return "command"
    }
    return "none"
}

<#
.SYNOPSIS
    Detects the encoding of an existing profile for safe rewrites.

.PARAMETER ProfilePath
    Existing profile file.

.OUTPUTS
    System.Text.Encoding. BOM-aware existing encoding or BOM-less UTF-8.
#>
function Get-ClsProfileEncoding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfilePath
    )

    $bytes = [System.IO.File]::ReadAllBytes($ProfilePath)
    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and
        $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
        return [System.Text.UTF32Encoding]::new($true, $true)
    }
    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and
        $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
        return [System.Text.UTF32Encoding]::new($false, $true)
    }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [System.Text.UTF8Encoding]::new($true)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return [System.Text.UnicodeEncoding]::new($true, $true)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return [System.Text.UnicodeEncoding]::new($false, $true)
    }
    return [System.Text.UTF8Encoding]::new($false)
}

<#
.SYNOPSIS
    Atomically replaces an existing regular profile with prepared text.

.PARAMETER ProfilePath
    Existing profile file to replace.

.PARAMETER Content
    Complete new content with unrelated profile text already preserved.

.PARAMETER Encoding
    Original profile encoding detected by Get-ClsProfileEncoding.

.EXCEPTION
    Throws when the temporary file cannot be written or atomically swapped.
#>
function Write-ClsProfileTextSafely {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfilePath,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [System.Text.Encoding]$Encoding
    )

    $profileDirectory = Split-Path -Parent $ProfilePath
    $temporaryName = ".$(Split-Path -Leaf $ProfilePath).dev-tools-cls-$([Guid]::NewGuid().ToString('N')).tmp"
    $temporaryPath = Join-Path $profileDirectory $temporaryName
    $backupPath = "$temporaryPath.backup"
    try {
        [System.IO.File]::WriteAllText($temporaryPath, $Content, $Encoding)
        [System.IO.File]::Replace($temporaryPath, $ProfilePath, $backupPath, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
        if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
            Remove-Item -LiteralPath $backupPath -Force
        }
    }
}

<#
.SYNOPSIS
    Installs or updates only the dev-tools-owned profile block.

.PARAMETER ProfilePath
    Current user's PowerShell profile. Missing parents and the file are created.

.PARAMETER ForceAppend
    Moves an existing managed block to the end so a confirmed override takes
    precedence over a separate user-defined cls entry without deleting it.

.OUTPUTS
    System.String. current, installed, or updated.

.EXCEPTION
    Throws for malformed managed markers, non-file paths, symlink updates, or
    file-system write failures.
#>
function Set-ClsManagedBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfilePath,
        [switch]$ForceAppend
    )

    $state = Get-ClsProfileState -ProfilePath $ProfilePath
    if ($state -eq "current" -and -not $ForceAppend) {
        return "current"
    }
    if ($state -eq "malformed") {
        throw "The profile contains incomplete or duplicate dev-tools cls markers."
    }

    $profileDirectory = Split-Path -Parent $ProfilePath
    if (-not [string]::IsNullOrWhiteSpace($profileDirectory)) {
        [void][System.IO.Directory]::CreateDirectory($profileDirectory)
    }

    $managedBlock = Get-ClsManagedBlock
    if ($state -eq "absent") {
        $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
        $newProfileBlock = $managedBlock.Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", [Environment]::NewLine)
        [System.IO.File]::WriteAllText(
            $ProfilePath,
            "$newProfileBlock$([Environment]::NewLine)",
            $utf8WithoutBom)
        return "installed"
    }

    $item = Get-Item -LiteralPath $ProfilePath -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 -and
        ($state -eq "stale" -or $ForceAppend)) {
        throw "A stale managed block in a linked profile must be updated manually."
    }

    $content = [System.IO.File]::ReadAllText($ProfilePath)
    $encoding = Get-ClsProfileEncoding -ProfilePath $ProfilePath
    $newline = if ($content.Contains("`r`n")) { "`r`n" } elseif ($content.Contains("`n")) { "`n" } else { [Environment]::NewLine }

    $managedBlockWithProfileEndings = $managedBlock.Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", $newline)
    $blockPattern = "(?ms)^$([regex]::Escape($script:ClsManagedBegin))`r?`n.*?^$([regex]::Escape($script:ClsManagedEnd))`r?$"
    if ($ForceAppend -and $state -in @("current", "stale")) {
        $content = [regex]::Replace($content, $blockPattern, "", 1)
        $separator = if ($content.Length -eq 0) { "" } elseif ($content.EndsWith("`n") -or $content.EndsWith("`r")) { $newline } else { "$newline$newline" }
        $writeParameters = @{
            ProfilePath = $ProfilePath
            Content = "$content$separator$managedBlockWithProfileEndings$newline"
            Encoding = $encoding
        }
        Write-ClsProfileTextSafely @writeParameters
        return "updated"
    }
    elseif ($state -eq "stale") {
        $updatedContent = [regex]::Replace(
            $content,
            $blockPattern,
            [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $managedBlockWithProfileEndings },
            1)
        Write-ClsProfileTextSafely -ProfilePath $ProfilePath -Content $updatedContent -Encoding $encoding
        return "updated"
    }

    $separator = ""
    if ($content.Length -gt 0) {
        $separator = if ($content.EndsWith("`n") -or $content.EndsWith("`r")) { $newline } else { "$newline$newline" }
    }
    [System.IO.File]::AppendAllText(
        $ProfilePath,
        "$separator$managedBlockWithProfileEndings$newline",
        $encoding)
    return "installed"
}

<#
.SYNOPSIS
    Returns the parent-shell activation command.

.OUTPUTS
    System.String. Dot-source command for the current PowerShell profile.
#>
function Get-ClsReloadCommand {
    return ". `$PROFILE"
}
