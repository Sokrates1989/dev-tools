# Branch Cleanup Feature

## Overview

The Branch Cleanup feature helps you maintain a clean Git repository by identifying and removing local branches that are fully merged with either `main` or `dev` branches. This is particularly useful for:

- Cleaning up feature branches after they've been merged
- Removing old development branches that are no longer needed
- Maintaining a tidy repository structure
- Reducing clutter in your local and remote repositories

## What It Does

The feature performs a comprehensive analysis and cleanup process:

1. **Repository Validation**: Ensures you're in a git repository with commits
2. **Branch Discovery**: Identifies all local branches (excluding main and dev)
3. **Merge Analysis**: Checks which branches are fully merged with main or dev
4. **Safety Checks**: Warns if you're on a branch that will be removed
5. **Interactive Removal**: Asks for confirmation for each branch (local and remote)
6. **Detailed Feedback**: Provides comprehensive summary of actions taken

## Safety Features

- **Protected Branches**: Never removes `main` or `dev` branches
- **Current Branch Protection**: Warns and offers to switch if you're on a branch to be removed
- **Individual Confirmation**: Asks for confirmation for each branch separately
- **Local/Remote Separation**: Allows removing locally but keeping remotely (or vice versa)
- **Detailed Reporting**: Shows exactly what was removed and what failed
- **Error Handling**: Gracefully handles failed removals and continues with others

## Usage

### From the Main Menu
```bash
# Run the main launcher
./start.sh

# Choose the branch cleanup option
```

### Direct Command Line
```bash
# Using the main launcher with flags
./start.sh --branch-cleanup
# or
./start.sh -b
```

### PowerShell
```powershell
# Using the main launcher with flags
.\start.ps1 -branch-cleanup
# or
.\start.ps1 -b
```

## Workflow

1. **Repository Check**: Ensures you're in a git repository with commits
2. **Branch Analysis**: Identifies all local branches and checks merge status
3. **Results Display**: Shows which branches are merged and which aren't
4. **Safety Check**: Warns if you're on a branch that will be removed
5. **Interactive Removal**: Processes each merged branch with individual confirmations
6. **Summary**: Provides detailed report of all actions taken

## Example Output

```
🧹 Branch Cleanup Tool
=====================

This tool will identify and remove local branches that are fully merged
with either main or dev branches (excluding main and dev themselves).

📍 Current branch: feature/new-feature

📋 Available merge targets:
   ✅ main
   ✅ dev

🔍 Checking 3 local branches for merge status...

✅ Found 2 fully merged branch(es):
   🟢 feature/login (merged into main)
   🟢 feature/settings (merged into dev)

⚠️  Unmerged branches (will be preserved):
   🔴 feature/new-feature

🗑️  Ready to remove merged branches...

📋 Processing: feature/login (merged into main)

🗑️  Remove 'feature/login' locally? [y/N]: y
🔄 Removing local branch 'feature/login'...
✅ Successfully removed local branch 'feature/login'.

🌐 Remove 'feature/login' from remote (origin)? [y/N]: y
🔄 Removing remote branch 'feature/login'...
✅ Successfully removed remote branch 'feature/login'.

📋 Processing: feature/settings (merged into dev)

🗑️  Remove 'feature/settings' locally? [y/N]: y
🔄 Removing local branch 'feature/settings'...
✅ Successfully removed local branch 'feature/settings'.

ℹ️  Branch 'feature/settings' doesn't exist on remote.

🎉 Branch cleanup completed!

✅ Successfully removed local branches:
   🗑️  feature/login
   🗑️  feature/settings

✅ Successfully removed remote branches:
   🌐 feature/login

💡 Tip: You can run 'git remote prune origin' to clean up stale remote references.
```

## When to Use

- **After Merging**: When feature branches have been successfully merged
- **Repository Maintenance**: Regular cleanup to keep your repository organized
- **Before Switching Projects**: Clean up before moving to a different project
- **Team Collaboration**: When working with teams to maintain clean repositories
- **Pre-Release**: Before making releases to ensure clean repository state

## Files

- `branch_cleanup.sh` - Bash implementation
- `branch_cleanup.ps1` - PowerShell implementation
- `README.md` - This documentation

## Dependencies

- Git repository with at least one commit
- At least one of `main` or `dev` branches must exist
- Same environment configuration as other dev-tools features

## Best Practices

1. **Regular Cleanup**: Run this tool periodically to maintain a clean repository
2. **Review Before Removal**: Always review the list of branches to be removed
3. **Coordinate with Team**: Let your team know when you're cleaning up branches
4. **Backup Important Work**: Ensure all important changes are merged before cleanup
5. **Use Feature Branches**: Follow a consistent branching strategy for easier cleanup

## Safety Notes

- **Never removes main/dev**: These branches are always protected
- **Warns about current branch**: Prevents accidentally removing the branch you're on
- **Individual confirmations**: You control exactly which branches to remove
- **Separate local/remote**: You can choose to remove locally but keep remotely
- **Graceful failures**: If a removal fails, the tool continues with other branches 