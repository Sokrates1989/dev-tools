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
CHARS_PER_TOKEN=2              # Conservative estimate (accounts for JSON escaping overhead)

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

# Estimate token count for a string (approximately 4 chars per token)
get_estimated_tokens() {
    local content="$1"
    local length=${#content}
    echo $(( (length + CHARS_PER_TOKEN - 1) / CHARS_PER_TOKEN ))
}

# Get MAX_CONTEXT_TOKENS from environment, with fallback default
get_token_budget_from_env() {
    local max_tokens="${MAX_CONTEXT_TOKENS:-115000}"
    echo "$max_tokens"
}

# Build token-aware content - outputs to stdout, omits large files if needed
# Arguments: diff_content, files_list (newline-separated), temp_dir for file contents
# Returns via global variables: TOKEN_AWARE_DIFF, TOKEN_AWARE_FILES_JSON, TOKEN_AWARE_OMITTED
build_token_aware_content() {
    local style_instruction="$1"
    local commit_prompt="$2"
    local files_summary="$3"
    local diff_content="$4"
    local files_list="$5"  # newline-separated list of files
    
    local max_tokens
    max_tokens=$(get_token_budget_from_env)
    
    # Reserve tokens for system prompt and response
    local reserved_tokens=2000
    local available_tokens=$((max_tokens - reserved_tokens))
    
    # Calculate tokens for fixed sections
    local fixed_content="${style_instruction}

${commit_prompt}

${files_summary}"
    local fixed_tokens
    fixed_tokens=$(get_estimated_tokens "$fixed_content")
    
    # Remaining budget for diff and file contents
    local content_budget=$((available_tokens - fixed_tokens))
    
    # Get diff tokens
    local diff_tokens
    diff_tokens=$(get_estimated_tokens "$diff_content")
    
    # Collect file contents with sizes
    declare -a file_names=()
    declare -a file_contents=()
    declare -a file_sizes=()
    local total_file_tokens=0
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local basename
        basename=$(basename "$file")
        local content
        content=$(get_smart_file_content "$file")
        local full_content="--- $basename ---
$content"
        local size=0
        [[ -f "$file" ]] && size=$(get_file_size "$file")
        local tokens
        tokens=$(get_estimated_tokens "$full_content")
        
        file_names+=("$basename")
        file_contents+=("$full_content")
        file_sizes+=("$size")
        total_file_tokens=$((total_file_tokens + tokens))
    done <<< "$files_list"
    
    local total_content_tokens=$((diff_tokens + total_file_tokens))
    
    # If within budget, output as-is
    if [[ $total_content_tokens -le $content_budget ]]; then
        TOKEN_AWARE_DIFF="$diff_content"
        TOKEN_AWARE_FILES=("${file_contents[@]}")
        TOKEN_AWARE_OMITTED=()
        TOKEN_AWARE_TOTAL=$((fixed_tokens + total_content_tokens))
        return 0
    fi
    
    # Over budget - need to omit/truncate
    echo "⚠️  WARNING: Content exceeds token budget ($total_content_tokens tokens > $content_budget available)" >&2
    echo "Intelligently reducing content..." >&2
    
    # Allocate 60% of content budget to diff, 40% to files
    local diff_budget=$((content_budget * 60 / 100))
    local file_budget=$((content_budget - diff_budget))
    
    # Truncate diff if needed
    if [[ $diff_tokens -gt $diff_budget ]]; then
        local max_diff_chars=$((diff_budget * CHARS_PER_TOKEN))
        TOKEN_AWARE_DIFF="${diff_content:0:$max_diff_chars}

[... DIFF TRUNCATED - showing first $max_diff_chars characters to stay within token limit ...]
"
        diff_tokens=$(get_estimated_tokens "$TOKEN_AWARE_DIFF")
        echo "  - Diff truncated to ~$diff_budget tokens" >&2
    else
        TOKEN_AWARE_DIFF="$diff_content"
    fi
    
    # Recalculate file budget with actual diff usage
    file_budget=$((content_budget - diff_tokens))
    
    # Sort files by size and include smallest first until budget exhausted
    # Create index array sorted by size
    local n=${#file_sizes[@]}
    declare -a sorted_indices=()
    for ((i=0; i<n; i++)); do
        sorted_indices+=("$i")
    done
    
    # Bubble sort by size (ascending - smallest first)
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            local idx1=${sorted_indices[j]}
            local idx2=${sorted_indices[j+1]}
            if [[ ${file_sizes[idx1]} -gt ${file_sizes[idx2]} ]]; then
                sorted_indices[j]=$idx2
                sorted_indices[j+1]=$idx1
            fi
        done
    done
    
    TOKEN_AWARE_FILES=()
    TOKEN_AWARE_OMITTED=()
    local current_file_tokens=0
    
    for idx in "${sorted_indices[@]}"; do
        local file_token_count
        file_token_count=$(get_estimated_tokens "${file_contents[idx]}")
        
        if [[ $((current_file_tokens + file_token_count)) -le $file_budget ]]; then
            TOKEN_AWARE_FILES+=("${file_contents[idx]}")
            current_file_tokens=$((current_file_tokens + file_token_count))
        else
            # Create placeholder for omitted file
            local size_str
            size_str=$(format_file_size "${file_sizes[idx]}")
            local placeholder="[FILE OMITTED: ${file_names[idx]} - $size_str - content excluded to stay within token limit]"
            TOKEN_AWARE_FILES+=("--- ${file_names[idx]} ---
$placeholder")
            TOKEN_AWARE_OMITTED+=("${file_names[idx]}")
            echo "  - Omitted: ${file_names[idx]} ($size_str)" >&2
        fi
    done
    
    local omitted_tokens=0
    for omitted in "${TOKEN_AWARE_OMITTED[@]}"; do
        omitted_tokens=$((omitted_tokens + 20))  # Approximate placeholder size
    done
    
    TOKEN_AWARE_TOTAL=$((fixed_tokens + diff_tokens + current_file_tokens + omitted_tokens))
    echo "  - Final estimated tokens: ~$TOKEN_AWARE_TOTAL (budget: $available_tokens)" >&2
    
    return 0
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
