# Docker Scout updater (`udc`)

From PowerShell, run `dev-tools --udc` or select menu item `22`. Copy the
entire printed block and paste it into Bash on the Ubuntu server while logged in
as the account that runs Docker. The server can run the block without Dev Tools.

From Bash on a machine with Dev Tools, `dev-tools --udc --print` prints the same
block. On Linux, `dev-tools --udc` installs the helper directly. If the direct
install prints a PATH command, run it in the current shell to activate `udc`.

The installer places `udc` in `~/.local/bin` without sudo. When that directory is
missing from `PATH`, it adds a guarded line to `~/.bashrc`. Pasting the block into
Bash also updates `PATH` in that session. Repeating the same setup is safe. An
existing different executable or symlink at `~/.local/bin/udc` is preserved.

Run `udc` to install or update Docker Scout. The updater needs `curl` and the
Docker CLI on an x86-64 or ARM64 Linux host. After confirmation it verifies the
archive against Docker's release checksum and installs `docker-scout` under
`${DOCKER_CONFIG:-$HOME/.docker}/cli-plugins` for the current account.
