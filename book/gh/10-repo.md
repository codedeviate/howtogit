# repo

Create, clone, fork, view, and manage GitHub repositories without leaving
the terminal.

## Mental model

Every `gh repo` subcommand talks to GitHub's API on your behalf. Think of
this command group as the GitHub web UI's repository tab — condensed into
a set of composable shell commands.

There are two layers to understand:

1. **Remote repositories** live on GitHub's servers. `gh repo create`,
   `edit`, `archive`, `delete`, `rename`, `list`, and `view` all operate
   on the remote.
2. **Local checkouts** live on your disk. `gh repo clone`, `fork`, `sync`,
   and `set-default` bridge the remote and your working directory.

`gh` identifies the *current* repository by reading the `origin` remote
(or whichever remote is set as the default — see `set-default`). If a
subcommand takes an optional `[<repository>]` argument you can always
spell it out as `OWNER/REPO` or pass a full GitHub URL; omitting it
targets the current directory's repository.

All API calls use the active `gh auth` credential (see *auth*). For
delete operations you need the extra `delete_repo` OAuth scope; `gh`
will tell you when to run `gh auth refresh`.

## Synopsis

```text
gh repo create   [<name>] [flags]
gh repo clone    <repository> [<directory>] [-- <gitflags>...]
gh repo fork     [<repository>] [-- <gitflags>...] [flags]
gh repo view     [<repository>] [flags]
gh repo list     [<owner>] [flags]
gh repo edit     [<repository>] [flags]
gh repo set-default [<repository>] [flags]
gh repo sync     [<destination-repository>] [flags]
gh repo rename   [<new-name>] [flags]
gh repo archive  [<repository>] [flags]
gh repo unarchive [<repository>] [flags]
gh repo delete   [<repository>] [flags]
```

## Everyday usage

### Creating a new repository

Start a brand-new public project and immediately clone it:

```sh
gh repo create my-project --public --clone
```

Bootstrap from code you already have locally:

```sh
cd ~/code/my-project
gh repo create my-project --private --source=. --remote=origin --push
```

Run with no arguments for a guided interactive wizard:

```sh
gh repo create
```

### Cloning a repository

```sh
# Clone by OWNER/REPO shorthand
gh repo clone cli/cli

# Clone to a specific directory
gh repo clone cli/cli workspace/gh-cli

# Clone with extra git flags (shallow clone)
gh repo clone cli/cli -- --depth=1
```

When you clone a fork, `gh` automatically adds the parent as a remote
named `upstream` and marks it as the default repository for `gh` commands.

### Forking a repository

Fork on GitHub and clone the fork in one step:

```sh
gh repo fork cli/cli --clone
```

Run inside an existing clone to fork the current repository:

```sh
gh repo fork
```

Fork into an organization rather than your personal account:

```sh
gh repo fork cli/cli --org my-company --clone
```

### Viewing a repository

Print the README and description in the terminal:

```sh
gh repo view
gh repo view torvalds/linux
```

Open in a browser instead:

```sh
gh repo view --web
```

Extract structured data:

```sh
gh repo view --json name,description,stargazerCount
```

### Listing repositories

```sh
# Your own repos (default 30)
gh repo list

# Another user or org
gh repo list my-company --limit 100

# Only private repos
gh repo list --visibility private

# Only forks
gh repo list --fork

# Filter by primary language
gh repo list --language go
```

### Setting a default repository

Inside a multi-remote clone, tell `gh` which GitHub repository to use for
PR and issue commands:

```sh
# Interactive picker
gh repo set-default

# Set explicitly
gh repo set-default owner/repo

# Check what is currently set
gh repo set-default --view

# Clear the setting
gh repo set-default --unset
```

### Syncing a fork

Pull the latest changes from the parent repository into your fork's default
branch:

```sh
# Sync your local clone from its upstream parent
gh repo sync

# Sync a specific branch
gh repo sync --branch develop

# Sync a remote fork (no local clone required)
gh repo sync your-handle/your-fork
```

## Key options

### create

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--public` / `--private` / `--internal` | Set repository visibility | Required for non-interactive creation |
| `-c` / `--clone` | Clone the new repo after creation | Jump straight into coding |
| `-s` / `--source` | Path to an existing local repo | Publish local work to GitHub |
| `--push` | Push local commits after creating | Combine with `--source` to upload history |
| `-d` / `--description` | Short description | Shown on GitHub and in `gh repo list` |
| `-g` / `--gitignore` | Apply a gitignore template | Saves manual setup |
| `-l` / `--license` | Apply an OSS license | Run `gh repo license list` for valid keywords |
| `-p` / `--template` | Base the repo on a template repo | Org-wide project starters |
| `--add-readme` | Create an initial README | Needed before cloning an otherwise empty repo |
| `-r` / `--remote` | Name for the new remote | When `origin` is already taken |
| `-t` / `--team` | Grant an org team access | Org repos |
| `--disable-issues` | Turn off the Issues tab | Docs-only or mirror repos |
| `--disable-wiki` | Turn off the Wiki tab | Keeps the repo tab bar clean |

### clone

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-u` / `--upstream-remote-name` | Name for the upstream remote when cloning a fork (default `upstream`) | Rename to match your convention |
| `--no-upstream` | Skip adding an upstream remote | When you do not want the parent wired in |

