$root = Resolve-Path "$PSScriptRoot\.."

# --- Git update check ---
$RootDir = Join-Path $PSScriptRoot ".." | Resolve-Path | Select-Object -ExpandProperty Path
& "$RootDir\check_for_updates.ps1"

while ($true) {
    Write-Host ""
    Write-Host "🔍 Git Log Explorer"
    Write-Host "===================="
    Write-Host "Choose a log format:"
    Write-Host ""
    Write-Host " 1) Pretty colored overview"
    Write-Host " 2) A DOG view"
    Write-Host " 3) Detailed commit history with patch"
    Write-Host " 4) Commits by author"
    Write-Host " 5) Commits since a date"
    Write-Host " 6) Commits in a date range"
    Write-Host " 7) Commits for a specific file"
    Write-Host " 8) Commit statistics"
    Write-Host " 9) Search commits containing text"
    Write-Host "10) Only mainline (no merges)"
    Write-Host "11) Only merge commits"
    Write-Host "12) Reverse order (oldest first)"
    Write-Host ""
    Write-Host " b) 🔙 Back to main menu"
    Write-Host " q) ❌ Quit"
    Write-Host ""

    $choice = Read-Host "Enter your choice [1–12, b, q]"
    Write-Host ""

    switch ($choice) {
        "1"  {
            Write-Host "▶ Running: git log --pretty=..."
            git log --pretty="%C(Yellow)%h  %C(reset)%ad (%C(Green)%cr%C(reset))%x09 %C(Cyan)%an: %C(reset)%s"
        }
        "2"  {
            Write-Host "▶ Running: git log --all --decorate --oneline --graph"
            git log --all --decorate --oneline --graph
        }
        "3"  {
            Write-Host "▶ Running: git log -p"
            git log -p
        }
        "4"  {
            $author = Read-Host "Author name or email"
            Write-Host "▶ Running: git log --author=`"$author`""
            git log --author="$author"
        }
        "5"  {
            $since = Read-Host "Since date (YYYY-MM-DD)"
            Write-Host "▶ Running: git log --since=`"$since`""
            git log --since="$since"
        }
        "6"  {
            $since = Read-Host "From (YYYY-MM-DD)"
            $until = Read-Host "To (YYYY-MM-DD)"
            Write-Host "▶ Running: git log --since=`"$since`" --until=`"$until`""
            git log --since="$since" --until="$until"
        }
        "7"  {
            $file = Read-Host "Filename"
            Write-Host "▶ Running: git log -- `"$file`""
            git log -- "$file"
        }
        "8"  {
            Write-Host "▶ Running: git log --stat"
            git log --stat
        }
        "9"  {
            $text = Read-Host "Search text"
            Write-Host "▶ Running: git log -S `"$text`""
            git log -S "$text"
        }
        "10" {
            Write-Host "▶ Running: git log --no-merges"
            git log --no-merges
        }
        "11" {
            Write-Host "▶ Running: git log --merges"
            git log --merges
        }
        "12" {
            Write-Host "▶ Running: git log --reverse"
            git log --reverse
        }
        "b" | "B" | "0" {
            Write-Host "🔁 Returning to main menu..."
            Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -File `"$root\start.ps1`""
            break
        }
        "q" | "Q" {
            Write-Host "👋 Exiting Dev Tools. Bye!"
            exit
        }
        default {
            Write-Host "❌ Invalid choice. Try again."
        }
    }

    Write-Host ""


    # --- Git update check ---
    $RootDir = Join-Path $PSScriptRoot ".." | Resolve-Path | Select-Object -ExpandProperty Path
    & "$RootDir\check_for_updates.ps1"

    Read-Host "🔁 Press Enter to return to the Git log menu..."
}
