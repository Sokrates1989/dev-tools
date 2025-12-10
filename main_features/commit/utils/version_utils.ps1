# -----------------------------------------------------------------------------
# Script: version_utils.ps1
# Description: Utility functions for version management in commit workflow
# Platform: PowerShell (Windows/Cross-platform)
# -----------------------------------------------------------------------------

function Test-CiCdSetup {
    <#
    .SYNOPSIS
    Detects if repository has CI/CD configuration
    #>
    
    try {
        $repoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $repoRoot) {
            return $false
        }
        
        # Normalize path separators for Windows
        $repoRoot = $repoRoot -replace '/', '\'
        
        # Check for various CI/CD indicators
        $cicdFiles = @(
            (Join-Path $repoRoot ".ci.env"),
            (Join-Path (Join-Path $repoRoot ".github") "workflows"),
            (Join-Path $repoRoot ".gitlab-ci.yml"),
            (Join-Path $repoRoot "azure-pipelines.yml"),
            (Join-Path $repoRoot "bitbucket-pipelines.yml")
        )
        
        foreach ($path in $cicdFiles) {
            if (Test-Path $path) {
                return $true
            }
        }
        
        return $false
    }
    catch {
        return $false
    }
}

function Find-ImageVariables {
    <#
    .SYNOPSIS
    Detects image-related variables from a file
    .PARAMETER FilePath
    Path to the file to analyze
    .OUTPUTS
    Returns hashtable with: VariableName, Value
    #>
    param(
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    
    try {
        $content = Get-Content $FilePath -ErrorAction SilentlyContinue
        if (-not $content) {
            return $null
        }
        
        # Priority order for variable names
        $priorityVars = @('IMAGE_VERSION', 'IMAGE_TAG', 'VERSION', 'TAG')
        
        # Check priority variables first
        foreach ($var in $priorityVars) {
            $line = $content | Where-Object { $_ -match "^$var=" } | Select-Object -First 1
            if ($line) {
                $value = ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
                if ($value -and $value -match '^[vV]?\d+\.\d+\.\d+') {
                    return @{
                        VariableName = $var
                        Value = $value
                    }
                }
            }
        }
        
        # Fallback: find any *IMAGE* or *VERSION variables with semver values
        $detectedVars = @()
        foreach ($line in $content) {
            if ($line -match '^[A-Z_]*IMAGE[A-Z_]*=' -or $line -match '^[A-Z_]*VERSION[A-Z_]*=') {
                $parts = $line -split '=', 2
                if ($parts.Length -eq 2) {
                    $varName = $parts[0].Trim()
                    $value = $parts[1].Trim().Trim('"').Trim("'")
                    if ($value -and $value -match '^[vV]?\d+\.\d+\.\d+') {
                        $detectedVars += @{
                            VariableName = $varName
                            Value = $value
                        }
                    }
                }
            }
        }
        
        # Return first detected variable
        if ($detectedVars.Count -gt 0) {
            return $detectedVars[0]
        }
        
        return $null
    }
    catch {
        return $null
    }
}

function Get-CurrentVersion {
    <#
    .SYNOPSIS
    Gets current image version from .env and .ci.env with flexible variable detection
    .OUTPUTS
    Returns hashtable with: Version, EnvVersion, CiEnvVersion, Source, VariableNameEnv, VariableNameCiEnv, VariableNameBase
    #>
    
    try {
        $repoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $repoRoot) {
            return $null
        }
        
        # Normalize path separators for Windows
        $repoRoot = $repoRoot -replace '/', '\'
        
        $envVersion = $null
        $ciEnvVersion = $null
        $envVarName = $null
        $ciEnvVarName = $null
        
        # Check .env
        $envFile = Join-Path $repoRoot ".env"
        if (Test-Path $envFile) {
            $detected = Find-ImageVariables -FilePath $envFile
            if ($detected) {
                $envVersion = $detected.Value
                $envVarName = $detected.VariableName
            }
        }
        
        # Check .ci.env
        $ciEnvFile = Join-Path $repoRoot ".ci.env"
        if (Test-Path $ciEnvFile) {
            $detected = Find-ImageVariables -FilePath $ciEnvFile
            if ($detected) {
                $ciEnvVersion = $detected.Value
                $ciEnvVarName = $detected.VariableName
            }
        }

        # Check root VERSION file (plain semver string, no key)
        $versionFilePath = Join-Path $repoRoot "VERSION"
        $versionFileVersion = $null
        if (Test-Path $versionFilePath -PathType Leaf) {
            $raw = (Get-Content $versionFilePath -ErrorAction SilentlyContinue) -join ''
            if ($raw) {
                $trimmed = $raw.Trim()
                if ($trimmed -and $trimmed -match '^[vV]?\d+\.\d+\.\d+') {
                    $versionFileVersion = $trimmed
                }
            }
        }
        
        # Determine base version and source - use the higher semantic version
        $baseVersion = $null
        $source = $null
        $baseVarName = $null
        
        if ($envVersion -and $ciEnvVersion) {
            # Both exist - compare and use the higher version
            $envParsed = $envVersion -replace '^[vV]', ''
            $ciEnvParsed = $ciEnvVersion -replace '^[vV]', ''
            
            $envParts = $envParsed -split '\.'
            $ciEnvParts = $ciEnvParsed -split '\.'
            
            $envMajor = [int]($envParts[0] -replace '\D', '')
            $envMinor = if ($envParts.Length -gt 1) { [int]($envParts[1] -replace '\D', '') } else { 0 }
            $envPatch = if ($envParts.Length -gt 2) { [int]($envParts[2] -replace '\D', '') } else { 0 }
            
            $ciEnvMajor = [int]($ciEnvParts[0] -replace '\D', '')
            $ciEnvMinor = if ($ciEnvParts.Length -gt 1) { [int]($ciEnvParts[1] -replace '\D', '') } else { 0 }
            $ciEnvPatch = if ($ciEnvParts.Length -gt 2) { [int]($ciEnvParts[2] -replace '\D', '') } else { 0 }
            
            # Compare versions
            if ($ciEnvMajor -gt $envMajor) {
                $baseVersion = $ciEnvVersion
                $source = ".ci.env (higher version)"
                $baseVarName = $ciEnvVarName
            }
            elseif ($ciEnvMajor -eq $envMajor) {
                if ($ciEnvMinor -gt $envMinor) {
                    $baseVersion = $ciEnvVersion
                    $source = ".ci.env (higher version)"
                    $baseVarName = $ciEnvVarName
                }
                elseif ($ciEnvMinor -eq $envMinor) {
                    if ($ciEnvPatch -gt $envPatch) {
                        $baseVersion = $ciEnvVersion
                        $source = ".ci.env (higher version)"
                        $baseVarName = $ciEnvVarName
                    }
                    elseif ($ciEnvPatch -eq $envPatch) {
                        # Equal versions - prefer .ci.env as it's what gets committed
                        $baseVersion = $ciEnvVersion
                        $source = ".ci.env"
                        $baseVarName = $ciEnvVarName
                    }
                    else {
                        # .env patch is higher
                        $baseVersion = $envVersion
                        $source = ".env (higher version)"
                        $baseVarName = $envVarName
                    }
                }
                else {
                    $baseVersion = $envVersion
                    $source = ".env (higher version)"
                    $baseVarName = $envVarName
                }
            }
            else {
                $baseVersion = $envVersion
                $source = ".env (higher version)"
                $baseVarName = $envVarName
            }
        }
        elseif ($envVersion) {
            $baseVersion = $envVersion
            $source = ".env"
            $baseVarName = $envVarName
        }
        elseif ($ciEnvVersion) {
            $baseVersion = $ciEnvVersion
            $source = ".ci.env"
            $baseVarName = $ciEnvVarName
        }
        elseif ($versionFileVersion) {
            $baseVersion = $versionFileVersion
            $source = "VERSION file"
            $baseVarName = "VERSION"
        }
        
        return @{
            Version = $baseVersion
            EnvVersion = $envVersion
            CiEnvVersion = $ciEnvVersion
            Source = $source
            VariableNameEnv = $envVarName
            VariableNameCiEnv = $ciEnvVarName
            VariableNameBase = $baseVarName
        }
    }
    catch {
        return $null
    }
}

