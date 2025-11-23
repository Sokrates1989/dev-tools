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

function Get-CurrentVersion {
    <#
    .SYNOPSIS
    Gets current IMAGE_VERSION from .env and .ci.env with source info
    .OUTPUTS
    Returns hashtable with: Version, EnvVersion, CiEnvVersion, Source
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
        
        # Check .env
        $envFile = Join-Path $repoRoot ".env"
        if (Test-Path $envFile) {
            $content = Get-Content $envFile -ErrorAction SilentlyContinue
            $versionLine = $content | Where-Object { $_ -match '^IMAGE_VERSION=' } | Select-Object -First 1
            if ($versionLine) {
                $envVersion = ($versionLine -split '=', 2)[1].Trim().Trim('"')
            }
        }
        
        # Check .ci.env
        $ciEnvFile = Join-Path $repoRoot ".ci.env"
        if (Test-Path $ciEnvFile) {
            $content = Get-Content $ciEnvFile -ErrorAction SilentlyContinue
            $versionLine = $content | Where-Object { $_ -match '^IMAGE_VERSION=' } | Select-Object -First 1
            if ($versionLine) {
                $ciEnvVersion = ($versionLine -split '=', 2)[1].Trim().Trim('"')
            }
        }
        
        # Determine base version and source - use the higher semantic version
        $baseVersion = $null
        $source = $null
        
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
            }
            elseif ($ciEnvMajor -eq $envMajor) {
                if ($ciEnvMinor -gt $envMinor) {
                    $baseVersion = $ciEnvVersion
                    $source = ".ci.env (higher version)"
                }
                elseif ($ciEnvMinor -eq $envMinor) {
                    if ($ciEnvPatch -gt $envPatch) {
                        $baseVersion = $ciEnvVersion
                        $source = ".ci.env (higher version)"
                    }
                    elseif ($ciEnvPatch -eq $envPatch) {
                        # Equal versions - prefer .ci.env as it's what gets committed
                        $baseVersion = $ciEnvVersion
                        $source = ".ci.env"
                    }
                    else {
                        # .env patch is higher
                        $baseVersion = $envVersion
                        $source = ".env (higher version)"
                    }
                }
                else {
                    $baseVersion = $envVersion
                    $source = ".env (higher version)"
                }
            }
            else {
                $baseVersion = $envVersion
                $source = ".env (higher version)"
            }
        }
        elseif ($envVersion) {
            $baseVersion = $envVersion
            $source = ".env"
        }
        elseif ($ciEnvVersion) {
            $baseVersion = $ciEnvVersion
            $source = ".ci.env"
        }
        
        return @{
            Version = $baseVersion
            EnvVersion = $envVersion
            CiEnvVersion = $ciEnvVersion
            Source = $source
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
    Updates IMAGE_VERSION in a file
    .PARAMETER FilePath
    Path to the file to update
    .PARAMETER NewVersion
    New version to set
    #>
    param(
        [string]$FilePath,
        [string]$NewVersion
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "WARNING: File not found: $FilePath (skipped)" -ForegroundColor Yellow
        return $false
    }
    
    try {
        $content = Get-Content $FilePath -ErrorAction Stop
        $updated = $false
        $newContent = @()
        
        foreach ($line in $content) {
            if (-not $updated -and $line -match '^IMAGE_VERSION=') {
                $newContent += "IMAGE_VERSION=$NewVersion"
                $updated = $true
            }
            else {
                $newContent += $line
            }
        }
        
        # Add if not found
        if (-not $updated) {
            $newContent += "IMAGE_VERSION=$NewVersion"
        }
        
        # Write content with proper line endings
        $newContent | Set-Content -Path $FilePath -Encoding UTF8
        Write-Host "[OK] Updated $FilePath -> IMAGE_VERSION=$NewVersion" -ForegroundColor Green
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
    Write-Host "Current IMAGE_VERSION values:" -ForegroundColor Cyan
    
    $envDisplay = if ($VersionInfo.EnvVersion) { $VersionInfo.EnvVersion } else { "<not set>" }
    $ciEnvDisplay = if ($VersionInfo.CiEnvVersion) { $VersionInfo.CiEnvVersion } else { "<not set>" }
    
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
        $repoRoot = $repoRoot -replace '/', '\'
        
        $updatedFiles = @()
        $stagedFiles = @()
        
        Write-Host ""
        Write-Host "Updating version files to $NewVersion..." -ForegroundColor Cyan
        
        # Always update .env to keep in sync (even if gitignored)
        $envFile = Join-Path $repoRoot ".env"
        if (Test-Path $envFile) {
            if (Update-VersionInFile -FilePath $envFile -NewVersion $NewVersion) {
                $updatedFiles += ".env"
                Write-Host "   [OK] Updated .env (local only, not committed)" -ForegroundColor Gray
            }
        }
        
        # Always update .ci.env (this will be committed)
        $ciEnvFile = Join-Path $repoRoot ".ci.env"
        if (Test-Path $ciEnvFile) {
            if (Update-VersionInFile -FilePath $ciEnvFile -NewVersion $NewVersion) {
                $updatedFiles += ".ci.env"
                $stagedFiles += ".ci.env"
            }
        }
        
        # Stage .ci.env for commit (skip .env as it's usually gitignored)
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
                Write-Host "WARNING: Files updated but none staged (check if .ci.env exists)" -ForegroundColor Yellow
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
