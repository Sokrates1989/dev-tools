param()

Write-Host "`n🌱 Create a New Branch"
Write-Host "====================="

# Get current branch
$currentBranch = git rev-parse --abbrev-ref HEAD

# List local branches
$branches = git for-each-ref --format='%(refname:short)' refs/heads/ | ForEach-Object { $_.Trim() }

Write-Host "Current branch: $currentBranch"
Write-Host ""
Write-Host "Available local branches:"
for ($i = 0; $i -lt $branches.Count; $i++) {
    Write-Host ("  {0,2}) {1}" -f ($i+1), $branches[$i])
}
Write-Host ""
$baseChoice = Read-Host "Base branch [default: $currentBranch, number or name]"
if ([string]::IsNullOrWhiteSpace($baseChoice)) {
    $baseBranch = $currentBranch
} elseif ($baseChoice -match '^[0-9]+$' -and [int]$baseChoice -ge 1 -and [int]$baseChoice -le $branches.Count) {
    $baseBranch = $branches[[int]$baseChoice-1]
} else {
    $baseBranch = $baseChoice
}

# Check if base branch exists
$localBranches = git branch --format='%(refname:short)'
if (-not ($localBranches -contains $baseBranch)) {
    Write-Host "❌ Base branch '$baseBranch' does not exist. Aborting." -ForegroundColor Red
    exit 1
}

$newBranch = Read-Host "Enter new branch name"
if ([string]::IsNullOrWhiteSpace($newBranch)) {
    Write-Host "❌ Branch name cannot be empty. Aborting." -ForegroundColor Red
    exit 1
}

# Check for remote branch with same name
$remoteExists = git ls-remote --exit-code --heads origin $newBranch 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "❌ A remote branch named '$newBranch' already exists on origin." -ForegroundColor Red
    $tryAgain = Read-Host "Choose a different name? (y/N)"
    if ($tryAgain -notmatch '^[Yy]$') {
        Write-Host "Aborting."
        exit 1
    }
    exit 1
}

# Check if local branch already exists
if ($localBranches -contains $newBranch) {
    Write-Host "❌ Local branch '$newBranch' already exists. Aborting." -ForegroundColor Red
    exit 1
}

# Checkout base branch and pull latest
& git checkout $baseBranch
& git pull origin $baseBranch

# Create new branch
& git checkout -b $newBranch

Write-Host "`nPushing new branch to remote and setting upstream..."
& git push --set-upstream origin $newBranch
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Branch '$newBranch' created from '$baseBranch' and pushed to origin."
    Write-Host "   You are now on '$newBranch'."
} else {
    Write-Host "❌ Failed to push branch to remote." -ForegroundColor Red
} 