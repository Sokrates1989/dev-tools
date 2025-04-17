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

4. [🧭 Toolbox Features](#-toolbox-features)
   - [🧱 Commit Exporter](#-commit-exporter)
   - [🔍 Git Log Explorer](#-git-log-explorer)

5. [🪟 Platform Support](#-platform-support)
   - [🖥️ Linux / macOS](#-linux--macos)
   - [🪟 Windows PowerShell](#-windows-powershell)

6. [🧪 Extending the Toolbox](#-extending-the-toolbox)
   - [➕ Add More Tools](#-add-more-tools)

7. [🚀 Summary](#-summary)

---

## 📖 Overview

This toolbox provides a unified `start.sh` (for Linux/macOS) and `start.ps1` (for Windows) that act as an entry point into your dev-helper ecosystem. It’s built with flexibility in mind — offering interactive menus, quick flag execution (`--commit`, `--log`), and tool-specific submenus that allow you to preview and run Git commands effortlessly.

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

Install the toolbox under a global tools directory: `/tools/dev-tools`

```bash
sudo mkdir -p /tools/dev-tools
sudo chown "$USER" /tools/dev-tools
git clone https://github.com/Sokrates1989/dev-tools.git /tools/dev-tools
```

Launch via:

```bash
bash /tools/dev-tools/start.sh
```

---

### 🍏 macOS (Manual Setup with Temp Folder)

Install Dev Tools under `~/tools/dev-tools`, create a global `dev-tools` command, and make it persistent:

Simply copy and run the following block in your terminal:

```bash
mkdir -p /tmp/devtools-setup && cd /tmp/devtools-setup
curl -sO https://raw.githubusercontent.com/Sokrates1989/dev-tools/main/setup/macos.sh
bash macos.sh
cd ~ && rm -rf /tmp/devtools-setup
```

### 🪟 Windows (System-Wide Installation with Global Commands)

Install Dev Tools into `C:\tools\dev-tools` and make it available globally using `dev-tools` and `open`.

Simply copy and run the following block in a PowerShell window **run as Administrator**:

```powershell
# Step 1: Create the target directory structure.
New-Item -ItemType Directory -Path "C:\tools\dev-tools" -Force

# Step 2: Take ownership of the dev-tools folder (avoids permission issues).
$acl = Get-Acl "C:\tools\dev-tools"
$acl.SetOwner([System.Security.Principal.NTAccount]"$env:USERNAME")
Set-Acl "C:\tools\dev-tools" $acl

# Step 3 (optional but recommended): Grant yourself full access recursively.
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "$env:USERNAME", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl "C:\tools\dev-tools" $acl

# Step 4: Clone the Dev Tools repository.
cd C:\tools\dev-tools
git clone https://github.com/Sokrates1989/dev-tools.git .

# Step 5: Set up quick commands for this session.
Set-Alias dev-tools "C:\tools\dev-tools\start.ps1"
Set-Alias open       "C:\tools\dev-tools\global_functions\open.ps1"

# Step 6: Show alias lines and prompt before editing profile.
Write-Host ""
Write-Host "📋 Copy the lines below, then paste them into the file that opens:"
Write-Host ""
Write-Host "# Dev-tools (https://github.com/Sokrates1989/dev-tools)"
Write-Host "Set-Alias dev-tools `"C:\tools\dev-tools\start.ps1`""
Write-Host "Set-Alias open       `"C:\tools\dev-tools\global_functions\open.ps1`""
Write-Host ""
Read-Host "📄 Press Enter to open your PowerShell profile..."
notepad $PROFILE

# Step 7: Create .env file from .env.template.
Copy-Item "C:\tools\dev-tools\.env.template" "C:\tools\dev-tools\.env" -Force

# Step 8: Configure settings.
Write-Host ""
Write-Host "🤖 AI Usage Mode Setup:"
Write-Host "   - 'manual' → prepares the prompt and opens it for copy/paste into ChatGPT or other AI tools"
Write-Host "   - 'api'    → directly calls the ChatGPT API using your key and model settings (must provide AI-API settings below)"
Write-Host ""
Read-Host "📄 Press Enter to open your .env file for editing..."
notepad "C:\tools\dev-tools\.env"


# Step 9: Done: Luanch the tool.
Write-Host ""
Write-Host "After having saved the .env file try it out: Just type:"
Write-Host "dev-tools"
```


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
bash /tools/dev-tools/start.sh            # interactive mode
bash /tools/dev-tools/start.sh --commit   # quick launch: export staged files
bash /tools/dev-tools/start.sh --log      # quick launch: Git log explorer
```

---

### 🍏 macOS Usage


🧪 You can now run Dev Tools from anywhere:

```bash
dev-tools         # launch the toolbox
dev-tools -c      # quick export of staged Git commit
```

---

### 🪟 Windows Usage


```powershell
dev-tools        # launch the toolbox
dev-tools -c     # quick export of staged Git commit
open .           # open current folder in Explorer
open C:\anywhere

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
