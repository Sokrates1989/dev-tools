# 🧰 Dev AI Toolbox – Daily Prompts, Scripts & Helpers

## 📜 Description

This repository contains curated prompts, helpful scripts, command snippets, and tips that support and accelerate daily development tasks. It’s designed as a productivity-first toolbox that integrates easily into your workflow—whether you're working in VSCode, Android Studio, or on the command line.

---

## Table of Contents

1. [📖 Overview](#-overview)

2. [🧑‍💻 Usage](#-usage)

3. [🛠️ Configuration](#-configuration)

4. [🧠 Prompts & AI Usage](#-prompts--ai-usage)

- [🧠 Continue / ChatGPT Prompts](#-continue--chatgpt-prompts)

5. [🧰 Useful Git Commands](#-useful-git-commands)

- [🔍 git log Essentials](#-git-log-essentials)

6. [📋 Commit Message Helpers](#-commit-message-helpers)

- [✍️ AI-Aided Messages](#-ai-aided-messages)

7. [📂 IDE Integrations](#-ide-integrations)

- [🧩 VSCode & Continue](#-vscode--continue)

... [🛟 Troubleshooting & Notes](#-troubleshooting--notes)

 - [📌 Known Issues](#-known-issues)

X. [🚀 Summary](#-summary)

---

## 📖 Overview

This project serves as a centralized location for commonly used development aids. Rather than searching the web for syntax or tools every day, this collection brings essential elements together into a format that's copy-paste friendly and IDE-integrated (especially with tools like Continue, ChatGPT, or Anthropic Claude).

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

Example Continue Prompt:

```bash
@files Write a README using the following template and logic: ...
```

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

## 📋 Commit Message Helpers

### ✍️ AI-Aided Messages

Use the `commit_message_staged` or `commit_message_any_changes` slash commands with task ID context to auto-generate commit messages.

Example Prompt:

```text
Write a commit message for the above git changes. Use this format:  
git commit -m "[ID-XY | Category] Affected file(s): short description"
```

---

## 📂 IDE Integrations

### 🧩 VSCode & Continue

- Install the **Continue** extension
- Configure models via `config.json`
- Add custom prompts using `customCommands`

Tips:
- Use @context or @file selection to get focused results
- Use CMD+L for prompt quicklaunch

## 🚀 Summary

This repo provides you with everything you need to streamline your dev routine:

✅ **Predefined AI Prompts for Dev Tasks**  
✅ **CLI & Git Command Shortcuts**  
✅ **Config Templates for Continue/ChatGPT Integration**  
✅ **IDE Custom Commands for Efficiency**

Start integrating this into your daily workflow to save time and brainpower!
```
