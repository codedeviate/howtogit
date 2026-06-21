# pull

Fetch changes from a remote repository and integrate them into the current
branch in one step.

## Mental model

`git pull` is a convenience command that runs two operations back to back:

1. `git fetch` — downloads new commits and updates the remote-tracking
   branches (e.g. `origin/main`) without touching your working tree.
2. Either `git merge` or `git rebase` — integrates those downloaded commits
   into your current branch.

```text
Remote: A---B---C          (origin/main)

Local:  A---B---D          (main, one local commit)

After git pull (merge mode):
        A---B---C
                 \
        A---B---D---E      (E is the merge commit)

After git pull --rebase:
        A---B---C---D'     (D replayed on top of C)
```

The remote-tracking branch (`origin/main`) is always updated first to reflect
what the server has. The integration step — merge or rebase — then happens
locally. Understanding that distinction matters when things go wrong: a
network failure aborts at step one; a conflict surfaces at step two.

By default Git uses merge. If you prefer rebase, set `pull.rebase = true` in
your config, or pass `--rebase` per-invocation.

## Synopsis

```text
git pull [<options>] [<repository> [<refspec>...]]
```

Common forms:

```text
git pull
git pull origin main
git pull --rebase
git pull --rebase origin main
git pull --ff-only
```

## Everyday usage

Update the current branch from its configured upstream (the common case):

```sh
git pull
```

Pull from a specific remote and branch when no upstream is configured:

```sh
git pull origin main
```

Pull and rebase instead of merge — keeps history linear:

```sh
git pull --rebase
```

Pull only if the result would be a fast-forward (no divergence allowed):

```sh
git pull --ff-only
```

Stash local changes automatically before pulling, then re-apply them:

```sh
git pull --autostash
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--rebase[=(false\|true\|merges\|interactive)]` | Rebase the current branch on top of the upstream instead of merging | Keeping a linear history; avoiding noisy merge commits |
| `--no-rebase` | Force merge even when `pull.rebase` is configured to true | Explicitly merging when your default is rebase |
| `--ff-only` | Abort if the update cannot be a fast-forward | CI pipelines, automation, or when you never want a local merge commit |
| `--no-ff` | Always create a merge commit even when fast-forward is possible | Preserving a visible record of every integration |
| `--autostash` | Stash dirty working tree before pulling, re-apply after | Pulling quickly without committing or stashing manually |
| `--squash` | Collapse all incoming commits into a single staged diff without committing | Squash-merging a remote branch into your working tree |
| `--no-commit` | Perform the merge but stop before creating the commit | Inspecting or editing the merge result before it becomes permanent |
| `-s <strategy>` | Use a specific merge strategy (`ort`, `octopus`, `ours`, etc.) | Unusual merge topologies or intentionally discarding one side |
| `-X <option>` | Pass a strategy-specific option (e.g. `-X ours`, `-X theirs`) | Resolving conflicts by always preferring one side |
| `--allow-unrelated-histories` | Merge two repos that share no common ancestor | Combining two independent Git projects for the first time |
| `--depth=<n>` | Limit the fetch to `<n>` commits from the tip | Shallow clones; reducing download size |
| `--recurse-submodules[=(yes\|on-demand\|no)]` | Also fetch and update submodules | Projects that use Git submodules |
| `--stat` | Show a diffstat of what was merged | Reviewing what changed at a glance after pulling |
| `-q, --quiet` | Suppress progress and merge output | Scripts and CI |
| `-v, --verbose` | Pass `--verbose` to both fetch and merge | Debugging network or merge issues |

## Best practices

**Prefer `--rebase` for feature branches.** A merge pull creates a merge
commit with a generic message like "Merge branch 'main' into feature/x". Over
the life of a long-lived branch, those commits accumulate and obscure the real
work. Rebasing replays your commits on top of the updated upstream, resulting
in a clean linear history that is easier to review and bisect.

**Set `pull.rebase` in your global config rather than typing `--rebase` every
time.** This makes the behavior consistent across all your repos:

```sh
git config --global pull.rebase true
```

If a specific repo needs merge pulls, override locally:

```sh
git config pull.rebase false
```

**Use `--ff-only` in automation.** On CI, deployment scripts, or repository
mirrors you never want an unexpected merge commit. `--ff-only` makes the
command fail loudly if the branches have diverged, forcing a human to decide
how to reconcile.

```sh
git pull --ff-only origin main
```

**Pull before you push.** Pushing to a remote that has commits you do not have
locally fails with a rejection. Running `git pull --rebase` first, resolving
any conflicts, and then pushing is the standard loop for shared branches.

**Keep your working tree clean before pulling.** Git will refuse to pull (into
a merge) if uncommitted local changes would be overwritten. Either commit,
stash manually, or pass `--autostash` to let Git handle it. Surprises from
`--autostash` are rare but possible when the re-applied stash conflicts with
the newly merged changes.

## Pitfalls & gotchas

