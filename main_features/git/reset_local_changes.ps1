Clear-Host
Write-Host 'Reset Local Changes – Dev Tools' -ForegroundColor Cyan
Write-Host '====================================='

# Show git status first
Write-Host ''
Write-Host 'Current Git Status:' -ForegroundColor Yellow
git status

# Show what untracked files would be deleted
Write-Host ''
Write-Host 'Untracked files that would be deleted:' -ForegroundColor DarkGray
git clean -fdn

# Confirm action
Write-Host ''
Write-Host 'WARNING: This will permanently discard ALL uncommitted changes and untracked files.' -ForegroundColor Red
$confirmation = Read-Host 'Are you sure you want to proceed? (yes/no)'
if ($confirmation -ne 'yes') {
    Write-Host 'Aborted. No changes were made.' -ForegroundColor DarkYellow
    exit
}

# Perform the reset
Write-Host ''
Write-Host 'Discarding changes...' -ForegroundColor Gray
git restore --source=HEAD --staged --worktree .
git clean -fd

Write-Host ''
Write-Host 'Local repository has been reset to the latest committed state.' -ForegroundColor Green
