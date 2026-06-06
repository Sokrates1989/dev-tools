# Safe Password Generator

The safe password generator creates high-entropy values for production Docker
secrets and dotenv-style `secrets.env` files.

## Usage

```bash
dev-tools --password
dev-tools --pw
```

Direct script usage supports custom output:

```bash
bash main_features/password/generate_safe_passwords.sh --length 64 --single
bash main_features/password/generate_safe_passwords.sh --length 64 --count 3
```

```powershell
.\main_features\password\generate_safe_passwords.ps1 -Length 64 -Single
.\main_features\password\generate_safe_passwords.ps1 -Length 64 -Count 3
```

## Security Policy

- Uses OS-backed cryptographic randomness.
- Uses rejection sampling to avoid modulo bias.
- Defaults to 48 characters per secret.
- Requires uppercase, lowercase, digit, and approved special characters.
- Outputs unquoted `KEY=value` lines for easy pasting into `secrets.env`.

Approved special characters:

```text
@%+-_:,.
```

Avoided characters include quotes, backslashes, whitespace, `#`, `$`, `&`, `|`,
`;`, `<`, `>`, brackets, and equals signs because they can interfere with
dotenv parsing, shell handling, comments, or secret-file workflows.
