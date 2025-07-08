# Branch Sync Feature

## Overview

The Branch Sync feature provides a comprehensive way to keep your local Git repository in sync with remote repositories. It fetches all remote branches and offers to pull changes for each local branch individually, giving you full control over the synchronization process.

This feature is particularly useful for:
- Keeping all local branches up to date with remote changes
- Managing multiple branches in a repository
- Ensuring you have the latest changes before starting work
- Maintaining consistency across team members' repositories

## What It Does

The feature performs a comprehensive synchronization process:

1. **Full Remote Fetch**: Fetches all branches from all remotes with pruning
2. **Branch Analysis**: Analyzes the status of each local branch
3. **Status Classification**: Categorizes branches as up-to-date, ahead, behind, or diverged
4. **Interactive Sync**: Offers to pull changes for each branch individually
5. **Smart Branch Switching**: Automatically switches between branches as needed
6. **Detailed Reporting**: Provides comprehensive feedback on all operations

## Branch Status Types

The tool identifies and categorizes branches into several status types:

- **✅ Up to date**: Local branch matches its remote tracking branch
- **🟡 Ahead**: Local branch has commits that aren't on the remote
- **🔴 Behind**: Remote branch has commits that aren't in the local branch
- **🟠 Diverged**: Both local and remote have different commits
- **⚠️ No remote tracking**: Local branch has no associated remote branch

## Safety Features

- **Individual Confirmation**: Asks for confirmation for each branch before pulling
- **Current Branch Protection**: Special handling for the branch you're currently on
- **Automatic Branch Switching**: Safely switches between branches and returns to your original branch
- **Error Handling**: Gracefully handles failed operations and continues with others
- **Detailed Feedback**: Shows exactly what succeeded and what failed

## Usage

### From the Main Menu
```bash
# Run the main launcher
./start.sh

# Choose the branch sync option
```

### Direct Command Line
```bash
# Using the main launcher with flags
./start.sh --sync-branches
# or
./start.sh -s
```

### PowerShell
```powershell
# Using the main launcher with flags
.\start.ps1 -sync-branches
# or
.\start.ps1 -s
```

## Workflow

1. **Repository Check**: Ensures you're in a git repository with commits
2. **Remote Fetch**: Fetches all remote branches and updates tracking
3. **Branch Analysis**: Analyzes each local branch's status
4. **Status Summary**: Displays categorized summary of all branches
5. **Interactive Sync**: Processes each branch that needs syncing
6. **Final Summary**: Provides detailed report of all actions taken

## Example Output

```
🔄 Branch Sync Tool
==================

This tool will fetch all remote branches and help you sync your local branches.

📍 Current branch: feature/new-feature

📥 Step 1: Fetching all remote branches...

✅ Successfully fetched all remote branches.
✅ Successfully updated remote tracking branches.

📋 Step 2: Analyzing local branches...

Found 4 local branch(es):

🔍 Analyzing: main
   ✅ Up to date

🔍 Analyzing: dev
   🔴 Behind by 3 commit(s)

🔍 Analyzing: feature/new-feature
   🟡 Ahead by 2 commit(s)

🔍 Analyzing: feature/old-feature
   ⚠️  No remote tracking branch found

📊 Branch Status Summary:

✅ Up to date (1):
   main

🟡 Ahead of remote (1):
   feature/new-feature

🔴 Behind remote (1):
   dev

⚠️  No remote tracking (1):
   feature/old-feature

🔄 Branches that can be synced: 1

🤔 Do you want to sync these branches? [y/N]: y

📋 Processing: dev

🔄 Pull changes for branch 'dev'? [y/N]: y
🔄 Pulling changes...
✅ Switched to dev
✅ Successfully pulled changes for dev
✅ Switched back to feature/new-feature

🎉 Branch sync completed!

✅ Successfully synced branches:
   🔄 dev

💡 Tip: You have 1 branch(es) ahead of remote.
   Consider pushing these changes when ready.

💡 Tip: You have 1 branch(es) without remote tracking.
   Consider setting up remote tracking with: git branch --set-upstream-to=origin/<branch> <branch>

🔄 Your repository is now up to date!
```

## When to Use

- **Daily Maintenance**: Regular sync to keep your repository up to date
- **Before Starting Work**: Ensure you have the latest changes before making new commits
- **After Team Updates**: When team members have pushed changes to remote
- **Multi-Branch Development**: When working with multiple feature branches
- **Repository Setup**: When setting up a new local repository

## Files

- `sync_branches.sh` - Bash implementation
- `sync_branches.ps1` - PowerShell implementation
- `README.md` - This documentation

## Dependencies

- Git repository with at least one commit
- Remote repository configured
- Same environment configuration as other dev-tools features

## Best Practices

1. **Regular Sync**: Run this tool regularly to keep your repository current
2. **Review Before Pulling**: Always review the branch status before syncing
3. **Handle Conflicts**: Be prepared to resolve merge conflicts if they occur
4. **Push Local Changes**: Consider pushing your local changes after syncing
5. **Set Up Tracking**: Set up remote tracking for branches that don't have it

## Safety Notes

- **Non-destructive**: Only pulls changes, never overwrites local work
- **Current branch safe**: Special handling ensures your current branch is protected
- **Individual control**: You decide which branches to sync
- **Error recovery**: Failed operations don't affect successful ones
- **Branch switching**: Automatically returns to your original branch 