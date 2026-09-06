# cls Terminal Cleaner

Run the guided installer through either launcher:

```bash
dev-tools --cls
```

After accepting the profile change, run the reload command printed for the
detected shell. A child `dev-tools` process cannot change its parent shell, so
the installer never claims to activate the alias by sourcing a profile itself.
Opening a new terminal or SSH session also loads the installed definition.

## Supported profiles

| Shell | Managed profile | Reload command |
| --- | --- | --- |
| Bash | `~/.bashrc` | `source ~/.bashrc` |
| Zsh | `~/.zshrc` | `source ~/.zshrc` |
| POSIX `sh` | `~/.profile` | `. ~/.profile` |
| BusyBox `ash` | `~/.profile` | `. ~/.profile` |
| PowerShell | `$PROFILE` (`CurrentUserCurrentHost`) | `. $PROFILE` |

BusyBox `ash` reads `~/.profile` for login shells. This covers normal login
sessions but cannot guarantee loading in every vendor-customized or non-login
QNAP shell. The printed reload command activates the definition explicitly in
the current session. An unknown shell receives manual instructions without an
automatic profile write.

## Installed configuration

Unix shells receive an alias that uses portable `printf` escape processing:

```sh
# dev-tools cls helper - begin.
alias cls="printf '\033[H\033[2J\033[3J'"
# dev-tools cls helper - end.
```

PowerShell receives a compatible function and forced global alias:

```powershell
# dev-tools cls helper - begin.
function Clear-DevToolsTerminal {
    [Console]::Write("$([char]27)[H$([char]27)[2J$([char]27)[3J")
}
Set-Alias -Name cls -Value Clear-DevToolsTerminal -Scope Global -Force
# dev-tools cls helper - end.
```

These sequences move the cursor home, clear the visible screen, and request
scrollback clearing through ANSI ED3. The terminal emulator decides whether
ED3 is supported; PuTTY and other compatible terminals clear scrollback, while
unsupported terminals may clear only the visible screen.

## Safety and conflicts

- Profile files and parent directories are created only after confirmation.
- Existing unrelated profile content is retained.
- Repeated installation does not append duplicate managed blocks.
- A current managed block is reported as already installed.
- A stale managed block is replaced only between its owned markers.
- Incomplete or duplicate markers stop automatic modification for review.
- Existing aliases, functions, or commands named `cls` require an explicit
  override confirmation. PowerShell's stock `Clear-Host` alias is identified
  separately as expected behavior.
- Declining installation prints the exact configuration and reload command.
