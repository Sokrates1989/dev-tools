# 🧰 Dev AI Toolbox – Daily Prompts, Scripts & Helpers

## 📜 Description

The **Dev AI Toolbox** is a developer-friendly command-line toolset designed to streamline your daily Git workflows. It features an interactive launcher that lets you run helpful tools like commit exporters and Git log explorers, with support for quick-access flags, smart feedback, and clipboard-ready diffs – all tailored for both Linux/macOS and Windows PowerShell environments.

---

## Table of Contents

1. [📖 Overview](#-overview)

2. [🚀 First-Time Setup](#-first-time-setup)
   - [🔧 Prerequisites](#-prerequisites)
   - [📦 Installation](#-installation)
     - [🐧 Linux](#-linux-installation)
     - [🍏 macOS](#-macos-manual-setup-with-temp-folder)
     - [🪟 Windows](#-windows-system-wide-installation-with-global-commands)
   - [🧬 Environment Setup](#-environment-setup-required-for-ai-based-features)

3. [🧑‍💻 Usage](#-usage)
   - [🐧 Linux](#-linux-usage)
   - [🍏 macOS](#-macos-usage)
   - [🪟 Windows](#-windows-usage)

4. [🗑️ Uninstallation](#-uninstallation)
   - [🐧 Linux / 🍏 macOS](#-linux---macos-uninstallation)
   - [🪟 Windows](#-windows-uninstallation)

5. [🧭 Toolbox Features](#-toolbox-features)
   - [🧱 Commit Exporter](#-commit-exporter)
   - [🔍 Git Log Explorer](#-git-log-explorer)

6. [🪟 Platform Support](#-platform-support)
   - [🖥️ Linux / macOS](#-linux--macos)
   - [🪟 Windows PowerShell](#-windows-powershell)

7. [🧪 Extending the Toolbox](#-extending-the-toolbox)
   - [➕ Add More Tools](#-add-more-tools)

8. [🚀 Summary](#-summary)

---

## 📖 Overview

This toolbox provides a unified `start.sh` (for Linux/macOS) and `start.ps1` (for Windows) that act as an entry point into your dev-helper ecosystem. It’s built with flexibility in mind — offering interactive menus, quick flag execution (`--commit`, `--cc`, `--log`), and tool-specific submenus that allow you to preview and run Git commands effortlessly.

---
## 🚀 First-Time Setup

---

### 🔧 Prerequisites

#### 🐧 Linux

- Requires **Bash** and **Git** (usually pre-installed)

If needed:

```bash
sudo apt update && sudo apt install bash git   # Debian/Ubuntu
# or
sudo dnf install bash git                      # RHEL/Fedora
```

#### 🍏 macOS

- **Bash** and **Git** are pre-installed
- (Optional) Consider installing Git via Homebrew for updates

```bash
brew install git
```

#### 🪟 Windows

- Requires **Git for Windows** (includes Git Bash)
- Also supports **PowerShell**

Download and install from: https://git-scm.com/download/win

---

### 📦 Installation

#### 🐧 Linux Installation

Install Dev Tools under `~/tools/dev-tools`, create a global `dev-tools` command, and make it persistent:

See [INSTALL.md](INSTALL.md) for detailed installation commands.

---

#### 🍏 macOS (Manual Setup with Temp Folder)

Install Dev Tools under `~/tools/dev-tools`, create a global `dev-tools` command, and make it persistent:

See [INSTALL.md](INSTALL.md) for detailed installation commands.

#### 🪟 Windows (System-Wide Installation with Global Commands)

Install Dev Tools into `C:\tools\dev-tools` and make it available globally using `dev-tools` and `open`.

See [INSTALL.md](INSTALL.md) for detailed installation commands.


### 🧬 Environment Setup (Required for AI-based features)

To enable features that require API access (e.g. OpenAI), you must set up your environment variables:

1. ✅ Copy the provided `.env.template` file to `.env`:

```bash
cp .env.template .env
```

2. ✅ Open the `.env` file in your editor and **add your API key**:

```bash
# Example content inside .env
OPENAI_API_KEY=sk-xxxxxx-your-key-here
```

3. ✅ Save the file.

---

## 🧑‍💻 Usage

### 🐧 Linux Usage

Installed to `/tools/dev-tools`:

```bash
dev-tools            # interactive mode
dev-tools --commit   # quick launch: export staged files
dev-tools --cc       # quick launch: show commit style instructions for external AI
dev-tools --log      # quick launch: Git log explorer
```

---

### 🍏 macOS Usage


🧪 You can now run Dev Tools from anywhere:

```bash
dev-tools         # launch the toolbox
dev-tools -c      # quick export of staged Git commit
dev-tools -cc     # show commit style instructions for external AI
```

---

### 🪟 Windows Usage


```powershell
dev-tools        # launch the toolbox
dev-tools -c     # quick export of staged Git commit
dev-tools -cc    # show commit style instructions for external AI
open .           # open current folder in Explorer
open C:\anywhere
```
---

## 🗑️ Uninstallation

### 🐧 Linux / 🍏 macOS Uninstallation

To completely remove Dev Tools and all its components, run the uninstall script:

```bash
# Run the uninstall script from the installed location:
bash ~/tools/dev-tools/setup/uninstall.sh
```

The uninstaller will:
- ✅ Remove the global `dev-tools` command
- ✅ Delete the `~/tools/dev-tools` directory
- ✅ Remove PATH updates from your shell config (`.zshrc` or `.bashrc`)
- ✅ Clean up empty directories
- ✅ Create backups of modified config files

### 🪟 Windows Uninstallation

To completely remove Dev Tools from Windows:

```powershell
# Remove the aliases from your PowerShell profile
notepad $PROFILE
# Delete these lines from the file:
# Set-Alias dev-tools "C:\tools\dev-tools\start.ps1"
# Set-Alias open       "C:\tools\dev-tools\global_functions\open.ps1"

# Remove the installation directory
Remove-Item -Recurse -Force "C:\tools\dev-tools"

# Remove the tools directory if empty
if ((Get-ChildItem "C:\tools" -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
    Remove-Item "C:\tools"
}
```

---

## 🛠️ Configuration

No special configuration is required. The toolbox uses:

- **Git CLI**: Make sure it's installed and available in your `$PATH`.
- **PowerShell execution policy**: May need to be adjusted to allow scripts to run:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```
- **Clipboard tools (Linux)**:
  - `xclip` for X11
  - `wl-clipboard` for Wayland
  - Auto-detected in the script for CLI-only Linux environments

---

## 🧭 Toolbox Features

### 🧱 Commit Exporter

- Collects all staged files and saves them to a flat `changed_files/` folder.
- Generates a `last_staged_commit_diff.txt` file for diffs.
- Creates a snapshot summary in CLI-only environments.
- Auto-opens the export folder in graphical environments.
- Warns if no staged files are present.

Quick command: `--commit` or `-c`

### 🤖 Commit Style Instructions for External AI

- Opens the shared commit style guide from `main_features/commit/commit_message_prompt.txt`.
- Does not inspect git state, staged files, or the current repository.
- Lets you paste only the style instructions into another AI that already knows the change context.

Quick command: `--cc` or `-cc`

---

### 🔍 Git Log Explorer

- Interactive menu to run preconfigured `git log` commands:
  - Pretty logs
  - Graphs
  - File-based diffs
  - Author/date filters
  - Reverse history
  - Patch output and statistics
- Lets you preview each command before execution
- Includes:
  - `b` → return to main menu
  - `q` → exit toolbox

Quick command: `--log` or `-l`

---

## 🪟 Platform Support

### 🖥️ Linux / macOS

Use the `start.sh` entry point. Scripts auto-detect X11/Wayland GUI or terminal-only environments.

::: tip
Use `Ctrl + H` to show hidden files (e.g., `.gitignore`) in most Linux file managers.
:::

### 🪟 Windows PowerShell

Use the `start.ps1` entry point. Folders are opened using `explorer.exe`.

::: tip
Enable "Hidden items" under the Explorer "View" tab to see files like `.gitignore`.
:::

---

## 🧪 Extending the Toolbox

### ➕ Add More Tools

1. Create a new folder under `dev-tools/` (e.g., `lint`, `deploy`)
2. Add your script there
3. Update both `start.sh` and `start.ps1`:
   - Add it to the interactive menu
   - Add quick flag support (e.g. `--lint` / `-l`)

Use the same submenu pattern as `git_log_explorer.sh` / `.ps1`.

---

## 🚀 Summary

✅ **Unified dev tool launcher for Bash and PowerShell**  
✅ **Export staged Git changes with one click**  
✅ **Explore Git history with an interactive menu**  
✅ **Quick launch flags for fast access**  
✅ **Modular and easy to extend**

Let the Dev AI Toolbox speed up your daily Git workflow ✨
