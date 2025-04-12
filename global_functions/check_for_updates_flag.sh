#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
ORIGINAL_DIR="$(pwd)"
cd "$ROOT_DIR"

if git fetch --quiet && ! git diff --quiet HEAD..origin/HEAD; then
  echo "1"
else
  echo "0"
fi

cd "$ORIGINAL_DIR"