### fork

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--clone` | Clone the fork locally | Almost always — saves a second command |
| `--remote` | Add a git remote for the fork without cloning | Already have a local clone |
| `--remote-name` | Name for the fork's remote (default `origin`) | When `origin` is taken |
| `--org` | Create the fork in an organization | Contributing under a team namespace |
| `--fork-name` | Rename the fork on creation | Avoid collision with existing repos |
| `--default-branch-only` | Include only the default branch | Smaller fork for quick PRs |

### view

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-w` / `--web` | Open in browser | When you want the full GitHub UI |
| `-b` / `--branch` | View a specific branch | Inspect a branch's README |
| `--json fields` | Output structured JSON | Scripting, dashboards |
| `-q` / `--jq` | Filter JSON with a jq expression | Quick field extraction in pipelines |

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-L` / `--limit` | Maximum repos to return (default 30) | Orgs with many repos |
| `--visibility` | Filter by `public`, `private`, or `internal` | Audit or scope work |
| `--fork` | Show only forks | Find forks to clean up |
| `--source` | Show only non-forks | Original repos only |
| `--archived` | Show only archived repos | Housekeeping |
| `--no-archived` | Omit archived repos | Active work list |
| `-l` / `--language` | Filter by primary language | Polyglot accounts |
| `--topic` | Filter by topic | Repos tagged with a keyword |
| `--json fields` | Output structured JSON | Scripting |

### edit

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-d` / `--description` | Change the description | Keep repo metadata current |
| `--default-branch` | Change the default branch | After a main-branch rename |
| `--visibility` | Change visibility (`public`/`private`/`internal`) | Requires `--accept-visibility-change-consequences` |
| `--delete-branch-on-merge` | Auto-delete head branch after merge | Cleaner PR workflow |
| `--enable-auto-merge` | Allow PRs to auto-merge when checks pass | CI-driven repos |
| `--enable-squash-merge` / `--enable-rebase-merge` / `--enable-merge-commit` | Toggle merge strategies | Enforce a team standard |
| `--enable-issues` / `--enable-wiki` / `--enable-discussions` | Toggle feature tabs | Slim down unused tabs |
| `--add-topic` / `--remove-topic` | Manage repository topics | Discoverability |
| `--template` | Make the repo a template | Publish a project starter |

### sync

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-b` / `--branch` | Branch to sync (default: default branch) | Keep a non-default branch current |
| `-s` / `--source` | Source repository | Sync from something other than the parent |
| `--force` | Hard reset the destination to match the source | After divergent history on a fork |

### set-default

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-v` / `--view` | Print the current default | Quick status check |
| `-u` / `--unset` | Remove the default | Reset after finishing a project |

## Best practices

**Prefer `--clone` over cloning separately.** Both `gh repo create` and
`gh repo fork` accept `--clone`. Using it saves a round trip and ensures
the remote is wired correctly from the start.

**Use `gh repo set-default` in multi-remote setups.** When a directory has
remotes pointing to different GitHub repositories, `gh` may pick the wrong
one for `gh pr` and `gh issue` commands. Set the default once and forget it:

```sh
gh repo set-default owner/canonical-repo
```

**Think hard before changing visibility.** Changing a public repository to
private has irreversible side-effects: stars and watchers are lost, public
forks are detached from the network, and push rulesets are disabled.
The `--accept-visibility-change-consequences` flag you must pass is a
reminder to weigh those costs first.

**Automate with `--json` and `--jq`.** Most `gh repo` subcommands support
JSON output. Pipe into `jq` for one-liners:

```sh
# List all your private repos by name
gh repo list --visibility private --json name --jq '.[].name'

# Show star counts sorted descending
gh repo list --json name,stargazerCount \
  --jq 'sort_by(-.stargazerCount) | .[] | "\(.stargazerCount)\t\(.name)"'
```

**Add gitignore and license at creation time.** It is far easier to set
`--gitignore` and `--license` when creating than to bolt them on later.
Run `gh repo license list` to see valid license keywords before creating.

**Use `gh repo sync --force` only on forks you control.** The flag performs
a hard reset. Any commits in the destination branch that are not in the
source will be permanently discarded.

## Pitfalls & gotchas

**`gh repo delete` requires the `delete_repo` scope.** If you see a
permissions error, add the scope and retry:

