#!/bin/bash
# -----------------------------------------------------------------------------
# Script: git_repair.sh
# Description: Detect and repair corrupted Git repositories
# Platform: Bash/Zsh compatible
# -----------------------------------------------------------------------------

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Backup method: "stash" or "files"
BACKUP_METHOD=""
BACKUP_DIR=""
STASH_NAME=""

# Function to check if current directory is a git repository
is_git_repo() {
    git rev-parse --git-dir > /dev/null 2>&1
}

# Function to detect git corruption
# Returns 0 if corruption detected, 1 if healthy
detect_git_corruption() {
    local output
    local exit_code
    
    # Run git fsck to check for corruption
    output=$(git fsck --full 2>&1)
    exit_code=$?
    
    # Check for common corruption patterns
    if echo "$output" | grep -qE "(far too short|invalid object|broken link|missing blob|missing tree|missing commit|dangling|corrupt)"; then
        return 0  # Corruption detected
    fi
    
    # Also check if pack files are readable
    if git rev-parse HEAD >/dev/null 2>&1; then
        # Try to access the tree
        if ! git ls-tree HEAD >/dev/null 2>&1; then
            return 0  # Corruption detected
        fi
    fi
    
    # Check pack files directly
    local pack_dir=".git/objects/pack"
    if [ -d "$pack_dir" ]; then
        for pack in "$pack_dir"/*.pack; do
            if [ -f "$pack" ]; then
                # Check if pack file is suspiciously small (< 1KB usually indicates corruption)
                local size=$(wc -c < "$pack" 2>/dev/null | tr -d ' ')
                if [ -n "$size" ] && [ "$size" -lt 1000 ]; then
                    return 0  # Corruption detected
                fi
            fi
        done
    fi
    
    # Also check submodule pack files
    if [ -d ".git/modules" ]; then
        for submod_pack_dir in .git/modules/*/objects/pack; do
            if [ -d "$submod_pack_dir" ]; then
                for pack in "$submod_pack_dir"/*.pack; do
                    if [ -f "$pack" ]; then
                        local size=$(wc -c < "$pack" 2>/dev/null | tr -d ' ')
                        if [ -n "$size" ] && [ "$size" -lt 1000 ]; then
                            return 0  # Corruption detected
                        fi
                    fi
                done
            fi
        done
    fi
    
    return 1  # No corruption detected
}

# Function to check git operation output for corruption errors
# Usage: echo "$output" | check_output_for_corruption
check_output_for_corruption() {
    grep -qE "(far too short to be a packfile|invalid object|Error building trees|broken link|missing blob|missing tree|fatal: unable to read tree)"
}

# Function to check if there are uncommitted changes
has_uncommitted_changes() {
    # Check for staged, unstaged, or untracked files
    if ! git diff --quiet 2>/dev/null; then
        return 0  # Has unstaged changes
    fi
    if ! git diff --cached --quiet 2>/dev/null; then
        return 0  # Has staged changes
    fi
    if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
        return 0  # Has untracked files
    fi
    return 1  # No changes
}

# Function to show current changes summary
show_changes_summary() {
    echo -e "${CYAN}📋 Current uncommitted changes:${NC}"
    echo ""
    
    # Show staged files
    local staged=$(git diff --cached --name-only 2>/dev/null)
    if [ -n "$staged" ]; then
        echo -e "${GREEN}Staged files:${NC}"
        echo "$staged" | while read -r file; do
            echo "   ✓ $file"
        done
        echo ""
    fi
    
    # Show modified files
    local modified=$(git diff --name-only 2>/dev/null)
    if [ -n "$modified" ]; then
        echo -e "${YELLOW}Modified files:${NC}"
        echo "$modified" | while read -r file; do
            echo "   ● $file"
        done
        echo ""
    fi
    
    # Show untracked files
    local untracked=$(git ls-files --others --exclude-standard 2>/dev/null)
    if [ -n "$untracked" ]; then
        echo -e "${BLUE}Untracked files:${NC}"
        echo "$untracked" | while read -r file; do
            echo "   + $file"
        done
        echo ""
    fi
}

# Function to backup using git stash (preferred method)
backup_with_stash() {
    STASH_NAME="git-repair-backup-$(date +%Y%m%d-%H%M%S)"
    
    echo -e "${BLUE}📦 Creating git stash with name: ${STASH_NAME}${NC}"
    echo ""
    
    # Include untracked files in stash
    if git stash push -u -m "$STASH_NAME" 2>/dev/null; then
        echo -e "${GREEN}✅ Changes stashed successfully!${NC}"
        echo ""
        
        # Show stash info
        echo -e "${CYAN}📋 Stash details:${NC}"
        git stash show -p "stash@{0}" --stat 2>/dev/null || git stash show "stash@{0}" 2>/dev/null
        echo ""
        
        BACKUP_METHOD="stash"
        return 0
    else
        echo -e "${RED}❌ Failed to create stash.${NC}"
        return 1
    fi
}

# Function to backup to files (fallback method)
backup_with_files() {
    BACKUP_DIR="/tmp/git-repair-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    echo -e "${BLUE}📁 Backing up changed files to: ${BACKUP_DIR}${NC}"
    echo ""
    
    local file_count=0
    
    # Backup modified files
    git diff --name-only 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            cp "$file" "$BACKUP_DIR/$file"
            echo "   ✓ $file"
            ((file_count++))
        fi
    done
    
    # Backup staged files
    git diff --cached --name-only 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            cp "$file" "$BACKUP_DIR/$file"
            echo "   ✓ $file (staged)"
            ((file_count++))
        fi
    done
    
    # Backup untracked files
    git ls-files --others --exclude-standard 2>/dev/null | while read -r file; do
        if [ -f "$file" ]; then
            mkdir -p "$BACKUP_DIR/$(dirname "$file")"
            cp "$file" "$BACKUP_DIR/$file"
            echo "   ✓ $file (untracked)"
            ((file_count++))
        fi
    done
    
    echo ""
    echo -e "${GREEN}✅ Files backed up to: $BACKUP_DIR${NC}"
    
    BACKUP_METHOD="files"
    return 0
}

# Function to show verification instructions
show_verification_instructions() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}📋 VERIFY YOUR BACKUP BEFORE CONTINUING${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ "$BACKUP_METHOD" = "stash" ]; then
        echo -e "${GREEN}Your changes were saved using git stash.${NC}"
        echo ""
        echo "To verify your stash (open a NEW terminal and run):"
        echo -e "${CYAN}  git stash list                    ${NC}# See all stashes"
        echo -e "${CYAN}  git stash show -p 'stash@{0}'     ${NC}# View stash contents"
        echo ""
        echo "To restore your changes after repair:"
        echo -e "${CYAN}  git stash pop                     ${NC}# Apply and remove stash"
        echo -e "${CYAN}  git stash apply                   ${NC}# Apply but keep stash"
        echo ""
        echo "Or use dev-tools:"
        echo -e "${CYAN}  dev-tools --stash                 ${NC}# Interactive stash manager"
        echo ""
    else
        echo -e "${GREEN}Your changes were saved to: $BACKUP_DIR${NC}"
        echo ""
        echo "To verify your backup (open a NEW terminal and run):"
        echo -e "${CYAN}  ls -la $BACKUP_DIR${NC}"
        echo -e "${CYAN}  find $BACKUP_DIR -type f${NC}"
        echo ""
        echo "To restore your changes after repair:"
        echo -e "${CYAN}  cp -r $BACKUP_DIR/* .${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function to repair git repository
repair_git_repo() {
    local repo_path="${1:-.}"
    local original_dir="$(pwd)"
    
    cd "$repo_path" || return 1
    
    if ! is_git_repo; then
        echo -e "${RED}❌ Not a git repository: $repo_path${NC}"
        cd "$original_dir"
        return 1
    fi
    
    echo -e "${BLUE}🔧 Git Repository Repair Tool${NC}"
    echo "=============================="
    echo ""
    echo -e "${YELLOW}Repository: $(pwd)${NC}"
    echo ""
    
    # Step 1: Check for uncommitted changes and backup
    echo -e "${BLUE}📋 Step 1: Checking for uncommitted changes...${NC}"
    echo ""
    
    if has_uncommitted_changes; then
        echo -e "${YELLOW}⚠️  You have uncommitted changes that need to be backed up first.${NC}"
        echo ""
        
        # Show what will be backed up
        show_changes_summary
        
        # Ask user for backup method (default: file backup, stash as advanced option)
        echo -e "${CYAN}How would you like to backup your changes?${NC}"
        echo ""
        echo "  1) File Backup (recommended) - Copies files to /tmp directory"
        echo "     ✓ Works even if git is severely corrupted"
        echo "     ✓ Independent of git internals (robust when packs are broken)"
        echo ""
        echo "  2) Git Stash (advanced) - Uses git's native stash feature"
        echo "     ✓ Preserves staged/unstaged state"
        echo "     ✓ Managed by dev-tools --stash"
        echo "     ⚠️  May fail if git cannot read corrupted pack files"
        echo ""
        
        read -r -p "Choose backup method [1/2] (default: 1): " backup_choice
        echo ""
        
        local backup_success=false
        
        if [ "$backup_choice" = "2" ]; then
            # Explicit stash choice, with fallback to file backup
            if backup_with_stash; then
                backup_success=true
            else
                echo -e "${YELLOW}Stash failed, falling back to file backup...${NC}"
                echo ""
                if backup_with_files; then
                    backup_success=true
                fi
            fi
        else
            # Default: robust file backup
            if backup_with_files; then
                backup_success=true
            fi
        fi
        
        if [ "$backup_success" = false ]; then
            echo -e "${RED}❌ Failed to backup changes. Aborting repair.${NC}"
            cd "$original_dir"
            return 1
        fi
        
        # Show verification instructions
        show_verification_instructions
        
        # CRITICAL: Require explicit confirmation before proceeding
        echo -e "${RED}⚠️  IMPORTANT: The next steps will modify your git repository!${NC}"
        echo ""
        echo "Before continuing, please verify your backup is correct."
        echo "You can open a NEW terminal to check using the commands above."
        echo ""
        read -r -p "Have you verified your changes are backed up correctly? Type 'yes' to continue: " verify_confirm
        
        if [ "$verify_confirm" != "yes" ]; then
            echo ""
            echo -e "${YELLOW}Repair cancelled. Your changes are still backed up.${NC}"
            if [ "$BACKUP_METHOD" = "stash" ]; then
                echo "To restore: git stash pop"
            else
                echo "Your backup is in: $BACKUP_DIR"
            fi
            cd "$original_dir"
            return 1
        fi
        echo ""
    else
        echo -e "${GREEN}✅ No uncommitted changes detected. Safe to proceed.${NC}"
        echo ""
        
        # Still ask for confirmation before destructive operations
        read -r -p "Proceed with repository repair? Type 'yes' to continue: " proceed_confirm
        if [ "$proceed_confirm" != "yes" ]; then
            echo "Repair cancelled."
            cd "$original_dir"
            return 1
        fi
        echo ""
    fi
    
    # Step 2: Get remote URL
    echo -e "${BLUE}📋 Step 2: Getting remote URL...${NC}"
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null)
    
    if [ -z "$remote_url" ]; then
        echo -e "${RED}❌ No remote 'origin' found. Cannot auto-repair without a remote.${NC}"
        cd "$original_dir"
        return 1
    fi
    echo "   Remote URL: $remote_url"
    echo ""
    
    # Step 3: Get current branch
    echo -e "${BLUE}📋 Step 3: Getting current branch...${NC}"
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
    
    if [ -z "$current_branch" ]; then
        current_branch="main"
        echo -e "${YELLOW}⚠️  Could not detect current branch, will use: $current_branch${NC}"
    else
        echo "   Current branch: $current_branch"
    fi
    echo ""
    
    # Step 4: Remove corrupted pack files
    echo -e "${BLUE}📋 Step 4: Removing corrupted pack files...${NC}"
    local pack_dir=".git/objects/pack"
    local removed_packs=0
    
    # Helper: check and remove a pack file if it looks corrupted
    remove_corrupted_pack() {
        local pack_path="$1"
        local size="$2"
        local pack_base="${pack_path%.pack}"
        echo "   Removing corrupted pack: $(basename "$pack_path") (${size} bytes)"
        rm -f "$pack_path" "${pack_base}.idx" "${pack_base}.rev" 2>/dev/null
        ((removed_packs++))
    }
    
    if [ -d "$pack_dir" ]; then
        for pack in "$pack_dir"/*.pack; do
            if [ -f "$pack" ]; then
                local size
                size=$(wc -c < "$pack" 2>/dev/null | tr -d ' ')
                local corrupted=false
                
                # Very small packs are almost always corrupted
                if [ -n "$size" ] && [ "$size" -lt 1000 ]; then
                    corrupted=true
                else
                    # Use git verify-pack on the corresponding index to detect broken packs
                    local idx_file="${pack%.pack}.idx"
                    if [ -f "$idx_file" ]; then
                        if ! git verify-pack -v "$idx_file" >/dev/null 2>&1; then
                            corrupted=true
                        fi
                    fi
                fi
                
                if [ "$corrupted" = true ]; then
                    remove_corrupted_pack "$pack" "${size:-unknown}"
                fi
            fi
        done
    fi
    
    # Also fix submodule pack files
    if [ -d ".git/modules" ]; then
        for submod_pack_dir in .git/modules/*/objects/pack; do
            if [ -d "$submod_pack_dir" ]; then
                for pack in "$submod_pack_dir"/*.pack; do
                    if [ -f "$pack" ]; then
                        local size
                        size=$(wc -c < "$pack" 2>/dev/null | tr -d ' ')
                        local corrupted=false
                        
                        if [ -n "$size" ] && [ "$size" -lt 1000 ]; then
                            corrupted=true
                        else
                            local idx_file="${pack%.pack}.idx"
                            if [ -f "$idx_file" ]; then
                                if ! git verify-pack -v "$idx_file" >/dev/null 2>&1; then
                                    corrupted=true
                                fi
                            fi
                        fi
                        
                        if [ "$corrupted" = true ]; then
                            remove_corrupted_pack "$pack" "${size:-unknown}"
                        fi
                    fi
                done
            fi
        done
    fi
    
    if [ $removed_packs -eq 0 ]; then
        echo "   No obviously corrupted pack files found."
    else
        echo -e "${GREEN}   ✅ Removed $removed_packs corrupted pack file(s).${NC}"
    fi
    echo ""
    
    # Step 5: Re-fetch from remote
    echo -e "${BLUE}📋 Step 5: Re-fetching objects from remote...${NC}"
    if git fetch --all --prune 2>&1; then
        echo -e "${GREEN}   ✅ Fetch completed successfully.${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Fetch had issues, trying alternative approach...${NC}"
        
        # Alternative: remove all pack files and re-fetch
        echo "   Removing all pack files and re-fetching..."
        rm -f .git/objects/pack/*.pack .git/objects/pack/*.idx 2>/dev/null
        
        if git fetch --all 2>&1; then
            echo -e "${GREEN}   ✅ Re-fetch completed.${NC}"
        else
            echo -e "${RED}   ❌ Re-fetch failed. Manual intervention may be needed.${NC}"
        fi
    fi
    echo ""
    
    # Step 6: Run git gc to clean up
    echo -e "${BLUE}📋 Step 6: Running garbage collection...${NC}"
    local gc_output
    local gc_exit
    gc_output=$(git gc --prune=now 2>&1)
    gc_exit=$?
    echo "$gc_output"
    if [ $gc_exit -eq 0 ]; then
        echo -e "${GREEN}   ✅ Garbage collection completed.${NC}"
    else
        echo -e "${YELLOW}   ⚠️  git gc reported errors. The repository may still be corrupted; a final verification step will check.${NC}"
    fi
    echo ""
    
    # Step 7: Reset submodules if present
    if [ -f ".gitmodules" ]; then
        echo -e "${BLUE}📋 Step 7: Repairing submodules...${NC}"
        
        # De-init and re-init submodules
        git submodule deinit --all -f 2>/dev/null || true
        rm -rf .git/modules/* 2>/dev/null || true
        git submodule update --init --recursive 2>&1 || true
        
        echo -e "${GREEN}   ✅ Submodules repaired.${NC}"
        echo ""
    fi
    
    # Step 8: Verify repair
    echo -e "${BLUE}📋 Step 8: Verifying repair...${NC}"
    echo "   Running a deep integrity check (git fsck --full). This can take up to a few minutes on large or heavily corrupted repositories..."
    local still_corrupted=0

    if detect_git_corruption; then
        still_corrupted=1
    fi

    if [ $still_corrupted -eq 1 ]; then
        echo -e "${RED}❌ Repository still appears corrupted.${NC}"
        echo ""

        # Optional: try a hard reset to the remote branch before giving up
        if [ -n "$current_branch" ]; then
            echo "We can try to reset your local branch to match origin/$current_branch."
            echo "This will DISCARD local commits on this branch, but your working tree changes are backed up."
            read -r -p "Attempt reset to 'origin/$current_branch' and re-run verification? Type 'yes' to continue: " reset_confirm
            if [ "$reset_confirm" = "yes" ]; then
                echo ""
                echo "Resetting local branch to origin/$current_branch..."
                if git reset --hard "origin/$current_branch" && git clean -fd; then
                    echo "Running git gc after reset..."
                    gc_output=$(git gc --prune=now 2>&1)
                    echo "$gc_output"
                else
                    echo -e "${YELLOW}⚠️  Failed to reset to origin/$current_branch. Skipping reset-based repair.${NC}"
                fi
                echo ""
                echo "Re-running corruption check after reset..."
                if ! detect_git_corruption; then
                    still_corrupted=0
                fi
            fi
            echo ""
        fi
    fi

    if [ $still_corrupted -eq 1 ]; then
        echo "Manual repair may be needed. Options:"
        echo "  1. Clone fresh: git clone $remote_url <new-dir>"
        if [ "$BACKUP_METHOD" = "stash" ]; then
            echo "  2. Restore your stash in new clone"
        elif [ -n "$BACKUP_DIR" ]; then
            echo "  2. Copy your changes from: $BACKUP_DIR"
        fi
        echo ""
        
        # Offer to automatically clone a fresh repository
        read -r -p "Would you like me to clone a fresh copy of this repository into a new directory now? [y/N]: " auto_clone
        if [[ "$auto_clone" =~ ^[Yy]$ ]]; then
            local parent_dir
            local repo_name
            local new_dir
            parent_dir="$(cd .. && pwd)"
            repo_name="$(basename "$(pwd)")"
            new_dir="${parent_dir}/${repo_name}-repaired-$(date +%Y%m%d-%H%M%S)"
            echo ""
            echo "Cloning into: $new_dir"
            if git clone "$remote_url" "$new_dir"; then
                echo -e "${GREEN}✅ Fresh clone created at: $new_dir${NC}"
                
                # Automatically restore file backups into the repaired clone
                if [ "$BACKUP_METHOD" = "files" ] && [ -n "$BACKUP_DIR" ]; then
                    echo ""
                    echo "Restoring your backed-up files into the repaired clone..."
                    cp -r "$BACKUP_DIR"/* "$new_dir"/ 2>/dev/null || true
                    echo -e "${GREEN}✅ Backup files copied into: $new_dir${NC}"
                elif [ "$BACKUP_METHOD" = "stash" ]; then
                    echo ""
                    echo "Your changes are stored in a git stash in the OLD repository."
                    echo "You can review them there using:"
                    echo "  git stash list"
                    echo "  git stash show -p"
                    echo ""
                    echo "To apply the stash onto the repaired clone, you can for example run from the OLD repo:"
                    echo "  cd \"$(pwd)\""
                    echo "  git stash list   # find the '$STASH_NAME' entry"
                    echo "  GIT_DIR=\"$(pwd)/.git\" GIT_WORK_TREE=\"$new_dir\" git stash apply <stash-ref>"
                    echo ""
                fi

                echo ""
                echo "Next steps to verify the repaired repository:"
                echo "  1) Open a new terminal and run:"
                echo "       cd \"$new_dir\""
                echo "  2) Check git status and corruption:"
                echo "       git status"
                echo "       git fsck --full"
                echo "  3) Verify your application / scripts run as expected."
                echo ""
                read -r -p "If everything works and no git errors are present, type 'replace' to replace the old repo in-place. Otherwise press Enter to keep both: " replace_confirm

                if [ "$replace_confirm" = "replace" ]; then
                    local old_dir current_parent repaired_basename broken_name
                    old_dir="$(pwd)"
                    current_parent="$parent_dir"
                    repaired_basename="$(basename "$new_dir")"
                    broken_name="${repo_name}-broken-$(date +%Y%m%d-%H%M%S)"

                    echo ""
                    echo "Archiving old repo as: $current_parent/$broken_name"
                    echo "Copying repaired repo into new working location at: $current_parent/$repo_name"
                    cd "$current_parent" || true
                    mv "$repo_name" "$broken_name"
                    mkdir -p "$repo_name"
                    cp -R "$repaired_basename"/. "$repo_name"/ 2>/dev/null || true
                    echo -e "${GREEN}✅ Replacement completed.${NC}"
                    echo "Old broken repo: $current_parent/$broken_name"
                    echo "New working repo: $current_parent/$repo_name"

                    echo ""
                    echo "To work in the new repository from a terminal, you can run:"
                    echo "  cd \"$current_parent/$repo_name\""
                    echo ""
                    echo "Please verify the new repository is working correctly (git status, git fsck --full, run your application)."
                    echo "If everything is fine and you no longer need the archived repo, you can remove it now."
                    read -r -p "Type 'remove' to delete '$current_parent/$broken_name'. Otherwise press Enter to keep it: " remove_confirm
                    if [ "$remove_confirm" = "remove" ]; then
                        echo "Running final validation checks in new repo before removing archived repo..."
                        if ( cd "$current_parent/$repo_name" && git status >/dev/null 2>&1 && git fsck --full >/dev/null 2>&1 ); then
                            echo "Final validation passed. Removing archived broken repo: $current_parent/$broken_name"
                            rm -rf "$current_parent/$broken_name"
                            echo -e "${GREEN}✅ Archived broken repo removed.${NC}"
                        else
                            echo -e "${YELLOW}⚠️  Final validation failed or reported git errors. Archived repo will NOT be removed.${NC}"
                            echo "You can inspect the new repo at: $current_parent/$repo_name and the archived repo at: $current_parent/$broken_name"
                        fi
                    else
                        echo "Archived broken repo kept at: $current_parent/$broken_name"
                    fi

                    # Show summary of remaining repair-related directories
                    echo ""
                    echo "Repair summary:"
                    echo "  New working repo: $current_parent/$repo_name"
                    if [ -d "$current_parent/$broken_name" ]; then
                        echo "  Archived broken repo: $current_parent/$broken_name"
                    fi
                    if [ -d "$current_parent/$repaired_basename" ]; then
                        echo "  Repaired clone still present at: $current_parent/$repaired_basename"
                        echo "  You can remove it later with: rm -rf \"$current_parent/$repaired_basename\""
                    fi

                    # Update original_dir to point at the new repo location and treat as success
                    original_dir="$current_parent/$repo_name"
                    cd "$original_dir" || true
                    return 0
                fi
            else
                echo -e "${RED}❌ Failed to clone fresh repository automatically.${NC}"
            fi
        fi
        cd "$original_dir"
        return 1
    else
        echo -e "${GREEN}✅ Repository appears healthy!${NC}"
    fi
    echo ""
    
    # Step 9: Restore changes if backed up
    if [ -n "$BACKUP_METHOD" ]; then
        echo -e "${BLUE}📋 Step 9: Restoring your changes...${NC}"
        echo ""
        
        if [ "$BACKUP_METHOD" = "stash" ]; then
            echo "Your changes are in the git stash."
            echo ""
            read -r -p "Apply stash now to restore your changes? [Y/n]: " restore_confirm
            if [[ ! "$restore_confirm" =~ ^[Nn]$ ]]; then
                echo "Applying stash..."
                if git stash pop 2>/dev/null; then
                    echo -e "${GREEN}✅ Changes restored from stash.${NC}"
                else
                    echo -e "${YELLOW}⚠️  Stash apply had conflicts. Use 'git stash show' to see changes.${NC}"
                fi
            else
                echo "Stash preserved. Restore later with: git stash pop"
            fi
        else
            echo "Your changes are backed up in: $BACKUP_DIR"
            echo ""
            read -r -p "Restore backed-up files now? [Y/n]: " restore_confirm
            if [[ ! "$restore_confirm" =~ ^[Nn]$ ]]; then
                echo "Restoring files..."
                cp -r "$BACKUP_DIR"/* . 2>/dev/null || true
                echo -e "${GREEN}✅ Files restored.${NC}"
            else
                echo "Files preserved in: $BACKUP_DIR"
            fi
        fi
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Git repository repair completed!${NC}"
    echo ""
    
    cd "$original_dir"
    return 0
}

# Function to run a quick check and offer repair if needed
# Usage: quick_check_and_offer_repair
# Returns: 0 if healthy or repaired, 1 if still broken
quick_check_and_offer_repair() {
    if ! is_git_repo; then
        return 0  # Not a git repo, nothing to check
    fi
    
    if detect_git_corruption; then
        echo ""
        echo -e "${RED}⚠️  Git repository corruption detected!${NC}"
        echo ""
        read -r -p "Would you like to attempt automatic repair? [Y/n]: " repair_confirm
        if [[ ! "$repair_confirm" =~ ^[Nn]$ ]]; then
            repair_git_repo "."
            return $?
        else
            echo ""
            echo "You can repair manually later with: dev-tools --repair"
            return 1
        fi
    fi
    
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo -e "${BLUE}🔧 Git Repository Repair Tool${NC}"
    echo "=============================="
    echo ""
    
    # Check if we're in a git repo
    if ! is_git_repo; then
        echo -e "${RED}❌ Not in a git repository.${NC}"
        echo "Please run this from within a git repository."
        exit 1
    fi
    
    # Check for corruption
    echo "🔍 Checking for repository corruption..."
    echo "   Running an integrity scan (git fsck --full and pack checks). This can take up to a few minutes on large or heavily corrupted repositories..."
    echo ""
    
    if detect_git_corruption; then
        echo -e "${RED}⚠️  Repository corruption detected!${NC}"
        echo ""
        read -r -p "Would you like to attempt automatic repair? [Y/n]: " confirm
        if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
            repair_git_repo "."
        else
            echo "Repair cancelled."
            exit 1
        fi
    else
        echo -e "${GREEN}✅ No corruption detected. Repository appears healthy.${NC}"
        echo ""
        read -r -p "Run repair anyway? (This can fix minor issues) [y/N]: " force_repair
        if [[ "$force_repair" =~ ^[Yy]$ ]]; then
            repair_git_repo "."
        fi
    fi
fi
