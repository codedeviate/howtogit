# gpg-key

Manage the GPG keys registered with your GitHub account — list what is there,
add a new public key, and delete one you no longer need.

## Mental model

GitHub uses GPG keys to verify signed commits and tags. When you sign a commit
with `git commit -S`, Git attaches your GPG signature to the object. Anyone
who fetches that commit can check the signature against the public key GitHub
holds on file for your account; if they match, GitHub displays the green
**Verified** badge in the UI.

`gh gpg-key` is the command-line shortcut to the *"SSH and GPG keys"* section
of your GitHub account settings. The three subcommands mirror the three
operations available there: `list` reads what is stored, `add` uploads a new
public key, and `delete` removes one by its numeric ID.

The keys managed here are **account-level** — they belong to your GitHub user
profile, not to any single repository. Every repository you push signed commits
to will verify against the same set of stored keys.

## Synopsis

```text
gh gpg-key list
gh gpg-key add   [<key-file>] [-t <title>]
gh gpg-key delete <key-id>   [-y]
```

## Everyday usage

List all GPG keys currently registered on your account:

```sh
gh gpg-key list
```

Upload a new GPG public-key file:

```sh
gh gpg-key add ~/.gnupg/my-key.pub --title "Personal laptop 2024"
```

Read the public key from stdin instead of a file:

```sh
gpg --armor --export alice@example.com | gh gpg-key add --title "alice work key"
```

Delete a key by its numeric ID (get the ID from `gh gpg-key list`):

```sh
gh gpg-key delete 12345678
```

Skip the confirmation prompt when scripting:

```sh
gh gpg-key delete 12345678 --yes
```

## Key options

### add

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `[<key-file>]` | Path to the ASCII-armored public-key file; omit to read from stdin | Use a file path for one-off uploads; stdin for piping from `gpg --export` |
| `-t` / `--title` | Human-readable label for the key on GitHub | Always set this — it is the only way to distinguish keys in the list |

### delete

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `<key-id>` | Numeric ID of the key to remove (required) | Obtain it from `gh gpg-key list` |
| `-y` / `--yes` | Skip the interactive confirmation prompt | Automation and CI scripts |

### list

`gh gpg-key list` (alias: `gh gpg-key ls`) has no additional flags. It prints
each key's ID, title, key ID fingerprint, and creation date.

## Best practices

**Always supply `--title` when adding a key.** GitHub shows the title in the
settings UI and in `gh gpg-key list` output. Without a descriptive title,
rows like `"Added 2024-01-15"` are indistinguishable from each other once you
have more than one key — you will not know which ID to delete when a key is
retired.

**Export only the public key, never the private key.** The standard GPG
export for uploading is:

```sh
gpg --armor --export <fingerprint-or-email>
```

The `--armor` flag produces ASCII output that `gh gpg-key add` expects.
Never run `gpg --export-secret-keys` and pipe that to GitHub.

**Pair this with `git commit -S` configuration.** Uploading a key to GitHub
has no effect until Git is actually signing commits. Configure Git to sign
automatically once the key is in place:

```sh
git config --global user.signingkey <fingerprint>
git config --global commit.gpgSign true
```

**Rotate keys on a schedule.** GPG subkeys can be set to expire. When a
subkey expires, remove the old entry with `gh gpg-key delete` and upload the
renewed public key (after running `gpg --send-keys` to your keyserver). This
keeps the number of active keys small and verifiable.

**Use `--yes` only in automation.** The confirmation prompt on `delete` exists
to prevent accidental removal. In a CI context where you are scripting
key rotation, pass `--yes` so the script does not hang waiting for input.

## Pitfalls & gotchas

**`gh gpg-key list` returns the GitHub key ID, not the GPG fingerprint.** The
numeric ID printed by `list` (e.g., `12345678`) is GitHub's internal
identifier for the uploaded record. It is not the 40-character GPG fingerprint
you see in `gpg --list-keys`. Always run `gh gpg-key list` to get the
correct ID before running `gh gpg-key delete`.

