# Commit Message Helper

## Overview

The Commit Message Helper is a powerful tool that exports staged Git changes and generates AI-powered commit messages. It creates a comprehensive snapshot of your changes, exports them to a structured format, and uses AI to generate descriptive commit messages that follow best practices.

## What it does

This tool performs the following operations:

1. **Exports staged changes** - Creates a structured export of all staged files and their changes
2. **Generates commit messages** - Uses AI to create descriptive, professional commit messages
3. **Supports multiple modes** - Works with API-based AI or manual prompt generation
4. **Creates change snapshots** - Saves staged files to a `changed_files/` directory
5. **Provides diff summaries** - Generates detailed diff output for review
6. **Handles various file types** - Works with any type of file in your repository

## Features

- **Comprehensive export** - Exports all staged files with their complete content
- **AI-powered messages** - Generates commit messages using OpenAI or Azure AI
- **Multiple AI modes** - Supports both API-based and manual AI interaction
- **Structured output** - Creates organized file exports and diff summaries
- **Interactive workflow** - Review and edit generated commit messages
- **Safety checks** - Validates staged changes and repository state
- **Cross-platform** - Works on Linux, macOS, and Windows

## Usage

### From the main launcher

```bash
# Interactive mode
./start.sh
# Then select option 1) Commit Message Helper

# Direct execution
./start.sh --commit
./start.sh -c
```

### Direct execution

```bash
# Bash
./main_features/commit/git_export_staged.sh

# PowerShell
./main_features/commit/git_export_staged.ps1
```

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

📝 Diff summary saved to: diff_output.txt
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

📝 Diff summary saved to: diff_output.txt

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
changed_files/
├── src/
│   ├── components/
│   │   ├── Dashboard.js          # Modified file
│   │   └── UserProfile.js        # Added file
│   └── utils/
│       └── old-helper.js         # Deleted file (marked)
├── diff_output.txt               # Complete diff summary
└── export_info.txt               # Export metadata
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