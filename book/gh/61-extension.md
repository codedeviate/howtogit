# extension

Extend the GitHub CLI with community-built commands that integrate
directly into the `gh` command surface.

## Mental model

The `gh` CLI ships with a fixed set of built-in commands, but the
ecosystem adds dozens more through **extensions**: ordinary Git
repositories whose name starts with `gh-` and whose root contains an
executable of the same name. When you run `gh <extname>`, the CLI
finds the matching extension and forwards all remaining arguments to
that executable.

Extensions live in `~/.local/share/gh/extensions/` (or the platform
equivalent). Installing one is a one-step operation — `gh extension
install owner/gh-extname` — and from that moment `gh extname` becomes
a first-class command on your machine.

There are two kinds of extensions:

- **Script extensions** — a shell script or any interpreted executable
  committed directly to the repository root. `gh` clones the repo and
  runs the script.
- **Precompiled (binary) extensions** — the repository ships compiled
  binaries as GitHub release assets. `gh` downloads the appropriate
  binary for your OS and architecture. Precompiled extensions start
  faster and have no runtime dependency requirements.

An extension cannot override a built-in `gh` command. If a naming
conflict arises — say you install `gh-label` and `gh label` already
exists — use `gh extension exec label` to invoke the extension version.

`gh` checks for new extension versions at most once every 24 hours and
prints an upgrade notice when one is available. Set the environment
variable `GH_NO_EXTENSION_UPDATE_NOTIFIER=1` to suppress these notices.

## Synopsis

```text
gh extension browse
gh extension create [<name>] [--precompiled=go|other]
gh extension exec   <name> [args]
gh extension install <repository> [--pin <ref>] [--force]
gh extension list
gh extension remove  <name>
gh extension search  [<query>] [flags]
gh extension upgrade {<name> | --all} [--dry-run] [--force]
```

Aliases: `gh ext`, `gh extensions`

## Everyday usage

Find extensions to install:

```sh
gh extension search
```

Install an extension:

```sh
gh extension install dlvhdr/gh-dash
```

List what is currently installed:

```sh
gh extension list
```

Upgrade a single extension:

```sh
gh extension upgrade gh-dash
```

Upgrade everything at once:

```sh
gh extension upgrade --all
```

Remove an extension you no longer need:

```sh
gh extension remove gh-dash
```

### Discovering extensions with browse

`browse` opens a full-screen terminal UI for finding, installing, and
removing extensions:

```sh
gh extension browse
```

Press `?` inside the TUI to see the keyboard shortcuts. Press `q` to
quit. The TUI requires a terminal at least 100 columns wide; on a
narrower terminal (or when using a screen reader) pass
`--single-column`:

```sh
gh extension browse --single-column
```

### Searching from the command line

`search` queries the GitHub API for repositories tagged as
`gh-extension`. With no arguments it returns the top 30 by star count:

```sh
gh extension search
gh extension search branch          # filter by keyword
gh extension search --owner github  # filter by owner
gh extension search --limit 100     # fetch more results
```

The first column shows a checkmark (`✓`) next to extensions that are
already installed. Pipe to `--json` / `--jq` for scripting:

```sh
gh extension search --json fullName,description,stargazersCount \
  --jq '.[] | [.stargazersCount, .fullName, .description] | @tsv'
```

Open the results in the browser instead:

```sh
gh extension search -w
```

### Installing with a pinned version

Pin a binary extension to a specific release tag:

```sh
gh extension install dlvhdr/gh-dash --pin v5.9.0
```

Pin a script extension to a specific commit:

```sh
gh extension install owner/gh-script --pin a1b2c3d
```

### Installing a local development extension

During development, install from the current directory. `gh` creates a
symlink rather than a copy, so edits take effect immediately:

```sh
cd ~/code/gh-myscript
gh extension install .
```

### Running an extension that conflicts with a built-in

If your installed extension shares a name with a built-in `gh` command,
use `exec` to call the extension explicitly:

```sh
gh extension exec label           # invokes the gh-label extension
gh label                          # still invokes the built-in
```

### Creating a new extension

