<#
.SYNOPSIS
    Provides safe startup update checks and manual Dev Tools updates.

.DESCRIPTION
    Loads localized update messages, classifies the installed checkout against
    its configured upstream, caches successful remote checks, prompts eligible
    interactive sessions, and applies only clean fast-forward updates.

.NOTES
    Automatic updates are restricted to the official repository on main.
#>

$script:DevToolsUpdateMessages = @{}
$script:DevToolsExpectedRemoteIdentity = "github.com/sokrates1989/dev-tools"
$script:DevToolsExpectedBranch = "main"
$script:DevToolsDefaultCheckIntervalSeconds = 300

<#
.SYNOPSIS
    Loads shared Dev Tools update messages for the active locale.

.PARAMETER RootDir
    Dev Tools repository root containing the locales directory.

.OUTPUTS
    System.Void. Populates the script-level update message catalog.
#>
function Initialize-DevToolsUpdateMessages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDir
    )

    $requestedLocale = $env:DEV_TOOLS_LOCALE
    if ([string]::IsNullOrWhiteSpace($requestedLocale)) {
        $requestedLocale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    }

    $language = if ($requestedLocale -match "^de([_-]|$)") { "de" } else { "en" }
    $localePath = Join-Path $RootDir "locales\$language.properties"
    $script:DevToolsUpdateMessages = @{}

    foreach ($line in [System.IO.File]::ReadAllLines($localePath, [System.Text.Encoding]::UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }

        $parts = $line -split "=", 2
        if ($parts.Count -eq 2) {
            $script:DevToolsUpdateMessages[$parts[0]] = $parts[1]
        }
    }
}

<#
.SYNOPSIS
    Returns a localized update message with ordered placeholder replacement.

.PARAMETER Key
    Stable message key from the shared locale catalog.

.PARAMETER Arguments
    Values replacing %s placeholders from left to right.

.OUTPUTS
    System.String. The formatted localized message.
#>
function Get-DevToolsUpdateMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [object[]]$Arguments = @()
    )

    if (-not $script:DevToolsUpdateMessages.ContainsKey($Key)) {
        throw "Missing Dev Tools update message key: $Key"
    }

    $remaining = $script:DevToolsUpdateMessages[$Key]
    $formatted = ""
    foreach ($argument in $Arguments) {
        $placeholderIndex = $remaining.IndexOf("%s", [System.StringComparison]::Ordinal)
        if ($placeholderIndex -lt 0) {
            throw "Dev Tools update message key '$Key' has too few placeholders."
        }

        $formatted += $remaining.Substring(0, $placeholderIndex) + [string]$argument
        $remaining = $remaining.Substring($placeholderIndex + 2)
    }

    return "$formatted$remaining"
}

<#
.SYNOPSIS
    Normalizes a Git remote URL for repository identity comparisons.

.PARAMETER RemoteUrl
    HTTPS, SSH, SCP-style, or local Git remote URL.

.OUTPUTS
    System.String. Lowercase host/path identity without credentials or .git.
#>
function ConvertTo-DevToolsRemoteIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemoteUrl
    )

    $identity = $RemoteUrl.Trim().Replace("\", "/")
    if ($identity -match "^[^@/]+@([^:]+):(.+)$") {
        $identity = "$($Matches[1])/$($Matches[2])"
    }
    else {
        $identity = $identity -replace "^[a-zA-Z][a-zA-Z0-9+.-]*://", ""
        $identity = $identity -replace "^[^@/]+@", ""
    }

    $identity = ($identity -split "[?#]", 2)[0].TrimEnd("/")
    $identity = $identity -replace "\.git$", ""
    return $identity.ToLowerInvariant()
}

<#
.SYNOPSIS
    Runs Git while preserving its output and exit code across PowerShell versions.

.PARAMETER RootDir
    Repository passed to Git with -C.

.PARAMETER Arguments
    Git arguments to execute.

.OUTPUTS
    PSCustomObject containing ExitCode and string Output properties.
