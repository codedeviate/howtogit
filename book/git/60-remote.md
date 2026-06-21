# remote

Manage the set of named remote repositories whose branches your local
repository tracks.

## Mental model

A remote is nothing more than a short alias — usually `origin` — that maps to
a URL and a set of rules about which branches to track. Git stores this in
`.git/config`:

```text
[remote "origin"]
    url     = git@github.com:acme/api.git
    fetch   = +refs/heads/*:refs/remotes/origin/*
```

The fetch refspec `+refs/heads/*:refs/remotes/origin/*` tells Git: when you
fetch from this remote, copy every branch from the server into the local
namespace `origin/<branch>`. Those copies are called *remote-tracking
branches* — read-only snapshots of where the remote's branches were the last
time you fetched.

`git remote` itself never talks to the network. It is purely a bookkeeping
command: it reads and writes the `[remote]` sections in `.git/config`. The
network calls happen in *fetch*, *pull*, and *push*.

```text
.git/config
 └─ [remote "origin"]        ← git remote manages this
      url = ...
      fetch = ...

refs/remotes/origin/main     ← git fetch populates this
```

A repository can have any number of remotes. The name `origin` is a
convention set by `git clone`; nothing requires it.

## Synopsis

```text
git remote [-v | --verbose]
git remote add     [-t <branch>] [-m <master>] [-f] [--[no-]tags]
                   [--mirror=(fetch|push)] <name> <URL>
git remote rename  [--[no-]progress] <old> <new>
git remote remove  <name>
git remote set-head   <name> (-a | --auto | -d | --delete | <branch>)
git remote set-branches [--add] <name> <branch>...
git remote get-url [--push] [--all] <name>
git remote set-url [--push] <name> <newurl> [<oldurl>]
git remote set-url --add    [--push] <name> <newurl>
git remote set-url --delete [--push] <name> <URL>
git remote [-v | --verbose] show    [-n] <name>...
git remote prune   [-n | --dry-run] <name>...
git remote [-v | --verbose] update  [-p | --prune] [(<group> | <remote>)...]
```

## Everyday usage

List all remotes (names only):

```sh
git remote
```

```text
origin
upstream
```

List remotes with their URLs:

```sh
git remote -v
```

```text
origin    git@github.com:you/api.git (fetch)
origin    git@github.com:you/api.git (push)
upstream  git@github.com:acme/api.git (fetch)
upstream  git@github.com:acme/api.git (push)
```

Add a new remote:

```sh
git remote add upstream git@github.com:acme/api.git
```

Remove a remote you no longer need:

```sh
git remote remove old-fork
```

Rename a remote:

```sh
git remote rename origin github
```

See full details about a remote — its URL, tracked branches, and whether
your local branches are ahead or behind:

```sh
git remote show origin
```

```text
* remote origin
  Fetch URL: git@github.com:you/api.git
  Push  URL: git@github.com:you/api.git
  HEAD branch: main
  Remote branches:
    main           tracked
    feature/auth   tracked
  Local branch configured for 'git pull':
    main merges with remote main
  Local ref configured for 'git push':
    main pushes to main (up to date)
```

Delete stale remote-tracking branches that no longer exist on the server:

```sh
git remote prune origin
```

Preview what prune would remove without actually removing it:

```sh
git remote prune --dry-run origin
```

## Key options

### `git remote add`

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-f` | Run `git fetch <name>` immediately after adding | Get remote-tracking branches right away |
| `-t <branch>` | Track only `<branch>` instead of all branches | Shallow-track a single branch of a large repo |
| `-m <master>` | Set `refs/remotes/<name>/HEAD` to point at `<master>` | Define a default branch for the remote |
| `--tags` | Import all tags on every fetch | Explicit tag mirroring |
| `--no-tags` | Never import tags from this remote | Keep tag namespace clean |
| `--mirror=fetch` | Mirror all refs into local `refs/` (bare repos only) | Backup mirrors |
| `--mirror=push` | Always push as a mirror | Publishing mirrors |

### `git remote show`

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-n` | Use cached info; do not query the remote | Inspect config offline |

### `git remote prune`

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-n` / `--dry-run` | Report what would be pruned without doing it | Verify before destructive cleanup |

### `git remote set-url`

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--push` | Operate on push URLs instead of fetch URLs | Set a different push destination |
| `--add` | Add a new URL rather than replacing the existing one | Push to multiple remotes at once |
| `--delete` | Delete all URLs matching a regex | Remove one URL from a multi-push set |

