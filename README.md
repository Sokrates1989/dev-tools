# 🧰 Dev AI Toolbox – Daily Prompts, Scripts & Helpers

## 📜 Description

This repository contains curated prompts, helpful scripts, command snippets, and tips that support and accelerate daily development tasks. It’s designed as a productivity-first toolbox that integrates easily into your workflow—whether you're working in VSCode, Android Studio, or on the command line.

---

## Table of Contents

1. [📖 Overview](#-overview)

2. [🚀 First-Time Setup](#-first-time-setup)

   - [🔧 Prerequisites](#-prerequisites)
   - [📦 Installation (Safe User-Space Option)](#-installation-safe-user-space-option)
   - [🧪 Run the Staged Export Script](#-run-the-staged-export-script)

3. [🧑‍💻 Usage](#-usage)

4. [🧠 Prompts & AI Usage](#-prompts--ai-usage)

   - [🧠 Continue / ChatGPT Prompts](#-continue--chatgpt-prompts)

5. [🧰 Useful Git Commands](#-useful-git-commands)

   - [🔍 git log Essentials](#-git-log-essentials)

6. [📋 Commit Message Helpers](#-commit-message-helpers)

   - [✍️ AI-Aided Messages](#-ai-aided-messages)

7. [🚀 Summary](#-summary)

---

## 📖 Overview

This project serves as a centralized location for commonly used development aids. Rather than searching the web for syntax or tools every day, this collection brings essential elements together into a format that's copy-paste friendly and IDE-integrated (especially with tools like Continue, ChatGPT, or Anthropic Claude).

---


## 🚀 First-Time Setup

### 🔧 Prerequisites

You need **Bash** installed to use this script.

#### macOS

Bash is pre-installed on macOS. No additional setup required.

#### Debian-based systems (Ubuntu, etc.)

```bash
sudo apt update
sudo apt install bash
```

#### Red Hat-based systems (RHEL, Fedora, CentOS)

```bash
sudo yum update
sudo yum install bash
```

---

### 📦 Installation (Safe User-Space Option)

Clone the repository into your home directory under `~/tools/dev-tool`:

```bash
mkdir -p ~/tools/dev-tool
cd ~/tools/dev-tool
git clone https://github.com/Sokrates1989/dev-tools.git .
```

---

### 🧪 Run the Staged Export Script

After staging your changes via `git add`, you can export all staged files, the diff, and your commit message prompt:

```bash
bash ~/tools/dev-tool/commit/git_export_staged.sh
```

- On **macOS**, the folder will open in Finder  
- On **graphical Linux**, it opens in your file manager  
- On **CLI-only Linux**, a combined file is generated with guidance on how to copy it

---

## 🧑‍💻 Usage

To use this project, simply browse the folders or use AI-assisted tools with the provided prompt structures.

---

## 🧠 Prompts & AI Usage

Use the provided prompt structures with Continue or ChatGPT to automate and accelerate your workflow.

### 🧠 Continue / ChatGPT Prompts

- **Generate README**  
- **Write Commit Messages**  
- **Explain Code / Audit for Bugs**  
- **Generate Docstrings / Add Comments**  
- **Optimize Code**

---

## 🧰 Useful Git Commands

Commands you want at your fingertips every day.

### 🔍 git log Essentials

```bash
git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"
```

```bash
git log --all --decorate --oneline --graph
```

```bash
git log --since="2023-01-01" --until="2023-12-31" -- filename.txt
```

---

## 📋 Commit Message Help



---

## 🚀 Summary

This repo provides you with everything you need to streamline your dev routine:

✅ **Predefined AI Prompts for Dev Tasks**  
✅ **CLI & Git Command Shortcuts**  
✅ **Config Templates for Continue/ChatGPT Integration**  
✅ **IDE Custom Commands for Efficiency**

Start integrating this into your daily workflow to save time and brainpower!
```
