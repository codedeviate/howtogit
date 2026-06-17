# switch

Move HEAD (and your working tree) to a different branch, creating one first
if needed.

## Mental model

A Git repository has many branches, but your working tree shows only one at a
time. HEAD is a pointer that says "I am here." `git switch` moves that pointer
to a different branch and updates every file in the working tree and index to
match the tip of that branch.

```text
Before:                       After: git switch feature
  main  <-- HEAD                main
    |                             |
    C3                            C3
    |                             |
    C2        feature             C2        feature  <-- HEAD
    |           |                 |           |
    C1          Cf                C1          Cf
```

Three things happen atomically:

1. HEAD is rewritten to point at the target branch.
2. The index is replaced with the tree at the tip of the target branch.
3. The working tree files are updated to match, file by file.

Git is cautious: if any of your local changes would be overwritten, the
operation is aborted and your work stays intact. You must either commit,
stash, or explicitly tell `git switch` what to do with the uncommitted
changes before it will proceed.

`git switch` was introduced in Git 2.23 as a focused alternative to
`git checkout` for branch-switching work. It has no staging or path-restore
duties — those belong to the *restore* command. When you read older
documentation or scripts using `git checkout <branch>`, the modern equivalent
is `git switch <branch>`.

## Synopsis

```text
git switch [<options>] [--no-guess] <branch>
git switch [<options>] --detach [<start-point>]
git switch [<options>] (-c | -C) <new-branch> [<start-point>]
git switch [<options>] --orphan <new-branch>
```

## Everyday usage

Switch to an existing local branch:

```sh
git switch feature/login
```

Jump back to the branch you were on before:

```sh
git switch -
```

Create a new branch and switch to it immediately:

```sh
git switch -c fix/null-check
```

Create a new branch starting from a specific commit or tag:

```sh
git switch -c release/2.1 v2.0.0
```

Check out a remote branch that does not exist locally yet (Git guesses the
tracking relationship automatically):

```sh
git switch staging
# Branch `staging` set up to track remote branch `staging` from `origin`.
# Switched to a new branch 'staging'
```

Detach HEAD to inspect a historical commit without creating a branch:

```sh
git switch --detach HEAD~5
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-c <new-branch>` | Create `<new-branch>` and switch to it | Start new work from the current or a named commit |
| `-C <new-branch>` | Create `<new-branch>`, resetting it if it already exists | Re-point an existing branch to a new start-point |
| `-d` / `--detach` | Switch to a commit in detached-HEAD state | Inspect history or run throwaway experiments |
| `--orphan <new-branch>` | Create a new branch with no history | Start a completely isolated history (e.g. `gh-pages`) |
| `--guess` / `--no-guess` | Auto-create a local tracking branch when the name matches a remote | `--guess` is the default; use `--no-guess` to suppress the behaviour when you do not want a tracking branch created automatically |
| `-t` / `--track` | Explicitly set the upstream tracking branch | When creating a branch that should track a non-default remote |
| `--no-track` | Do not set up upstream tracking | Suppress tracking even when `branch.autoSetupMerge` is true |
| `-m` / `--merge` | Three-way merge local changes into the target branch | Carry uncommitted edits across a branch switch |
| `--conflict=<style>` | Override conflict-marker style (`merge`, `diff3`, `zdiff3`) | Prefer `diff3` when you want the common ancestor shown |
| `-f` / `--force` / `--discard-changes` | Throw away local changes and force the switch | You want to start over and do not care about uncommitted work |
| `-q` / `--quiet` | Suppress progress and informational messages | Scripting; reduces noise |
| `--recurse-submodules` | Also update submodule working trees | Repositories that use submodules |

## Best practices

**Prefer `git switch` over `git checkout` for branch operations.** The
commands overlap, but `git switch` has a single, clear responsibility. Code
reviews and shell histories are easier to read when branch moves and file
restores are separate operations.

**Use `git switch -c` instead of `git branch` + `git switch`.** The combined
form is transactional: if the switch fails (because the branch is already
checked out in another worktree, for example), the branch is not created
either. With the two-command form the branch exists but you are still on the
old one, which can confuse `git status`.

**Let `--guess` do the remote-tracking wiring for you.** When you type
`git switch staging` and `staging` does not exist locally but `origin/staging`
does, Git creates the local branch and sets its upstream automatically. There
is no need to spell out `git switch -c staging --track origin/staging` by
hand.

**Commit or stash before switching.** If your local changes conflict with the
target branch, the switch is aborted. Running `git stash push -m "WIP: login
refactor"` before `git switch` and `git stash pop` after is the safest and
most explicit pattern. It preserves a clear record of what you set aside.

**Use `-` liberally.** `git switch -` is the fastest way to toggle between two
branches. It behaves like `cd -` in the shell: it always switches to wherever
you were before.

**Name branches consistently before creating them.** Use a
`<type>/<short-description>` convention (e.g. `fix/`, `feat/`, `docs/`,
`chore/`) so branches are sortable and identifiable in long `git branch -a`
listings.

