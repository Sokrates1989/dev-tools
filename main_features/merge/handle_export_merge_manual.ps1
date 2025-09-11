# -----------------------------------------------------------------------------
# Script: handle_export_merge_manual.ps1
#
# Description:
# PowerShell version of the manual helper for merge commit message generation.
# Lets the user copy the generated AI prompt into a tool like ChatGPT or DeepSeek.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Resolve-Path "$ScriptDir\..\.." | Select-Object -ExpandProperty Path
$ParentDir = Join-Path $ScriptDir "git_export_merge"
$AiMessageFile = $args[0]
$TargetBranch = $args[1]

# --- Check if message file exists ---
if (-not (Test-Path $AiMessageFile)) {
    Write-Host "[ERROR] Cannot find AI message file:" -ForegroundColor Red
    Write-Host "   $AiMessageFile" -ForegroundColor Yellow
    exit 1
}

# --- OS Detection ---
$os = [System.Environment]::OSVersion.Platform

# --- Platform-specific export handling ---
if ($os -eq "Win32NT") {
    # Windows
    Write-Host ""
    Write-Host "[INFO] Windows environment detected. Preparing export view..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[INFO] Copy the content of the opened file to your preferred AI tool (e.g., ChatGPT, DeepSeek, Gemini)" -ForegroundColor White
    Write-Host "[INFO] Then, include the related Project Task ID (or write: `"no task ID`")" -ForegroundColor White
    Write-Host ""

    # --- Git update check ---
    & "$RootDir\global_functions\check_for_updates.ps1"

    Read-Host "Press Enter to open the file now..."
    try {
        Start-Process $AiMessageFile
    } catch {
        Write-Host "[WARNING] Could not open the file. Please open it manually: $AiMessageFile" -ForegroundColor Yellow
    }

} elseif ($os -eq "Unix") {
    # macOS or Linux
    $uname = uname -s
    if ($uname -eq "Darwin") {
        # macOS
        Write-Host ""
        Write-Host "[INFO] macOS environment detected. Preparing export view..." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[INFO] Copy the content of the opened file to your preferred AI tool (e.g., ChatGPT, DeepSeek, Gemini)" -ForegroundColor White
        Write-Host "[INFO] Then, include the related Project Task ID (or write: `"no task ID`")" -ForegroundColor White
        Write-Host ""

        # --- Git update check ---
        & "$RootDir\global_functions\check_for_updates.ps1"

        Read-Host "Press Enter to open the file now..."
        try {
            & open $AiMessageFile 2>$null
        } catch {
            Write-Host "[WARNING] Could not open the file. Please open it manually: $AiMessageFile" -ForegroundColor Yellow
        }

    } else {
        # Linux
        Write-Host ""
        if ($env:DISPLAY -or $env:WAYLAND_DISPLAY) {
            Write-Host "[INFO] Graphical environment detected. Preparing export view..." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "[INFO] Copy the content of the opened file to your preferred AI tool (e.g., ChatGPT, DeepSeek, Gemini)" -ForegroundColor White
            Write-Host "[INFO] Then, include the related Project Task ID (or write: `"no task ID`")" -ForegroundColor White
            Write-Host ""

            # --- Git update check ---
            & "$RootDir\global_functions\check_for_updates.ps1"

            Read-Host "Press Enter to open the file now..."
            try {
                & xdg-open $AiMessageFile >$null 2>&1
            } catch {
                Write-Host "[WARNING] Could not open the file. Please open it manually: $AiMessageFile" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[INFO] CLI-only Linux detected." -ForegroundColor Yellow
            $snapshotFile = Join-Path $ParentDir "merge_manual_snapshot.txt"

            Write-Host "[INFO] Creating text snapshot: $snapshotFile" -ForegroundColor Cyan
            Copy-Item $AiMessageFile $snapshotFile

            Write-Host ""
            Write-Host "[OK] Snapshot saved to: $snapshotFile" -ForegroundColor Green
            Write-Host ""
            Write-Host "[INFO] To copy this content to clipboard, install one of the following:" -ForegroundColor White
            Write-Host ""
            Write-Host "[INFO] Ubuntu/Debian (X11):" -ForegroundColor Cyan
            Write-Host "    sudo apt install xclip" -ForegroundColor Gray
            Write-Host ""
            Write-Host "[INFO] Wayland (GNOME/KDE):" -ForegroundColor Cyan
            Write-Host "    sudo apt install wl-clipboard" -ForegroundColor Gray
            Write-Host ""
            Write-Host "[INFO] After installing, copy with:" -ForegroundColor Cyan
            Write-Host "    xclip -selection clipboard < `"$snapshotFile`"" -ForegroundColor Gray
            Write-Host "    # or" -ForegroundColor Gray
            Write-Host "    wl-copy < `"$snapshotFile`"" -ForegroundColor Gray
            Write-Host ""
        }
    }
} else {
    Write-Host "[WARNING] Unknown OS. Please open the file manually:" -ForegroundColor Yellow
    Write-Host "   $AiMessageFile" -ForegroundColor White
}

exit 0 