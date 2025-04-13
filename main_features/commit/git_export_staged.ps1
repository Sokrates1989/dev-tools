# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Git update check
$RootDir = Resolve-Path "$PSScriptRoot\..\.." | Select-Object -ExpandProperty Path
& "$RootDir\global_functions\check_for_updates.ps1"

# Load .env file.
. "$RootDir\global_functions\load_dotenv.ps1"
Load-DotEnv

$AI_MODE = $env:AI_MODE
Write-Host "AI Mode: -> $AI_MODE"

# Call the appropriate post-export handler
if ($AI_MODE -eq "api") {
    & "$ScriptDir\handle_export_api.ps1"
} else {
    if ($AI_MODE -eq "manual") {
        & "$ScriptDir\handle_export_manual.ps1"
    } else
    {
        & "$ScriptDir\handle_export_manual.ps1"
    }
}
