<#
.SYNOPSIS
    Reports disk usage and prunes resources in the current Docker context.

.DESCRIPTION
    Prompts for optional volume cleanup, then lets Docker confirm the prune.
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

$pruneArguments = @('system', 'prune', '-a')
$answer = Read-Host (Get-DevToolsUpdateMessage -Key 'docker_cleanup.volumes_prompt')
if ($null -eq $answer) {
    [Console]::Error.WriteLine((Get-DevToolsUpdateMessage -Key 'docker_cleanup.input_closed'))
    exit 1
}
if ($answer -ieq 'y') {
    $pruneArguments += '--volumes'
}

& $docker.Source system df
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $docker.Source @pruneArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $docker.Source system df
exit $LASTEXITCODE
