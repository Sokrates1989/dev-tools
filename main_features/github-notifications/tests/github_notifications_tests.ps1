<#
.SYNOPSIS
    Runs mocked regression tests for the PowerShell GitHub Notification Audit.

.DESCRIPTION
    Replaces the GitHub CLI boundary with deterministic responses. No request
    reaches GitHub and no repository subscription is changed.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$testDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$featureDirectory = Split-Path -Parent $testDirectory
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $featureDirectory)

. "$featureDirectory\github_notifications.ps1"

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

function Assert-NotContains {
    param([string]$Unexpected, [string]$Actual, [string]$Context)
    if ($Actual.Contains($Unexpected)) {
        throw "$Context. Unexpected text: $Unexpected"
    }
}

$isWindowsPlatform = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
if ($isWindowsPlatform) {
    $previousPath = $env:Path
    try {
        $separator = [System.IO.Path]::PathSeparator
        $env:Path = "C:\Existing${separator}C:\Duplicate${separator}C:\Duplicate"
        Update-GitHubNotificationsProcessPath
        Assert-Contains -Expected "C:\Existing" -Actual $env:Path -Context "Current process PATH entries were discarded"
        Assert-Equal -Expected 1 -Actual (@($env:Path.Split($separator) | Where-Object { $_ -eq "C:\Duplicate" }).Count) -Context "PATH refresh retained duplicate entries"

        $persistedPath = @(
            [Environment]::GetEnvironmentVariable("Path", "User"),
            [Environment]::GetEnvironmentVariable("Path", "Machine")
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
        if ($null -ne $persistedPath) {
            $firstPersistedEntry = $persistedPath.Split($separator) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -First 1
            Assert-Contains -Expected $firstPersistedEntry -Actual $env:Path -Context "Persisted Windows PATH entries were not refreshed"
        }
    }
    finally {
        $env:Path = $previousPath
    }

    $previousGhCommand = $script:GitHubNotificationsGhCommand
    try {
        $script:GitHubNotificationsGhCommand = $env:ComSpec
        $stderrResult = Invoke-GitHubNotificationsGh -Arguments @("/d", "/c", "echo github.com 1>&2")
        Assert-Equal -Expected 0 -Actual $stderrResult.ExitCode -Context "Successful native stderr changed the exit code"
        Assert-Contains -Expected "github.com" -Actual $stderrResult.Output -Context "Native stderr was not captured"

        $failureResult = Invoke-GitHubNotificationsGh -Arguments @("/d", "/c", "echo auth-failed 1>&2 & exit /b 7")
        Assert-Equal -Expected 7 -Actual $failureResult.ExitCode -Context "Native command failure exit code was lost"
        Assert-Contains -Expected "auth-failed" -Actual $failureResult.Output -Context "Failed native stderr was not captured"
    }
    finally {
        $script:GitHubNotificationsGhCommand = $previousGhCommand
    }
}

$script:MockGhAvailable = $true
$script:MockGhScenario = "audit"

function Test-GitHubNotificationsGhAvailable {
    return $script:MockGhAvailable
}

function Invoke-GitHubNotificationsGh {
    param([string[]]$Arguments)

    $joined = " " + ($Arguments -join " ") + " "
    if ($joined.Contains(" auth status ")) {
        $exitCode = if ($script:MockGhScenario -eq "unauthenticated") { 1 } else { 0 }
        return [pscustomobject]@{ ExitCode = $exitCode; Output = "" }
    }
    if ($joined.Contains(" user/repos?")) {
        if (-not $joined.Contains(" --paginate ")) {
            return [pscustomobject]@{ ExitCode = 70; Output = "" }
        }
        $records = @(
            "audit-user/subscribed`tfalse`tfalse",
            "audit-user/not-subscribed`tfalse`tfalse",
            "audit-user/ignored`tfalse`ttrue",
            "audit-user/api-error`tfalse`tfalse",
            "audit-user/archived`ttrue`ttrue") -join "`n"
        return [pscustomobject]@{ ExitCode = 0; Output = $records }
    }
    if ($joined.Contains(" api ") -and $joined.Contains(" user ")) {
        return [pscustomobject]@{ ExitCode = 0; Output = "audit-user" }
    }

    $endpoint = $Arguments | Where-Object { $_ -like "repos/*/subscription" } | Select-Object -First 1
    switch ($endpoint) {
        "repos/audit-user/subscribed/subscription" {
            return [pscustomobject]@{ ExitCode = 0; Output = "HTTP/2.0 200 OK`n`ntrue`tfalse" }
        }
        "repos/audit-user/not-subscribed/subscription" {
            return [pscustomobject]@{ ExitCode = 1; Output = "HTTP/2.0 404 Not Found`ngh: Not Found (HTTP 404)" }
        }
        "repos/audit-user/ignored/subscription" {
            return [pscustomobject]@{ ExitCode = 0; Output = "HTTP/2.0 200 OK`n`nfalse`ttrue" }
        }
        "repos/audit-user/api-error/subscription" {
            return [pscustomobject]@{ ExitCode = 1; Output = "HTTP/2.0 403 Forbidden`ngh: Forbidden (HTTP 403)" }
        }
        "repos/audit-user/archived/subscription" {
            return [pscustomobject]@{ ExitCode = 99; Output = "Archived repositories must not be checked." }
        }
        default {
            return [pscustomobject]@{ ExitCode = 64; Output = "Unexpected fake gh invocation." }
        }
    }
}

$previousLocale = $env:DEV_TOOLS_LOCALE
try {
    $env:DEV_TOOLS_LOCALE = "en"
    Initialize-GitHubNotificationsMessages

    $script:MockGhAvailable = $false
    $missingOutput = (& { Invoke-GitHubNotificationsAudit } | Out-String)
    Assert-Equal -Expected 1 -Actual $script:GitHubNotificationsLastExitCode -Context "Missing gh did not fail cleanly"
    Assert-Contains -Expected "GitHub CLI (gh) is not installed." -Actual $missingOutput -Context "Missing gh explanation changed"
    Assert-Contains -Expected "Normal git authentication is not sufficient" -Actual $missingOutput -Context "Git authentication distinction is missing"
    Assert-NotContains -Unexpected "gh auth login" -Actual $missingOutput -Context "Missing gh was treated as an authentication-only problem"

    $script:MockGhAvailable = $true
    $script:MockGhScenario = "unauthenticated"
    $unauthenticatedOutput = (& { Invoke-GitHubNotificationsAudit } | Out-String)
    Assert-Equal -Expected 1 -Actual $script:GitHubNotificationsLastExitCode -Context "Unauthenticated gh did not fail cleanly"
    Assert-Contains -Expected "gh auth login" -Actual $unauthenticatedOutput -Context "Authentication guidance is missing"

    $script:MockGhScenario = "audit"
    $auditOutput = (& { Invoke-GitHubNotificationsAudit } | Out-String)
    Assert-Equal -Expected 1 -Actual $script:GitHubNotificationsLastExitCode -Context "Per-repository API errors did not mark the audit incomplete"
    Assert-Contains -Expected "Account: audit-user" -Actual $auditOutput -Context "Authenticated account is missing"
    Assert-Contains -Expected "Repositories checked: 4" -Actual $auditOutput -Context "Active repository count changed"
    Assert-Contains -Expected "Subscribed:           1" -Actual $auditOutput -Context "Subscribed state changed"
    Assert-Contains -Expected "Not subscribed:       1" -Actual $auditOutput -Context "HTTP 404 classification changed"
    Assert-Contains -Expected "Ignored:              1" -Actual $auditOutput -Context "Ignored state changed"
    Assert-Contains -Expected "Private (included):   1" -Actual $auditOutput -Context "Private repository inclusion changed"
    Assert-Contains -Expected "Archived/skipped:     1" -Actual $auditOutput -Context "Archived skip count changed"
    Assert-Contains -Expected "Errors:               1" -Actual $auditOutput -Context "API error count changed"
    Assert-Contains -Expected "exact Custom event categories cannot be verified via the GitHub API." -Actual $auditOutput -Context "Custom-category limitation is missing"
    Assert-Contains -Expected "SUBSCRIBED" -Actual $auditOutput -Context "Subscribed repository heading is missing"
    Assert-Contains -Expected "https://github.com/audit-user/subscribed" -Actual $auditOutput -Context "Subscribed repository URL is missing"
    Assert-Contains -Expected "https://github.com/audit-user/not-subscribed" -Actual $auditOutput -Context "Not-subscribed URL is missing"
    Assert-Contains -Expected "https://github.com/audit-user/ignored" -Actual $auditOutput -Context "Ignored URL is missing"
    Assert-Contains -Expected "https://github.com/audit-user/api-error" -Actual $auditOutput -Context "API-error URL is missing"
    Assert-NotContains -Unexpected "https://github.com/audit-user/archived" -Actual $auditOutput -Context "Archived repository was not skipped"
    Assert-Contains -Expected "[x] Issues" -Actual $auditOutput -Context "Recommended Issues configuration is missing"
    Assert-Contains -Expected "[x] Pull requests" -Actual $auditOutput -Context "Recommended Pull requests configuration is missing"
    Assert-Contains -Expected "[x] Security alerts" -Actual $auditOutput -Context "Recommended Security alerts configuration is missing"
    Assert-Contains -Expected "Manage watched repositories:" -Actual $auditOutput -Context "Watching management guidance is missing"
    Assert-Contains -Expected "https://github.com/watching" -Actual $auditOutput -Context "Watching management URL is missing"

    $launcherContent = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot "start.ps1"))
    Assert-Contains -Expected '"--github-notifications" { & "$RootDir\main_features\github-notifications\github_notifications.ps1"; exit $LASTEXITCODE }' -Actual $launcherContent -Context "PowerShell quick-command routing is missing"
    Assert-Contains -Expected '"--gn" { & "$RootDir\main_features\github-notifications\github_notifications.ps1"; exit $LASTEXITCODE }' -Actual $launcherContent -Context "PowerShell --gn routing is missing"
    Assert-Contains -Expected '"^(16|cls|--cls)$"' -Actual $launcherContent -Context "PowerShell interactive menu numbering changed unexpectedly"

    $englishKeys = Get-Content (Join-Path $repositoryRoot "locales\en.properties") |
        Where-Object { $_ -match "^[^#].*=" } | ForEach-Object { ($_ -split "=", 2)[0] }
    $germanKeys = Get-Content (Join-Path $repositoryRoot "locales\de.properties") |
        Where-Object { $_ -match "^[^#].*=" } | ForEach-Object { ($_ -split "=", 2)[0] }
    Assert-Equal -Expected ($englishKeys -join "`n") -Actual ($germanKeys -join "`n") -Context "Root locale key sets differ"

    Write-Output "PowerShell GitHub Notification Audit tests passed."
}
finally {
    if ($null -eq $previousLocale) {
        Remove-Item Env:\DEV_TOOLS_LOCALE -ErrorAction SilentlyContinue
    }
    else {
        $env:DEV_TOOLS_LOCALE = $previousLocale
    }
}
