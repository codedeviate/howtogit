# fetch

Download objects and refs from a remote repository without modifying your
working tree or current branch.

## Mental model

Your local repository holds two kinds of branch pointers. First, your own
branches (`main`, `feature/login`, etc.) — these move when you commit. Second,
remote-tracking branches (`origin/main`, `origin/feature/login`, etc.) — these
are read-only snapshots of what the remote looked like the last time you
contacted it.

`git fetch` reaches out to the remote, downloads any new commits and objects,
and advances those remote-tracking pointers. It never touches your branches.
After a fetch, you have the remote's work locally, but none of it has been
merged into anything you own. You are free to inspect it, compare it, or
integrate it on your own terms.

```text
Remote:   A -- B -- C -- D   (origin/main after fetch)

Local:    A -- B -- C         (your main, unchanged)
                     \
                      E       (your unshared work)
```

Think of `git fetch` as refreshing your map of the world: the terrain may have
changed, but you have not moved yet.

## Synopsis

```text
git fetch [<options>] [<repository> [<refspec>...]]
git fetch [<options>] <group>
git fetch --multiple [<options>] [(<repository> | <group>)...]
git fetch --all [<options>]
```

## Everyday usage

Update all remote-tracking branches from the default remote (`origin`):

```sh
git fetch
```

Fetch from a specific remote:

```sh
git fetch origin
```

Fetch and prune stale remote-tracking branches in one step:

```sh
git fetch --prune
```

See what the remote has that you do not, after fetching:

```sh
git fetch origin
git log HEAD..origin/main --oneline
```

Fetch a single branch only:

```sh
git fetch origin feature/payments
```

Fetch from every configured remote at once:

```sh
git fetch --all
```

Inspect a remote branch before integrating it:

```sh
git fetch origin
git diff main origin/main
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--all` | Fetch from every configured remote | Monorepos or repos with multiple remotes |
| `-p`, `--prune` | Remove remote-tracking refs that no longer exist on the remote | Keeping the ref namespace tidy after upstream branches are deleted |
| `-P`, `--prune-tags` | Remove local tags that no longer exist on the remote (requires `--prune`) | Syncing tag lifecycle with the remote |
| `-t`, `--tags` | Fetch all remote tags in addition to branches | Ensuring all release tags are present locally |
| `-n`, `--no-tags` | Disable automatic tag following | CI environments or shallow clones where tags are not needed |
| `--depth=<depth>` | Limit fetched history to `<depth>` commits from each branch tip | Speeding up fetches in large repos; also deepens existing shallow clones |
| `--unshallow` | Convert a shallow clone into a complete one | When you need full history after cloning with `--depth` |
| `--dry-run` | Show what would be fetched without making any changes | Verifying the effect of a refspec before running for real |
| `-f`, `--force` | Allow updating a local branch even if it is not a fast-forward | Overriding safety checks on explicitly mapped refspecs |
| `--atomic` | Update all local refs in one atomic transaction | Ensuring refs are never in a partially-updated state on error |
| `--multiple` | Allow fetching from several remotes or groups in one command | Batch fetching when you want to name remotes explicitly |
| `-j <n>`, `--jobs=<n>` | Fetch remotes or submodules in parallel | Speeding up `--all` or submodule-heavy repos |
| `--recurse-submodules[=yes\|on-demand\|no]` | Also fetch new commits in populated submodules | Projects that use submodules and need them up to date |
| `--set-upstream` | Record the fetched remote as the upstream for the current branch | Setting up tracking after a manual fetch |
| `-q`, `--quiet` | Suppress progress output | Scripts and CI pipelines |
| `-v`, `--verbose` | Print more information, including up-to-date refs | Debugging what was and was not fetched |
| `--porcelain` | Machine-parseable output on stdout | Scripts that parse fetch results |
| `--show-forced-updates` | Always check whether any branch was force-updated | Auditing whether remote history was rewritten |

## Best practices

**Fetch before you branch or rebase.** Before creating a feature branch or
rebasing onto `main`, run `git fetch origin` so your remote-tracking branches
reflect the current upstream state. Branching from a stale `origin/main` means
you may miss recent merges and encounter more conflicts later.

**Prefer `git fetch` + explicit integration over `git pull`.** `git pull` runs
fetch and immediately integrates. Fetching first gives you a moment to look at
what arrived — `git log HEAD..origin/main --oneline` — before deciding whether
to merge or rebase. See the *pull* chapter for when that convenience is
justified.

**Enable pruning by default.** Upstream branches that have been deleted linger
as stale remote-tracking refs unless you prune them. Add this to your global
config once:

```sh
git config --global fetch.prune true
```

After that, every `git fetch` automatically removes stale refs, and `git branch
-r` stays clean.

**Fetch all remotes on build servers.** On a developer laptop with a single
`origin`, plain `git fetch` is enough. On CI machines or multi-remote
workflows, use `git fetch --all` or set `fetch.all = true` in config to keep
every remote current without thinking about it.

**Use `--dry-run` when experimenting with refspecs.** Custom refspec mappings
(for example `+refs/pull/*/head:refs/remotes/origin/pr/*`) can have surprising
side effects. Verify with `--dry-run` before running for real.

