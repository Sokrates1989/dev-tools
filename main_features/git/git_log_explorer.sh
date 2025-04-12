#!/bin/bash

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Git update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"

while true; do
  echo ""
  echo "🔍 Git Log Explorer"
  echo "===================="
  echo "Choose a log format:"
  echo ""
  echo " 1) Pretty colored overview"
  echo " 2) A DOG view"
  echo " 3) Detailed commit history with patch"
  echo " 4) Commits by author"
  echo " 5) Commits since a date"
  echo " 6) Commits in a date range"
  echo " 7) Commits for a specific file"
  echo " 8) Commit statistics"
  echo " 9) Search commits containing text"
  echo "10) Only mainline (no merges)"
  echo "11) Only merge commits"
  echo "12) Reverse order (oldest first)"
  echo ""
  echo " b) 🔙 Back to main menu"
  echo " q) ❌ Quit"
  echo ""

  read -p "Enter your choice [1–12, b, q]: " choice
  echo ""

  case "$choice" in
    1)
      echo "▶ Running: git log --pretty=\"%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s\" "
      git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"
      ;;
    2)
      echo "▶ Running: git log --all --decorate --oneline --graph"
      git log --all --decorate --oneline --graph
      ;;
    3)
      echo "▶ Running: git log -p"
      git log -p
      ;;
    4)
      read -p "Author name or email: " author
      echo "▶ Running: git log --author=\"$author\""
      git log --author="$author"
      ;;
    5)
      read -p "Since date (YYYY-MM-DD): " since
      echo "▶ Running: git log --since=\"$since\""
      git log --since="$since"
      ;;
    6)
      read -p "From (YYYY-MM-DD): " since
      read -p "To (YYYY-MM-DD): " until
      echo "▶ Running: git log --since=\"$since\" --until=\"$until\""
      git log --since="$since" --until="$until"
      ;;
    7)
      read -p "Filename: " file
      echo "▶ Running: git log -- \"$file\""
      git log -- "$file"
      ;;
    8)
      echo "▶ Running: git log --stat"
      git log --stat
      ;;
    9)
      read -p "Search text: " text
      echo "▶ Running: git log -S \"$text\""
      git log -S "$text"
      ;;
    10)
      echo "▶ Running: git log --no-merges"
      git log --no-merges
      ;;
    11)
      echo "▶ Running: git log --merges"
      git log --merges
      ;;
    12)
      echo "▶ Running: git log --reverse"
      git log --reverse
      ;;
    0|b|B)
      bash "$ROOT_DIR/start.sh"
      break
      ;;
    q|Q)
      echo "👋 Exiting Dev Tools. Bye!"
      exit 0
      ;;
    *)
      echo "❌ Invalid choice. Try again."
      ;;
  esac

  echo ""
  read -p "🔁 Press Enter to return to the Git log menu..."
done

# --- Git update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"
