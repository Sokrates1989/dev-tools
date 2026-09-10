<#
.SYNOPSIS
    Audits repository notification subscriptions for the authenticated GitHub account.

.DESCRIPTION
    Uses GitHub CLI authentication and documented REST endpoints. The workflow
    is read-only and never infers granular Custom notification categories.
#>

param(
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:GitHubNotificationsDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$script:GitHubNotificationsRoot = Resolve-Path "$script:GitHubNotificationsDirectory\..\.." | Select-Object -ExpandProperty Path
$script:GitHubNotificationsApiVersion = "2026-03-10"
$script:GitHubNotificationsGhCommand = if ($env:GITHUB_NOTIFICATIONS_GH_COMMAND) { $env:GITHUB_NOTIFICATIONS_GH_COMMAND } else { "gh" }
$script:GitHubNotificationsLastExitCode = 0

. "$script:GitHubNotificationsRoot\global_functions\update_manager.ps1"

<#
.SYNOPSIS
    Loads GitHub Notification Audit messages from the shared root catalog.
#>
function Initialize-GitHubNotificationsMessages {
    Initialize-DevToolsUpdateMessages -RootDir $script:GitHubNotificationsRoot
}

<#
.SYNOPSIS
    Adds newly persisted user and machine PATH entries to this process.

.DESCRIPTION
    Windows installers such as winget update the persisted PATH without
    changing an already running PowerShell process. Existing process entries
    remain first so temporary command overrides keep their precedence.
#>
function Update-GitHubNotificationsProcessPath {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        return
    }

    $separator = [System.IO.Path]::PathSeparator
    $pathValues = @(
        $env:Path,
        [Environment]::GetEnvironmentVariable("Path", "User"),
        [Environment]::GetEnvironmentVariable("Path", "Machine")
    )
    $entries = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($pathValue in $pathValues) {
        if ([string]::IsNullOrWhiteSpace($pathValue)) {
            continue
        }
        foreach ($entry in $pathValue.Split($separator)) {
            $trimmedEntry = $entry.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmedEntry) -and $seen.Add($trimmedEntry)) {
                $entries.Add($trimmedEntry)
            }
        }
    }

    $env:Path = $entries -join $separator
}

<#
.SYNOPSIS
    Reports whether the configured GitHub CLI command is available.

.DESCRIPTION
    Retries the default gh lookup after refreshing this process from the
    persisted PATH. Explicit test or user command overrides are never changed.
#>
function Test-GitHubNotificationsGhAvailable {
    if ($null -ne (Get-Command -Name $script:GitHubNotificationsGhCommand -ErrorAction SilentlyContinue)) {
        return $true
    }
    if ($script:GitHubNotificationsGhCommand -ne "gh") {
        return $false
    }

    Update-GitHubNotificationsProcessPath
    return $null -ne (Get-Command -Name $script:GitHubNotificationsGhCommand -ErrorAction SilentlyContinue)
}

<#
.SYNOPSIS
    Invokes GitHub CLI and captures its complete output and exit code.

.PARAMETER Arguments
    Arguments forwarded to the configured GitHub CLI command.
#>
function Invoke-GitHubNotificationsGh {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell represents redirected native stderr as error
        # records. gh writes normal auth status details there even on success.
        $ErrorActionPreference = "Continue"
        $outputItems = @(& $script:GitHubNotificationsGhCommand @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $output = ($outputItems | ForEach-Object { $_.ToString() }) -join "`n"
    return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

<#
.SYNOPSIS
    Prints the Windows GitHub CLI installation command.
#>
function Show-GitHubNotificationsInstallInstructions {
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.install.windows")
    Write-Output "  winget install --id GitHub.cli --source winget"
}

<#
.SYNOPSIS
    Prints focused command help without contacting GitHub.
#>
function Show-GitHubNotificationsHelp {
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.title")
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.title_divider")
    Write-Output ""
    foreach ($key in @(
            "github_notifications.help.usage",
            "github_notifications.help.description",
            "github_notifications.help.read_only",
            "github_notifications.help.custom_limit")) {
        Write-Output (Get-DevToolsUpdateMessage -Key $key)
    }
}

<#
.SYNOPSIS
    Returns the last HTTP status included in GitHub CLI API output.

.PARAMETER Output
    Combined response output produced by gh api --include.
#>
function Get-GitHubNotificationsHttpStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Output
    )

    $matches = [regex]::Matches($Output, "(?m)^HTTP/[0-9.]+\s+([0-9]{3})")
    if ($matches.Count -gt 0) {
        return $matches[$matches.Count - 1].Groups[1].Value
    }

    $fallback = [regex]::Match($Output, "HTTP\s+([0-9]{3})")
    if ($fallback.Success) {
        return $fallback.Groups[1].Value
    }
    return ""
}