#>
function Invoke-DevToolsGitCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDir,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell turns native stderr into error records when the
        # caller uses Stop. Git exit codes remain the authoritative result.
        $ErrorActionPreference = "Continue"
        $commandOutput = @(& git -C $RootDir @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($commandOutput | ForEach-Object { [string]$_ })
    }
}

<#
.SYNOPSIS
    Returns the configured update-check cache interval.

.OUTPUTS
    System.Int32. Non-negative cache interval in seconds.
#>
function Get-DevToolsUpdateCheckInterval {
    $interval = $script:DevToolsDefaultCheckIntervalSeconds
    $configuredInterval = 0
    if ([int]::TryParse($env:DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS, [ref]$configuredInterval) -and
        $configuredInterval -ge 0) {
        $interval = $configuredInterval
    }

    return $interval
}

<#
.SYNOPSIS
    Tests whether a successful check for the current HEAD is still fresh.

.PARAMETER RootDir
    Dev Tools repository root.

.PARAMETER LocalCommit
    Current full HEAD commit identifier.

.OUTPUTS
    System.Boolean. True when the cache is fresh and belongs to LocalCommit.
#>
function Test-DevToolsUpdateCache {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDir,
        [Parameter(Mandatory = $true)]
        [string]$LocalCommit
    )

    $interval = Get-DevToolsUpdateCheckInterval
    if ($interval -eq 0) {
        return $false
    }

    $cachePath = Join-Path $RootDir ".git\dev-tools-update-check"
    if (-not (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
        return $false
    }

    try {
        $cachedCommit = [System.IO.File]::ReadAllText($cachePath).Trim()
        $age = [DateTime]::UtcNow - [System.IO.File]::GetLastWriteTimeUtc($cachePath)
        return $cachedCommit -eq $LocalCommit -and $age.TotalSeconds -lt $interval
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Records a successful remote update check for the current HEAD.

.PARAMETER RootDir
    Dev Tools repository root.

.PARAMETER LocalCommit
    Full HEAD commit identifier associated with the check.

.OUTPUTS
    System.Void. Cache failures are intentionally non-fatal.
#>
function Set-DevToolsUpdateCache {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDir,
        [Parameter(Mandatory = $true)]
        [string]$LocalCommit
    )

    try {
        $cachePath = Join-Path $RootDir ".git\dev-tools-update-check"
        [System.IO.File]::WriteAllText($cachePath, $LocalCommit, [System.Text.Encoding]::UTF8)
    }
    catch {
        # A read-only checkout may still run commands; caching is optional.
    }
}

<#
.SYNOPSIS
    Creates a structured update-state result.

.OUTPUTS
    PSCustomObject containing state, branch, upstream, and commit context.
#>
function New-DevToolsUpdateState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$State,
        [string]$Branch = "",
        [string]$Upstream = "",
        [string]$LocalCommit = "",
        [string]$RemoteCommit = "",
        [string]$Reason = ""
    )

    return [pscustomobject]@{
        State = $State
        Branch = $Branch
        Upstream = $Upstream
        LocalCommit = $LocalCommit
        RemoteCommit = $RemoteCommit
        Reason = $Reason
    }
}

<#
.SYNOPSIS
    Classifies the local Dev Tools checkout against its upstream.

.DESCRIPTION
    Validates cleanliness, branch, upstream, and official origin; optionally
    honors a fresh cache; fetches without merging; and distinguishes equal,
    behind, ahead, diverged, detached, dirty, and unavailable states.

.PARAMETER RootDir
    Dev Tools repository root.

.PARAMETER UseCache
    When true, a fresh successful check for the same HEAD skips network access.

.PARAMETER ExpectedRemoteIdentity
    Normalized repository identity required for update eligibility.

.OUTPUTS
    PSCustomObject. Structured update state and commit context.
