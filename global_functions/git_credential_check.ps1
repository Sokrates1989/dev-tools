# -----------------------------------------------------------------------------
# Script: git_credential_check.ps1
# Description: Warns when GitHub HTTPS credentials would be repeatedly requested.
# -----------------------------------------------------------------------------

$noticeFlagName = "DEVTOOLS_GIT_CRED_NOTICE"
$noticeFlagItem = Get-Item "env:$noticeFlagName" -ErrorAction SilentlyContinue
if ($noticeFlagItem -and $noticeFlagItem.Value -eq "1") {
    return
}

function Invoke-GitConfigValue {
    param (
        [Parameter(Mandatory = $true)][string]$Key,
        [switch]$Global
    )

    $gitArgs = @()
    if ($Global) {
        $gitArgs += "--global"
    }
    $gitArgs += "--get"
    $gitArgs += $Key

    try {
        $result = git config @gitArgs 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            return $result.Trim()
        }
    }
    catch {
        return $null
    }

    return $null
}

try {
    git rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { return }
}
catch {
    return
}

$remoteUrl = Invoke-GitConfigValue -Key "remote.origin.url"
if (-not $remoteUrl) { return }

$usesSsh = $remoteUrl -match '^(git@|ssh://)'
if ($usesSsh) { return }

$usesHttps = $remoteUrl -like "https://*"
if (-not $usesHttps) { return }

$helper = Invoke-GitConfigValue -Key "credential.helper"
if (-not $helper) {
    $helper = Invoke-GitConfigValue -Key "credential.helper" -Global
}

if ($helper) { return }

Write-Host ""  # spacer
Write-Host "🔐  GitHub credentials will be requested for every git command." -ForegroundColor Yellow
Write-Host "   • Remote 'origin' uses HTTPS: $remoteUrl" -ForegroundColor Yellow
Write-Host "   • No credential helper is configured for this user." -ForegroundColor Yellow
Write-Host ""  # spacer
Write-Host "Recommended fixes:" -ForegroundColor Cyan
Write-Host "  1) Switch to SSH (recommended):" -ForegroundColor White
Write-Host "     ssh-keygen -t ed25519 -C \"your-email@example.com\"" -ForegroundColor DarkGray
Write-Host "     git remote set-url origin git@github.com:<owner>/<repo>.git" -ForegroundColor DarkGray
Write-Host "  2) Cache HTTPS credentials temporarily:" -ForegroundColor White
Write-Host "     git config --global credential.helper 'cache --timeout=3600'" -ForegroundColor DarkGray
Write-Host "  3) Store a Personal Access Token (plaintext):" -ForegroundColor White
Write-Host "     git config --global credential.helper store" -ForegroundColor DarkGray
Write-Host ""  # spacer

Set-Item -Path "env:$noticeFlagName" -Value "1"
