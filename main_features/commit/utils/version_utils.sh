#!/bin/bash
# -----------------------------------------------------------------------------
# Script: version_utils.sh
# Description: Utility functions for version management in commit workflow
# Platform: Bash/Zsh compatible
# -----------------------------------------------------------------------------

# Detect if repo has CI/CD configuration
detect_cicd_setup() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    if [[ -z "$repo_root" ]]; then
        echo "false"
        return
    fi
    
    # Check for various CI/CD indicators
    if [[ -f "$repo_root/.ci.env" ]] || \
       [[ -d "$repo_root/.github/workflows" ]] || \
       [[ -f "$repo_root/.gitlab-ci.yml" ]] || \
       [[ -f "$repo_root/azure-pipelines.yml" ]] || \
       [[ -f "$repo_root/bitbucket-pipelines.yml" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Detect image-related variables from a file
detect_image_variables() {
    local file="$1"
    local detected_vars=()
    
    if [[ ! -f "$file" ]]; then
        return
    fi
    
    # Priority order for variable names
    local priority_vars=("IMAGE_VERSION" "IMAGE_TAG" "VERSION" "TAG")
    local found_priority=""
    
    # Check priority variables first
    for var in "${priority_vars[@]}"; do
        local line=$(grep "^$var=" "$file" 2>/dev/null | head -n1)
        if [[ -n "$line" ]]; then
            local value=$(echo "$line" | cut -d'=' -f2- | tr -d ' "')
            if [[ -n "$value" && "$value" =~ ^[vV]?[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                found_priority="$var=$value"
                break
            fi
        fi
    done
    
    if [[ -n "$found_priority" ]]; then
        echo "$found_priority"
        return
    fi
    
    # Fallback: find any *IMAGE* or *VERSION variables with semver values
    while IFS= read -r line; do
        if [[ "$line" =~ ^[A-Z_]*IMAGE[A-Z_]*= ]] || [[ "$line" =~ ^[A-Z_]*VERSION[A-Z_]*= ]]; then
            local var_name=$(echo "$line" | cut -d'=' -f1)
            local value=$(echo "$line" | cut -d'=' -f2- | tr -d ' "')
            if [[ -n "$value" && "$value" =~ ^[vV]?[0-9]+\.[0-9]+\.[0-9]+ ]]; then
                detected_vars+=("$var_name=$value")
            fi
        fi
    done < "$file"
    
    # Return the first detected variable
    if [[ ${#detected_vars[@]} -gt 0 ]]; then
        echo "${detected_vars[0]}"
    fi
}

# Get current image version from .env or .ci.env with flexible variable detection
get_current_version() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    if [[ -z "$repo_root" ]]; then
        echo ""
        return
    fi
    
    local version=""
    local variable_name=""
    
    # Check .env first
    if [[ -f "$repo_root/.env" ]]; then
        local detected=$(detect_image_variables "$repo_root/.env")
        if [[ -n "$detected" ]]; then
            version=$(echo "$detected" | cut -d'=' -f2-)
            variable_name=$(echo "$detected" | cut -d'=' -f1)
        fi
    fi
    
    # Fallback to .ci.env
    if [[ -z "$version" && -f "$repo_root/.ci.env" ]]; then
        local detected=$(detect_image_variables "$repo_root/.ci.env")
        if [[ -n "$detected" ]]; then
            version=$(echo "$detected" | cut -d'=' -f2-)
            variable_name=$(echo "$detected" | cut -d'=' -f1)
        fi
    fi
    
    echo "$version"
}

# Get current image version info from both .env and .ci.env with flexible variable detection
# Sets global variables: VERSION_ENV, VERSION_CIENV, VERSION_BASE, VERSION_SOURCE, VARIABLE_NAME_ENV, VARIABLE_NAME_CIENV, VARIABLE_NAME_BASE
get_current_version_info() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    VERSION_ENV=""
    VERSION_CIENV=""
    VERSION_BASE=""
    VERSION_SOURCE=""
    VARIABLE_NAME_ENV=""
    VARIABLE_NAME_CIENV=""
    VARIABLE_NAME_BASE=""
    
    if [[ -z "$repo_root" ]]; then
        return
    fi
    
    # Check .env
    if [[ -f "$repo_root/.env" ]]; then
        local detected=$(detect_image_variables "$repo_root/.env")
        if [[ -n "$detected" ]]; then
            VERSION_ENV=$(echo "$detected" | cut -d'=' -f2-)
            VARIABLE_NAME_ENV=$(echo "$detected" | cut -d'=' -f1)
        fi
    fi
    
    # Check .ci.env
    if [[ -f "$repo_root/.ci.env" ]]; then
        local detected=$(detect_image_variables "$repo_root/.ci.env")
        if [[ -n "$detected" ]]; then
            VERSION_CIENV=$(echo "$detected" | cut -d'=' -f2-)
            VARIABLE_NAME_CIENV=$(echo "$detected" | cut -d'=' -f1)
        fi
    fi
    
    # Determine base version and source - use the higher semantic version
    if [[ -n "$VERSION_ENV" && -n "$VERSION_CIENV" ]]; then
        # Both exist - compare and use the higher version
        local env_parsed="${VERSION_ENV#[vV]}"
        local cienv_parsed="${VERSION_CIENV#[vV]}"
        
        IFS='.' read -r env_major env_minor env_patch <<< "$env_parsed"
        IFS='.' read -r cienv_major cienv_minor cienv_patch <<< "$cienv_parsed"
        
        # Remove non-numeric characters and default to 0 if empty
        env_major=${env_major//[!0-9]/}
        env_minor=${env_minor//[!0-9]/}
        env_patch=${env_patch//[!0-9]/}
        env_major=${env_major:-0}
        env_minor=${env_minor:-0}
        env_patch=${env_patch:-0}
        
        cienv_major=${cienv_major//[!0-9]/}
        cienv_minor=${cienv_minor//[!0-9]/}
        cienv_patch=${cienv_patch//[!0-9]/}
        cienv_major=${cienv_major:-0}
        cienv_minor=${cienv_minor:-0}
        cienv_patch=${cienv_patch:-0}
        
        # Compare versions
        if [[ $cienv_major -gt $env_major ]]; then
            VERSION_BASE="$VERSION_CIENV"
            VERSION_SOURCE=".ci.env (higher version)"
            VARIABLE_NAME_BASE="$VARIABLE_NAME_CIENV"
        elif [[ $cienv_major -eq $env_major ]]; then
            if [[ $cienv_minor -gt $env_minor ]]; then
                VERSION_BASE="$VERSION_CIENV"
                VERSION_SOURCE=".ci.env (higher version)"
                VARIABLE_NAME_BASE="$VARIABLE_NAME_CIENV"
            elif [[ $cienv_minor -eq $env_minor ]]; then
                if [[ $cienv_patch -gt $env_patch ]]; then
                    VERSION_BASE="$VERSION_CIENV"
                    VERSION_SOURCE=".ci.env (higher version)"
                    VARIABLE_NAME_BASE="$VARIABLE_NAME_CIENV"
                elif [[ $cienv_patch -eq $env_patch ]]; then
                    # Equal versions - prefer .ci.env as it's what gets committed
                    VERSION_BASE="$VERSION_CIENV"
                    VERSION_SOURCE=".ci.env"
                    VARIABLE_NAME_BASE="$VARIABLE_NAME_CIENV"
                else
                    # .env patch is higher
                    VERSION_BASE="$VERSION_ENV"
                    VERSION_SOURCE=".env (higher version)"
                    VARIABLE_NAME_BASE="$VARIABLE_NAME_ENV"
                fi
            else
                VERSION_BASE="$VERSION_ENV"
                VERSION_SOURCE=".env (higher version)"
                VARIABLE_NAME_BASE="$VARIABLE_NAME_ENV"
            fi
        else
            VERSION_BASE="$VERSION_ENV"
            VERSION_SOURCE=".env (higher version)"
            VARIABLE_NAME_BASE="$VARIABLE_NAME_ENV"
        fi
    elif [[ -n "$VERSION_ENV" ]]; then
        VERSION_BASE="$VERSION_ENV"
        VERSION_SOURCE=".env"
        VARIABLE_NAME_BASE="$VARIABLE_NAME_ENV"
    elif [[ -n "$VERSION_CIENV" ]]; then
        VERSION_BASE="$VERSION_CIENV"
        VERSION_SOURCE=".ci.env"
        VARIABLE_NAME_BASE="$VARIABLE_NAME_CIENV"
    fi
}

# Bump semantic version
bump_semver() {
    local version="$1"
    local level="$2"
    
    if [[ -z "$version" ]]; then
        version="0.0.0"
    fi
    
    # Remove v prefix if present
    local prefix=""
    if [[ "$version" =~ ^[vV] ]]; then
        prefix="${version:0:1}"
        version="${version:1}"
    fi
    
    # Parse version components
    local IFS='.'
    read -r major minor patch <<< "$version"
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}
    
    # Validate numeric components
    if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]]; then
        echo ""
        return
    fi
    
    # Bump based on level
    case "$level" in
        patch) patch=$((patch + 1)) ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        major) major=$((major + 1)); minor=0; patch=0 ;;
        *) echo ""; return ;;
    esac
    
    echo "${prefix}${major}.${minor}.${patch}"
}

# Update image version in a file using flexible variable detection
update_version_in_file() {
    local file="$1"
    local new_version="$2"
    local force_variable="$3"  # Optional: force specific variable name
    local add_if_missing="${4:-false}"  # Optional: whether to add variable if not found (default: false)
    
    if [[ ! -f "$file" ]]; then
        echo "⚠️  File not found: $file (skipped)"
        return 1
    fi
    
    # Determine which variable to update
    local target_variable=""
    if [[ -n "$force_variable" ]]; then
        target_variable="$force_variable"
    else
        # Auto-detect existing variable
        local detected=$(detect_image_variables "$file")
        if [[ -n "$detected" ]]; then
            target_variable=$(echo "$detected" | cut -d'=' -f1)
        else
            # Default fallback
            target_variable="IMAGE_VERSION"
        fi
    fi
    
    local tmp_file
    tmp_file=$(mktemp) || {
        echo "❌ Could not create temporary file"
        return 1
    }
    
    local replaced=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $replaced -eq 0 && $line == $target_variable=* ]]; then
            echo "$target_variable=$new_version" >> "$tmp_file"
            replaced=1
        else
            echo "$line" >> "$tmp_file"
        fi
    done < "$file"
    
    # Add if not found (only if add_if_missing is true)
    if [[ $replaced -eq 0 ]]; then
        if [[ "$add_if_missing" == "true" ]]; then
            echo "$target_variable=$new_version" >> "$tmp_file"
            echo "✅ Added $file -> $target_variable=$new_version" >&2
        else
            rm -f "$tmp_file"
            echo "⚠️  Variable $target_variable not found in $file (skipped - not adding)" >&2
            return 1
        fi
    else
        echo "✅ Updated $file -> $target_variable=$new_version" >&2
    fi
    
    mv "$tmp_file" "$file"
    return 0
}

# Interactive version update prompt
prompt_version_update() {
    local current_version="$1"
    
    echo "" >&2
    echo "📦 Image Version Management" >&2
    echo "============================" >&2
    
    if [[ -n "$current_version" ]]; then
        echo "Current version: $current_version" >&2
    else
        echo "No current version found" >&2
        current_version="0.0.0"
    fi
    
    echo "" >&2
    echo "Update options:" >&2
    echo "[1] Auto-increment PATCH (${current_version} → $(bump_semver "$current_version" "patch"))" >&2
    echo "[2] Auto-increment MINOR (${current_version} → $(bump_semver "$current_version" "minor"))" >&2
    echo "[3] Auto-increment MAJOR (${current_version} → $(bump_semver "$current_version" "major"))" >&2
    echo "[4] Enter version manually" >&2
    echo "[N] No update (skip)" >&2
    echo "" >&2
    
    read -r -p "Choose option: " version_choice
    
    local new_version=""
    case "$version_choice" in
        1)
            new_version=$(bump_semver "$current_version" "patch")
            ;;
        2)
            new_version=$(bump_semver "$current_version" "minor")
            ;;
        3)
            new_version=$(bump_semver "$current_version" "major")
            ;;
        4)
            read -r -p "Enter new version (e.g., 1.2.3 or v1.2.3): " manual_version
            new_version="$manual_version"
            ;;
        [Nn])
            echo "ℹ️  Version update skipped" >&2
            return 1
            ;;
        *)
            echo "Invalid option. Version update skipped." >&2
            return 1
            ;;
    esac
    
    if [[ -z "$new_version" ]]; then
        echo "⚠️  Invalid version. Skipping update." >&2
        return 1
    fi
    
    echo "$new_version"
    return 0
}

