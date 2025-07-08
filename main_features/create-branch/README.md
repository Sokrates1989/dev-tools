# Create New Branch Tool

## Overview

The Create New Branch tool helps you create new local branches with proper remote tracking setup. It guides you through selecting a base branch, naming your new branch, and automatically pushes it to the remote repository with upstream tracking configured.

## What it does

This tool performs the following operations:

1. **Shows available base branches** - Lists all local branches for you to choose from
2. **Prompts for branch name** - Gets your desired branch name with validation
3. **Checks for conflicts** - Verifies the branch name doesn't exist locally or remotely
4. **Creates the branch** - Checks out the base branch, pulls latest changes, and creates your new branch
5. **Sets up remote tracking** - Pushes the branch to remote and configures upstream tracking
6. **Provides feedback** - Confirms success and shows you're now on the new branch

## Features

- **Smart base branch selection** - Defaults to current branch but allows choosing any local branch
- **Conflict prevention** - Checks for existing local and remote branches with the same name
- **Automatic upstream setup** - Pushes to remote and sets up tracking in one step
- **Latest base branch** - Ensures your new branch is based on the latest version of the base branch
- **Interactive selection** - Choose base branch by number or name
- **Safety validations** - Multiple checks to prevent branch creation conflicts
- **Clear feedback** - Detailed status messages throughout the process

## Usage

### From the main launcher

```bash
# Interactive mode
./start.sh
# Then select option 7) Create New Branch

# Direct execution
./start.sh --create-branch
./start.sh -n
```

### Direct execution

```bash
# Bash
./main_features/create-branch/create_branch.sh

# PowerShell
./main_features/create-branch/create_branch.ps1
```

## Workflow

### Step 1: Base Branch Selection
The tool shows your current branch and lists all available local branches:

```
🌱 Create a New Branch
=====================
Current branch: main

Available local branches:
   1) main
   2) develop
   3) feature/user-auth
   4) hotfix/security-patch

Base branch [default: main, number or name]:
```

You can:
- **Press Enter** to use the current branch as base
- **Enter a number** to select by position (e.g., `2` for develop)
- **Enter a branch name** to select by name (e.g., `feature/user-auth`)

### Step 2: Branch Name Input
Enter your desired branch name:

```
Enter new branch name: feature/new-dashboard
```

### Step 3: Conflict Checking
The tool automatically checks for conflicts:
- **Local branch exists**: Warns if a local branch with that name already exists
- **Remote branch exists**: Warns if a remote branch with that name already exists

### Step 4: Branch Creation
If no conflicts are found, the tool:
1. Checks out the base branch
2. Pulls the latest changes from remote
3. Creates your new branch from the base
4. Pushes the branch to remote with `--set-upstream`

### Step 5: Confirmation
You'll see confirmation that the branch was created and you're now on it:

```
✅ Branch 'feature/new-dashboard' created from 'develop' and pushed to origin.
   You are now on 'feature/new-dashboard'.
```

## Example Output

```
🌱 Create a New Branch
=====================
Current branch: main

Available local branches:
   1) main
   2) develop
   3) feature/user-auth
   4) hotfix/security-patch

Base branch [default: main, number or name]: 2

Enter new branch name: feature/new-dashboard

Pushing new branch to remote and setting upstream...

✅ Branch 'feature/new-dashboard' created from 'develop' and pushed to origin.
   You are now on 'feature/new-dashboard'.
```

## Benefits

- **No tracking issues** - Automatically sets up upstream tracking to prevent future push/pull problems
- **Latest base** - Ensures your new branch starts from the most recent version of the base branch
- **Conflict prevention** - Checks for naming conflicts before creating the branch
- **Streamlined workflow** - Creates and pushes the branch in one operation
- **Clear guidance** - Interactive prompts make branch creation intuitive

## Tips

- **Meaningful names** - Use descriptive branch names like `feature/user-dashboard` or `bugfix/login-error`
- **Choose the right base** - Select a base branch that makes sense for your changes
- **Regular updates** - The tool pulls latest changes from the base branch before creating yours
- **Immediate push** - Your branch is immediately available to other team members

## Error Handling

The tool handles various error conditions:

- **Invalid base branch** - Exits if the specified base branch doesn't exist
- **Empty branch name** - Prevents creation of branches with empty names
- **Local branch exists** - Warns if a local branch with that name already exists
- **Remote branch exists** - Warns if a remote branch with that name already exists
- **Push failures** - Reports if pushing to remote fails

## Integration

This tool integrates seamlessly with other dev tools:

- **Branch cleanup** - Use after completing work to clean up merged branches
- **Branch sync** - Keep your new branch up to date with remote changes
- **Git log explorer** - Explore the history of your new branch
- **Commit tools** - Start making commits on your new branch immediately
- **Track remote** - Discover other remote branches you might want to work with 