<#
.SYNOPSIS
    Classifies one documented repository-subscription response.

.PARAMETER Repository
    Owner/name identity returned by the authenticated repositories endpoint.

.OUTPUTS
    System.String. subscribed, not-subscribed, ignored, or error.
#>
function Get-GitHubNotificationsSubscriptionState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository
    )

    $response = Invoke-GitHubNotificationsGh -Arguments @(
        "api",
        "--include",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: $script:GitHubNotificationsApiVersion",
        "repos/$Repository/subscription",
        "--jq", "[.subscribed, .ignored] | @tsv")
    $status = Get-GitHubNotificationsHttpStatus -Output $response.Output

    if ($status -eq "404") {
        return "not-subscribed"
    }
    if ($response.ExitCode -ne 0 -or $status -ne "200") {
        return "error"
    }

    $tuple = [regex]::Match($response.Output, "(?m)^(true|false)\t(true|false)\r?$")
    if (-not $tuple.Success) {
        return "error"
    }
    if ($tuple.Groups[2].Value -eq "true") {
        return "ignored"
    }
    if ($tuple.Groups[1].Value -eq "true" -and $tuple.Groups[2].Value -eq "false") {
        return "subscribed"
    }
    return "error"
}

<#
.SYNOPSIS
    Prints repositories in one attention category with copyable GitHub URLs.

.PARAMETER HeadingKey
    Localized heading catalog key.

.PARAMETER Repositories
    Owner/name repository identities.
#>
function Show-GitHubNotificationsRepositoryList {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HeadingKey,
        [Parameter(Mandatory = $true)]
        [string[]]$Repositories
    )

    Write-Output ""
    Write-Output (Get-DevToolsUpdateMessage -Key $HeadingKey)
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.list.divider")
    foreach ($repository in $Repositories) {
        Write-Output "- $repository"
        Write-Output "  https://github.com/$repository"
    }
}

<#
.SYNOPSIS
    Runs the complete read-only GitHub notification audit.

.NOTES
    Sets GitHubNotificationsLastExitCode to 1 when a prerequisite or API error
    makes the audit incomplete. Attention findings alone remain successful.
