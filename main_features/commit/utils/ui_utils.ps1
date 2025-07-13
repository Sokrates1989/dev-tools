# -----------------------------------------------------------------------------
# Script: ui_utils.ps1
# Description: Utility functions for UI operations in commit scripts
# Platform: Windows PowerShell 5.1 compatible
# -----------------------------------------------------------------------------

# Function to show commit message options menu
function Show-CommitOptions {
    param(
        [string]$CommitMessage
    )
    
    Write-Host ""
    Write-Host "✅ AI suggested commit command:"
    Write-Host "--------------------------"
    Write-Host $CommitMessage

    Write-Host ""
    Write-Host "Options:"
    Write-Host "[Enter] Accept as is"
    Write-Host "[E] Edit manually"
    Write-Host "[R] Regenerate message"
    Write-Host "[C] Chat with AI"
    Write-Host ""
}

# Function to edit commit message using Notepad
function Edit-CommitMessage {
    param(
        [string]$CommitMessage
    )
    
    # Create temp file with .txt extension
    $tempFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) `
    -ChildPath ("commit_msg_{0}.txt" -f ([System.Guid]::NewGuid().ToString()))

    # Write content safely
    Set-Content -Path $tempFile -Value $CommitMessage -Encoding UTF8 -Force

    # Start editor
    Write-Host ""
    Write-Host "Opening Notepad so you can edit the commit message..."
    $notepadProcess = Start-Process -FilePath "notepad.exe" -ArgumentList $tempFile -PassThru
    $notepadProcess.WaitForExit()

    # Read content back
    $finalCommitMessage = Get-Content -Path $tempFile -Raw -Encoding UTF8
    Remove-Item $tempFile -Force

    return $finalCommitMessage
}

# Function to validate commit message format
function Test-CommitMessageFormat {
    param(
        [string]$CommitMessage
    )
    
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        Write-Host "Commit message is empty. Please rerun the script or commit manually."
        return $false
    }
    
    $commitMessage = $CommitMessage.Trim()

    # Regex: Must match pattern exactly
    $pattern = '^git commit -m "([^"]+)"$'
    if ($commitMessage -notmatch $pattern) {
        Write-Host "Invalid commit command!"
        Write-Host 'The command must follow this structure:'
        Write-Host 'git commit -m "Your message here"'
        return $false
    }
    
    return $true
}

# Function to handle commit execution
function Invoke-CommitExecution {
    param(
        [string]$CommitCommand
    )
    
    Write-Host ""
    Write-Host "Final commit message:"
    Write-Host "--------------------------"
    Write-Host "$CommitCommand"

    # Auto commit?
    $confirm = Read-Host "Do you want to run this commit command now? [y/N]"
    if ($confirm -match "^[Yy]$") {
        Invoke-Expression $CommitCommand
        Write-Host "Commit executed."
        Write-Host ""

        # Auto push?
        $pushConfirm = Read-Host "Do you want to push the commit to the remote now? [y/N]"
        if ($pushConfirm -match "^[Yy]$") {
            Write-Host "Pushing changes to remote..."
            git push
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Push successful."
            } else {
                Write-Host "Push failed. Please check your Git configuration or network."
            }
        } else {
            Write-Host "Push skipped. You can run 'git push' later manually."
        }
    } else {
        Write-Host "Commit not executed. You can run it manually:"
        Write-Host $CommitCommand
    }
}

# Function to get user choice for commit options
function Get-UserChoice {
    return Read-Host "Choose an option"
}

# Function to get chat instructions from user
function Get-ChatInstructions {
    Write-Host ""
    Write-Host "Enter your message to chat with the AI about the commit message:"
    Write-Host "Example: 'Make it more concise' or 'Add more technical details' or any other instruction."
    Write-Host ""
    
    return Read-Host "Chat message to AI"
} 