Scaffold a shell-script extension:

```sh
gh extension create gh-hello
```

Scaffold a Go precompiled extension:

```sh
gh extension create --precompiled=go gh-hello
```

Scaffold a non-Go precompiled extension (provides the build skeleton
without Go-specific tooling):

```sh
gh extension create --precompiled=other gh-hello
```

Run `gh extension create` with no arguments to use the interactive
wizard instead.

## Key options

### install

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--pin <ref>` | Pin the extension to a tag or commit | Reproducible environments; avoid surprise upgrades |
| `--force` | Force the install even if the extension is already installed | Re-install after a broken upgrade |

### search

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-L` / `--limit <n>` | Maximum results to return (default 30) | Browsing beyond the top 30 |
| `--owner <org>` | Filter by repository owner | Finding all extensions from a trusted org |
| `--sort <field>` | Sort by `forks`, `help-wanted-issues`, `stars`, or `updated` | Surface recently-maintained extensions |
| `--order <asc\|desc>` | Sort direction (default `desc`); ignored unless `--sort` is also specified | Find oldest or least-starred first |
| `--license <type>` | Filter by SPDX license identifier | Compliance requirements |
| `--json <fields>` | Output JSON with the specified fields | Scripting |
| `-q` / `--jq <expr>` | Filter JSON output with a jq expression | Inline scripting |
| `-t` / `--template <tmpl>` | Format JSON output with a Go template | Custom formatting |
| `-w` / `--web` | Open results in the browser | Visual browsing |

### upgrade

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--all` | Upgrade every installed extension | Maintenance pass |
| `--dry-run` | Print what would be upgraded without doing it | Preview before committing |
| `--force` | Downgrade or reinstall even if already current | Recovering from a broken state |

### create

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--precompiled=go` | Scaffold a Go binary extension | Extensions that need performance or cross-platform distribution |
| `--precompiled=other` | Scaffold a non-Go binary extension | Rust, Zig, or other compiled languages |

### browse

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-s` / `--single-column` | Render the TUI with a single column | Screen readers, narrow terminals |
| `--debug` | Write a debug log to `/tmp/extBrowse-*` | Diagnosing TUI rendering issues |

## Best practices

**Pin extensions in shared or CI environments.** Without `--pin`, every
fresh install fetches the latest version, which can introduce
unexpected behaviour when the upstream author pushes a breaking change.
Record the pin in a setup script or a Makefile target so the whole team
runs the same version.

**Prefer precompiled extensions for speed.** Script extensions execute
through the shell and carry runtime dependencies. Precompiled
extensions are single static binaries — faster cold starts and no
interpreter requirement.

**Review extension source before installing.** Extensions are not
vetted, signed, or endorsed by GitHub. Read the repository (at
minimum, the main executable and any `install.sh`) before running code
from an unfamiliar publisher. Check the star count and recent commit
activity as a rough signal of community trust.

**Suppress the daily update check in automation.** The once-per-24-hour
version check writes to the filesystem and prints output that can
pollute script logs. Suppress it:

```sh
export GH_NO_EXTENSION_UPDATE_NOTIFIER=1
```

**Run `gh extension upgrade --all` regularly.** Extension authors fix
bugs, add features, and patch security issues. A quick weekly upgrade
sweep keeps the risk surface small without requiring per-extension
tracking.

**Develop with a local install.** Use `gh extension install .` during
development. `gh` follows the symlink on every invocation, so you
iterate without reinstalling.

## Pitfalls & gotchas

**Extension names must not conflict with built-in commands — or you
must use `exec`.** If you install `gh-run` and the built-in `gh run`
exists, typing `gh run` always invokes the built-in. Use
`gh extension exec run` to reach your extension. This surprises people
who expect the extension to shadow the core command.

**`gh extension remove` uses the short name, not the `OWNER/REPO`
form.** Remove `dlvhdr/gh-dash` like this:

```sh
gh extension remove gh-dash        # correct
gh extension remove dlvhdr/gh-dash # WRONG — not found
```

**Pinned script extensions track commits, not tags.** For binary
extensions, `--pin` refers to a release tag (e.g. `v1.2.3`). For
script extensions, it refers to a commit SHA. If you pin a script
extension to a branch name it may still drift because `gh` stores the
branch tip at install time, not the branch reference.

**Local installs become broken symlinks if you move the source repo.**
Because `gh extension install .` creates a symlink to the source
directory, relocating or deleting that directory breaks the extension.
Run `gh extension remove` then `gh extension install .` from the new
location.

**`--force` on `upgrade` can downgrade.** If there is no pin and the
latest release asset is older than what is installed (a yanked-release
scenario), the force flag overwrites the newer local copy.

**The TUI in `browse` may render badly in small terminals.** The
recommended minimum is 100 columns. On a terminal below that threshold
the columns overlap. Pass `--single-column` as a workaround.

## Worked examples

### Installing and using gh-dash

`gh-dash` is a popular TUI dashboard for pull requests and issues.

```sh
gh extension install dlvhdr/gh-dash
```

```text
✓ Installed extension dlvhdr/gh-dash
```

Run it:

```sh
gh dash
```

Upgrade it later:

```sh
gh extension upgrade gh-dash
```

```text
[gh-dash]: upgraded from v5.9.0 to v5.10.0
```

Remove it:

```sh
gh extension remove gh-dash
```

### Scripting a pinned extension setup

A team setup script that installs two extensions at known versions and
suppresses the update notifier:

```sh
#!/usr/bin/env bash
set -euo pipefail

