# 🚀 Quick Install Commands

## 🍏 macOS / 🐧 Linux Installation

### Option 1: Direct Download (May require authentication)

Install Dev Tools under `~/tools/dev-tools`, create a global `dev-tools` command, and make it persistent  
Copy below and execute in the terminal:
```bash
ORIGINAL_DIR=$(pwd)
mkdir -p /tmp/devtools-setup && cd /tmp/devtools-setup
curl -sO https://raw.githubusercontent.com/Sokrates1989/dev-tools/main/setup/macos.sh
bash macos.sh
cd "$ORIGINAL_DIR"
rm -rf /tmp/devtools-setup
```

**If you see HTML content instead of the script, use this alternative:**

```bash
ORIGINAL_DIR=$(pwd)
mkdir -p /tmp/devtools-setup && cd /tmp/devtools-setup

# Create macos.sh manually
touch macos.sh
nano macos.sh
# Copy content from: https://raw.githubusercontent.com/Sokrates1989/dev-tools/main/setup/macos.sh

bash macos.sh
cd "$ORIGINAL_DIR"
rm -rf /tmp/devtools-setup
```

## 🐧 Linux Installation

### Option 1: Direct Download (May require authentication)

Install Dev Tools under `~/tools/dev-tools`, create a global `dev-tools` command, and make it persistent  
Copy below and execute in the terminal:
```bash
ORIGINAL_DIR=$(pwd)
mkdir -p /tmp/devtools-setup && cd /tmp/devtools-setup
curl -sO https://raw.githubusercontent.com/Sokrates1989/dev-tools/main/setup/linux-cli.sh
bash linux-cli.sh
cd "$ORIGINAL_DIR"
rm -rf /tmp/devtools-setup
```

**If you see HTML content instead of the script, use this alternative:**

```bash
ORIGINAL_DIR=$(pwd)
mkdir -p /tmp/devtools-setup && cd /tmp/devtools-setup

# Create linux-cli.sh manually
touch linux-cli.sh
nano linux-cli.sh
# Copy content from: https://raw.githubusercontent.com/Sokrates1989/dev-tools/main/setup/linux-cli.sh

bash linux-cli.sh
cd "$ORIGINAL_DIR"
rm -rf /tmp/devtools-setup
```

## 🪟 Windows Installation

### Option 1: Direct Download (May require authentication)

Install Dev Tools into `C:\tools\dev-tools` and make it available globally:

```powershell
# Run in PowerShell as Administrator
New-Item -ItemType Directory -Path "C:\tools\dev-tools" -Force
cd C:\tools\dev-tools
git clone https://github.com/Sokrates1989/dev-tools.git .
Copy-Item "C:\tools\dev-tools\.env.template" "C:\tools\dev-tools\.env" -Force
notepad $PROFILE
# Add these lines to your profile:
# Set-Alias dev-tools "C:\tools\dev-tools\start.ps1"
# Set-Alias open       "C:\tools\dev-tools\global_functions\open.ps1"
```

**If you get authentication errors, use this alternative:**

```powershell
# Run in PowerShell as Administrator
New-Item -ItemType Directory -Path "C:\tools\dev-tools" -Force
cd C:\tools\dev-tools

# Create windows.ps1 manually
New-Item -ItemType File -Path "windows.ps1" -Force
notepad windows.ps1
# Copy content from: https://raw.githubusercontent.com/Sokrates1989/dev-tools/main/setup/windows.ps1

# Run the setup
powershell -ExecutionPolicy Bypass -File windows.ps1
```

## 🗑️ Uninstallation

### macOS / Linux
```bash
bash ~/tools/dev-tools/setup/uninstall.sh
```

### Windows
```powershell
Remove-Item -Recurse -Force "C:\tools\dev-tools"
# Remove aliases from PowerShell profile manually
``` 