```sh
gh auth refresh -s delete_repo
gh repo delete owner/repo --yes
```

**Deleting without an explicit argument is always interactive.** Even with
`--yes`, `gh` prompts for confirmation when no repository argument is
supplied. Pass the full `OWNER/REPO` to make it non-interactive:

```sh
gh repo delete owner/repo --yes   # non-interactive
gh repo delete --yes              # still prompts — --yes is ignored here
```

**`gh repo sync` only fast-forwards by default.** If your fork has
diverged (for example you rebased a branch), the sync will fail unless you
pass `--force`. That flag hard-resets the branch, discarding divergent
commits.

**Forking rewires `origin`.** Running `gh repo fork` inside an existing
clone sets `origin` to your fork and renames the original remote to
`upstream`. If scripts or CI jobs reference a remote by name, audit them
before forking.

**Changing the default branch with `gh repo edit --default-branch` does
not update local clones.** After the rename, each collaborator must update
their local tracking reference:

```sh
git fetch origin
git branch -u origin/<new-name> <new-name>
git remote set-head origin -a
```

Alternatively, delete and re-clone.

**`gh repo list --fork` does not cross ownership boundaries.** When listing
forks in an organization, the output will not include forks owned by
individual members — only forks owned by the org itself.

## Worked examples

### Publishing a new open-source project from scratch

You have code in `~/code/hello-world` and want to publish it:

```sh
cd ~/code/hello-world
git init
git add .
git commit -m "Initial commit"

gh repo create hello-world \
  --public \
  --description "A friendly Hello World" \
  --license mit \
  --source=. \
  --remote=origin \
  --push
```

```text
✓ Created repository ada/hello-world on GitHub
  https://github.com/ada/hello-world
✓ Added remote https://github.com/ada/hello-world.git
✓ Pushed commits to https://github.com/ada/hello-world.git
```

Browse the result immediately:

```sh
gh repo view --web
```

### Contributing to an upstream project (fork-and-PR workflow)

Fork an upstream project, clone your fork, make a change, and open a PR:

```sh
# Fork and clone in one step
gh repo fork cli/cli --clone
cd cli

# Upstream is wired automatically
git remote -v
```

```text
origin    https://github.com/ada/cli.git (fetch)
origin    https://github.com/ada/cli.git (push)
upstream  https://github.com/cli/cli.git (fetch)
upstream  https://github.com/cli/cli.git (push)
```

```sh
git switch -c fix/typo-in-readme
# ... edit files ...
git commit -am "Fix typo in README"
git push origin fix/typo-in-readme

# Open a PR against the upstream default branch
gh pr create --fill
```

Keep your fork current with upstream as work continues:

```sh
gh repo sync
```

### Auditing and cleaning up stale repositories

List all archived repos sorted by last-updated date:

```sh
gh repo list --archived --json name,updatedAt \
  --jq '.[] | "\(.updatedAt) \(.name)"' | sort
```

Delete a stale fork after confirming you no longer need it:

```sh
gh repo delete ada/old-fork --yes
```

### Locking down a repository after a project ends

Archive it so the history is preserved but no new issues or PRs can be
opened:

```sh
gh repo archive ada/finished-project --yes
```

If the project is revived:

```sh
gh repo unarchive ada/finished-project --yes
```

### Collecting star counts across an organization

```sh
gh repo list my-org --limit 200 \
  --json name,stargazerCount,isPrivate \
  --jq '.[] | select(.isPrivate == false) | [.name, .stargazerCount] | @tsv' \
  | sort -t$'\t' -k2 -rn
```

## Recovery

**Accidentally deleted a repository.** GitHub keeps deleted repositories
recoverable for 90 days. Visit
`https://github.com/settings/deleted_repositories` and restore from there.
There is no `gh` CLI command for this — use the web UI.

**Pushed to the wrong repository after a remote rename.** Check where
`origin` points, then correct it:

```sh
git remote -v
git remote set-url origin https://github.com/correct-owner/correct-repo.git
```

**Cloned a fork without an upstream remote.** Add it manually:

```sh
git remote add upstream https://github.com/original-owner/original-repo.git
git fetch upstream
```

Or re-clone with `gh repo clone`, which adds the upstream remote
automatically for known forks.

**Visibility change had unintended consequences.** To reverse a
private-to-public or public-to-private change:

```sh
gh repo edit --visibility public --accept-visibility-change-consequences
```

Stars, watchers, and fork-network connections lost during a private period
are not restored.

## See also

- *auth* — managing the credentials that `gh repo` uses for all API calls.
- *pr* — open and review pull requests against repositories cloned or forked here.
- *issue* — file and track issues in repositories managed here.
- *release* — publish versioned releases for repositories you create.
- *browse* — open any part of a repository in a browser with `gh browse`.
