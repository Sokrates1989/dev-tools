<#
.SYNOPSIS
    Checks Windows cleanup ordering and exit codes with a fake Docker CLI.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$rootDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$launcher = Join-Path $rootDir 'start.ps1'
$testDir = Join-Path ([System.IO.Path]::GetTempPath()) ('dev-tools-cleanup-' + [guid]::NewGuid())
$previousEnvironment = @{
    PATH = $env:PATH
    DEV_TOOLS_LOCALE = $env:DEV_TOOLS_LOCALE
    DEV_TOOLS_UPDATE_REPLAYED = $env:DEV_TOOLS_UPDATE_REPLAYED
    DOCKER_CLEANUP_TEST_LOG = $env:DOCKER_CLEANUP_TEST_LOG
    DOCKER_CLEANUP_TEST_FAIL = $env:DOCKER_CLEANUP_TEST_FAIL
}

# Records both prompts alongside the mocked CLI calls and returns test answers.
function Read-Host([string]$Prompt) {
    if ($Prompt.EndsWith('several minutes to finish. Continue? [Y/n]', [StringComparison]::Ordinal)) {
        Add-Content -LiteralPath $env:DOCKER_CLEANUP_TEST_LOG -Value 'continue prompt'
        return $confirmationAnswer
    }
    if (-not $Prompt.EndsWith('permanently delete data. [y/N]', [StringComparison]::Ordinal)) {
        throw "Missing data-loss warning in cleanup prompt: $Prompt"
    }
    Add-Content -LiteralPath $env:DOCKER_CLEANUP_TEST_LOG -Value 'volume prompt'
    return $volumeAnswer
}

try {
    $null = New-Item -ItemType Directory -Path $testDir
    $mockDocker = Join-Path $testDir 'docker.cmd'
    Set-Content -LiteralPath $mockDocker -Encoding Ascii -Value @'
@echo off
>> "%DOCKER_CLEANUP_TEST_LOG%" echo %*
if "%~2"=="%DOCKER_CLEANUP_TEST_FAIL%" exit /b 17
exit /b 0
'@
    $env:PATH = "$testDir;$env:PATH"
    $env:DEV_TOOLS_LOCALE = 'en'
    $env:DOCKER_CLEANUP_TEST_LOG = Join-Path $testDir 'commands'
    $env:DOCKER_CLEANUP_TEST_FAIL = ''
    if ((Get-Command docker -CommandType Application | Select-Object -First 1).Source -ne $mockDocker) {
        throw 'Docker test executable is not first on PATH.'
    }

    $confirmationAnswer = 'n'
    $env:DEV_TOOLS_UPDATE_REPLAYED = '1'
    [System.IO.File]::WriteAllText($env:DOCKER_CLEANUP_TEST_LOG, '')
    $output = & $launcher --docker-cleanup
    if ($LASTEXITCODE -ne 0 -or $output -cne 'Docker cleanup canceled.' -or
        (Get-Content -LiteralPath $env:DOCKER_CLEANUP_TEST_LOG -Raw).Trim() -cne 'continue prompt') {
        throw 'Declining the initial confirmation must stop before the volume prompt and Docker calls.'
    }

    foreach ($case in @(
            @{ Answer = ''; Prune = 'system prune -a'; Fail = ''; Status = 0 },
            @{ Answer = 'n'; Prune = 'system prune -a'; Fail = ''; Status = 0 },
            @{ Answer = 'y'; Prune = 'system prune -a --volumes'; Fail = ''; Status = 0 },
            @{ Answer = 'Y'; Prune = 'system prune -a --volumes'; Fail = ''; Status = 0 },
            @{ Answer = ''; Prune = 'system prune -a'; Fail = 'df'; Status = 17 },
            @{ Answer = ''; Prune = 'system prune -a'; Fail = 'prune'; Status = 17 })) {
        $confirmationAnswer = if ($case.Answer -ceq 'Y') { 'Y' } else { '' }
        $volumeAnswer = $case.Answer
        $env:DOCKER_CLEANUP_TEST_FAIL = $case.Fail
        $env:DEV_TOOLS_UPDATE_REPLAYED = '1'
        [System.IO.File]::WriteAllText($env:DOCKER_CLEANUP_TEST_LOG, '')
        & $launcher --docker-cleanup
        if ($LASTEXITCODE -ne $case.Status) {
            throw "Expected cleanup exit code $($case.Status), got $LASTEXITCODE."
        }

        $expected = @('continue prompt', 'volume prompt', 'system df')
        if ($case.Fail -ne 'df') { $expected += $case.Prune }
        if ($case.Status -eq 0) { $expected += 'system df' }
        $actual = Get-Content -LiteralPath $env:DOCKER_CLEANUP_TEST_LOG
        if (($actual -join "`n") -cne ($expected -join "`n")) {
            throw "Unexpected Docker cleanup sequence: $($actual -join ', ')"
        }
    }
}
finally {
    foreach ($entry in $previousEnvironment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
    }
    $resolvedTestDir = Resolve-Path -LiteralPath $testDir -ErrorAction SilentlyContinue
    if ($resolvedTestDir -and $resolvedTestDir.ProviderPath -eq $testDir) {
        Remove-Item -LiteralPath $resolvedTestDir.ProviderPath -Recurse -Force
    }
}

Write-Output 'PowerShell Docker cleanup tests passed.'