#>
function Get-DevToolsUpdateState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDir,
        [bool]$UseCache = $true,
        [string]$ExpectedRemoteIdentity = $script:DevToolsExpectedRemoteIdentity
    )

    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
        return New-DevToolsUpdateState -State "unavailable" -Reason "git-not-found"
    }

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("rev-parse", "--is-inside-work-tree")
    $insideWorkTree = [string]($gitResult.Output | Select-Object -First 1)
    if ($gitResult.ExitCode -ne 0 -or $insideWorkTree.Trim() -ne "true") {
        return New-DevToolsUpdateState -State "unavailable" -Reason "not-work-tree"
    }

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("rev-parse", "HEAD")
    $localCommit = [string]($gitResult.Output | Select-Object -First 1)
    if ($gitResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($localCommit)) {
        return New-DevToolsUpdateState -State "unavailable" -Reason "missing-head"
    }
    $localCommit = $localCommit.Trim()

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("symbolic-ref", "--quiet", "--short", "HEAD")
    $branch = [string]($gitResult.Output | Select-Object -First 1)
    if ($gitResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
        return New-DevToolsUpdateState -State "detached" -LocalCommit $localCommit
    }
    $branch = $branch.Trim()

    if ($branch -ne $script:DevToolsExpectedBranch) {
        return New-DevToolsUpdateState -State "unexpected-branch" -Branch $branch -LocalCommit $localCommit
    }

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("status", "--porcelain", "--untracked-files=normal")
    $workingChanges = @($gitResult.Output)
    if ($gitResult.ExitCode -ne 0) {
        return New-DevToolsUpdateState -State "unavailable" -Branch $branch -LocalCommit $localCommit -Reason "status-failed"
    }
    if ($workingChanges.Count -gt 0) {
        return New-DevToolsUpdateState -State "dirty" -Branch $branch -LocalCommit $localCommit
    }

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}")
    $upstream = [string]($gitResult.Output | Select-Object -First 1)
    if ($gitResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($upstream)) {
        return New-DevToolsUpdateState -State "missing-upstream" -Branch $branch -LocalCommit $localCommit
    }
    $upstream = $upstream.Trim()
    if ($upstream -ne "origin/main") {
        return New-DevToolsUpdateState -State "unexpected-upstream" -Branch $branch -Upstream $upstream -LocalCommit $localCommit
    }

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("remote", "get-url", "origin")
    $originUrl = [string]($gitResult.Output | Select-Object -First 1)
    if ($gitResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($originUrl)) {
        return New-DevToolsUpdateState -State "unexpected-origin" -Branch $branch -Upstream $upstream -LocalCommit $localCommit
    }

    if ((ConvertTo-DevToolsRemoteIdentity -RemoteUrl $originUrl) -ne $ExpectedRemoteIdentity.ToLowerInvariant()) {
        return New-DevToolsUpdateState -State "unexpected-origin" -Branch $branch -Upstream $upstream -LocalCommit $localCommit
    }

    if ($UseCache -and (Test-DevToolsUpdateCache -RootDir $RootDir -LocalCommit $localCommit)) {
        return New-DevToolsUpdateState -State "cached" -Branch $branch -Upstream $upstream -LocalCommit $localCommit
    }

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("fetch", "--quiet", "origin")
    if ($gitResult.ExitCode -ne 0) {
        return New-DevToolsUpdateState -State "unavailable" -Branch $branch -Upstream $upstream -LocalCommit $localCommit -Reason "fetch-failed"
    }

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("rev-parse", $upstream)
    $remoteCommit = [string]($gitResult.Output | Select-Object -First 1)
    if ($gitResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($remoteCommit)) {
        return New-DevToolsUpdateState -State "unavailable" -Branch $branch -Upstream $upstream -LocalCommit $localCommit -Reason "missing-remote-commit"
    }
    $remoteCommit = $remoteCommit.Trim()

    if ($localCommit -eq $remoteCommit) {
        Set-DevToolsUpdateCache -RootDir $RootDir -LocalCommit $localCommit
        return New-DevToolsUpdateState -State "equal" -Branch $branch -Upstream $upstream -LocalCommit $localCommit -RemoteCommit $remoteCommit
    }

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("merge-base", "--is-ancestor", $localCommit, $remoteCommit)
    if ($gitResult.ExitCode -eq 0) {
        return New-DevToolsUpdateState -State "behind" -Branch $branch -Upstream $upstream -LocalCommit $localCommit -RemoteCommit $remoteCommit
    }

    $gitResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("merge-base", "--is-ancestor", $remoteCommit, $localCommit)
    if ($gitResult.ExitCode -eq 0) {
        return New-DevToolsUpdateState -State "ahead" -Branch $branch -Upstream $upstream -LocalCommit $localCommit -RemoteCommit $remoteCommit
    }

    return New-DevToolsUpdateState -State "diverged" -Branch $branch -Upstream $upstream -LocalCommit $localCommit -RemoteCommit $remoteCommit
}

