# Commit Message Helper with Automated Version Management

## Overview

The Commit Message Helper is a powerful tool that exports staged Git changes, manages semantic versioning for CI/CD workflows, and generates AI-powered commit messages. It automatically detects CI/CD configurations, manages IMAGE_VERSION across `.env` and `.ci.env` files, and creates professional commit messages with version tracking.

## What it does

This tool performs the following operations:

1. **CI/CD Detection** - Automatically detects `.ci.env` files and CI/CD configurations
2. **Version Management** - Manages IMAGE_VERSION in `.env` and `.ci.env` files with semantic versioning
3. **Smart Version Selection** - Uses the higher semantic version when files differ
4. **Staged Version Detection** - Detects existing version changes and prompts for acceptance
5. **JIRA Integration** - Optionally includes JIRA task IDs in commit messages
6. **AI Commit Messages** - Generates professional messages with version and JIRA tracking
7. **Exports staged changes** - Creates a structured export of all staged files and their changes
8. **Automatic File Sync** - Keeps `.env` and `.ci.env` in sync when accepting staged versions

## Features

### Version Management
- **Automatic CI/CD detection** - Detects `.ci.env` and GitHub workflows
- **Semantic version comparison** - Compares MAJOR.MINOR.PATCH versions intelligently
- **Higher version selection** - Always uses the highest version as base
- **Staged version detection** - Shows old → new version changes from git diff
- **Accept/reject prompts** - User can accept staged version or choose a new one
- **Auto-increment options** - PATCH, MINOR, or MAJOR version bumps
- **File synchronization** - Keeps `.env` and `.ci.env` in perfect sync
- **Smart staging** - Only stages `.ci.env` for commit (`.env` stays local)

### Commit Message Generation
- **Version tracking** - Includes IMAGE_VERSION in commit message: `[0.3.1 | Feature]`
- **JIRA integration** - Optional JIRA task ID: `[PROJ-123 | 0.3.1 | Feature]`
- **Clean placeholders** - Removes unused placeholders automatically
- **AI-powered messages** - Generates commit messages using OpenAI or Azure AI
- **Interactive workflow** - Review, edit, regenerate, or chat with AI
- **Multiple AI modes** - Supports both API-based and manual AI interaction

### Export and Safety
- **Comprehensive export** - Exports all staged files with their complete content
- **Structured output** - Creates organized file exports and diff summaries
- **Safety checks** - Validates staged changes and repository state
- **Cross-platform** - Works on Linux, macOS, and Windows (PowerShell and Bash)
- **File integrity** - Preserves line endings and file structure

## Usage

### From the main launcher

```bash
# Interactive mode
./start.sh
# Then select option 1) Commit Message Helper
# Or select option cc) Commit style instructions for external AI

# Direct execution
./start.sh --commit
./start.sh -c
./start.sh --cc
./start.sh -cc
```

### Direct execution

```bash
# Bash
./main_features/commit/git_export_staged.sh
# Shows only the shared commit style guide for copy/paste into another AI
./main_features/commit/create_commit_with_external_ai.sh

# PowerShell
./main_features/commit/git_export_staged.ps1
# Shows only the shared commit style guide for copy/paste into another AI
./main_features/commit/create_commit_with_external_ai.ps1
```

### External AI Mode

The external AI entrypoint is intentionally lightweight. It only shows the shared `commit_message_prompt.txt` strategy file so you can paste the commit style rules into another AI that already knows the change context. It does not inspect git state, staged files, or the current repository.

## Workflow

### Step 1: Staged Changes Analysis
The tool first checks your staged changes:

```
📤 Commit Message Helper
========================

📍 Current branch: feature/new-dashboard
🔍 Analyzing staged changes...

📋 Staged files (3):
   M  src/components/Dashboard.js
   A  src/components/UserProfile.js
   D  src/utils/old-helper.js

📊 Change summary:
   - 1 file modified
   - 1 file added
   - 1 file deleted
   - Total changes: 45 lines added, 12 lines removed
```

### Step 2: Export Creation
The tool exports your staged changes to a structured format:

```
📁 Creating export...
✅ Export created in: changed_files/
📄 Files exported:
   - src/components/Dashboard.js
   - src/components/UserProfile.js
   - src/utils/old-helper.js (deleted)

📝 Diff summary saved to: git_export_staged/last_staged_commit_diff.txt
```

### Step 3: AI Message Generation
The tool generates a commit message using AI:

```
🤖 Generating commit message using AI...

📝 Generated commit message:
   feat: add user dashboard with profile component

   - Add new UserProfile component with avatar and settings
   - Update Dashboard component with improved layout and navigation
   - Remove deprecated old-helper utility functions
   - Implement responsive design for mobile devices

   Changes include:
   - 45 lines added across 2 new/modified components
   - 12 lines removed from deprecated utility file
   - Enhanced user experience with modern UI patterns
```

### Step 4: Message Review and Edit
Review and customize the generated message:

```
👉 Use this commit message? [Y/n/e]: e

📝 Edit commit message (save and close to continue):
```

### Step 5: Commit Execution
The tool executes the commit with your chosen message:

```
🔄 Creating commit...
✅ Commit created successfully!

📋 Commit details:
   Hash: a1b2c3d4e5f6
   Message: feat: add user dashboard with profile component
   Files: 3 changed (1 added, 1 modified, 1 deleted)
```

## Example Output

