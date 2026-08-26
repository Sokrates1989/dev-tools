# Safe Password Generator

The safe password generator creates high-entropy password values for production
secrets. It does not emit `KEY=value` or `secrets.env`-styled output.

## Usage

```bash
dev-tools --password
dev-tools --pw
```

The interactive menu asks for:

- A numbered or lettered special-character preset, defaulting to Balanced.
- Password length, defaulting to 64 characters.
- Number of passwords, defaulting to 1.
- Delivery method, defaulting to clipboard as the recommended option.

The special-character menu accepts either the number, shortcut letter, or full
preset name:

- `1` / `n` / `none`: no special characters. This has the widest
  compatibility but the lowest preset strength and is not recommended.
- `2` / `m` / `minimum`: only `_.-`, for a small strength increase with no
  known compatibility issues.
- `3` / `b` / `balanced`: the recommended default, with more variety and high
  compatibility.
- `4` / `h` / `high`: a broader punctuation set with moderate compatibility
  risk.
- `5` / `a` / `all`: every printable ASCII punctuation character, with high
  compatibility risk.

The exact sets are:

```text
None:     (empty)
Minimum:  _.-
Balanced: @%+-_:,.
High:     @%+-_:,.!#$^&*?~=()
All:      !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
```

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
- `locales/en.properties` / `locales/de.properties`: localized CLI messages.
- `tests/password_core_tests.ps1` / `tests/password_core_tests.sh`: focused
  preset, complexity, menu, and locale regression tests.

## Security Policy

- Uses OS-backed cryptographic randomness.
- Uses rejection sampling to avoid modulo bias.
- Defaults to 64 characters per password.
- Every password contains at least one uppercase letter, one lowercase letter,
  and one digit.
- Every preset except None also guarantees at least one character from that
  preset's exact special-character set.
- Generated characters never fall outside the selected preset's alphabet.

## Language

The generator uses German messages when the active UI locale begins with `de`
and English otherwise. Set `PASSWORD_GENERATOR_LOCALE=en` or
`PASSWORD_GENERATOR_LOCALE=de` to override locale detection for one invocation.
