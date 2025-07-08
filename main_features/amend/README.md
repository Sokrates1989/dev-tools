# Git Amend Feature

## Overview

The Git Amend feature allows you to modify the last commit in your repository **only if it hasn't been pushed to remote**. This is useful when you need to:
- Add forgotten files to the last commit
- Fix a typo in the commit message
- Regenerate the commit message with AI assistance
- Make small adjustments before pushing

**Note**: If the commit has already been pushed to remote, the tool will prevent amending and instead guide you to create a new commit, which is safer and won't rewrite history.

## Features

### 1. Amend Without Changing Message
- Uses `git commit --amend --no-edit`
- Keeps the original commit message
- Useful when you just want to add files or make small changes

### 2. Amend With New Message
- Temporarily removes the last commit (keeping changes staged)
- Uses the existing commit functionality to generate a new AI-powered message
- Creates a new commit with the regenerated message
- Reuses all the existing commit features (API/Manual modes, editing, etc.)

## Safety Features

- **Push Detection**: Prevents amending commits that have been pushed to remote
- **Smart Redirect**: Automatically offers to create a new commit instead
- **Confirmation Prompts**: Asks for confirmation before making changes
- **Error Handling**: Validates git repository and commit existence

## Usage

### From the Main Menu
```bash
# Run the main launcher
./start.sh

# Choose option 6: "🔄 Amend Last Commit"
```

### Direct Command Line
```bash
# Using the main launcher with flags
./start.sh --amend
# or
./start.sh -a
```

### PowerShell
```powershell
# Using the main launcher with flags
.\start.ps1 -amend
# or
.\start.ps1 -a
```

## Workflow

1. **Repository Check**: Ensures you're in a git repository with commits
2. **Commit Info Display**: Shows the last commit hash, message, and branch
3. **Push Status Check**: 
   - If pushed: Prevents amend and offers to create new commit instead
   - If not pushed: Proceeds with amend options
4. **Option Selection**: Choose between no-edit amend or regenerate message
5. **Confirmation**: Confirm the action before proceeding
6. **Execution**: Performs the amend operation

## Integration

The amend feature is fully integrated with the existing commit functionality:
- Uses the same AI modes (API/Manual) from `.env`
- Reuses the commit message prompt templates
- Leverages existing utility functions
- Maintains consistency with other dev-tools features

## Files

- `git_amend.sh` - Bash implementation
- `git_amend.ps1` - PowerShell implementation
- `README.md` - This documentation

## Dependencies

- Git repository with at least one commit
- Existing commit functionality (for message regeneration)
- Environment configuration (`.env` file)
- Same dependencies as the commit feature 