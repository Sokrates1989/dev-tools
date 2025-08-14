# Git Stash Manager – Dev Tools

A comprehensive Git stash management tool that provides an interactive menu-driven interface for all common stash operations.

## Features

### 📥 Stash Operations
- **Stash all changes (including untracked)** - Saves all uncommitted changes including untracked files
- **Stash only tracked changes** - Saves only tracked file changes, leaves untracked files
- **Stash with custom message** - Create a stash with a descriptive message

### 📤 Apply/Pop Operations
- **Apply latest stash** - Applies the most recent stash while keeping it in the stash list
- **Pop latest stash** - Applies and removes the most recent stash
- **Apply specific stash** - Apply any stash by index or reference
- **Pop specific stash** - Apply and remove any stash by index or reference

### 📋 View Operations
- **List all stashes** - Shows all available stashes with timestamps and messages
- **Show latest stash content** - Displays the diff content of the most recent stash
- **Show specific stash content** - View the diff content of any stash

### 🗑️ Cleanup Operations
- **Drop latest stash** - Permanently delete the most recent stash without applying
- **Drop specific stash** - Permanently delete any stash by index or reference
- **Clear all stashes** - Remove all stashes (requires confirmation)

## Usage

### From Dev Tools Main Menu
1. Run `./start.sh` from the dev-tools root directory
2. Select option `8) 📦 Git Stash Manager`

### Direct Access
```bash
# Quick access via command line argument
./start.sh --stash
./start.sh -st

# Direct script execution
./main_features/stash/stash_manager.sh
```

## Stash Reference Format

When working with specific stashes, you can use either:
- **Index number**: `1`, `2`, `3` (corresponds to the numbered list)
- **Git stash reference**: `stash@{0}`, `stash@{1}`, `stash@{2}`

## Safety Features

- **Confirmation prompts** for destructive operations
- **Working directory status checks** before applying stashes
- **Conflict detection and guidance** when stash operations fail
- **Input validation** for stash references and indices

## Tips

- Use descriptive messages when creating stashes to easily identify them later
- Check your working directory status before applying stashes to avoid conflicts
- Use "apply" operations to test stashes before committing to "pop" operations
- The stash list is ordered with the most recent stash at index 0

## Error Handling

The tool provides clear error messages and guidance for:
- Invalid stash references or indices
- Merge conflicts during stash application
- Empty stash lists
- Non-Git repositories
