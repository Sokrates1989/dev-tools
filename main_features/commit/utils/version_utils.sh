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

# Get current IMAGE_VERSION from .env or .ci.env
get_current_version() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    if [[ -z "$repo_root" ]]; then
        echo ""
        return
    fi
    
    local version=""
    
    # Check .env first
    if [[ -f "$repo_root/.env" ]]; then
        version=$(grep '^IMAGE_VERSION=' "$repo_root/.env" 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "')
    fi
    
    # Fallback to .ci.env
    if [[ -z "$version" && -f "$repo_root/.ci.env" ]]; then
        version=$(grep '^IMAGE_VERSION=' "$repo_root/.ci.env" 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "')
    fi
    
    echo "$version"
}

# Get current IMAGE_VERSION info from both .env and .ci.env
# Sets global variables: VERSION_ENV, VERSION_CIENV, VERSION_BASE, VERSION_SOURCE
get_current_version_info() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    VERSION_ENV=""
    VERSION_CIENV=""
    VERSION_BASE=""
    VERSION_SOURCE=""
    
    if [[ -z "$repo_root" ]]; then
        return
    fi
    
    # Check .env
    if [[ -f "$repo_root/.env" ]]; then
        VERSION_ENV=$(grep '^IMAGE_VERSION=' "$repo_root/.env" 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "')
    fi
    
    # Check .ci.env
    if [[ -f "$repo_root/.ci.env" ]]; then
        VERSION_CIENV=$(grep '^IMAGE_VERSION=' "$repo_root/.ci.env" 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "')
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
        elif [[ $cienv_major -eq $env_major ]]; then
            if [[ $cienv_minor -gt $env_minor ]]; then
                VERSION_BASE="$VERSION_CIENV"
                VERSION_SOURCE=".ci.env (higher version)"
            elif [[ $cienv_minor -eq $env_minor ]]; then
                if [[ $cienv_patch -gt $env_patch ]]; then
                    VERSION_BASE="$VERSION_CIENV"
                    VERSION_SOURCE=".ci.env (higher version)"
                elif [[ $cienv_patch -eq $env_patch ]]; then
                    # Equal versions - prefer .ci.env as it's what gets committed
                    VERSION_BASE="$VERSION_CIENV"
                    VERSION_SOURCE=".ci.env"
                else
                    # .env patch is higher
                    VERSION_BASE="$VERSION_ENV"
                    VERSION_SOURCE=".env (higher version)"
                fi
            else
                VERSION_BASE="$VERSION_ENV"
                VERSION_SOURCE=".env (higher version)"
            fi
        else
            VERSION_BASE="$VERSION_ENV"
            VERSION_SOURCE=".env (higher version)"
        fi
    elif [[ -n "$VERSION_ENV" ]]; then
        VERSION_BASE="$VERSION_ENV"
        VERSION_SOURCE=".env"
    elif [[ -n "$VERSION_CIENV" ]]; then
        VERSION_BASE="$VERSION_CIENV"
        VERSION_SOURCE=".ci.env"
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

# Update IMAGE_VERSION in a file
update_version_in_file() {
    local file="$1"
    local new_version="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "⚠️  File not found: $file (skipped)"
        return 1
    fi
    
    local tmp_file
    tmp_file=$(mktemp) || {
        echo "❌ Could not create temporary file"
        return 1
    }
    
    local replaced=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $replaced -eq 0 && $line == IMAGE_VERSION=* ]]; then
            echo "IMAGE_VERSION=$new_version" >> "$tmp_file"
            replaced=1
        else
            echo "$line" >> "$tmp_file"
        fi
    done < "$file"
    
    # Add if not found
    if [[ $replaced -eq 0 ]]; then
        echo "IMAGE_VERSION=$new_version" >> "$tmp_file"
    fi
    
    mv "$tmp_file" "$file"
    echo "✅ Updated $file -> IMAGE_VERSION=$new_version"
    return 0
}

# Interactive version update prompt
prompt_version_update() {
    local current_version="$1"
    
    echo ""
    echo "📦 Image Version Management"
    echo "============================"
    
    if [[ -n "$current_version" ]]; then
        echo "Current version: $current_version"
    else
        echo "No current version found"
        current_version="0.0.0"
    fi
    
    echo ""
    echo "Update options:"
    echo "[1] Auto-increment PATCH (${current_version} → $(bump_semver "$current_version" "patch"))"
    echo "[2] Auto-increment MINOR (${current_version} → $(bump_semver "$current_version" "minor"))"
    echo "[3] Auto-increment MAJOR (${current_version} → $(bump_semver "$current_version" "major"))"
    echo "[4] Enter version manually"
    echo "[N] No update (skip)"
    echo ""
    
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
            echo "ℹ️  Version update skipped"
            return 1
            ;;
        *)
            echo "Invalid option. Version update skipped."
            return 1
            ;;
    esac
    
    if [[ -z "$new_version" ]]; then
        echo "⚠️  Invalid version. Skipping update."
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
    
    local updated_files=()
    
    # Update .env if it exists
    if [[ -f "$repo_root/.env" ]]; then
        if update_version_in_file "$repo_root/.env" "$new_version"; then
            updated_files+=(".env")
        fi
    fi
    
    # Update .ci.env if it exists
    if [[ -f "$repo_root/.ci.env" ]]; then
        if update_version_in_file "$repo_root/.ci.env" "$new_version"; then
            updated_files+=(".ci.env")
        fi
    fi
    
    # Stage updated files
    if [[ ${#updated_files[@]} -gt 0 ]]; then
        echo ""
        echo "📝 Staging version files for commit..."
        for file in "${updated_files[@]}"; do
            git add "$repo_root/$file"
            echo "   ✓ Staged: $file"
        done
        echo "VERSION_FILES_STAGED=${updated_files[*]}"
        return 0
    else
        echo "⚠️  No version files were updated"
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