### `git remote update`

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-p` / `--prune` | Prune stale tracking branches for each updated remote | Keep refs tidy after a bulk fetch |

## Best practices

**Use `upstream` for the canonical source, `origin` for your fork.** The
convention that `origin` points to *your* fork and `upstream` points to the
project you forked is widely understood. Inverting them confuses collaborators
and tools.

```sh
git remote add upstream git@github.com:acme/api.git
git remote set-url origin git@github.com:you/api.git
```

**Change URLs with `set-url`, not by editing `.git/config` by hand.** The
subcommand validates the new URL and handles the push/fetch URL distinction
cleanly. Hand-editing is error-prone and bypasses that validation.

**Prune regularly — or pass `--prune` to fetch.** Branches deleted on the
server linger as stale remote-tracking refs until you prune. Run
`git remote prune origin` after a sprint ends, or configure automatic
pruning once:

```sh
git config fetch.prune true
```

With that setting, every `git fetch` behaves as if `--prune` was passed,
so `git remote prune` becomes unnecessary day-to-day.

**Use `-t` when adding a large monorepo remote you only partially need.**
Tracking all branches of a repo with thousands of refs wastes bandwidth and
clutters your ref namespace. Track only the branches you care about:

```sh
git remote add -t main -t release/v3 upstream git@github.com:acme/mono.git
```

**Verify the URL before pushing to a new remote.** A mistyped URL can
create a new repository on some hosts instead of failing cleanly. Check
it first:

```sh
git remote show new-remote
```

**Prefer SSH URLs for remotes you push to.** HTTPS requires credential
entry on every push (or a credential helper). SSH keys authenticate
silently and do not expire the same way personal access tokens do.

## Pitfalls & gotchas

**`git remote remove` deletes remote-tracking branches silently.** Running
`git remote remove upstream` also removes all `refs/remotes/upstream/*`
refs. Those branches disappear from your local view. The data still exists
on the actual server; re-add the remote and fetch to restore the
remote-tracking refs.

**`git remote rename` does not break existing local branches.** The command
automatically updates every `branch.<name>.remote` entry and all
remote-tracking refs that referenced the old name, so default push/pull
keeps working with no manual `--set-upstream-to` step:

```sh
git remote rename origin github   # branch.main.remote is rewritten to github automatically
```

What is *not* updated is anything outside Git's own config: CI pipelines,
deployment scripts, or other tools that hard-code the old remote name in
their own configuration files.

**`git remote show` makes a live network call.** It queries the remote
using `git ls-remote`. On a slow or offline connection this hangs. Pass
`-n` to use cached information instead.

**A remote with multiple push URLs pushes to all of them.** This is useful
for maintaining mirrors, but surprises people who added a second URL
experimentally. Verify with `git remote get-url --push --all <name>` before
pushing to avoid unintended writes.

**`--mirror=fetch` is only safe in bare repositories.** In a normal
working-tree repo, a fetch mirror overwrites local commits because it copies
every ref unconditionally. Use it only in repos created with
`git init --bare` or `git clone --bare`.

**`set-url --delete` matches a regex, not a literal string.** Characters
like `.` match any character in a URL. Verify the match first with
`git remote get-url --all <name>` before deleting.

## Worked examples

### Setting up a fork workflow

You have cloned your fork and want to keep it in sync with the upstream
project.

```sh
# Your clone already has origin pointing to your fork.
git remote -v
```

```text
origin  git@github.com:you/api.git (fetch)
origin  git@github.com:you/api.git (push)
```

Add the upstream remote:

```sh
git remote add upstream git@github.com:acme/api.git
git fetch upstream
```

```text
From git@github.com:acme/api.git
 * [new branch]  main     -> upstream/main
 * [new branch]  v2       -> upstream/v2
```

Rebase your feature branch on the latest upstream main:

```sh
git switch feature/auth
git rebase upstream/main
```

Push the updated branch to your fork:

```sh
git push origin feature/auth --force-with-lease
```

See the *rebase* chapter for details on interactive rebase and
`--autosquash`, and the *push* chapter for `--force-with-lease`.

### Correcting a remote URL after a repository migration

Your team migrated from Bitbucket to GitHub. The old URL stops working.

Check the current URL:

```sh
git remote get-url origin
```

```text
git@bitbucket.org:acme/api.git
```

Update it:

```sh
git remote set-url origin git@github.com:acme/api.git
```

Verify:

```sh
git remote -v
```

```text
origin  git@github.com:acme/api.git (fetch)
origin  git@github.com:acme/api.git (push)
```

Test that the new URL resolves before pushing:

```sh
git remote show origin
```

### Pushing to two remotes simultaneously

You want every push to `origin` to also update a backup mirror on a
self-hosted Gitea instance.

```sh
git remote set-url --add --push origin git@github.com:acme/api.git
git remote set-url --add --push origin git@gitea.internal:acme/api.git
```

Confirm both push URLs are registered:

```sh
git remote get-url --push --all origin
```

```text
git@github.com:acme/api.git
git@gitea.internal:acme/api.git
```

From now on, `git push origin main` sends to both destinations in sequence.
A failure on either URL causes that destination to report an error while the
successful one proceeds normally.

### Tracking a subset of branches from a large remote

You only need the `main` branch of a large upstream repository. Adding it
without `-t` would download hundreds of branches.

```sh
git remote add -t main -f upstream git@github.com:acme/mono.git
```

The `-f` flag fetches immediately. Confirm only the requested branch was
tracked:

```sh
git branch -r | grep upstream
```

```text
  upstream/main
```

Later, if you also need `release/v4`:

```sh
git remote set-branches --add upstream release/v4
git fetch upstream
```

## Recovery

If you accidentally remove a remote, re-add it and fetch:

```sh
git remote add origin git@github.com:acme/api.git
git fetch origin
```

Your local commits are unaffected. Remote-tracking branches are cached
pointers; the underlying commit objects remain in your local object database
until a garbage-collection run removes unreachable objects.

If a rename or URL change breaks branch tracking, restore it with:

```sh
git branch --set-upstream-to=origin/main main
```

See *Getting out of jams* for broader undo strategies, including recovering
from a mistaken force push.

## See also

- *fetch* — download objects and update remote-tracking branches.
- *pull* — fetch followed by merge or rebase.
- *push* — upload local commits to a remote.
- *branch* — list and manage remote-tracking branches with `-r`.
- *clone* — the command that creates the initial `origin` remote.
