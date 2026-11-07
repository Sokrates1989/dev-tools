<#
.SYNOPSIS
    Disposable integration tests for the PowerShell update manager.

.DESCRIPTION
    Builds a local bare remote plus installed and authoring clones, then verifies
    cache, branch-state classification, decline/accept prompting, and safe
    fast-forward behavior without contacting an external network.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..") | Select-Object -ExpandProperty Path
. (Join-Path $repositoryRoot "global_functions\update_manager.ps1")

$launcherContent = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot "start.ps1"))
$guardIndex = $launcherContent.IndexOf('$updateResult = Invoke-DevToolsStartupUpdateCheck', [System.StringComparison]::Ordinal)
$dispatchIndex = $launcherContent.IndexOf('if ($gnuStyleArgument)', [System.StringComparison]::Ordinal)
if ($guardIndex -lt 0 -or $dispatchIndex -lt 0 -or $guardIndex -ge $dispatchIndex) {
    throw "PowerShell launcher must run its update guard before argument dispatch."
}
if (-not $launcherContent.Contains('& "$RootDir\start.ps1" @PSBoundParameters @originalArguments')) {
    throw "PowerShell launcher must replay both bound switches and the original argument array after updating."
}

function Assert-UpdateTestEqual {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Expected,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Actual,
        [Parameter(Mandatory = $true)]
        [string]$Context
    )

    if ($Expected -cne $Actual) {
        throw "$Context. Expected '$Expected', received '$Actual'."
    }
}

Assert-UpdateTestEqual -Expected "github.com/sokrates1989/dev-tools" `
    -Actual (ConvertTo-DevToolsRemoteIdentity -RemoteUrl "https://github.com/Sokrates1989/dev-tools.git") `
    -Context "HTTPS remote normalization"
Assert-UpdateTestEqual -Expected "github.com/sokrates1989/dev-tools" `
    -Actual (ConvertTo-DevToolsRemoteIdentity -RemoteUrl "git@github.com:Sokrates1989/dev-tools.git") `
    -Context "SSH remote normalization"

function Invoke-UpdateTestGit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & git -C $Repository @Arguments 2>&1 | Out-Null
        $gitExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($gitExitCode -ne 0) {
        throw "Git test command failed in ${Repository}: git $($Arguments -join ' ')"
    }
}

$temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryParent "dev-tools-update-tests-$([Guid]::NewGuid().ToString('N'))"
$remoteRepository = Join-Path $testRoot "remote.git"
$authorRepository = Join-Path $testRoot "author"
$installedRepository = Join-Path $testRoot "installed"
$originalLocale = $env:DEV_TOOLS_LOCALE
$originalInterval = $env:DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS

try {
    [void][System.IO.Directory]::CreateDirectory($testRoot)
    Invoke-UpdateTestGit -Repository $testRoot -Arguments @("init", "--bare", "--initial-branch=main", $remoteRepository)
    Invoke-UpdateTestGit -Repository $testRoot -Arguments @("init", "--initial-branch=main", $authorRepository)
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("config", "user.name", "Dev Tools Tests")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("config", "user.email", "dev-tools-tests@example.invalid")

    [void][System.IO.Directory]::CreateDirectory((Join-Path $authorRepository "locales"))
    [System.IO.File]::Copy((Join-Path $repositoryRoot "locales\en.properties"), (Join-Path $authorRepository "locales\en.properties"))
    [System.IO.File]::Copy((Join-Path $repositoryRoot "locales\de.properties"), (Join-Path $authorRepository "locales\de.properties"))
    [System.IO.File]::WriteAllText((Join-Path $authorRepository "release.txt"), "initial")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("remote", "add", "origin", $remoteRepository)
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("add", "-A")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("commit", "-m", "initial")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("push", "-u", "origin", "main")

    Invoke-UpdateTestGit -Repository $testRoot -Arguments @("clone", $remoteRepository, $installedRepository)
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("config", "user.name", "Dev Tools Tests")
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("config", "user.email", "dev-tools-tests@example.invalid")

    $expectedIdentity = ConvertTo-DevToolsRemoteIdentity -RemoteUrl $remoteRepository
    $env:DEV_TOOLS_LOCALE = "en"
    $env:DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS = "0"
    Initialize-DevToolsUpdateMessages -RootDir $installedRepository

    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "equal" -Actual $state.State -Context "Initial state"

    $env:DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS = "300"
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $true -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "cached" -Actual $state.State -Context "Fresh cache state"
    $env:DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS = "0"

    $offlineRemote = "$remoteRepository.offline"
    Move-Item -LiteralPath $remoteRepository -Destination $offlineRemote
    try {
        $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
        Assert-UpdateTestEqual -Expected "unavailable" -Actual $state.State -Context "Offline state"
    }
    finally {
        Move-Item -LiteralPath $offlineRemote -Destination $remoteRepository
    }

    [System.IO.File]::WriteAllText((Join-Path $authorRepository "release.txt"), "remote update")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("add", "release.txt")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("commit", "-m", "remote update")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("push", "origin", "main")

    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "behind" -Actual $state.State -Context "Behind state"

    $result = Invoke-DevToolsStartupUpdateCheck -RootDir $installedRepository -IsInteractive $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "False" -Actual ([string]$result.Updated) -Context "Non-interactive update result"
    Assert-UpdateTestEqual -Expected "False" -Actual ([string]$result.UpdateAvailable) -Context "Non-interactive availability"

    [System.IO.File]::WriteAllText((Join-Path $installedRepository "dirty.tmp"), "dirty")
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "dirty" -Actual $state.State -Context "Dirty state"
    Remove-Item -LiteralPath (Join-Path $installedRepository "dirty.tmp")

    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity "example.invalid/wrong/repository"
    Assert-UpdateTestEqual -Expected "unexpected-origin" -Actual $state.State -Context "Origin identity state"

    $script:UpdateTestPromptAnswer = "n"
    function Read-Host { param([string]$Prompt); return $script:UpdateTestPromptAnswer }
    $result = Invoke-DevToolsStartupUpdateCheck -RootDir $installedRepository -IsInteractive $true -ExpectedRemoteIdentity $expectedIdentity 6>$null
    Assert-UpdateTestEqual -Expected "False" -Actual ([string]$result.Updated) -Context "Declined update result"
    Assert-UpdateTestEqual -Expected "True" -Actual ([string]$result.UpdateAvailable) -Context "Declined availability"
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $true -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "behind" -Actual $state.State -Context "Declined update remains discoverable"

    $script:UpdateTestPromptAnswer = ""
    $result = Invoke-DevToolsStartupUpdateCheck -RootDir $installedRepository -IsInteractive $true -ExpectedRemoteIdentity $expectedIdentity 6>$null
    Assert-UpdateTestEqual -Expected "True" -Actual ([string]$result.Updated) -Context "Accepted update result"
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "equal" -Actual $state.State -Context "Post-update state"
    Remove-Item Function:\Read-Host

    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("branch", "--unset-upstream")
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "missing-upstream" -Actual $state.State -Context "Missing upstream state"
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("branch", "--set-upstream-to", "origin/main")

    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("remote", "add", "other", $remoteRepository)
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("fetch", "other")
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("branch", "--set-upstream-to", "other/main")
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "unexpected-upstream" -Actual $state.State -Context "Unexpected upstream state"
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("branch", "--set-upstream-to", "origin/main")
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("remote", "remove", "other")

    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("checkout", "-b", "feature")
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "unexpected-branch" -Actual $state.State -Context "Unexpected branch state"
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("checkout", "main")

    [System.IO.File]::WriteAllText((Join-Path $installedRepository "local.txt"), "local")
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("add", "local.txt")
    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("commit", "-m", "local update")
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "ahead" -Actual $state.State -Context "Ahead state"

    [System.IO.File]::WriteAllText((Join-Path $authorRepository "release.txt"), "diverging update")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("add", "release.txt")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("commit", "-m", "diverging update")
    Invoke-UpdateTestGit -Repository $authorRepository -Arguments @("push", "origin", "main")
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "diverged" -Actual $state.State -Context "Diverged state"

    Invoke-UpdateTestGit -Repository $installedRepository -Arguments @("checkout", "--detach")
    $state = Get-DevToolsUpdateState -RootDir $installedRepository -UseCache $false -ExpectedRemoteIdentity $expectedIdentity
    Assert-UpdateTestEqual -Expected "detached" -Actual $state.State -Context "Detached state"

    Write-Output "PowerShell update manager tests passed."
}
finally {
    if (Test-Path Function:\Read-Host) {
        Remove-Item Function:\Read-Host
    }

    if ($null -eq $originalLocale) { Remove-Item Env:\DEV_TOOLS_LOCALE -ErrorAction SilentlyContinue } else { $env:DEV_TOOLS_LOCALE = $originalLocale }
    if ($null -eq $originalInterval) { Remove-Item Env:\DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS -ErrorAction SilentlyContinue } else { $env:DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS = $originalInterval }

    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot.StartsWith($temporaryParent, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTestRoot).StartsWith("dev-tools-update-tests-")) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