function Update-SemVer {
    <#
    .SYNOPSIS
    Bumps semantic version
    .PARAMETER Version
    Current version string
    .PARAMETER Level
    Bump level: patch, minor, or major
    #>
    param(
        [string]$Version,
        [ValidateSet('patch', 'minor', 'major')]
        [string]$Level
    )
    
    if (-not $Version) {
        $Version = "0.0.0"
    }
    
    # Remove v prefix if present
    $prefix = ""
    if ($Version -match '^[vV]') {
        $prefix = $Version.Substring(0, 1)
        $Version = $Version.Substring(1)
    }
    
    # Parse version components
    $parts = $Version -split '\.'
    $major = if ($parts[0]) { [int]$parts[0] } else { 0 }
    $minor = if ($parts[1]) { [int]$parts[1] } else { 0 }
    $patch = if ($parts[2]) { [int]$parts[2] } else { 0 }
    
    # Bump based on level
    switch ($Level) {
        'patch' { $patch++ }
        'minor' { $minor++; $patch = 0 }
        'major' { $major++; $minor = 0; $patch = 0 }
    }
    
    return "${prefix}${major}.${minor}.${patch}"
}

function Update-VersionInFile {
    <#
    .SYNOPSIS
    Updates image version in a file using flexible variable detection
    .PARAMETER FilePath
    Path to the file to update
    .PARAMETER NewVersion
    New version to set
    .PARAMETER ForceVariable
    Optional: force specific variable name
    #>
    param(
        [string]$FilePath,
        [string]$NewVersion,
        [string]$ForceVariable = $null,
        [bool]$AddIfMissing = $true
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "WARNING: File not found: $FilePath (skipped)" -ForegroundColor Yellow
        return $false
    }
    
    try {
        # Determine which variable to update
        $targetVariable = $null
        if ($ForceVariable) {
            $targetVariable = $ForceVariable
        }
        else {
            # Auto-detect existing variable
            $detected = Find-ImageVariables -FilePath $FilePath
            if ($detected) {
                $targetVariable = $detected.VariableName
            }
            else {
                # Default fallback
                $targetVariable = "IMAGE_VERSION"
            }
        }
        
        $content = Get-Content $FilePath -ErrorAction Stop
        $updated = $false
        $newContent = @()
        
        foreach ($line in $content) {
            if (-not $updated -and $line -match "^$targetVariable=") {
                $newContent += "$targetVariable=$NewVersion"
                $updated = $true
            }
            else {
                $newContent += $line
            }
        }
        
        # Add if not found (only when allowed)
        if (-not $updated) {
            if (-not $AddIfMissing) {
                Write-Host "WARNING: Variable $targetVariable not found in $FilePath (skipped - not adding)" -ForegroundColor Yellow
                return $false
            }
            $newContent += "$targetVariable=$NewVersion"
        }
        
        # Write content with proper line endings
        $newContent | Set-Content -Path $FilePath -Encoding UTF8
        Write-Host "[OK] Updated $FilePath -> $targetVariable=$NewVersion" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "ERROR: Error updating file: $_" -ForegroundColor Red
        return $false
    }
}

