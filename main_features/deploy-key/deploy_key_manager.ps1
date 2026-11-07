<#
.SYNOPSIS
    Runs the shared Deploy Key Manager with the Bash bundled with Git for Windows.

.DESCRIPTION
    Resolves Bash from the active Git installation, forwards the feature's
    arguments and console streams, and returns its exit status.
#>

$rootDirectory = Join-Path $PSScriptRoot '..\..'
. (Join-Path $rootDirectory 'global_functions\update_manager.ps1')
Initialize-DevToolsUpdateMessages -RootDir $rootDirectory

$gitCommand = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
$bashPath = $null
if ($gitCommand) {
    $gitExecPath = & $gitCommand.Source --exec-path
    if ($LASTEXITCODE -eq 0 -and $gitExecPath) {
        $bashPath = Join-Path $gitExecPath '..\..\..\bin\bash.exe'
    }
}

if (-not $bashPath -or -not (Test-Path -LiteralPath $bashPath -PathType Leaf)) {
    [Console]::Error.WriteLine((Get-DevToolsUpdateMessage -Key 'deploy_key.error.git_bash'))
    exit 1
}

& $bashPath (Join-Path $PSScriptRoot 'deploy_key_manager.sh') @args
exit $LASTEXITCODE