**The default behavior changed — and it varies by version.** Older Git
versions (before 2.27) defaulted to merge without warning. Starting with 2.27,
Git warns on the first `git pull` in a new clone when `pull.rebase` is not
set. Configure it explicitly rather than relying on any particular default.

**`--rebase` rewrites history.** Rebasing replays your local commits as new
objects with new SHA-1 hashes. If you have already pushed those commits to a
shared remote, rewriting them forces everyone else to reconcile the divergence.
Only use `--rebase` on commits that exist solely on your machine, or on a
private branch.

**Fast-forward is not always possible.** If your local branch and the remote
branch have both advanced since they last shared a commit, no fast-forward
exists. Running `git pull --ff-only` in that situation aborts with:

```text
fatal: Not possible to fast-forward, aborting.
```

This is a signal to investigate: have you accidentally committed to a branch
you share with others, or has the remote been force-pushed?

**`--autostash` can surface conflicts on re-apply.** Git stashes your dirty
working tree, performs the pull, then runs `git stash pop`. If the pulled
changes touch the same lines as your stashed work, the pop can conflict. The
stash is not lost — Git leaves it in the stash list — but you need to resolve
the conflict manually.

**Submodule updates require an extra step.** A plain `git pull` updates the
superproject's pointer to the submodule's commit but does not check out that
commit inside the submodule directory. Use:

```sh
git pull --recurse-submodules
```

Or, after the pull, run `git submodule update --init --recursive`.

**Pulling from a remote and specifying a refspec merges that ref immediately.**
If you run `git pull origin next`, Git fetches `next` and merges it into your
current branch. If you run `git pull origin` with no refspec, it fetches all
configured refs from `origin` but only merges the tracked one. The distinction
trips people up when they want to fetch a branch without merging — use
`git fetch` alone for that.

## Worked examples

### Daily sync on a shared feature branch

You and a colleague both push to `feature/checkout-flow`. You start the
morning by syncing:

```sh
git pull --rebase origin feature/checkout-flow
```

```text
From https://github.com/example/shop
 * branch            feature/checkout-flow -> FETCH_HEAD
Successfully rebased and updated refs/heads/feature/checkout-flow.
```

Your local commits are replayed on top of your colleague's commits. History
stays linear and `git log --oneline` remains readable.

If a conflict arises during the rebase:

```sh
# Git pauses and shows which file conflicts
git status
# Edit the file to resolve, then stage it:
git add src/checkout.js
git rebase --continue
```

### Pulling into a dirty working tree

You are mid-edit on `README.md` and need to pull an urgent fix your teammate
just pushed:

```sh
git pull --autostash --rebase
```

```text
Created autostash: cd487f4
From https://github.com/example/docs
 * branch            main -> FETCH_HEAD
   f3a9c11..a2d4f90  main -> origin/main
Applied autostash.
Successfully rebased and updated refs/heads/main.
```

Your uncommitted changes are back in the working tree, layered on top of the
newly fetched commits.

### Pulling an unrelated history when combining two projects

You start a new repo and want to pull in a skeleton from a separate upstream
project that was initialized independently:

```sh
git remote add upstream https://github.com/example/skeleton
git pull upstream main --allow-unrelated-histories
```

Without `--allow-unrelated-histories`, Git refuses because the two repos share
no ancestor commit.

### Using `--ff-only` in a deploy script

A deployment script that runs on every merge to `main` needs to be certain the
branch is always in a known, linear state:

```sh
#!/bin/sh
git pull --ff-only origin main || {
  echo "ERROR: main has diverged from origin/main. Manual intervention required."
  exit 1
}
```

If the branch has diverged — someone force-pushed, or a commit landed locally
by mistake — the script exits non-zero rather than silently creating a merge
commit.

## Recovery

If a pull triggered a merge or rebase that you want to undo, use `ORIG_HEAD`.
Git sets `ORIG_HEAD` before any operation that moves the branch pointer in a
potentially disruptive way:

```sh
# Undo a merge pull — return to the state before git pull ran
git reset --merge ORIG_HEAD
```

If the pull used rebase and you want to abort while it is still in progress:

```sh
git rebase --abort
```

If you have already completed the pull but realize the result is wrong, the
reflog records every position your branch has been at:

```sh
git reflog
# Find the SHA before the pull, then:
git reset --hard <sha-before-pull>
```

See *Getting out of jams* for a broader treatment of undoing merges and
recovering from rebase disasters.

## See also

- *fetch* — the first half of what `pull` does; use it when you want to
  inspect remote changes before integrating.
- *merge* — how Git integrates divergent histories; the second half of a
  merge-mode pull.
- *rebase* — replaying commits onto a new base; the second half of
  `git pull --rebase`.
- *stash* — manually saving and restoring a dirty working tree before pulling.
- *reflog* — recovering commits after a rebase or hard reset goes wrong.
- *Getting out of jams* — undoing pulls, merges, and rebases safely.
