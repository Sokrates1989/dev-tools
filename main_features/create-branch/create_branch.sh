#!/bin/bash
set -e

# Helper: get current branch
current_branch=$(git rev-parse --abbrev-ref HEAD)

# List local branches
branches=($(git for-each-ref --format='%(refname:short)' refs/heads/))

# Prompt for base branch
echo "\n🌱 Create a New Branch"
echo "====================="
echo "Current branch: $current_branch"
echo ""
echo "Available local branches:"
for i in "${!branches[@]}"; do
  printf "  %2d) %s\n" $((i+1)) "${branches[$i]}"
done
echo ""
read -p "Base branch [default: $current_branch, number or name]: " base_choice
if [[ -z "$base_choice" ]]; then
  base_branch="$current_branch"
elif [[ "$base_choice" =~ ^[0-9]+$ ]] && (( base_choice >= 1 && base_choice <= ${#branches[@]} )); then
  base_branch="${branches[$((base_choice-1))]}"
else
  base_branch="$base_choice"
fi

# Check if base branch exists
if ! git show-ref --verify --quiet refs/heads/$base_branch; then
  echo "❌ Base branch '$base_branch' does not exist. Aborting."
  exit 1
fi

echo ""
read -p "Enter new branch name: " new_branch
if [[ -z "$new_branch" ]]; then
  echo "❌ Branch name cannot be empty. Aborting."
  exit 1
fi

# Check for remote branch with same name
if git ls-remote --exit-code --heads origin "$new_branch" >/dev/null 2>&1; then
  echo "❌ A remote branch named '$new_branch' already exists on origin."
  read -p "Choose a different name? (y/N): " try_again
  if [[ ! "$try_again" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
  fi
  exit 1
fi

# Create new branch from base
if git show-ref --verify --quiet refs/heads/$new_branch; then
  echo "❌ Local branch '$new_branch' already exists. Aborting."
  exit 1
fi

git checkout "$base_branch"
git pull origin "$base_branch"
git checkout -b "$new_branch"

echo "\nPushing new branch to remote and setting upstream..."
git push --set-upstream origin "$new_branch"

if [[ $? -eq 0 ]]; then
  echo "\n✅ Branch '$new_branch' created from '$base_branch' and pushed to origin."
  echo "   You are now on '$new_branch'."
else
  echo "❌ Failed to push branch to remote."
fi 