function Invoke-VersionUpdatePrompt {
    <#
    .SYNOPSIS
    Interactive prompt for version update
    .PARAMETER VersionInfo
    Hashtable with version information from Get-CurrentVersion
    #>
    param(
        $VersionInfo
    )
    
    Write-Host ""
    Write-Host "Image Version Management" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current image version values:" -ForegroundColor Cyan
    
    $envDisplay = if ($VersionInfo.EnvVersion) { "$($VersionInfo.VariableNameEnv)=$($VersionInfo.EnvVersion)" } else { "<not set>" }
    $ciEnvDisplay = if ($VersionInfo.CiEnvVersion) { "$($VersionInfo.VariableNameCiEnv)=$($VersionInfo.CiEnvVersion)" } else { "<not set>" }
    
    Write-Host "  - .env    : $envDisplay" -ForegroundColor Gray
    Write-Host "  - .ci.env : $ciEnvDisplay" -ForegroundColor Gray
    Write-Host ""
    
    $CurrentVersion = $VersionInfo.Version
    if (-not $CurrentVersion) {
        Write-Host "No current version found - defaulting to 0.0.0" -ForegroundColor Yellow
        $CurrentVersion = "0.0.0"
    }
    else {
        Write-Host "Base version (from $($VersionInfo.Source)): $CurrentVersion" -ForegroundColor Green
    }
    
    $patchVersion = Update-SemVer -Version $CurrentVersion -Level 'patch'
    $minorVersion = Update-SemVer -Version $CurrentVersion -Level 'minor'
    $majorVersion = Update-SemVer -Version $CurrentVersion -Level 'major'
    
    Write-Host ""
    Write-Host "Update options:"
    Write-Host "[1] Auto-increment PATCH ($CurrentVersion -> $patchVersion)"
    Write-Host "[2] Auto-increment MINOR ($CurrentVersion -> $minorVersion)"
    Write-Host "[3] Auto-increment MAJOR ($CurrentVersion -> $majorVersion)"
    Write-Host "[4] Enter version manually"
    Write-Host "[N] No update (skip)"
    Write-Host ""
    
    $choice = Read-Host "Choose option"
    
    $newVersion = $null
    switch ($choice) {
        "1" { $newVersion = $patchVersion }
        "2" { $newVersion = $minorVersion }
        "3" { $newVersion = $majorVersion }
        "4" {
            $manualVersion = Read-Host "Enter new version (e.g., 1.2.3 or v1.2.3)"
            $newVersion = $manualVersion
        }
        { $_ -match '^[Nn]$' } {
            Write-Host "Version update skipped" -ForegroundColor Yellow
            return $null
        }
        default {
            Write-Host "Invalid option. Version update skipped." -ForegroundColor Yellow
            return $null
        }
    }
    
    if (-not $newVersion) {
        Write-Host "WARNING: Invalid version. Skipping update." -ForegroundColor Yellow
        return $null
    }
    
    return $newVersion
}

