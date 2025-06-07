#!/bin/bash

echo ""
echo "🧹 Reset Local Git Changes – Dev Tools"
echo "======================================"

# Show git status
echo ""
echo "📋 Current Git Status:"
git status

# Show what untracked files would be deleted
echo ""
echo "🗑️  Untracked files that would be deleted:"
git clean -fdn

# Confirm
echo ""
read -p "⚠️  This will discard ALL uncommitted and untracked files. Continue? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "❌ Aborted. No changes were made."
  exit 1
fi

# Reset changes
echo ""
echo "Discarding changes..."
git restore --source=HEAD --staged --worktree .
git clean -fd

echo ""
echo "✅ Local repository has been reset to the latest committed state."
