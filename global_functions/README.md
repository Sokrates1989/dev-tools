# Global Functions

This directory contains utility scripts that are shared across multiple dev tools features and provide core functionality.

## Available Functions

### Update Management
- **`check_for_updates.sh/.ps1`** - Checks for dev tools updates
- **`check_for_updates_flag.sh/.ps1`** - Returns update availability flag
- **`perform_auto_update.sh/.ps1`** - Performs automatic updates

### Environment Management
- **`load_dotenv.ps1`** - Loads environment variables from .env file

### System Integration
- **`open.ps1`** - Cross-platform file opening utility

### Git Operations
- **`sync_check.sh/.ps1`** - Checks if branch is in sync with remote

## Sync Check Utility

### Overview

The `sync_check.sh` and `sync_check.ps1` scripts are utility functions that check if the current branch is in sync with its remote counterpart before allowing operations like commits or merges. This helps prevent merge conflicts by ensuring the local branch is up-to-date.

### What it does

1. **Checks remote tracking** - Verifies if the current branch has a remote tracking branch
2. **Fetches latest info** - Gets the most recent remote information
3. **Compares status** - Determines if local is ahead, behind, or diverged from remote
4. **Shows context** - Displays recent commits for better understanding
5. **Offers sync options** - Provides interactive options to resolve sync issues
6. **Returns status** - Exits with appropriate codes for integration

### Integration

The sync check is automatically integrated into the following features:

- **Commit Tool** (`git_export_staged.sh/.ps1`) - Runs before creating commits
- **Merge Tool** (`git_export_merge.sh`) - Runs before merging branches
- **Amend Tool** (`git_amend.sh/.ps1`) - Runs before amending commits

### Branch Status Detection

The utility detects three main scenarios:

#### 1. Local Ahead of Remote
```
📤 Local is 3 commit(s) ahead of remote
💡 You can push your changes: git push
```

#### 2. Local Behind Remote
```
📥 Local is 2 commit(s) behind remote
💡 You should pull remote changes: git pull
```

#### 3. Diverged Branches
```
🔀 Local and remote have diverged
📤 Local is 1 commit(s) ahead
📥 Remote is 2 commit(s) ahead
💡 You need to merge or rebase: git pull --rebase
```

### Sync Options

When sync issues are detected, the utility offers these options:

1. **Pull remote changes** - Standard `git pull`
2. **Pull with rebase** - `git pull --rebase` for cleaner history
3. **Push local changes** - `git push` to share your work
4. **Force push** - `git push --force-with-lease` (with safety warnings)
5. **Skip sync** - Continue without syncing (may cause conflicts later)
6. **Cancel operation** - Abort the current operation

### Safety Features

- **Force push protection** - Requires explicit confirmation for dangerous operations
- **Conflict detection** - Warns about potential merge conflicts
- **Context display** - Shows recent commits to help understand changes
- **Graceful handling** - Handles new branches without remote tracking
- **Error recovery** - Provides clear error messages and recovery options

### Usage Examples

#### Direct Execution
```bash
# Bash
./global_functions/sync_check.sh

# PowerShell
./global_functions/sync_check.ps1
```

#### Integration Example
```bash
# The sync check runs automatically before commits
./start.sh --commit

# Output example:
🔍 Checking if branch is in sync with remote...
⚠️  Branch 'feature/new-ui' is not in sync with remote:
   📥 Local is 2 commit(s) behind remote
   
🔄 Sync options:
1) 📥 Pull remote changes (git pull)
2) 📥 Pull with rebase (git pull --rebase)
5) ❌ Skip sync and continue anyway
6) ❌ Cancel operation

🤔 Choose an option [1-6]: 1
📥 Pulling remote changes...
✅ Successfully pulled remote changes.
```

### Exit Codes

- **0** - Success (branch is in sync or sync completed successfully)
- **1** - Error (sync failed, operation cancelled, or invalid choice)

### Benefits

- **Prevents merge conflicts** - Ensures branches are up-to-date before operations
- **Improves workflow** - Automatically handles common sync scenarios
- **Reduces errors** - Catches sync issues before they cause problems
- **Provides guidance** - Offers clear options for resolving sync issues
- **Maintains safety** - Warns about dangerous operations like force push

### Configuration

The sync check respects the same environment configuration as other dev tools:

- Uses `.env` file for configuration
- Integrates with the update check system
- Follows the same error handling patterns
- Maintains consistent UI/UX with other tools 