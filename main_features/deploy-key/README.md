# Deploy Key Manager

The Deploy Key Manager creates one unattended ED25519 SSH key for exactly one
repository on the current hostname. Re-running it for the same pair reuses the
same private key and prints the same public key.

This feature is intended for Linux and macOS servers through the Bash launcher.
It does not edit `~/.ssh/config` or enable write access on a Git provider.

## Usage

Run it from the Bash launcher:

```bash
dev-tools --deploy-key
dev-tools --dk
```

Or choose `15) Deploy Key Manager` from the interactive `dev-tools` menu.

The prompt accepts a browser URL, an HTTPS or SSH Git remote, or the complete
output from `git remote -v`. For example:

```text
origin  https://github.com/my-user/server-info.git (fetch)
origin  https://github.com/my-user/server-info.git (push)
```

When run inside a Git repository with a supported `origin`, pressing Enter uses
that remote. Invalid input returns to the prompt.

## Managed Files

Keys are stored below:

```text
~/.ssh/dev-tools/deploy-keys/
```

The filename encodes provider, owner, repository, and hostname. For example:

```text
github.com__my-user__server-info__netcup-server
github.com__my-user__server-info__netcup-server.pub
```

The SSH directories use mode `700`, private keys use `600`, and public keys use
`644`. The private key is never printed or copied outside this directory.

## Idempotency and Recovery

- When both files exist and match, the helper reuses them.
- When the private key exists but the `.pub` file is missing, the public key is
  recovered with `ssh-keygen -y`.
- When only the public key exists, the helper stops without overwriting or
  generating anything. Restore the matching private key to the displayed path,
  or review and relocate the orphaned public file before running the helper
  again.
- Symlinks, non-regular key paths, and mismatched key pairs are rejected.

## GitHub Setup

The result includes the repository's exact GitHub deploy-key settings URL, a
suggested title, and a reminder to leave **Allow write access** disabled for
normal clone, fetch, and pull deployments.

Each repository receives a dedicated SSH alias. Copy the printed block into
`~/.ssh/config`, preserving any existing entries, and then use the printed
repository-specific remote URL. The helper also prints exact commands for an
existing checkout, a new clone, and an SSH connection test.

## Supported Remotes

GitHub is the primary supported provider. The parser also accepts ordinary
two-component `owner/repository` HTTPS, SSH URI, and SCP-style remotes for other
hosts and prints provider-neutral setup guidance. Nested GitLab subgroup paths
are not currently supported.

## Tests

From the repository root, run:

```bash
bash main_features/deploy-key/tests/deploy_key_tests.sh
```

The tests create keys only inside a disposable temporary directory.
