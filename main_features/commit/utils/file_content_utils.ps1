# -----------------------------------------------------------------------------
# Script: file_content_utils.ps1
# Description: Utility functions for handling file content in commit scripts
#              Handles binary files, large files, and content truncation
# Platform: PowerShell (Windows/Cross-platform)
# -----------------------------------------------------------------------------

# Configuration
$script:MAX_FILE_SIZE_BYTES = 51200      # 50KB per file
$script:MAX_TOTAL_CONTENT_BYTES = 204800 # 200KB total content
$script:MAX_DIFF_SIZE_BYTES = 102400     # 100KB for diff

# Binary file extensions
$script:BINARY_EXTENSIONS = @(
    'pdf', 'png', 'jpg', 'jpeg', 'gif', 'bmp', 'ico', 'webp', 'svg', 'tiff', 'heic', 'heif',
    'mp3', 'mp4', 'avi', 'mov', 'wav',
    'zip', 'tar', 'gz', '7z', 'rar',
    'exe', 'dll', 'so', 'dylib', 'bin', 'dat',
    'db', 'sqlite',
    'woff', 'woff2', 'ttf', 'otf', 'eot'
)

function Test-BinaryExtension {
    <#
    .SYNOPSIS
    Check if file has a binary extension
    #>
    param([string]$FilePath)
    
    $ext = [System.IO.Path]::GetExtension($FilePath).TrimStart('.').ToLower()
    return $script:BINARY_EXTENSIONS -contains $ext
}

function Test-BinaryContent {
    <#
    .SYNOPSIS
    Check if file contains binary content by looking for null bytes
    #>
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        return $false
    }
    
    try {
        # Read first 8KB and check for null bytes
        $bytes = [System.IO.File]::ReadAllBytes($FilePath) | Select-Object -First 8192
        foreach ($byte in $bytes) {
            if ($byte -eq 0) {
                return $true
            }
        }
        return $false
    }
    catch {
        return $false
    }
}

function Test-BinaryFile {
    <#
    .SYNOPSIS
    Check if file is binary (extension or content)
    #>
    param([string]$FilePath)
    
    # First check extension (fast)
    if (Test-BinaryExtension -FilePath $FilePath) {
        return $true
    }
    
    # Then check content if file exists
    if ((Test-Path $FilePath) -and (Test-BinaryContent -FilePath $FilePath)) {
        return $true
    }
    
    return $false
}

function Get-FileSize {
    <#
    .SYNOPSIS
    Get file size in bytes
    #>
    param([string]$FilePath)
    
    try {
        if (-not (Test-Path -LiteralPath $FilePath)) {
            return 0
        }
        
        $item = Get-Item -LiteralPath $FilePath -ErrorAction Stop
        return $item.Length
    }
    catch {
        return 0
    }
}

function Format-FileSize {
    <#
    .SYNOPSIS
    Format file size as human-readable string
    #>
    param([long]$Bytes)
    
    if ($Bytes -lt 1024) {
        return "${Bytes}B"
    }
    elseif ($Bytes -lt 1048576) {
        return "$([math]::Floor($Bytes / 1024))KB"
    }
    else {
        return "$([math]::Floor($Bytes / 1048576))MB"
    }
}

function Get-SmartFileContent {
    <#
    .SYNOPSIS
    Get smart file content for AI prompt
    Returns metadata for binary/large files, truncated content for large text files
    #>
    param(
        [string]$FilePath,
        [long]$MaxSize = $script:MAX_FILE_SIZE_BYTES
    )
    
    $basename = Split-Path $FilePath -Leaf
    $output = @()
    
    # Check if file exists
    if (-not (Test-Path $FilePath)) {
        $output += "[File deleted or not found: $basename]"
        return $output -join "`n"
    }
    
    $fileSize = Get-FileSize -FilePath $FilePath
    $sizeStr = Format-FileSize -Bytes $fileSize
    
    # Handle binary files
    if (Test-BinaryFile -FilePath $FilePath) {
        $output += "[Binary file: $basename]"
        $output += "[Size: $sizeStr]"
        $output += "[Content not included - binary files are excluded from AI analysis]"
        return $output -join "`n"
    }
    
    # Handle large text files
    if ($fileSize -gt $MaxSize) {
        $truncateLines = 100
        $output += "[Large file: $basename - $sizeStr (truncated to first $truncateLines lines)]"
        $output += "--- START TRUNCATED CONTENT ---"
        $content = Get-Content $FilePath -TotalCount $truncateLines -ErrorAction SilentlyContinue
        $output += $content
        $output += "--- END TRUNCATED CONTENT ---"
        $output += "[... remaining content truncated for size ...]"
        return $output -join "`n"
    }
    
    # Normal file - return full content
    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        return $content
    }
    catch {
        return "[Error reading file: $basename]"
    }
}

function Get-SmartDiffContent {
    <#
    .SYNOPSIS
    Get smart diff content (truncate if too large)
    #>
    param(
        [string]$DiffFile,
        [long]$MaxSize = $script:MAX_DIFF_SIZE_BYTES
    )
    
    $output = @()
    
    if (-not (Test-Path $DiffFile)) {
        return "(no diff available)"
    }
    
    $diffSize = Get-FileSize -FilePath $DiffFile
    
    if ($diffSize -gt $MaxSize) {
        $sizeStr = Format-FileSize -Bytes $diffSize
        $output += "[Diff is large: $sizeStr - showing first 500 lines]"
        $output += "--- START TRUNCATED DIFF ---"
        $content = Get-Content $DiffFile -TotalCount 500 -ErrorAction SilentlyContinue
        $output += $content
        $output += "--- END TRUNCATED DIFF ---"
        $output += "[... remaining diff truncated ...]"
        return $output -join "`n"
    }
    
    return Get-Content $DiffFile -Raw -ErrorAction SilentlyContinue
}

function Get-FilesSummary {
    <#
    .SYNOPSIS
    Generate file summary for a list of files
    #>
    param([string[]]$Files)
    
    $output = @()
    $output += "Files in this commit:"
    
    $totalSize = 0
    $fileCount = 0
    $binaryCount = 0
    $largeCount = 0
    
    foreach ($file in $Files) {
        if ([string]::IsNullOrWhiteSpace($file)) { continue }
        
        $basename = Split-Path $file -Leaf
        $size = 0
        $status = "text"
        
        if (Test-Path $file) {
            $size = Get-FileSize -FilePath $file
            $totalSize += $size
            
            if (Test-BinaryFile -FilePath $file) {
                $status = "binary"
                $binaryCount++
            }
            elseif ($size -gt $script:MAX_FILE_SIZE_BYTES) {
                $status = "large"
                $largeCount++
            }
        }
        else {
            $status = "deleted"
        }
        
        $sizeStr = Format-FileSize -Bytes $size
        $output += "  - $basename ($sizeStr, $status)"
        $fileCount++
    }
    
    $output += ""
    $totalSizeStr = Format-FileSize -Bytes $totalSize
    $output += "Summary: $fileCount files, $totalSizeStr total"
    
    if ($binaryCount -gt 0) {
        $output += "  - $binaryCount binary file(s) (content excluded)"
    }
    if ($largeCount -gt 0) {
        $output += "  - $largeCount large file(s) (content truncated)"
    }
    
    return $output -join "`n"
}
