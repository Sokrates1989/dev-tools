# ---------------------------------------------------------------------------
# Script: load_dotenv.ps1
# Description: Loads variables from .env into environment using Set-Item
# Compatible: PowerShell 5.1
# ---------------------------------------------------------------------------

function global:Load-DotEnv {
    $RootDir = Resolve-Path "$PSScriptRoot\.." | Select-Object -ExpandProperty Path
    $envFilePath = Join-Path $RootDir ".env"

    if (-Not (Test-Path $envFilePath)) {
        Write-Host "[WARN] .env file not found at: $envFilePath"
        return
    }

    $lines = Get-Content $envFilePath
    foreach ($line in $lines) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') {
            continue
        }

        if ($line -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"')  # <- Remove surrounding quotes
            Set-Item -Path "Env:$key" -Value $value
        }
    }
}
