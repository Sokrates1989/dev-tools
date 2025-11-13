param()

Write-Host ""
Write-Host "Create a New Branch"
Write-Host "====================="

# Get current branch
$currentBranch = git rev-parse --abbrev-ref HEAD

# List local branches
$branchOutput = git for-each-ref --format='%(refname:short)' refs/heads/
$branches = $branchOutput -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$branches = @($branches)

if ($branches.Count -eq 0) {
    Write-Host "[ERROR] No local branches found. Aborting." -ForegroundColor Red
    exit 1
}

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
& git show-ref --verify --quiet ("refs/heads/$baseBranch") 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Base branch '$baseBranch' does not exist. Aborting." -ForegroundColor Red
    exit 1
}

$newBranch = Read-Host "Enter new branch name"
if ([string]::IsNullOrWhiteSpace($newBranch)) {
    Write-Host "[ERROR] Branch name cannot be empty. Aborting." -ForegroundColor Red
    exit 1
}

# Check for remote branch with same name
$remoteExists = git ls-remote --exit-code --heads origin $newBranch 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[ERROR] A remote branch named '$newBranch' already exists on origin." -ForegroundColor Red
    $tryAgain = Read-Host "Choose a different name? (y/N)"
    if ($tryAgain -notmatch '^[Yy]$') {
        Write-Host "Aborting."
        exit 1
    }
    exit 1
}

# Check if local branch already exists
& git show-ref --verify --quiet ("refs/heads/$newBranch") 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "[ERROR] Local branch '$newBranch' already exists. Aborting." -ForegroundColor Red
    exit 1
}

# Checkout base branch and pull latest
& git checkout $baseBranch
& git pull origin $baseBranch

# Create new branch
& git checkout -b $newBranch


Write-Host ""
Write-Host "Pushing new branch to remote and setting upstream..."
& git push --set-upstream origin $newBranch
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] Branch '$newBranch' created from '$baseBranch' and pushed to origin."
    Write-Host "   You are now on '$newBranch'."
} else {
    Write-Host "[ERROR] Failed to push branch to remote." -ForegroundColor Red
} 