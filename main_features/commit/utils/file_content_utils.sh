#!/bin/bash
# -----------------------------------------------------------------------------
# Script: file_content_utils.sh
# Description: Utility functions for handling file content in commit scripts
#              Handles binary files, large files, and content truncation
# Platform: Bash/Zsh compatible
# -----------------------------------------------------------------------------

# Configuration
MAX_FILE_SIZE_BYTES=51200      # 50KB per file
MAX_TOTAL_CONTENT_BYTES=204800 # 200KB total content
MAX_DIFF_SIZE_BYTES=102400     # 100KB for diff

# Binary file extensions (lowercase)
BINARY_EXTENSIONS="pdf png jpg jpeg gif bmp ico webp svg tiff heic heif mp3 mp4 avi mov wav zip tar gz 7z rar exe dll so dylib bin dat db sqlite woff woff2 ttf otf eot"

# Check if file is binary based on extension
is_binary_extension() {
    local file="$1"
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    for binary_ext in $BINARY_EXTENSIONS; do
        if [[ "$ext" == "$binary_ext" ]]; then
            return 0  # true - is binary
        fi
    done
    return 1  # false - not binary
}

# Check if file is binary using file command
is_binary_content() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Use file command to detect binary content
    local file_type
    file_type=$(file -b --mime-encoding "$file" 2>/dev/null)
    
    if [[ "$file_type" == "binary" ]]; then
        return 0  # true - is binary
    fi
    return 1  # false - not binary
}

# Check if file is binary (uses both extension and content check)
is_binary_file() {
    local file="$1"
    
    # First check extension (fast)
    if is_binary_extension "$file"; then
        return 0
    fi
    
    # Then check content if file exists
    if [[ -f "$file" ]] && is_binary_content "$file"; then
        return 0
    fi
    
    return 1
}

# Get file size in bytes
get_file_size() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    
    # macOS and Linux compatible
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f%z "$file" 2>/dev/null || echo "0"
    else
        stat -c%s "$file" 2>/dev/null || echo "0"
    fi
}

# Get human-readable file size
format_file_size() {
    local bytes="$1"
    
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$((bytes / 1024))KB"
    else
        echo "$((bytes / 1048576))MB"
    fi
}

# Get smart file content for AI prompt
# Returns metadata for binary/large files, truncated content for large text files
get_smart_file_content() {
    local file="$1"
    local max_size="${2:-$MAX_FILE_SIZE_BYTES}"
    local basename
    basename=$(basename "$file")
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "[File deleted or not found: $basename]"
        return
    fi
    
    local file_size
    file_size=$(get_file_size "$file")
    local size_str
    size_str=$(format_file_size "$file_size")
    
    # Handle binary files
    if is_binary_file "$file"; then
        local file_type
        file_type=$(file -b "$file" 2>/dev/null | head -c 100)
        echo "[Binary file: $basename]"
        echo "[Type: $file_type]"
        echo "[Size: $size_str]"
        echo "[Content not included - binary files are excluded from AI analysis]"
        return
    fi
    
    # Handle large text files
    if [[ $file_size -gt $max_size ]]; then
        local truncate_lines=100
        echo "[Large file: $basename - $size_str (truncated to first $truncate_lines lines)]"
        echo "--- START TRUNCATED CONTENT ---"
        head -n "$truncate_lines" "$file" 2>/dev/null
        echo ""
        echo "--- END TRUNCATED CONTENT ---"
        echo "[... remaining content truncated for size ...]"
        return
    fi
    
    # Normal file - return full content
    cat "$file" 2>/dev/null
}

# Get smart diff content (truncate if too large)
get_smart_diff_content() {
    local diff_file="$1"
    local max_size="${2:-$MAX_DIFF_SIZE_BYTES}"
    
    if [[ ! -f "$diff_file" ]]; then
        echo "(no diff available)"
        return
    fi
    
    local diff_size
    diff_size=$(get_file_size "$diff_file")
    
    if [[ $diff_size -gt $max_size ]]; then
        local size_str
        size_str=$(format_file_size "$diff_size")
        echo "[Diff is large: $size_str - showing first 500 lines]"
        echo "--- START TRUNCATED DIFF ---"
        head -n 500 "$diff_file" 2>/dev/null
        echo ""
        echo "--- END TRUNCATED DIFF ---"
        echo "[... remaining diff truncated ...]"
    else
        cat "$diff_file" 2>/dev/null
    fi
}

# Generate file summary for a list of files
generate_files_summary() {
    local files="$1"
    
    echo "Files in this commit:"
    local total_size=0
    local file_count=0
    local binary_count=0
    local large_count=0
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local basename
        basename=$(basename "$file")
        local size=0
        local status="text"
        
        if [[ -f "$file" ]]; then
            size=$(get_file_size "$file")
            total_size=$((total_size + size))
            
            if is_binary_file "$file"; then
                status="binary"
                binary_count=$((binary_count + 1))
            elif [[ $size -gt $MAX_FILE_SIZE_BYTES ]]; then
                status="large"
                large_count=$((large_count + 1))
            fi
        else
            status="deleted"
        fi
        
        local size_str
        size_str=$(format_file_size "$size")
        echo "  - $basename ($size_str, $status)"
        file_count=$((file_count + 1))
    done <<< "$files"
    
    echo ""
    echo "Summary: $file_count files, $(format_file_size $total_size) total"
    [[ $binary_count -gt 0 ]] && echo "  - $binary_count binary file(s) (content excluded)"
    [[ $large_count -gt 0 ]] && echo "  - $large_count large file(s) (content truncated)"
}