<#
.SYNOPSIS
    Reports an actionable localized notice for an unsafe update state.

.PARAMETER State
    Structured state returned by Get-DevToolsUpdateState.

.OUTPUTS
    System.Void. Remote-unavailable and cached states remain silent.
#>
function Write-DevToolsUpdateStateNotice {
    param(
        [Parameter(Mandatory = $true)]
        [object]$State
    )

    $messageKey = switch ($State.State) {
        "dirty" { "updates.dirty" }
        "ahead" { "updates.ahead" }
        "diverged" { "updates.diverged" }
        "detached" { "updates.detached" }
        "missing-upstream" { "updates.missing_upstream" }
        "unexpected-upstream" { "updates.unexpected_upstream" }
        "unexpected-origin" { "updates.unexpected_origin" }
        "unexpected-branch" { "updates.unexpected_branch" }
        default { $null }
    }

    if ($null -ne $messageKey) {
        Write-Host (Get-DevToolsUpdateMessage -Key $messageKey) -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
    Detects whether the current process can safely show an update prompt.

.OUTPUTS
    System.Boolean. False for redirected streams and common CI environments.
#>
function Test-DevToolsInteractiveSession {
    foreach ($variableName in @("CI", "TF_BUILD", "GITHUB_ACTIONS")) {
        $value = [Environment]::GetEnvironmentVariable($variableName)
        if (-not [string]::IsNullOrWhiteSpace($value) -and $value -ne "false" -and $value -ne "0") {
            return $false
        }
    }

    try {
        return [Environment]::UserInteractive -and
            -not [Console]::IsInputRedirected -and
            -not [Console]::IsOutputRedirected
    }
    catch {
        return [Environment]::UserInteractive
    }
}

<#
.SYNOPSIS
    Prompts whether an available update should be installed now.

.OUTPUTS
    System.Boolean. Enter defaults to true.
#>
function Read-DevToolsUpdateConfirmation {
    while ($true) {
        $answer = Read-Host (Get-DevToolsUpdateMessage -Key "updates.prompt")
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $true
        }

        switch ($answer.Trim().ToLowerInvariant()) {
            { $_ -in @("y", "yes", "j", "ja") } { return $true }
            { $_ -in @("n", "no", "nein") } { return $false }
            default { Write-Host (Get-DevToolsUpdateMessage -Key "updates.invalid") -ForegroundColor Yellow }
        }
    }
}

<#
.SYNOPSIS
    Applies a clean fast-forward update represented by a behind state.

.PARAMETER RootDir
    Dev Tools repository root.

.PARAMETER ExpectedRemoteIdentity
    Normalized repository identity required for update eligibility. The
    optional override supports disposable local integration tests.

.OUTPUTS
    System.Boolean. True only when the checkout reaches the fetched commit.
#>
function Invoke-DevToolsUpdate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDir,
        [string]$ExpectedRemoteIdentity = $script:DevToolsExpectedRemoteIdentity
    )

    # Reclassify immediately before mutation so a stale prompt or cache can
    # never authorize an update after repository state has changed.
    $State = Get-DevToolsUpdateState -RootDir $RootDir -UseCache $false -ExpectedRemoteIdentity $ExpectedRemoteIdentity

    if ($State.State -eq "equal") {
        Write-Host (Get-DevToolsUpdateMessage -Key "updates.current") -ForegroundColor Green
        return $true
    }
    if ($State.State -ne "behind") {
        Write-DevToolsUpdateStateNotice -State $State
        if ($State.State -eq "unavailable") {
            Write-Host (Get-DevToolsUpdateMessage -Key "updates.failed") -ForegroundColor Yellow
        }
        return $false
    }

    $headResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("rev-parse", "HEAD")
    $currentCommit = [string]($headResult.Output | Select-Object -First 1)
    $statusResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("status", "--porcelain", "--untracked-files=normal")
    $workingChanges = @($statusResult.Output)
    if ($headResult.ExitCode -ne 0 -or $statusResult.ExitCode -ne 0 -or
        $currentCommit.Trim() -ne $State.LocalCommit -or $workingChanges.Count -gt 0) {
        Write-Host (Get-DevToolsUpdateMessage -Key "updates.failed") -ForegroundColor Yellow
        return $false
    }

    $oldShortCommit = $State.LocalCommit.Substring(0, [Math]::Min(7, $State.LocalCommit.Length))
    $newShortCommit = $State.RemoteCommit.Substring(0, [Math]::Min(7, $State.RemoteCommit.Length))
    Write-Host (Get-DevToolsUpdateMessage -Key "updates.performing" -Arguments $oldShortCommit, $newShortCommit)

    $mergeResult = Invoke-DevToolsGitCommand -RootDir $RootDir -Arguments @("merge", "--ff-only", $State.RemoteCommit)
    foreach ($line in $mergeResult.Output) {
        Write-Host $line
    }
    if ($mergeResult.ExitCode -ne 0) {
        Write-Host (Get-DevToolsUpdateMessage -Key "updates.failed") -ForegroundColor Yellow
        return $false
    }

    Set-DevToolsUpdateCache -RootDir $RootDir -LocalCommit $State.RemoteCommit
    Write-Host (Get-DevToolsUpdateMessage -Key "updates.complete" -Arguments $oldShortCommit, $newShortCommit) -ForegroundColor Green
    return $true
}

