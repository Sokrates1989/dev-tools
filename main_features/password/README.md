# Safe Password Generator

The safe password generator creates high-entropy password values for production
secrets. It does not emit `KEY=value` or `secrets.env`-styled output.

## Usage

```bash
dev-tools --password
dev-tools --pw
```

The interactive menu asks for:

- Whether to include safe special characters.
- Password length, defaulting to 64 characters.
- Number of passwords, defaulting to 1.
- Delivery method, defaulting to clipboard as the recommended option.

## Delivery Options

Clipboard is recommended because it avoids terminal scrollback and plaintext
files. After pasting, the tool asks whether to clear the clipboard.

The file option writes plaintext password values, one per line, and should only
be used when you immediately move the file into secure secret storage. The
terminal option is least secure because scrollback may retain the password.

## File Layout

- `generate_safe_passwords.ps1` / `generate_safe_passwords.sh`: entrypoints.
- `password_core.ps1` / `password_core.sh`: CSPRNG password generation.
- `password_ui.ps1` / `password_ui.sh`: prompts and delivery methods.

## Security Policy

- Uses OS-backed cryptographic randomness.
- Uses rejection sampling to avoid modulo bias.
- Defaults to 64 characters per password.
- Requires uppercase, lowercase, digit, and optionally safe special characters.

Approved special characters:

```text
@%+-_:,.
```

Avoided characters include quotes, backslashes, whitespace, `#`, `$`, `&`, `|`,
`;`, `<`, `>`, brackets, and equals signs because they can interfere with
dotenv parsing, shell handling, comments, or secret-file workflows.
