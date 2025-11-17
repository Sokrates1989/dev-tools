#!/bin/bash

# -----------------------------------------------------------------------------
# Script: git_credential_check.sh
# Description: Warns when GitHub HTTPS credentials would be repeatedly requested.
# -----------------------------------------------------------------------------

NOTICE_FLAG_NAME="DEVTOOLS_GIT_CRED_NOTICE"
NOTICE_FLAG_VALUE=$(printf '%s' "${!NOTICE_FLAG_NAME}")
if [[ "$NOTICE_FLAG_VALUE" == "1" ]]; then
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null)
if [[ -z "$REMOTE_URL" ]]; then
  exit 0
fi

if [[ "$REMOTE_URL" =~ ^(git@|ssh://) ]]; then
  exit 0
fi

if [[ "$REMOTE_URL" != https://* ]]; then
  exit 0
fi

HELPER=$(git config --get credential.helper 2>/dev/null)
if [[ -z "$HELPER" ]]; then
  HELPER=$(git config --global --get credential.helper 2>/dev/null)
fi

if [[ -n "$HELPER" ]]; then
  exit 0
fi

echo ""
echo "🔐  GitHub credentials will be requested for every git command."
echo "   • Remote 'origin' uses HTTPS: $REMOTE_URL"
echo "   • No credential helper is configured for this user."
echo ""
echo "Recommended fixes:"
echo "  1) Switch to SSH (recommended):"
echo "     ssh-keygen -t ed25519 -C \"your-email@example.com\""
echo "     git remote set-url origin git@github.com:<owner>/<repo>.git"
echo "  2) Cache HTTPS credentials temporarily:"
echo "     git config --global credential.helper 'cache --timeout=3600'"
echo "  3) Store a Personal Access Token (plaintext):"
echo "     git config --global credential.helper store"
echo ""

export DEVTOOLS_GIT_CRED_NOTICE=1
