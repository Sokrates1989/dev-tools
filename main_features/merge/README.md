# Merge Commit Assistant

## Overview

The Merge Commit Assistant helps you create well-structured merge commits with AI-generated commit messages. It guides you through the merge process, handles conflicts, and generates descriptive commit messages based on the changes being merged.

## What it does

This tool performs the following operations:

1. **Analyzes merge status** - Checks if you're in a merge state or ready to merge
2. **Handles conflicts** - Detects and helps resolve merge conflicts
3. **Generates commit messages** - Uses AI to create descriptive merge commit messages
4. **Supports multiple modes** - Works with API-based AI or manual prompt generation
5. **Provides merge guidance** - Offers step-by-step assistance throughout the process
6. **Ensures clean merges** - Validates the merge state and provides feedback

## Features

- **Smart merge detection** - Automatically detects if you're in a merge state
- **Conflict resolution guidance** - Helps you resolve merge conflicts step by step
- **AI-powered commit messages** - Generates descriptive merge commit messages
- **Multiple AI modes** - Supports both API-based and manual AI interaction
- **Safety checks** - Validates repository state before proceeding
- **Interactive workflow** - Guides you through each step of the merge process
- **Error handling** - Graceful handling of merge failures and conflicts

## Usage

### From the main launcher

```bash
# Interactive mode
./start.sh
# Then select option 2) Merge commit assistant

# Direct execution
./start.sh --merge
./start.sh -m
```

### Direct execution

```bash
# Bash
./main_features/merge/git_export_merge.sh

# PowerShell
./main_features/merge/git_export_merge.ps1
```

## Workflow

### Step 1: Merge State Analysis
The tool first checks your current Git state:

```
🔀 Merge Commit Assistant
=========================

📍 Current branch: feature/new-feature
🔍 Checking merge status...

✅ Ready to merge: You have staged changes ready for commit
```

### Step 2: Conflict Detection
If conflicts exist, the tool helps you resolve them:

```
⚠️  Merge conflicts detected in:
   src/components/Button.js
   src/utils/helpers.js

🔄 Please resolve conflicts manually, then:
   1. Stage resolved files: git add <filename>
   2. Continue with merge: git commit
```

### Step 3: AI Message Generation
The tool generates a merge commit message using AI:

```
🤖 Generating merge commit message...

📝 Suggested commit message:
   Merge feature/new-feature into main

   - Add new user dashboard components
   - Implement user authentication flow
   - Update API endpoints for user management
   - Fix responsive design issues

   Conflicts resolved:
   - src/components/Button.js: Updated styling
   - src/utils/helpers.js: Enhanced utility functions
```

### Step 4: Message Review and Edit
You can review and edit the generated message:

```
👉 Use this commit message? [Y/n/e]: e

📝 Edit commit message (save and close to continue):
```

### Step 5: Commit Execution
The tool executes the merge commit:

```
🔄 Creating merge commit...
✅ Merge commit created successfully!

📋 Commit details:
   Hash: a1b2c3d4e5f6
   Message: Merge feature/new-feature into main
   Files: 15 changed, 3 conflicts resolved
```

## Example Output

```
🔀 Merge Commit Assistant
=========================

📍 Current branch: feature/new-feature
🔍 Checking merge status...

✅ Ready to merge: You have staged changes ready for commit

🤖 Generating merge commit message using AI...

📝 Generated commit message:
   Merge feature/new-feature into main

   This merge introduces the new user dashboard feature with:
   - Enhanced user interface components
   - Improved authentication flow
   - Updated API integration
   - Responsive design improvements

   Changes include:
   - 12 new components added
   - 8 existing components updated
   - 3 utility functions enhanced
   - 2 API endpoints modified

👉 Use this commit message? [Y/n/e]: y

🔄 Creating merge commit...
✅ Merge commit created successfully!

📋 Commit details:
   Hash: a1b2c3d4e5f6
   Message: Merge feature/new-feature into main
   Files: 15 changed, 3 conflicts resolved

🎉 Merge completed successfully!
```

## AI Integration

The tool supports two AI modes:

### API Mode (Recommended)
- **Direct AI calls** - Uses your OpenAI or Azure API key
- **Real-time generation** - Instantly generates commit messages
- **Configurable models** - Choose your preferred AI model
- **Temperature control** - Adjust creativity vs consistency

### Manual Mode
- **Prompt generation** - Creates prompts for copy/paste into AI tools
- **No API required** - Works with any AI service (ChatGPT, Claude, etc.)
- **Full control** - Edit prompts before sending to AI
- **Offline capable** - No internet connection required for prompt generation

## Benefits

- **Professional commits** - AI-generated messages are descriptive and consistent
- **Conflict resolution** - Step-by-step guidance for resolving merge conflicts
- **Time saving** - Automates the tedious process of writing merge commit messages
- **Consistency** - Ensures all merge commits follow the same format and style
- **Error prevention** - Validates merge state and prevents common mistakes
- **Team collaboration** - Clear commit messages help team members understand changes

## Tips

- **Resolve conflicts first** - Always resolve conflicts before generating commit messages
- **Review AI messages** - Always review and edit AI-generated messages as needed
- **Use descriptive branch names** - Good branch names help AI generate better messages
- **Stage all changes** - Ensure all relevant changes are staged before merging
- **Test after merge** - Always test your application after completing a merge

## Error Handling

The tool handles various error conditions:

- **No merge state** - Guides you to start a merge if needed
- **Unresolved conflicts** - Provides step-by-step conflict resolution guidance
- **AI failures** - Falls back to manual mode if AI generation fails
- **Invalid repository state** - Validates Git state before proceeding
- **Commit failures** - Reports detailed error information if commit fails

## Integration

This tool integrates seamlessly with other dev tools:

- **Commit tools** - Use before merging to ensure clean commit history
- **Branch tools** - Merge feature branches back to main/develop
- **Git log explorer** - Review merge history after completion
- **Branch cleanup** - Clean up merged branches after successful merge
- **Sync tools** - Keep branches up to date before merging 