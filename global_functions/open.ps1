# Enable UTF-8 for proper emoji rendering
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

<#
.SYNOPSIS
Opens the given folder (or file) in Windows Explorer — like macOS 'open'.

.EXAMPLE
.\open.ps1 C:\tools\dev-tools
.EXAMPLE
.\open.ps1 .

If no path is provided, it opens the current directory.
#>

param (
    [string]$Path = "."
)

# Resolve full path
$FullPath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue

if (-not $FullPath) {
    Write-Host "❌ Could not resolve path: $Path"
    exit 1
}

Start-Process "explorer.exe" $FullPath
