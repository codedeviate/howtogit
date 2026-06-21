# ssh-key

List, add, and delete the SSH keys registered with your GitHub account.

## Mental model

GitHub stores public SSH keys against your account so that `git push` and
`git clone` over SSH can prove who you are without a password. Think of it as
a lock (GitHub holds the lock, you hold the private key). `gh ssh-key` is the
toolbelt for managing those locks: you can see which keys are registered, add a
new one, or remove one that is no longer in use.

Two key types exist on GitHub. An **authentication key** is used for `git`
operations — the classic use-case. A **signing key** is used to
cryptographically sign commits and tags (the "Verified" badge on GitHub). A
single public key can be registered for one purpose but not both; if you want
the same physical key to do both jobs you must upload it twice, once as each
type.

`gh ssh-key` talks directly to the GitHub API, so the changes take effect
immediately — no browser login required. The subcommands mirror the three
things you need to do: `list` to see, `add` to register, `delete` to remove.

## Synopsis

```text
gh ssh-key list
gh ssh-key add   [<key-file>] [-t title] [--type authentication|signing]
gh ssh-key delete <id>        [-y]
```

## Everyday usage

### Listing registered keys

Show every SSH key on your account, including its title, ID, and type:

```sh
gh ssh-key list
```

```text
Work MacBook	ssh-ed25519 AAAAC3...	2024-01-10T00:00:00Z	12345678	authentication
Personal M3 	ssh-ed25519 AAAAC3...	2024-03-22T00:00:00Z	12345679	authentication
```

The output is tab-separated with no header row. Columns are TITLE, KEY,
CREATED, ID, TYPE. The numeric ID (4th field) is what you pass to `delete`.

### Adding a key

Upload your default public key and give it a recognisable title:

```sh
gh ssh-key add ~/.ssh/id_ed25519.pub --title "Work MacBook"
```

If you omit the file argument, `gh` reads from stdin — useful when piping:

```sh
cat ~/.ssh/id_ed25519.pub | gh ssh-key add --title "Work MacBook"
```

Register the same key as a signing key (to sign commits):

```sh
gh ssh-key add ~/.ssh/id_ed25519.pub --title "Work MacBook signing" --type signing
```

### Deleting a key

Find the ID with `list`, then delete it. The command asks for confirmation by
default:

```sh
gh ssh-key delete 12345678
```

```text
Are you sure you want to delete key 12345678 (Work MacBook)? (y/N)
```

Skip the prompt in scripts with `--yes`:

```sh
gh ssh-key delete 12345678 --yes
```

## Key options

### add

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-t` / `--title` | Label the key on GitHub | Always — names make `list` output readable |
| `--type` | `authentication` (default) or `signing` | When uploading a key exclusively for commit signing |

### delete

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-y` / `--yes` | Skip the confirmation prompt | Automation and scripts |

### list

`list` has no flags beyond `--help`. It has the alias `ls`:

```sh
gh ssh-key ls
```

## Best practices

**Give keys descriptive titles.** The default `id_ed25519` title tells you
nothing six months later. Include the machine and, if useful, the purpose —
`Work MacBook signing`, `CI runner deploy key`. Good titles make it obvious
which row to delete when a machine is decommissioned.

**Register signing keys separately.** Even if your authentication and signing
keys are the same physical key pair, GitHub requires a separate entry for each
type. Keep the titles consistent — `Personal M3 auth` and `Personal M3
signing` — so they pair up visually in `gh ssh-key list`.

**Audit keys periodically.** Run `gh ssh-key list` every few months and delete
keys from machines you no longer use. Each key is a potential entry point; a
decommissioned laptop's key should not remain active.

**Prefer `--yes` only in automation.** The confirmation prompt on `delete`
exists to prevent accidents. In CI or scripts where you have already validated
the ID, passing `--yes` is fine. Do not use it interactively out of habit.

**Generate the key locally before uploading.** `gh ssh-key add` only
*registers* a public key — it does not generate one for you. Generate the key
pair first:

```sh
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Then upload the public half with `gh ssh-key add`.

## Pitfalls & gotchas

**Uploading the private key by mistake.** The `add` subcommand expects a
public key (the file ending in `.pub`). If you accidentally pass the private
key file the command will reject it with an error, but double-check before
running:

```sh
# Wrong — private key
gh ssh-key add ~/.ssh/id_ed25519