## Pitfalls & gotchas

**"THIS COMMAND IS EXPERIMENTAL"** — the help page carries this warning
because the interface may still change between Git versions. In practice
`git switch` has been stable since Git 2.23, but be aware that very old
installations may not have it at all.

**Detached HEAD is not a branch.** When you run `git switch --detach HEAD~5`,
any commits you make are reachable only through their hash. If you switch away
without first running `git switch -c <new-branch>`, those commits become
unreachable and are eventually garbage-collected. Git warns you when you leave
a detached HEAD that has new commits, but the warning is easy to overlook.

**`-C` is destructive.** `git switch -C existing-branch HEAD` resets
`existing-branch` to point at HEAD without asking for confirmation. Use it
only when you are certain you want to abandon the existing tip of that branch.

**Stashed changes are not automatically reapplied.** `git switch` does not
touch the stash. After switching, you must run `git stash pop` yourself. If
you forget and stash again on the new branch, you will have two stash entries
to untangle.

**`--merge` can leave conflicts.** When `--merge` is used to carry local
changes to the target branch and there are conflicts, the index is left in an
unmerged state. You must resolve conflicts and `git add` each resolved file
before continuing. Run `git status` immediately after a `--merge` switch to
see what needs attention.

**`--discard-changes` is silent and permanent.** Unlike `git stash`, it
destroys your uncommitted work with no recovery path. Run `git diff` and
`git diff --cached` first so you know exactly what you would be discarding.

**The `@{-N}` shorthand counts switch operations, not branch hops.** If you
run `git switch feature`, then `git switch -`, then `git switch -` again, you
end up back on `feature`. Switching back to where you were with `-` is
conceptually a single hop regardless of how many times you do it in a row.

## Worked examples

### Starting a feature branch and returning to main

```sh
# You are on main. Start a new feature.
git switch -c feat/user-preferences
# ... edit and commit work ...
git commit -m "Add user preference storage"

# Reviewer asks for a hotfix on main before the feature is done.
git switch main
git switch -c fix/typo-in-readme
git commit -m "Fix typo in README"

# Merge the hotfix, then return to feature work.
git switch main
git merge --no-ff fix/typo-in-readme
git switch feat/user-preferences
```

The `-` shorthand works perfectly here for the final step if `main` was the
last branch:

```sh
git switch -   # back to feat/user-preferences
```

### Carrying uncommitted changes to the right branch

You edited `src/api.js` on `main` but realise the changes belong on
`feat/api-refactor`.

```sh
# Attempt a normal switch — will fail if the changes conflict.
git switch feat/api-refactor
# error: Your local changes to the following files would be overwritten:
#         src/api.js
# Please commit your changes or stash them before you switch branches.

# Option A: stash, switch, and reapply.
git stash push -m "WIP: api refactor edits"
git switch feat/api-refactor
git stash pop

# Option B: let git do a three-way merge during the switch.
git switch -m feat/api-refactor
# Auto-merging src/api.js
```

Option A is safer when the branches are far apart. Option B is convenient
when you know the branches share a recent common ancestor and the change is
small.

### Inspecting a release tag without creating a branch

```sh
git switch --detach v1.8.3
# HEAD is now at d3a91f2 Release 1.8.3

# Run tests against the old release.
make test

# Nothing worth keeping — return to your branch.
git switch main
# Warning: you are leaving 0 commits behind, not connected to any branch.
# Switched to branch 'main'
```

If you had made commits in detached HEAD state and wanted to keep them:

```sh
git switch -c investigation/v1.8.3-repro
```

### Creating an orphan branch for GitHub Pages

```sh
git switch --orphan gh-pages
# Switched to a new branch 'gh-pages'
# All tracked files are removed from the working tree.

# Add the static site content and commit.
cp -r _site/* .
git add .
git commit -m "Publish docs site"
git push -u origin gh-pages
```

The `--orphan` branch starts with an empty index and no parent commit, so the
documentation history is completely isolated from the source-code history.

## Recovery

If you switched to the wrong branch by accident, switch back immediately:

```sh
git switch -   # return to the previous branch
```

If you ran `--discard-changes` and lost uncommitted work, there is no direct
undo — discarded working-tree changes are not stored by Git. Check whether
your editor or IDE has a local history feature.

If you accidentally moved away from a detached HEAD that had new commits, the
commits are still in the reflog for a while:

```sh
git reflog
# find the hash of the last commit you made in detached HEAD
git switch -c recovery/detached abc1234
```

See *Getting out of jams* for additional undo recipes covering lost commits
and stash conflicts.

## See also

- *checkout* — the older command that `switch` was split out from; still
  needed for checking out individual files.
- *restore* — the companion command for discarding file-level changes without
  switching branches.
- *branch* — create, list, rename, and delete branches.
- *stash* — save uncommitted changes before switching when `-m` is not
  appropriate.
- *worktree* — check out multiple branches simultaneously in separate
  directories, eliminating many context-switch round-trips.
- *Getting out of jams* — recovering lost commits and resolving post-switch
  conflicts.
