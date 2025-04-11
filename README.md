# 🧰 Dev AI Toolbox – Daily Prompts, Scripts & Helpers

## 📜 Description

The **Dev AI Toolbox** is a developer-friendly command-line toolset designed to streamline your daily Git workflows. It features an interactive launcher that lets you run helpful tools like commit exporters and Git log explorers, with support for quick-access flags, smart feedback, and clipboard-ready diffs – all tailored for both Linux/macOS and Windows PowerShell environments.

---

## Table of Contents

1. [📖 Overview](#-overview)

2. [🚀 First-Time Setup](#-first-time-setup)

   - [🔧 Prerequisites](#-prerequisites)
   - [📦 Installation](#-installation)
   - [🧬 Environment Setup](#-environment-setup-required-for-ai-based-features)
   - [🔗 Optional Symlink Setup (macOS)](#-optional-symlink-setup-macos)

3. [🧑‍💻 Usage](#-usage)

4. [🛠️ Configuration](#-configuration)

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

#### 🐧 Linux

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

#### 🍏 macOS

Install under your user folder at `~/tools/dev-tools`:

```bash
mkdir -p ~/tools/dev-tools
cd ~/tools/dev-tools
git clone https://github.com/Sokrates1989/dev-tools.git .
```

Launch via:

```bash
bash ~/tools/dev-tools/start.sh
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

#### 🔗 Optional Symlink Setup (macOS)

To run the toolbox using `dev-tools` from anywhere in your terminal instead of calling `bash ~/tools/dev-tools/start.sh`, follow these steps:

---

#### 🕵️ Step 0: Determine your shell

Check which shell you're currently using:

```bash
echo $SHELL
```

Expected outputs:
- `/bin/zsh` → you're using **Zsh** (macOS default since Catalina)
- `/bin/bash` → you're using **Bash**

We'll adjust the config accordingly in the next steps.

---

#### 🛠️ Step-by-Step Instructions

1. ✅ Make the script executable (if not already):

```bash
chmod +x ~/tools/dev-tools/start.sh
```

2. ✅ Create a local bin directory (if it doesn't exist):

```bash
mkdir -p ~/.local/bin
```

3. ✅ Create a symbolic link pointing to your launcher:

```bash
ln -s ~/tools/dev-tools/start.sh ~/.local/bin/dev-tools
```

4. ✅ Add `~/.local/bin` to your `PATH`  
(Choose your shell below ⬇️)

##### For Zsh users (`/bin/zsh`):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

##### For Bash users (`/bin/bash`):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

5. ✅ Test it from anywhere in your terminal:

```bash
dev-tools
dev-tools -c   # for quick commit export
```

---

#### 🪟 Windows

Install globally under `C:\tools\dev-tools` (admin required **once**):

1. ✅ **Create the folder** (run PowerShell as Administrator):

```powershell
New-Item -ItemType Directory -Path "C:\tools" -Force

# Optional: Make yourself the owner (avoids needing admin later)
$acl = Get-Acl "C:\tools"
$acl.SetOwner([System.Security.Principal.NTAccount]"$env:USERNAME")
Set-Acl "C:\tools" $acl
```

2. ✅ **Clone the toolbox** (normal PowerShell):

```powershell
git clone https://github.com/Sokrates1989/dev-tools.git "C:\tools\dev-tools"
```

Launch via:

```powershell
C:\tools\dev-tools\start.ps1
```

---

## 🧑‍💻 Usage

### 🐧 Linux

Installed to `/tools/dev-tools`:

```bash
bash /tools/dev-tools/start.sh            # interactive mode
bash /tools/dev-tools/start.sh --commit   # quick launch: export staged files
bash /tools/dev-tools/start.sh --log      # quick launch: Git log explorer
```

---

### 🍏 macOS

Installed to `~/tools/dev-tools`:

```bash
bash ~/tools/dev-tools/start.sh           # interactive mode
bash ~/tools/dev-tools/start.sh --commit  # quick launch: export staged files
bash ~/tools/dev-tools/start.sh --log     # quick launch: Git log explorer
```

Symlink usage implemented:

```bash
dev-tools           # interactive mode
dev-tools --commit  # quick launch: export staged files
dev-tools --log     # quick launch: Git log explorer
```

---

### 🪟 Windows PowerShell

Installed to `C:\tools\dev-tools`:

```powershell
C:\tools\dev-tools\start.ps1                      # interactive mode
C:\tools\dev-tools\start.ps1 -Command "--commit"  # quick launch
C:\tools\dev-tools\start.ps1 -Command "--log"     # quick launch
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
