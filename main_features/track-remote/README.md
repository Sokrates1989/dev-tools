# Track Remote Branch Tool

## Overview

The Track Remote Branch tool helps you discover and track remote branches locally. It identifies all remote branches that aren't yet tracked locally and allows you to create local tracking branches for the ones you want to work with.

## What it does

This tool performs the following operations:

1. **Fetches all remote branches** - Ensures you have the latest information about remote branches
2. **Analyzes branch status** - Compares remote branches with local branches to find untracked ones
3. **Presents selection options** - Shows you which remote branches can be tracked locally
4. **Creates tracking branches** - Sets up local branches that track the selected remote branches
5. **Provides feedback** - Gives you detailed information about what was accomplished

## Features

- **Smart branch detection** - Automatically identifies which remote branches aren't tracked locally
- **Flexible selection** - Choose branches by number, name, or a combination of both
- **Interactive selection** - Choose specific branches or track all untracked branches at once
- **Safety confirmations** - Multiple confirmation steps to prevent accidental operations
- **Detailed feedback** - Clear reporting of what was tracked and what failed
- **Branch preservation** - Returns you to your original branch after tracking operations
- **Error handling** - Graceful handling of network issues and invalid selections

## Usage

### From the main launcher

```bash
# Interactive mode
./start.sh
# Then select option 10) Track Remote Branches

# Direct execution
./start.sh --track-remote
./start.sh -t
```

### Direct execution

```bash
# Bash
./main_features/track-remote/track_remote.sh

# PowerShell
./main_features/track-remote/track_remote.ps1
```

## Workflow

### Step 1: Repository Analysis
The tool first checks that you're in a valid Git repository and fetches the latest remote information.

### Step 2: Branch Discovery
It identifies all remote branches and compares them with your local branches to find untracked ones.

### Step 3: Selection Interface
You'll see a list like this:
```
🌐 Untracked remote branches (3):
   1) feature/new-ui
   2) bugfix/login-issue
   3) hotfix/security-patch
```

### Step 4: Branch Selection
You can select branches in several ways:
- **Individual numbers**: `1 3` (tracks branches 1 and 3)
- **Branch names**: `feature/new-ui bugfix/login-issue` (tracks by exact name)
- **Mixed selection**: `1 feature/new-ui 3` (combines numbers and names)
- **All branches**: `all` (tracks all untracked branches)

### Step 5: Confirmation
The tool shows you which branches will be tracked and asks for final confirmation.

### Step 6: Tracking Creation
For each selected branch, it creates a local branch that tracks the remote branch:
```bash
git checkout -b branch-name origin/branch-name
```

## Example Output

```
📡 Track Remote Branch Tool
===========================

📍 Current branch: main

📥 Step 1: Fetching all remote branches...
✅ Successfully fetched all remote branches.

📋 Step 2: Analyzing remote branches...
Found remote branches:
   🌐 main
   🌐 develop
   🌐 feature/new-ui
   🌐 bugfix/login-issue

📋 Step 3: Analyzing local branches...
Found local branches:
   📁 main
   📁 develop

🔍 Step 4: Finding untracked remote branches...

✅ Already tracked locally (2):
   📁 main
   📁 develop

🌐 Untracked remote branches (2):
   1) feature/new-ui
   2) bugfix/login-issue

🔄 You can track these remote branches locally.

🤔 Do you want to track any of these branches? [y/N]: y

📋 Select branches to track (enter numbers or branch names separated by spaces, or 'all' for all):
Enter your selection: 1 2

🔄 Selected branches to track:
   🌐 feature/new-ui
   🌐 bugfix/login-issue

👉 Confirm tracking these branches? [y/N]: y

🔄 Step 5: Tracking selected branches...

📋 Processing: feature/new-ui
   ✅ Successfully created local branch 'feature/new-ui' tracking 'origin/feature/new-ui'

📋 Processing: bugfix/login-issue
   ✅ Successfully created local branch 'bugfix/login-issue' tracking 'origin/bugfix/login-issue'

🔄 Switching back to original branch...
✅ Switched back to main

🎉 Remote branch tracking completed!

✅ Successfully tracked branches:
   📁 feature/new-ui
   📁 bugfix/login-issue

💡 Tip: You can now switch to these branches using:
   git checkout feature/new-ui
   git checkout bugfix/login-issue

🔄 Your local repository now has access to the tracked remote branches!
```

## Benefits

- **Discover hidden branches** - Find remote branches you didn't know existed
- **Organized workflow** - Keep your local repository organized with only the branches you need
- **Safe operations** - Multiple confirmation steps prevent accidental tracking
- **Clear feedback** - Always know what happened and what you can do next
- **Preserves workflow** - Returns you to your original branch after operations

## Tips

- **Regular use**: Run this tool periodically to discover new remote branches
- **Selective tracking**: Only track branches you actually plan to work on
- **Clean repository**: Untracked remote branches won't clutter your local branch list
- **Team collaboration**: Great for discovering branches created by other team members

## Error Handling

The tool handles various error conditions:

- **No Git repository**: Exits with clear error message
- **No remote branches**: Informs you when no remote branches are available
- **Network issues**: Handles fetch failures gracefully
- **Invalid selections**: Validates user input and provides helpful feedback
- **Tracking failures**: Reports which branches failed to track and why

## Integration

This tool integrates seamlessly with other dev tools:

- **Branch cleanup**: Use after tracking to clean up merged branches
- **Branch sync**: Keep tracked branches up to date
- **Git log explorer**: Explore history of newly tracked branches
- **Commit tools**: Work with changes on tracked branches 