# Update version in repository files
update_repo_version() {
    local new_version="$1"
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    if [[ -z "$repo_root" ]]; then
        echo "❌ Not in a git repository"
        return 1
    fi
    
    # Get current version info to determine variable names
    get_current_version_info
    local env_var_name="$VARIABLE_NAME_ENV"
    local ci_env_var_name="$VARIABLE_NAME_CIENV"
    
    local updated_files=()
    local staged_files=()
    
    echo "" >&2
    echo "📝 Updating version files to $new_version..." >&2
    
    # Update .env if it exists (local only, not staged)
    if [[ -f "$repo_root/.env" ]]; then
        # Only update if variable already exists in .env (don't add it)
        local force_var="$env_var_name"
        if update_version_in_file "$repo_root/.env" "$new_version" "$force_var" "false"; then
            updated_files+=(".env")
            echo "   [OK] Updated .env (local only, not committed)" >&2
        fi
    fi
    
    # Update .ci.env if it exists (will be committed)
    if [[ -f "$repo_root/.ci.env" ]]; then
        # Add variable if it doesn't exist in .ci.env
        local force_var="$ci_env_var_name"
        [[ -z "$force_var" ]] && force_var="IMAGE_VERSION"
        if update_version_in_file "$repo_root/.ci.env" "$new_version" "$force_var" "true"; then
            updated_files+=(".ci.env")
            staged_files+=(".ci.env")
        fi
    fi
    
    # Stage .ci.env for commit (skip .env as it's usually gitignored)
    if [[ ${#staged_files[@]} -gt 0 ]]; then
        echo "" >&2
        echo "📝 Staging version files for commit..." >&2
        for file in "${staged_files[@]}"; do
            git add "$repo_root/$file"
            echo "   ✓ Staged: $file" >&2
        done
        # Only this line goes to stdout (for capture)
        echo "${staged_files[*]}"
        return 0
    else
        if [[ ${#updated_files[@]} -gt 0 ]]; then
            echo "" >&2
            echo "⚠️  Files updated but none staged (check if .ci.env exists)" >&2
        else
            echo "" >&2
            echo "⚠️  No version files were updated" >&2
        fi
        return 1
    fi
}

# Prompt for JIRA task ID
prompt_jira_id() {
    echo ""
    echo "🎫 JIRA Task Reference"
    echo "====================="
    echo ""
    read -r -p "Enter JIRA task ID (or press Enter to skip): " jira_id
    
    if [[ -n "$jira_id" ]]; then
        echo "$jira_id"
        return 0
    else
        echo "ℹ️  No JIRA ID provided"
        return 1
    fi
}