## Pitfalls & gotchas

**`git fetch` does not update your working tree.** New commits on `origin/main`
do not appear in your `main` until you integrate them. A common surprise is
running `git fetch` and then wondering why `git log` shows nothing new — your
branch pointer has not moved. Follow up with `git merge origin/main` or `git
rebase origin/main` as appropriate.

**Stale remote-tracking branches accumulate silently.** When a teammate deletes
a remote branch, your local `refs/remotes/origin/<branch>` persists until you
prune. Without `--prune` (or `fetch.prune = true`), `git branch -r` fills with
dead refs over time. On repos with heavy branch churn this can degrade
performance of ref-scanning operations.

**`--prune-tags` removes local tags not on the remote — including ones you
created yourself.** If you use local tags as personal bookmarks and never push
them, they will vanish. Use `--prune-tags` only when your local tags are
intended to mirror the remote exactly.

**Shallow clones give incomplete results for history-dependent commands.** A
clone made with `git clone --depth=1` fetches only a slice of history.
Commands like `git bisect`, `git blame` on old commits, and `git log --follow`
across renames silently return incomplete results. Run `git fetch --unshallow`
when you need full history.

**`FETCH_HEAD` is overwritten on every fetch.** The file `.git/FETCH_HEAD`
records what the most recent fetch retrieved. A subsequent `git fetch` replaces
it entirely. Rely on named remote-tracking branches (`origin/main`) rather than
`FETCH_HEAD` in any script that outlives a single command.

**Force-fetching with an explicit `<src>:<dst>` refspec overwrites the local
branch.** Using `git fetch origin main:main --force` overwrites your local
`main` unconditionally, discarding any unpushed commits. Reserve this pattern
for read-only mirror setups.

## Worked examples

### Reviewing a colleague's branch before merging

A pull request for `feature/checkout` has been opened upstream. You want to
inspect it locally without switching branches.

```sh
# Bring remote-tracking branches up to date
git fetch origin

# See what commits the branch adds over main
git log origin/main..origin/feature/checkout --oneline
```

```text
e4a91bc Add address validation to checkout form
8f30c17 Extract PaymentService into its own module
```

```sh
# Diff the branch against main
git diff origin/main...origin/feature/checkout
```

Nothing in your working tree or branches changed. When you are ready to
integrate, merge or check out the remote-tracking branch:

```sh
git checkout -b feature/checkout origin/feature/checkout
```

### Cleaning up after a team sprint

Your team deleted several merged branches on the remote. Your local
remote-tracking refs still list them.

```sh
git branch -r
```

```text
  origin/HEAD -> origin/main
  origin/feature/auth
  origin/feature/search
  origin/main
  origin/release/v2.1
  origin/release/v2.2
```

`feature/auth` and `feature/search` were merged and deleted upstream. Fetch
with `--prune`:

```sh
git fetch --prune
```

```text
From github.com:acme/storefront
 - [deleted]         (none)     -> origin/feature/auth
 - [deleted]         (none)     -> origin/feature/search
   abc1234..def5678  main       -> origin/main
```

```sh
git branch -r
```

```text
  origin/HEAD -> origin/main
  origin/main
  origin/release/v2.1
  origin/release/v2.2
```

The stale refs are gone and `origin/main` reflects the latest upstream commit.

### Fetching GitHub pull-request refs for local testing

GitHub exposes pull requests under `refs/pull/<number>/head`. These are not
fetched by the default refspec. Fetch PR #42 into a local tracking branch:

```sh
git fetch origin refs/pull/42/head:refs/remotes/origin/pr/42
git checkout origin/pr/42
```

To keep all open PRs current automatically, add a permanent refspec to your
remote configuration:

```sh
git config --add remote.origin.fetch '+refs/pull/*/head:refs/remotes/origin/pr/*'
git fetch origin
```

Now every `git fetch origin` updates all PR branches under
`refs/remotes/origin/pr/`.

## Recovery

`git fetch` is non-destructive with respect to your branches — it never
modifies commits you own. There is nothing to undo in the traditional sense.

If `--prune` removed a remote-tracking ref you still needed (because the
upstream branch was deleted), the ref pointer is gone but the underlying
commits remain in the object database until garbage collection. Locate the
commit hash with `git reflog` or `git fsck --unreachable`, then recreate a
branch from it:

```sh
git branch recover-work <commit-hash>
```

If you fetched with an explicit `<src>:<dst>` refspec and accidentally
overwrote a local branch, the overwritten commit is still reachable via the
reflog:

```sh
git reflog show main
# find the entry just before the overwrite
git branch recover-main <sha-before-overwrite>
```

See *Getting out of jams* for broader undo recipes.

## See also

- *remote* — managing the remote entries that `git fetch` reads from.
- *pull* — fetch followed by an immediate merge or rebase.
- *merge* — integrating fetched remote-tracking branches into your own.
- *rebase* — replaying your commits on top of freshly fetched upstream work.
- *log* — inspecting what arrived after a fetch with range syntax
  (`HEAD..origin/main`).
- *Getting out of jams* — recovering from unexpected ref changes.