export GH_NO_EXTENSION_UPDATE_NOTIFIER=1

gh extension install dlvhdr/gh-dash --pin v5.9.0
gh extension install nicholasgasior/gsfmt --pin a3f1c9e

gh extension list
```

Running this script on any machine produces the same installed set,
regardless of what the upstream repos have published since.

### Creating and publishing a shell-script extension

Scaffold the extension:

```sh
gh extension create gh-greet
cd gh-greet
```

`gh extension create` generates a starter script named `gh-greet`. Edit
it to call the GitHub API:

```sh
#!/usr/bin/env bash
echo "Hello, $(gh api user --jq .login)!"
```

Make it executable and test locally:

```sh
chmod +x gh-greet
gh extension install .
gh greet
```

```text
Hello, ada-lovelace!
```

Publish by pushing the repository to GitHub — `gh repo create` from
the *repo* command group handles this:

```sh
gh repo create gh-greet --public --source=. --push
```

Anyone can now install it with:

```sh
gh extension install ada-lovelace/gh-greet
```

### Discovering high-quality extensions

Find the top extensions in a category, sorted by stars:

```sh
gh extension search dashboard --sort stars --limit 10
```

```text
  REPO                         DESCRIPTION
✓ dlvhdr/gh-dash               A beautiful CLI dashboard for GitHub
  dlvhdr/gh-prs                Review GitHub pull requests in your terminal
  ...
```

Extensions already installed are marked with `✓`. Filter to see only
extensions published by a trusted organisation:

```sh
gh extension search --owner github
```

## Recovery

**An upgrade broke an extension.** Roll back by reinstalling the last
known-good version with `--pin`:

```sh
gh extension remove gh-dash
gh extension install dlvhdr/gh-dash --pin v5.9.0
```

**An extension executable is missing or corrupt.** Force a clean
reinstall:

```sh
gh extension upgrade gh-dash --force
```

**A local-install extension stopped working after moving the repo.**
The symlink is stale. Remove and reinstall from the new location:

```sh
gh extension remove my-ext
cd /new/path/to/gh-my-ext
gh extension install .
```

**`gh extension list` shows nothing after migrating machines.**
Extensions are machine-local and are not synced through your GitHub
account. Re-run your setup script, or reinstall manually.

For general `gh` authentication problems that prevent installing or
publishing extensions, see *auth*.

## See also

- *auth* — authenticate `gh` before installing or publishing extensions.
- *search* — `gh search repos --topic gh-extension` for a finer-grained
  extension search with full qualifier support.
- *repo* — create and manage the repository that backs an extension.
- *release* — publish precompiled extension binaries as release assets.