function Update-RepoVersion {
    <#
    .SYNOPSIS
    Updates version in repository files and stages them
    .DESCRIPTION
    Always updates BOTH .env and .ci.env to keep them in sync.
    Only .ci.env will be staged for commit (as .env is gitignored).
    .PARAMETER NewVersion
    New version to set
    #>
    param(
        [string]$NewVersion
    )
    
    try {
        $repoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $repoRoot) {
            Write-Host "ERROR: Not in a git repository" -ForegroundColor Red
            return $null
        }
        
        # Normalize path separators for Windows
        $repoRoot = $repoRoot -replace '/', '\\'
        
        $updatedFiles = @()
        $stagedFiles = @()
        
        Write-Host ""
        Write-Host "Updating version files to $NewVersion..." -ForegroundColor Cyan
        
        # Get current version info to determine variable names
        $versionInfo = Get-CurrentVersion
        
        # Always update .env to keep in sync (even if gitignored)
        $envFile = Join-Path $repoRoot ".env"
        if (Test-Path $envFile) {
            $forceVar = if ($versionInfo.VariableNameEnv) { $versionInfo.VariableNameEnv } else { $null }
            # Only update .env if the variable already exists; do NOT add it when missing
            if (Update-VersionInFile -FilePath $envFile -NewVersion $NewVersion -ForceVariable $forceVar -AddIfMissing:$false) {
                $updatedFiles += ".env"
                Write-Host "   [OK] Updated .env (local only, not committed)" -ForegroundColor Gray
            }
        }
        
        # Always update .ci.env (this will be committed)
        $ciEnvFile = Join-Path $repoRoot ".ci.env"
        if (Test-Path $ciEnvFile) {
            $forceVar = if ($versionInfo.VariableNameCiEnv) { $versionInfo.VariableNameCiEnv } else { $null }
            # For .ci.env we allow creating the variable if it's missing
            if (Update-VersionInFile -FilePath $ciEnvFile -NewVersion $NewVersion -ForceVariable $forceVar -AddIfMissing:$true) {
                $updatedFiles += ".ci.env"
                $stagedFiles += ".ci.env"
            }
        }

        # If a root VERSION file exists, keep it in sync with the selected version
        $versionFile = Join-Path $repoRoot "VERSION"
        if (Test-Path $versionFile -PathType Leaf) {
            if ($NewVersion) {
                # Write plain version string (no key) and stage it
                $NewVersion | Set-Content -Path $versionFile -Encoding UTF8
                $updatedFiles += "VERSION"
                $stagedFiles += "VERSION"
                Write-Host "   [OK] Updated VERSION file" -ForegroundColor Gray
            }
        }
        
        # Stage committed version files (skip .env as it's usually gitignored)
        if ($stagedFiles.Count -gt 0) {
            Write-Host ""
            Write-Host "Staging version files for commit..." -ForegroundColor Cyan
            foreach ($file in $stagedFiles) {
                git add (Join-Path $repoRoot $file)
                Write-Host "   [OK] Staged: $file" -ForegroundColor Green
            }
            return $stagedFiles -join ','
        }
        else {
            if ($updatedFiles.Count -gt 0) {
                Write-Host ""
                Write-Host "WARNING: Files updated but none staged (check if .ci.env exists or VERSION file)" -ForegroundColor Yellow
            }
            else {
                Write-Host ""
                Write-Host "WARNING: No version files were updated" -ForegroundColor Yellow
            }
            return $null
        }
    }
    catch {
        Write-Host "ERROR: Error updating repository version: $_" -ForegroundColor Red
        return $null
    }
}

function Invoke-JiraIdPrompt {
    <#
    .SYNOPSIS
    Prompts user for JIRA task ID
    #>
    
    Write-Host ""
    Write-Host "JIRA Task Reference" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host ""
    
    $jiraId = Read-Host "Enter JIRA task ID (or press Enter to skip)"
    
    if ($jiraId) {
        return $jiraId
    }
    else {
        Write-Host "No JIRA ID provided" -ForegroundColor Yellow
        return $null
    }
}