# Correct — public key
gh ssh-key add ~/.ssh/id_ed25519.pub
```

**A key registered as `authentication` cannot serve as a `signing` key, and
vice versa.** GitHub enforces the type at registration time. If you need both,
upload the same public key twice with different `--type` values and different
titles. Attempting to use an authentication key for commit signing will produce
a signing key not found error on the GitHub side.

**`list` shows no output when no keys are registered.** The command exits
cleanly with an empty table. If you expected to see keys and the output is
blank, check that you are authenticated as the correct account — see *auth*.

**IDs are numeric, not fingerprints.** `gh ssh-key delete` takes the integer
ID shown in `gh ssh-key list`, not the key fingerprint from `ssh-keygen -lf`.
Confirm the ID from `list` before deleting.

**`gh ssh-key add` with stdin requires the key on a single line.** Multi-line
input or extra whitespace will cause the API to reject the key. If you are
constructing the key string programmatically, strip trailing newlines before
piping.

## Worked examples

### Setting up a new machine from scratch

Generate a key, upload it, and verify it is registered:

```sh
# Generate a new Ed25519 key pair
ssh-keygen -t ed25519 -C "ada@example.com" -f ~/.ssh/id_ed25519

# Add to the SSH agent
ssh-add ~/.ssh/id_ed25519

# Upload the public key to GitHub
gh ssh-key add ~/.ssh/id_ed25519.pub --title "Ada's MacBook Pro"

# Confirm it appears
gh ssh-key list
```

```text
Ada's MacBook Pro	ssh-ed25519 AAAAC3...	2026-06-17T00:00:00Z	87654321	authentication
```

Test the connection:

```sh
ssh -T git@github.com
```

```text
Hi ada-lovelace! You've successfully authenticated, but GitHub does not provide shell access.
```

### Enabling verified commit signing

Register the same key for signing (GitHub requires a separate entry):

```sh
gh ssh-key add ~/.ssh/id_ed25519.pub \
  --title "Ada's MacBook Pro signing" \
  --type signing
```

Then configure git locally to sign commits with that key:

```sh
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

Now commits pushed from this machine will show the "Verified" badge on GitHub.

### Rotating a compromised key

If a private key is exposed, remove the corresponding public key from GitHub
immediately:

```sh
# Find the ID of the compromised key
gh ssh-key list
```

```text
Old Laptop  	ssh-ed25519 AAAAB3...	2023-09-01T00:00:00Z	11111111	authentication
Work MacBook	ssh-ed25519 AAAAC3...	2025-01-15T00:00:00Z	22222222	authentication
```

```sh
# Delete without waiting for a prompt
gh ssh-key delete 11111111 --yes
```

Generate a fresh key pair on your current machine and upload it:

```sh
ssh-keygen -t ed25519 -C "ada@example.com" -f ~/.ssh/id_ed25519_new
gh ssh-key add ~/.ssh/id_ed25519_new.pub --title "Work MacBook (rotated 2026-06)"
```

Update any deployment targets or CI runners that used the old key.

### Removing stale keys in a script

Fetch the list of key IDs matching a known title pattern and delete each one:

```sh
# List all keys, filter by title, extract ID, delete
gh ssh-key list | grep "Old CI runner" | awk -F'\t' '{print $4}' | while read id; do
  gh ssh-key delete "$id" --yes
done
```

## Recovery

Deleted a key by accident? There is no undo — `gh ssh-key delete` is
permanent. Re-add the public key file if you still have it:

```sh
gh ssh-key add ~/.ssh/id_ed25519.pub --title "Work MacBook"
```

If the key is gone from disk as well, generate a new pair with `ssh-keygen`,
upload the public half with `gh ssh-key add`, update your `~/.ssh/config` or
run `ssh-add`, and test with `ssh -T git@github.com`.

For authentication failures after a key rotation, see *Getting out of jams*.

## See also

- *auth* — log in to GitHub and configure the active account that `gh ssh-key` acts on.
- *gpg-key* — manage GPG keys for commit signing as an alternative to SSH signing keys.
- *config* — set default hosts and other gh-wide settings.
