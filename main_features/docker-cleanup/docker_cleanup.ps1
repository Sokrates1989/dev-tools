<#
.SYNOPSIS
    Reports disk usage and prunes resources in the current Docker context.

.DESCRIPTION
    Confirms the workflow and optional volume cleanup before Docker's own prompt.
    Stops and returns the Docker CLI exit code if a Docker command fails.
#>

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$rootDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $rootDir 'global_functions/update_manager.ps1')
Initialize-DevToolsUpdateMessages -RootDir $rootDir

if ($args.Count -eq 1 -and $args[0] -in @('--help', '--h', '-help', '-h', 'help')) {
    Get-DevToolsUpdateMessage -Key 'docker_cleanup.usage'
    Get-DevToolsUpdateMessage -Key 'docker_cleanup.description'
    exit 0
}
if ($args.Count -gt 0) {
    [Console]::Error.WriteLine((Get-DevToolsUpdateMessage -Key 'docker_cleanup.invalid_option'))
    [Console]::Error.WriteLine((Get-DevToolsUpdateMessage -Key 'docker_cleanup.usage'))
    exit 2
}

$docker = Get-Command -Name docker -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $docker) {
    [Console]::Error.WriteLine((Get-DevToolsUpdateMessage -Key 'docker_cleanup.docker_missing'))
    exit 127
}

# Reads the answer to the specified localized prompt and stops on closed input.
function Read-DockerCleanupAnswer([string]$Key) {
    $answer = Read-Host (Get-DevToolsUpdateMessage -Key $Key)
    if ($null -eq $answer) {
        [Console]::Error.WriteLine((Get-DevToolsUpdateMessage -Key 'docker_cleanup.input_closed'))
        exit 1
    }
    return $answer
}

$confirmation = Read-DockerCleanupAnswer 'docker_cleanup.continue_prompt'
if ($confirmation -ne '' -and $confirmation -ine 'y') {
    Get-DevToolsUpdateMessage -Key 'docker_cleanup.canceled'
    exit 0
}

$pruneArguments = @('system', 'prune', '-a')
if ((Read-DockerCleanupAnswer 'docker_cleanup.volumes_prompt') -ieq 'y') {
    $pruneArguments += '--volumes'
}

& $docker.Source system df
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $docker.Source @pruneArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $docker.Source system df
exit $LASTEXITCODE