**Uploading the wrong key (private vs. public) will fail.** The API validates
that the submitted key is a valid OpenPGP public-key block. If you accidentally
pipe a secret key export, GitHub will reject the request with an error message.

**A key can be uploaded but still not verify commits if the email does not
match.** GitHub links a GPG key to the email addresses embedded in that key.
If the email in your GPG user ID does not match a verified email address on
your GitHub account, commits signed with that key will show **Unverified**
even after upload. Run `gpg --edit-key <fingerprint>` to inspect the UIDs and
add a matching email if needed.

**Deleting a key does not un-verify historical commits.** Once a commit was
verified against a key, that verification is stored. Removing the key from
your account affects future verification checks, not past ones.

**`gh gpg-key add` reads stdin only when no file argument is given.** If you
accidentally supply both a file path and a pipe, the file path takes precedence
and the piped data is ignored without a warning.

## Worked examples

### Adding a freshly generated GPG key

Generate a new key, export the public half, and upload it in one pipeline:

```sh
# Generate a key (interactive — choose RSA 4096 and your email)
gpg --full-generate-key

# Find the fingerprint of the new key
gpg --list-secret-keys --keyid-format LONG

# Export and upload in one step
gpg --armor --export 3AA5C34371567BD2 | gh gpg-key add --title "MacBook Pro 2025"
```

Confirm the upload worked:

```sh
gh gpg-key list
```

```text
ID        Title              Key ID              Created
12345678  MacBook Pro 2025   3AA5C34371567BD2    2025-03-10
```

Now configure Git to sign all commits automatically:

```sh
git config --global user.signingkey 3AA5C34371567BD2
git config --global commit.gpgSign true
```

Make a signed commit and check the GitHub UI for the green **Verified** badge.

### Rotating an expired key

Your GPG subkey has expired. Generate a new one, then swap the GitHub record:

```sh
# Extend or create a new subkey in GPG
gpg --edit-key 3AA5C34371567BD2
# Inside gpg> prompt: addkey, then save

# Re-export the full public key (includes the new subkey)
gpg --armor --export 3AA5C34371567BD2 | gh gpg-key add --title "MacBook Pro 2025 (renewed)"

# List keys to see both old and new entries
gh gpg-key list
```

```text
ID        Title                          Key ID              Created
12345678  MacBook Pro 2025               3AA5C34371567BD2    2025-03-10
23456789  MacBook Pro 2025 (renewed)     3AA5C34371567BD2    2025-11-01
```

Delete the old entry:

```sh
gh gpg-key delete 12345678
```

```text
! Are you sure you want to delete GPG key 12345678? (y/N)
```

Type `y` to confirm, or pass `--yes` to skip the prompt.

### Auditing and cleaning up stale keys

List every key currently on file:

```sh
gh gpg-key list
```

Cross-reference with the local keyring:

```sh
gpg --list-secret-keys --keyid-format LONG
```

For any key ID that no longer has a corresponding private key on this machine
(decommissioned laptop, revoked key), delete it:

```sh
gh gpg-key delete 99887766 --yes
```

## Recovery

If you delete a key by mistake, re-add it from your local keyring immediately:

```sh
gpg --armor --export <fingerprint> | gh gpg-key add --title "Restored key"
```

If you have lost the private key entirely and cannot regenerate the public key,
you cannot restore the GitHub entry. Future commits will need to be signed with
a new key — generate one, upload it, and update `user.signingkey` in your Git
config.

If signed commits are showing **Unverified** after adding a key, verify that
the email address embedded in the GPG key UID is listed as a verified email in
your GitHub account settings. See *auth* for how to manage the GitHub account
that `gh` is authenticated as, in case you are uploading the key to the wrong
account.

## See also

- *auth* — manage the GitHub account `gh` acts on; ensure you are logged in as
  the correct user before adding or deleting keys.
- *ssh-key* — the parallel command group for SSH authentication keys; GPG keys
  are for commit signing, SSH keys are for repository access.
- *config* — configure `gh` behavior and defaults beyond authentication.
