<#
.SYNOPSIS
Edit the dev-tools .env settings/config file.

.DESCRIPTION
Presents a sub-menu offering three ways to edit the .env file:
    1) Inline terminal editor (nano/vim/vi if available, else notepad)
    2) Default GUI editor (Start-Process .env)
    3) Reveal the dev-tools folder in Explorer

If .env does not exist but .env.template does, prompts to copy the template
into place before opening.

.NOTES
Author : Patrick Michiels
Date   : 2026-05-04
Version: 1.0.0
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir   = Resolve-Path "$ScriptDir\..\.." | Select-Object -ExpandProperty Path
$EnvFile   = Join-Path $RootDir ".env"
$EnvTpl    = Join-Path $RootDir ".env.template"

function Ensure-EnvFile {
    <#
    .SYNOPSIS
    Verifies .env exists; offers to copy from .env.template if missing.

    .OUTPUTS
    [bool] $true if the file is ready to edit, $false otherwise.
    #>
    if (Test-Path $EnvFile) { return $true }

    Write-Host "[WARN] No .env file found at: $EnvFile"
    if (Test-Path $EnvTpl) {
        $reply = Read-Host "Copy .env.template -> .env now? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($reply)) { $reply = "Y" }
        if ($reply -match '^[Yy]') {
            Copy-Item -Path $EnvTpl -Destination $EnvFile
            Write-Host "[OK] Created $EnvFile from template."
            return $true
        }
        Write-Host "[INFO] Skipped. Cannot edit a non-existent file."
        return $false
    }
    Write-Host "[ERROR] No .env.template found either. Nothing to edit."
    return $false
}

function Open-InlineEditor {
    <#
    .SYNOPSIS
    Opens .env in a terminal editor. Honours $env:VISUAL / $env:EDITOR first,
    then nano, vim, vi, finally notepad.exe as a Windows fallback.
    #>
    $editor = $null
    foreach ($cand in @($env:VISUAL, $env:EDITOR, "nano", "vim", "vi")) {
        if ([string]::IsNullOrWhiteSpace($cand)) { continue }
        $exe = ($cand -split '\s+')[0]
        if (Get-Command $exe -ErrorAction SilentlyContinue) {
            $editor = $cand
            break
        }
    }

    if (-not $editor) {
        Write-Host "[INFO] No terminal editor found in PATH. Falling back to notepad.exe."
        $editor = "notepad"
    }

    Write-Host "[*] Opening $EnvFile in: $editor"
    # Use Start-Process -Wait so the menu blocks until the editor closes,
    # matching the inline-editor expectation.
    $parts = $editor -split '\s+'
    $exe   = $parts[0]
    $extra = @()
    if ($parts.Count -gt 1) { $extra = $parts[1..($parts.Count - 1)] }
    Start-Process -FilePath $exe -ArgumentList ($extra + @($EnvFile)) -NoNewWindow -Wait
    Write-Host "[OK] Editor closed."
}

function Open-GuiEditor {
    <#
    .SYNOPSIS
    Opens .env using the OS default file association.
    #>
    Write-Host "[*] Opening $EnvFile in the default GUI editor..."
    try {
        Start-Process -FilePath $EnvFile
        Write-Host "[OK] Launched. Save the file in your editor to apply changes."
    } catch {
        Write-Host "[ERROR] Could not open file: $($_.Exception.Message)"
        Write-Host "        Try option 1 (inline) or option 3 (folder)."
    }
}

function Open-Folder {
    <#
    .SYNOPSIS
    Reveals the dev-tools root in Windows Explorer.
    #>
    Write-Host "[*] Opening folder: $RootDir"
    Start-Process -FilePath "explorer.exe" -ArgumentList $RootDir
}

# === Sub-menu ===
Write-Host ""
Write-Host "Dev Tools - Settings / Config"
Write-Host "============================="
Write-Host "Target file: $EnvFile"
if (Test-Path $EnvFile) {
    Write-Host "Status:      exists"
} else {
    Write-Host "Status:      missing"
}
Write-Host ""
Write-Host "How would you like to edit the settings?"
Write-Host "1) Inline terminal editor (nano / vim / `$env:EDITOR / notepad)"
Write-Host "2) Open .env in default GUI editor"
Write-Host "3) Reveal folder in Explorer"
Write-Host "q) Cancel"
Write-Host ""

$choice = Read-Host "Enter your choice [1-3, q]"
$choiceLower = $choice.ToLower()

switch -Regex ($choiceLower) {
    '^(1|inline|nano|vim|vi|editor)$' {
        if (Ensure-EnvFile) { Open-InlineEditor }
        break
    }
    '^(2|gui|open|edit)$' {
        if (Ensure-EnvFile) { Open-GuiEditor }
        break
    }
    '^(3|folder|reveal|explorer|finder)$' {
        Open-Folder
        break
    }
    '^(q|quit|exit|cancel|)$' {
        Write-Host "Cancelled."
        break
    }
    default {
        Write-Host "Invalid choice: $choice"
    }
}