```
📤 Commit Message Helper
========================

📍 Current branch: feature/new-dashboard
🔍 Analyzing staged changes...

📋 Staged files (3):
   M  src/components/Dashboard.js
   A  src/components/UserProfile.js
   D  src/utils/old-helper.js

📊 Change summary:
   - 1 file modified
   - 1 file added
   - 1 file deleted
   - Total changes: 45 lines added, 12 lines removed

📁 Creating export...
✅ Export created in: changed_files/
📄 Files exported:
   - src/components/Dashboard.js
   - src/components/UserProfile.js
   - src/utils/old-helper.js (deleted)

📝 Diff summary saved to: git_export_staged/last_staged_commit_diff.txt

🤖 Generating commit message using AI...

📝 Generated commit message:
   feat: add user dashboard with profile component

   - Add new UserProfile component with avatar and settings
   - Update Dashboard component with improved layout and navigation
   - Remove deprecated old-helper utility functions
   - Implement responsive design for mobile devices

   Changes include:
   - 45 lines added across 2 new/modified components
   - 12 lines removed from deprecated utility file
   - Enhanced user experience with modern UI patterns

👉 Use this commit message? [Y/n/e]: y

🔄 Creating commit...
✅ Commit created successfully!

📋 Commit details:
   Hash: a1b2c3d4e5f6
   Message: feat: add user dashboard with profile component
   Files: 3 changed (1 added, 1 modified, 1 deleted)

🎉 Commit completed successfully!
```

## Export Structure

The tool creates a structured export of your changes:

```
git_export_staged/
├── changed_files/
│   ├── Dashboard.js              # Modified file
│   ├── UserProfile.js            # Added file
│   └── old-helper.js             # Deleted file (marked)
├── last_staged_commit_diff.txt     # Complete diff summary
├── commit_message_prompt.txt       # Commit style instructions
└── all_in_one/
    └── ai_message.txt               # AI-ready prompt and staged context
```

## Version Management Workflows

### Scenario 1: Accepting Staged Version Change

When `.ci.env` is already staged with a version change:

```
Checking if branch is in sync with remote...
Branch 'main' is up-to-date with remote.

 CI/CD configuration detected in this repository

NOTE: .ci.env is staged and will be committed
  Version change: 0.3.0 -> 0.3.1

 Accept this staged version change? [Y/n]: 
  Using staged version: 0.3.1
  Synced .env to version: 0.3.1

 Do you want to add a JIRA task ID to the commit message? [y/N]: y
 Enter JIRA task ID (e.g., PROJ-123): PROJ-456

[OK] AI suggested commit message:
git commit -m "[PROJ-456 | 0.3.1 | New Feature] settings.py: added Cognito config"
```

### Scenario 2: Rejecting Staged Version

When you want to choose a different version:

```
 Accept this staged version change? [Y/n]: n

Current IMAGE_VERSION:
  - .env    : 0.3.4
  - .ci.env : 0.3.1

Image Version Management
============================

Base version (from .env (higher version)): 0.3.4

Update options:
[1] Auto-increment PATCH (0.3.4 -> 0.3.5)
[2] Auto-increment MINOR (0.3.4 -> 0.4.0)
[3] Auto-increment MAJOR (0.3.4 -> 1.0.0)
[4] Enter version manually

Choose option: 1

Updating version files to 0.3.5...
[OK] Updated .env -> IMAGE_VERSION=0.3.5
[OK] Updated .ci.env -> IMAGE_VERSION=0.3.5
   [OK] Staged: .ci.env

 Version updated to: 0.3.5
```

### Commit Message Formats

**With JIRA and Version:**
```
[PROJ-123 | 0.3.1 | New Feature] settings.py: added Cognito config
```

**With Version only:**
```
[0.3.1 | New Feature] settings.py: added Cognito config
```

**Without CI/CD:**
```
[New Feature] settings.py: added Cognito config
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

- **Professional commits** - AI-generated messages follow conventional commit standards
- **Comprehensive exports** - Complete snapshot of changes for review and backup
- **Time saving** - Automates the tedious process of writing commit messages
- **Consistency** - Ensures all commits follow the same format and style
- **Change tracking** - Structured exports help track and review changes
- **Team collaboration** - Clear commit messages help team members understand changes

## Tips

- **Stage relevant changes** - Only stage changes that belong together in one commit
- **Review AI messages** - Always review and edit AI-generated messages as needed
- **Use descriptive branch names** - Good branch names help AI generate better messages
- **Check exports** - Review the exported files to ensure all changes are captured
- **Follow conventions** - Use conventional commit format (feat:, fix:, docs:, etc.)

## Error Handling

The tool handles various error conditions:

- **No staged changes** - Warns if no files are staged for commit
- **Export failures** - Reports if file export cannot be completed
- **AI generation failures** - Falls back to manual mode if AI generation fails
- **Invalid repository state** - Validates Git state before proceeding
- **Commit failures** - Reports detailed error information if commit fails

## Integration

This tool integrates seamlessly with other dev tools:

- **Git log explorer** - Review commit history after creating commits
- **Branch tools** - Create commits before merging or creating new branches
- **Merge tools** - Use before merging to ensure clean commit history
- **Amend tools** - Amend commits if you need to make changes
- **Reset tools** - Reset commits if you need to undo changes

## File Types Supported

The tool works with any file type in your repository:

- **Source code** - JavaScript, Python, Java, C#, etc.
- **Configuration files** - JSON, YAML, XML, INI, etc.
- **Documentation** - Markdown, RST, HTML, etc.
- **Binary files** - Images, executables, archives, etc.
- **Data files** - CSV, TSV, SQL, etc.

## Export Features

### File Export
- **Complete content** - Exports full file content, not just diffs
- **Directory structure** - Maintains original directory hierarchy
- **File metadata** - Preserves file permissions and timestamps
- **Deleted files** - Marks deleted files for reference

### Diff Summary
- **Comprehensive diffs** - Shows all changes in detail
- **Context lines** - Includes surrounding code for context
- **File headers** - Clear file identification in diff output
- **Change statistics** - Summary of additions and deletions
