# Installing and configuring git

Before you can track a single change, git needs to know who you are. This
chapter walks through installation, identity, and the configuration knobs that
make everyday git noticeably more comfortable.

## Installing git

**macOS** — Git ships with the Xcode Command Line Tools. Install them once:

```sh
xcode-select --install
```

For a newer version, use Homebrew: `brew install git`.

**Linux (Debian / Ubuntu)**

```sh
sudo apt update && sudo apt install git
```

**Linux (Fedora / RHEL)**

```sh
sudo dnf install git
```

**Windows** — Download the official installer from <https://git-scm.com>.
It bundles Git Bash and a credential manager. WSL 2 users can also install
git inside their Linux distribution with the commands above.

Verify the installation:

```sh
git --version
```

```text
git version 2.47.0
```

## Configuration scopes

Git stores configuration in three layered files. A more specific scope
overrides a broader one.

| Scope | File | Applies to |
|-------|------|------------|
| `--system` | `/etc/gitconfig` | Every user on the machine |
| `--global` | `~/.gitconfig` (or `~/.config/git/config`) | Your user account |
| `--local` | `.git/config` inside the repo | That repository only |

Read the effective value of any key:

```sh
git config --show-origin user.email
```

List everything with its origin:

```sh
git config --list --show-origin
```

## Setting your identity

Git embeds author name and email in every commit. Set them globally:

```sh
git config --global user.name  "Ada Lovelace"
git config --global user.email "ada@example.com"
```

Override per-repository when you work under a different identity (e.g., a
work email in a company repo):

```sh
git config --local user.email "ada@company.com"
```

If you forget to set these, git will guess from the system hostname — almost
always wrong.

## Essential quality-of-life settings

### Default branch name

New repositories default to `master` in older git versions. Change to `main`
(or any name your team uses) before you ever run `git init`:

```sh
git config --global init.defaultBranch main
```

### Rebase on pull

By default `git pull` creates a merge commit when the remote has moved ahead.
Rebasing keeps a linear history:

```sh
git config --global pull.rebase true
```

If you are new to rebase, set this to `false` and revisit the decision after
reading *Rewriting history with rebase*.

### Editor

Git opens a text editor when you commit without `-m`, write a rebase plan, or
edit a tag. Point it at your preferred tool:

```sh
git config --global core.editor "code --wait"   # VS Code
git config --global core.editor nvim             # Neovim
git config --global core.editor nano             # nano (safe default for beginners)
```

### Automatic upstream tracking

Without this setting, the first push to a new branch requires the verbose form
`git push --set-upstream origin <branch>`. Enable auto-setup:

```sh
git config --global push.autoSetupRemote true
```

After this, a plain `git push` on a new branch sets the upstream and pushes
in one step.

## Aliases

Aliases let you create short names for long or frequently-typed commands.
They live in `~/.gitconfig` under the `[alias]` section.

```sh
git config --global alias.st  status
git config --global alias.co  checkout
git config --global alias.br  branch
git config --global alias.lg  "log --oneline --graph --decorate --all"
```

Run them like any git command: `git st`, `git lg`.

Aliases can also wrap external shell commands by prefixing with `!`:

```sh
git config --global alias.root "!pwd"
```

## Global .gitignore

Some files should never appear in any repository: OS metadata, editor swap
files, compiled artifacts. Maintain a global ignore list so you never have to
add them to every project:

```sh
git config --global core.excludesFile ~/.gitignore_global
```

A minimal `~/.gitignore_global`:

```text
## macOS
.DS_Store
.AppleDouble

## Windows
Thumbs.db
Desktop.ini

## Editor swap / workspace files
*.swp
*.swo
.idea/
.vscode/

## Compiled output
*.o
*.pyc
__pycache__/
```

## Best practices

**Separate personal and work identities at the directory level.** Use
`includeIf` in `~/.gitconfig` to switch identity automatically based on where
the repository lives:

```ini
[includeIf "gitdir:~/work/"]
    path = ~/.gitconfig-work
```

`~/.gitconfig-work` then sets `user.email = ada@company.com`. Git picks the
right identity without any manual switching.

**Pin `pull.rebase` to a value explicitly.** Leaving it unset means git will
warn on every pull once it detects diverged branches. Decide your policy
upfront.

**Avoid global `core.autocrlf`** unless everyone on the project is on Windows.
Let the repository's `.gitattributes` handle line-ending normalisation instead;
that policy travels with the repo.

**Use `--global` for identity and preferences; use `--local` for per-project
overrides.** Never use `--system` in day-to-day work — it requires root and
affects every user on the machine.

## See also

- *What git really is* — the object model and the three areas.
- *commit* — how git uses your identity in each commit object.
