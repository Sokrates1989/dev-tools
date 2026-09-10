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
Remove-Item Env:\GH_TOKEN -ErrorAction SilentlyContinue
Remove-Item Env:\GITHUB_TOKEN -ErrorAction SilentlyContinue

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
    if ($joined.Contains(" api graphql ")) {
        if (-not $joined.Contains(" --paginate ") -or
            -not $joined.Contains("pageInfo") -or
            -not $joined.Contains('$endCursor')) {
            return [pscustomobject]@{ ExitCode = 70; Output = "" }
        }
        if ($script:MockGhScenario -eq "api-failure") {
            return [pscustomobject]@{ ExitCode = 75; Output = "gh: mock GraphQL access denied (HTTP 403)" }
        }
        $records = [System.Collections.Generic.List[string]]::new()
        $records.Add("audit-user/all-activity`tfalse`tfalse`tSUBSCRIBED`ttrue")
        $records.Add("Sokrates1989/thunderbird-ai`tfalse`ttrue`tUNREPRESENTED`ttrue")
        $records.Add("audit-user/participating`tfalse`tfalse`tUNSUBSCRIBED`ttrue")
        $records.Add("audit-user/ignored`tfalse`tfalse`tIGNORED`ttrue")
        $records.Add("audit-user/api-error`tfalse`tfalse`tBROKEN`ttrue")
        $records.Add("audit-user/archived`ttrue`ttrue`tSUBSCRIBED`ttrue")
        foreach ($index in 1..101) {
            $records.Add("audit-user/bulk-$($index.ToString('000'))`tfalse`tfalse`tSUBSCRIBED`ttrue")
        }
        return [pscustomobject]@{ ExitCode = 0; Output = ($records -join "`n") }
    }
    if ($joined.Contains(" api ") -and $joined.Contains(" user ")) {
        return [pscustomobject]@{ ExitCode = 0; Output = "audit-user" }
    }
    return [pscustomobject]@{ ExitCode = 64; Output = "Unexpected fake gh invocation." }
}

$previousLocale = $env:DEV_TOOLS_LOCALE
try {
    $env:DEV_TOOLS_LOCALE = "en"
    Initialize-GitHubNotificationsMessages

    $env:GH_TOKEN = "hidden-primary-token"
    $env:GITHUB_TOKEN = "hidden-secondary-token"
    Assert-Equal -Expected "GH_TOKEN" -Actual (Get-GitHubNotificationsEnvironmentTokenName) -Context "GH_TOKEN precedence changed"
    Remove-Item Env:\GH_TOKEN
    Remove-Item Env:\GITHUB_TOKEN

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

    $script:MockGhScenario = "api-failure"
    $env:GITHUB_TOKEN = "hidden-mock-token"
    $apiFailureOutput = (& { Invoke-GitHubNotificationsAudit } | Out-String)
    Assert-Equal -Expected 1 -Actual $script:GitHubNotificationsLastExitCode -Context "A failed GraphQL request did not fail the audit"
    Assert-Contains -Expected "Owned repository watch states could not be retrieved" -Actual $apiFailureOutput -Context "GraphQL failure explanation is missing"
    Assert-Contains -Expected "environment variable GITHUB_TOKEN (value hidden)" -Actual $apiFailureOutput -Context "Environment-token source was not detected"
    Assert-Contains -Expected "GitHub CLI request failed with exit code 75." -Actual $apiFailureOutput -Context "GitHub CLI exit code is missing"
    Assert-Contains -Expected "GitHub API HTTP status: 403." -Actual $apiFailureOutput -Context "GitHub API status is missing"
    Assert-NotContains -Unexpected "mock GraphQL access denied" -Actual $apiFailureOutput -Context "Unfiltered GitHub CLI output was exposed"
    Assert-Contains -Expected "GH_TOKEN and GITHUB_TOKEN take precedence" -Actual $apiFailureOutput -Context "Credential precedence explanation is missing"
    Assert-Contains -Expected "Remove-Item Env:\GITHUB_TOKEN" -Actual $apiFailureOutput -Context "PowerShell environment-token mitigation is missing"
    Assert-Contains -Expected "gh auth status --active --hostname github.com" -Actual $apiFailureOutput -Context "Stored-login check is missing"
    Assert-Contains -Expected "Keep GITHUB_TOKEN" -Actual $apiFailureOutput -Context "Environment-token replacement option is missing"
    Assert-NotContains -Unexpected "hidden-mock-token" -Actual $apiFailureOutput -Context "Environment-token value was exposed"
    Remove-Item Env:\GITHUB_TOKEN

    $script:MockGhScenario = "audit"
    $auditOutput = (& { Invoke-GitHubNotificationsAudit } | Out-String)
    Assert-Equal -Expected 1 -Actual $script:GitHubNotificationsLastExitCode -Context "Per-repository API errors did not mark the audit incomplete"
    Assert-Contains -Expected "stored gh credentials (no environment-token override detected)" -Actual $auditOutput -Context "Stored-credential source was not reported"
    Assert-Contains -Expected "Account: audit-user" -Actual $auditOutput -Context "Authenticated account is missing"
    Assert-Contains -Expected "Repositories checked:                106" -Actual $auditOutput -Context "Pagination beyond 100 repositories failed"
    Assert-Contains -Expected "All Activity / broad watch:          102" -Actual $auditOutput -Context "Broad-watch state changed"
    Assert-Contains -Expected "Custom / API-unrepresented:          1" -Actual $auditOutput -Context "Custom control state changed"
    Assert-Contains -Expected "Participating / @mentions only:      1" -Actual $auditOutput -Context "Participating state changed"
    Assert-Contains -Expected "Ignored:                             1" -Actual $auditOutput -Context "Ignored state changed"
    Assert-Contains -Expected "Private (included):                  1" -Actual $auditOutput -Context "Private repository inclusion changed"
    Assert-Contains -Expected "Archived/skipped:                    1" -Actual $auditOutput -Context "Archived skip count changed"
    Assert-Contains -Expected "Errors:                              1" -Actual $auditOutput -Context "API error count changed"
    Assert-Contains -Expected "ALL ACTIVITY / BROAD WATCH" -Actual $auditOutput -Context "Broad-watch heading is missing"
    Assert-Contains -Expected "https://github.com/audit-user/all-activity" -Actual $auditOutput -Context "Broad-watch repository URL is missing"
    Assert-Contains -Expected "CUSTOM / API-UNREPRESENTED" -Actual $auditOutput -Context "Custom heading is missing"
    Assert-Contains -Expected "https://github.com/Sokrates1989/thunderbird-ai" -Actual $auditOutput -Context "Custom control repository is missing"
    Assert-Contains -Expected "PARTICIPATING / @MENTIONS ONLY" -Actual $auditOutput -Context "Participating heading is missing"
    Assert-Contains -Expected "https://github.com/audit-user/participating" -Actual $auditOutput -Context "Participating repository URL is missing"
    Assert-Contains -Expected "https://github.com/audit-user/ignored" -Actual $auditOutput -Context "Ignored URL is missing"
    Assert-Contains -Expected "https://github.com/audit-user/api-error" -Actual $auditOutput -Context "API-error URL is missing"
    Assert-NotContains -Unexpected "https://github.com/audit-user/archived" -Actual $auditOutput -Context "Archived repository was not skipped"
    Assert-NotContains -Unexpected "Not subscribed" -Actual $auditOutput -Context "Custom-capable repositories were labelled not subscribed"
    Assert-NotContains -Unexpected "NOT SUBSCRIBED" -Actual $auditOutput -Context "Legacy not-subscribed heading remains"
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