#>
function Invoke-GitHubNotificationsAudit {
    $script:GitHubNotificationsLastExitCode = 0
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.title")
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.title_divider")
    Write-Output ""

    if (-not (Test-GitHubNotificationsGhAvailable)) {
        Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.gh_missing")
        Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.git_auth_insufficient")
        Write-Output ""
        Show-GitHubNotificationsInstallInstructions
        $script:GitHubNotificationsLastExitCode = 1
        return
    }

    $authResult = Invoke-GitHubNotificationsGh -Arguments @("auth", "status", "--active", "--hostname", "github.com")
    if ($authResult.ExitCode -ne 0) {
        Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.not_authenticated")
        Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.authenticate_with")
        Write-Output "  gh auth login"
        $script:GitHubNotificationsLastExitCode = 1
        return
    }

    $accountResult = Invoke-GitHubNotificationsGh -Arguments @(
        "api",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: $script:GitHubNotificationsApiVersion",
        "user",
        "--jq", ".login")
    $account = $accountResult.Output.Trim()
    if ($accountResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($account) -or $account.Contains("`n")) {
        Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.error.account")
        $script:GitHubNotificationsLastExitCode = 1
        return
    }

    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.audit_progress" -Arguments $account)
    $repositoryResult = Invoke-GitHubNotificationsGh -Arguments @(
        "api",
        "--paginate",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: $script:GitHubNotificationsApiVersion",
        "user/repos?affiliation=owner&visibility=all&per_page=100&sort=full_name&direction=asc",
        "--jq", ".[] | [.full_name, (.archived | tostring), (.private | tostring)] | @tsv")
    if ($repositoryResult.ExitCode -ne 0) {
        Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.error.repositories")
        $script:GitHubNotificationsLastExitCode = 1
        return
    }

    $notSubscribed = [System.Collections.Generic.List[string]]::new()
    $ignoredRepositories = [System.Collections.Generic.List[string]]::new()
    $errorRepositories = [System.Collections.Generic.List[string]]::new()
    $checked = 0
    $subscribedCount = 0
    $archivedCount = 0
    $privateCount = 0

    foreach ($record in @($repositoryResult.Output -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($record)) {
            continue
        }
        $parts = $record -split "`t", 3
        if ($parts.Count -ne 3 -or $parts[1] -notin @("true", "false") -or $parts[2] -notin @("true", "false")) {
            Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.error.repositories")
            $script:GitHubNotificationsLastExitCode = 1
            return
        }

        $repository = $parts[0]
        if ($parts[1] -eq "true") {
            $archivedCount++
            continue
        }
        $checked++
        if ($parts[2] -eq "true") {
            $privateCount++
        }

        switch (Get-GitHubNotificationsSubscriptionState -Repository $repository) {
            "subscribed" { $subscribedCount++ }
            "not-subscribed" { $notSubscribed.Add($repository) }
            "ignored" { $ignoredRepositories.Add($repository) }
            default { $errorRepositories.Add($repository) }
        }
    }

    Write-Output ""
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.summary.account" -Arguments $account)
    Write-Output ""
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.summary.checked" -Arguments $checked)
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.summary.subscribed" -Arguments $subscribedCount)
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.summary.not_subscribed" -Arguments $notSubscribed.Count)
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.summary.ignored" -Arguments $ignoredRepositories.Count)
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.summary.private" -Arguments $privateCount)
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.summary.archived" -Arguments $archivedCount)
    Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.summary.errors" -Arguments $errorRepositories.Count)

    if ($subscribedCount -gt 0) {
        Write-Output ""
        Write-Output (Get-DevToolsUpdateMessage -Key "github_notifications.subscribed_note")
    }
    if ($notSubscribed.Count -gt 0) {
        Show-GitHubNotificationsRepositoryList -HeadingKey "github_notifications.heading.not_subscribed" -Repositories $notSubscribed.ToArray()
    }
    if ($ignoredRepositories.Count -gt 0) {
        Show-GitHubNotificationsRepositoryList -HeadingKey "github_notifications.heading.ignored" -Repositories $ignoredRepositories.ToArray()
    }
    if ($errorRepositories.Count -gt 0) {
        Show-GitHubNotificationsRepositoryList -HeadingKey "github_notifications.heading.errors" -Repositories $errorRepositories.ToArray()
        $script:GitHubNotificationsLastExitCode = 1
    }

    Write-Output ""
    foreach ($key in @(
            "github_notifications.recommendation.heading",
            "github_notifications.recommendation.path",
            "github_notifications.recommendation.issues",
            "github_notifications.recommendation.pull_requests",
            "github_notifications.recommendation.security_alerts",
            "github_notifications.recommendation.limit")) {
        Write-Output (Get-DevToolsUpdateMessage -Key $key)
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    Initialize-GitHubNotificationsMessages
    if ($Help) {
        Show-GitHubNotificationsHelp
        return
    }

    Invoke-GitHubNotificationsAudit
    if ($script:GitHubNotificationsLastExitCode -ne 0) {
        exit $script:GitHubNotificationsLastExitCode
    }
    exit 0
}
