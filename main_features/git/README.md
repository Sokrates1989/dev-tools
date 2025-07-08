# Git Tools

## Overview

The Git Tools provide essential Git repository management features including Git log exploration and local changes reset functionality. These tools help you understand your repository history and manage your working directory effectively.

## Features

### Git Log Explorer
An interactive tool for exploring Git history with various viewing options and filters.

### Reset Local Changes
A safety-focused tool for resetting your working directory and discarding local changes.

## Git Log Explorer

### What it does

The Git Log Explorer provides an interactive interface for viewing Git history with multiple display options:

1. **Pretty logs** - Formatted, readable commit history
2. **Graph visualization** - Branch and merge history with ASCII graphs
3. **File-specific history** - View commits that affected specific files
4. **Author filtering** - Filter commits by author
5. **Date filtering** - View commits within specific time ranges
6. **Reverse history** - View commits in reverse chronological order
7. **Patch output** - View detailed changes in each commit
8. **Statistics** - Get commit statistics and summaries

### Usage

#### From the main launcher

```bash
# Interactive mode
./start.sh
# Then select option 8) Git log explorer

# Direct execution
./start.sh --log
./start.sh -l
```

#### Direct execution

```bash
# Bash
./main_features/git/git_log_explorer.sh

# PowerShell
./main_features/git/git_log_explorer.ps1
```

### Workflow

1. **Select log type** - Choose from various log display options
2. **Preview command** - See the Git command that will be executed
3. **Execute or modify** - Run the command or modify parameters
4. **Navigate results** - Use pager navigation (space, q, arrow keys)
5. **Return to menu** - Continue exploring or return to main menu

### Example Output

```
📜 Git Log Explorer
==================

Choose a log type:

1) Pretty log (oneline)
2) Pretty log (short)
3) Pretty log (medium)
4) Pretty log (full)
5) Graph log
6) File-specific log
7) Author-specific log
8) Date range log
9) Reverse log
10) Patch log
11) Statistics
b) Back to main menu
q) Quit

Enter your choice: 5

Command: git log --graph --oneline --all --decorate

Preview this command? [Y/n]: y

* a1b2c3d (HEAD -> main) Latest commit message
* d4e5f6g Previous commit message
* g7h8i9j Another commit message
```

## Reset Local Changes

### What it does

The Reset Local Changes tool provides a safe way to discard local changes and reset your working directory:

1. **Shows current status** - Displays what files have been modified
2. **Explains consequences** - Clearly explains what will be lost
3. **Multiple reset options** - Choose from different reset levels
4. **Safety confirmations** - Multiple confirmation steps to prevent accidents
5. **Clean working directory** - Resets to a clean state

### Usage

#### From the main launcher

```bash
# Interactive mode
./start.sh
# Then select option 11) Reset Local Git Changes

# Direct execution
./start.sh --reset
./start.sh -x
```

#### Direct execution

```bash
# Bash
./main_features/git/reset_local_changes.sh

# PowerShell
./main_features/git/reset_local_changes.ps1
```

### Workflow

1. **Status check** - Shows current repository status
2. **Reset type selection** - Choose reset level (soft, mixed, hard)
3. **Confirmation** - Multiple safety confirmations
4. **Execution** - Performs the reset operation
5. **Verification** - Confirms the reset was successful

### Reset Types

- **Soft reset** - Moves HEAD but keeps changes staged
- **Mixed reset** - Moves HEAD and unstages changes (default)
- **Hard reset** - Moves HEAD and discards all changes (dangerous)

### Example Output

```
🧹 Reset Local Git Changes
==========================

📍 Current branch: feature/new-feature

📋 Current status:
   M  src/components/Button.js
   A  src/components/NewComponent.js
   D  src/utils/old-util.js

⚠️  WARNING: This will discard all local changes!

Choose reset type:
1) Soft reset (keep changes staged)
2) Mixed reset (unstaged changes) [default]
3) Hard reset (discard all changes)

Enter your choice [2]: 2

🔄 This will:
   - Move HEAD to the last commit
   - Unstage all changes
   - Keep working directory changes

👉 Are you sure you want to continue? [y/N]: y

✅ Successfully reset local changes.
   Your working directory is now clean.
```

## Benefits

### Git Log Explorer
- **Multiple viewing options** - Choose the best format for your needs
- **Interactive interface** - Easy navigation and command preview
- **Flexible filtering** - Find specific commits quickly
- **Visual history** - Graph view shows branch relationships
- **Detailed analysis** - Patch view for detailed change inspection

### Reset Local Changes
- **Safety first** - Multiple confirmations prevent accidental data loss
- **Clear explanations** - Understand exactly what will happen
- **Flexible options** - Choose the right reset level for your situation
- **Status awareness** - See what changes will be lost before proceeding
- **Clean workflow** - Quickly return to a clean working state

## Tips

### Git Log Explorer
- **Use graph view** for understanding branch history and merges
- **File-specific logs** help track changes to specific components
- **Author filtering** is useful in team environments
- **Patch view** shows exactly what changed in each commit
- **Statistics** provide overview of repository activity

### Reset Local Changes
- **Always check status first** to see what will be lost
- **Use mixed reset** for most situations (safest option)
- **Hard reset only** when you're absolutely sure you want to discard everything
- **Consider stashing** instead of resetting if you might want changes later
- **Backup important changes** before using hard reset

## Error Handling

### Git Log Explorer
- **No commits** - Handles repositories with no commit history
- **Invalid options** - Validates user input and provides helpful feedback
- **Pager issues** - Graceful handling of pager navigation problems

### Reset Local Changes
- **No changes** - Informs when there's nothing to reset
- **Invalid reset type** - Validates reset type selection
- **Reset failures** - Reports if reset operation fails
- **Safety cancellations** - Allows users to cancel at any confirmation step

## Integration

These tools integrate seamlessly with other dev tools:

- **Commit tools** - Use log explorer to understand what to commit
- **Branch tools** - Explore history before creating new branches
- **Merge tools** - Use log explorer to understand merge conflicts
- **Amend tools** - Reset changes before amending commits
- **Cleanup tools** - Reset before cleaning up branches 