<#
.SYNOPSIS
    Runs the once-per-launch interactive update guard.

.PARAMETER RootDir
    Dev Tools repository root.

.PARAMETER IsInteractive
    Whether prompting is permitted. Defaults to terminal/CI detection.

.PARAMETER ExpectedRemoteIdentity
    Normalized repository identity required for update eligibility. The
    optional override supports disposable local integration tests.

.OUTPUTS
    PSCustomObject with Updated and UpdateAvailable flags for dispatcher replay
    and menu rendering.
#>
function Invoke-DevToolsStartupUpdateCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootDir,
        [bool]$IsInteractive = (Test-DevToolsInteractiveSession),
        [string]$ExpectedRemoteIdentity = $script:DevToolsExpectedRemoteIdentity
    )

    Initialize-DevToolsUpdateMessages -RootDir $RootDir
    if (-not $IsInteractive) {
        return [pscustomobject]@{ Updated = $false; UpdateAvailable = $false }
    }

    $state = Get-DevToolsUpdateState -RootDir $RootDir -UseCache $true -ExpectedRemoteIdentity $ExpectedRemoteIdentity
    if ($state.State -ne "behind") {
        Write-DevToolsUpdateStateNotice -State $state
        return [pscustomobject]@{ Updated = $false; UpdateAvailable = $false }
    }

    $oldShortCommit = $state.LocalCommit.Substring(0, [Math]::Min(7, $state.LocalCommit.Length))
    $newShortCommit = $state.RemoteCommit.Substring(0, [Math]::Min(7, $state.RemoteCommit.Length))
    Write-Host ""
    Write-Host (Get-DevToolsUpdateMessage -Key "updates.available" -Arguments $oldShortCommit, $newShortCommit) -ForegroundColor Cyan

    if (-not (Read-DevToolsUpdateConfirmation)) {
        Write-Host (Get-DevToolsUpdateMessage -Key "updates.declined")
        return [pscustomobject]@{ Updated = $false; UpdateAvailable = $true }
    }

    $updated = Invoke-DevToolsUpdate -RootDir $RootDir -ExpectedRemoteIdentity $ExpectedRemoteIdentity
    return [pscustomobject]@{ Updated = $updated; UpdateAvailable = (-not $updated) }
}
