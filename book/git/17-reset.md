# reset

Move the current branch pointer to a different commit, with optional control
over whether the index and working tree follow along.

## Mental model

Git tracks three distinct snapshots at any moment:

- **HEAD** — the commit the current branch points to (the repository).
- **Index** — the staging area; a draft of the next commit.
- **Working tree** — files as they exist on disk.

`git reset` is a dial that controls how far those three layers are rewound
toward a target commit. The dial has three main positions:

```text
                      HEAD    Index    Working tree
  --soft    rewind    yes      no          no
  --mixed   rewind    yes      yes         no       (default)
  --hard    rewind    yes      yes         yes
```

Moving HEAD backward is always safe — the commits you pass over are not
deleted, just no longer reachable from the branch tip. The index and working
tree are where data can be lost: `--hard` discards changes in both without a
second prompt.

A second, distinct use of `reset` targets individual paths rather than the
whole tree. `git reset <pathspec>` copies entries from HEAD back into the
index without touching the working tree or moving HEAD at all. That is the
opposite of `git add <pathspec>`, and is the canonical way to unstage a file.

```text
Unstage:  git add README  ──────>  index has README change
          git reset README <──────  index reverts to HEAD's README
```

Before every whole-branch reset, Git writes the current HEAD into
`ORIG_HEAD`, giving you a one-step escape hatch.

## Synopsis

```text
# Move branch pointer (whole-tree forms)
git reset [--soft | --mixed [-N] | --hard | --merge | --keep] [-q] [<commit>]

# Unstage paths (path forms — never moves HEAD)
git reset [-q] [<tree-ish>] [--] <pathspec>...
git reset [-q] [--pathspec-from-file=<file> [--pathspec-file-nul]] [<tree-ish>]

# Interactively unstage hunks
git reset (--patch | -p) [<tree-ish>] [--] [<pathspec>...]
```

`<commit>` defaults to HEAD when omitted.

## Everyday usage

**Unstage a file you added by mistake:**

```sh
git add oops.log
git reset oops.log          # remove from index, keep on disk
```

**Undo the last commit, keep changes staged:**

```sh
git reset --soft HEAD~1
```

The files are still staged exactly as they were; you can edit and re-commit.

**Undo the last commit, unstage the changes (but keep files on disk):**

```sh
git reset HEAD~1            # --mixed is the default
```

Use this when you want to re-examine what you committed before deciding how
to split it up.

**Discard the last commit and all changes completely:**

```sh
git reset --hard HEAD~1
```

This is destructive. Anything not committed is gone.

**Unstage part of a commit interactively:**

```sh
git reset -p                # hunk-by-hunk: remove hunks from the index
```

Each hunk is presented and you choose whether to unstage it. This is the
mirror image of `git add -p`.

**Abort a botched merge that has not been committed:**

```sh
git reset --hard ORIG_HEAD
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--soft` | Moves HEAD only; index and working tree unchanged | Re-do the last commit: change the message or add more files |
| `--mixed` | Moves HEAD and resets the index; working tree unchanged | Default; unstage everything since the target commit |
| `--hard` | Moves HEAD, resets index, and overwrites working tree | Throw away a commit and all uncommitted changes completely |
| `--merge` | Resets the index and updates working-tree files that differ between `<commit>` and HEAD, but preserves files that differ between the index and working tree (i.e. unstaged changes); aborts if a file that differs between `<commit>` and the index also has unstaged changes | Back out of a failed merge while keeping your in-progress edits |
| `--keep` | Resets index and working-tree files that differ between HEAD and target; aborts if any such file has local changes | Remove recent commits while protecting local edits from being overwritten |
| `-N` | With `--mixed`: marks removed paths as intent-to-add instead of truly removing them | Split a commit while preserving newly added files for `git add -p` |
| `-p` / `--patch` | Interactively select hunks to remove from the index | Partially unstage a file, hunk by hunk |
| `-q` / `--quiet` | Suppress output; report errors only | Scripts and hooks |
| `--pathspec-from-file=<file>` | Read path list from a file instead of the command line | Scripted bulk unstage from a generated file list |

## Best practices

**Prefer `--soft` or `--mixed` for commits that have not been pushed.** Both
modes preserve your work in a recoverable state. Reserve `--hard` for
situations where you are certain you want the working-tree changes gone.

**Reset to a symbolic reference rather than a raw hash.** `HEAD~1`, `HEAD~3`,
and `ORIG_HEAD` are self-documenting. Raw hashes typed by hand are opaque and
error-prone.

**Check `git status` immediately after `--mixed`.** After unwinding commits,
the index is clean and the changes appear as unstaged modifications. Glancing
at `git status` before re-staging confirms you understand exactly what was
unwound.

**Use `ORIG_HEAD` as your safety net.** Every whole-tree `reset` records the
previous HEAD in `ORIG_HEAD`. If you immediately regret the reset, `git reset
--hard ORIG_HEAD` brings you back. This only works before you do another
reset that overwrites `ORIG_HEAD`.

**Do not reset commits that have been pushed to a shared branch.** Resetting
rewrites the branch tip. Any collaborator who already pulled those commits
will have a diverged history. Use `git revert` instead when you need to undo
work on a public branch — it adds a new commit that reverses the changes
without rewriting history.

**Prefer `git restore --staged <file>` for single-file unstaging.** For
modern Git (2.23+), `git restore --staged <file>` is more explicit than
`git reset <file>` for the path-form use case. Both are correct; `restore`
makes the intent harder to misread.

## Pitfalls & gotchas

**`--hard` permanently discards uncommitted changes.** There is no undo for
working-tree changes that were never committed or stashed. Before running
`--hard`, verify with `git status` that you have nothing valuable unstaged or
untracked.

**`--hard` deletes untracked files that block writing a tracked file.** If a
tracked file was deleted in HEAD but you have an untracked file with the same
name in the working tree, `--hard` removes the untracked file to restore the
tracked version.

**`--soft` on a merge commit leaves the index in a merged state.** If HEAD is
a merge commit and you reset `--soft HEAD~1`, you land on one parent while
the index still contains the merged tree. That is usually not what you want;
use `--mixed` instead.

**Path-form reset does not move HEAD.** Running `git reset HEAD~1 src/` copies
`src/` from `HEAD~1` into the index but leaves the branch pointer where it is.
It looks like `--mixed` but only for the specified paths.

**`--merge` and `--keep` both abort on certain dirty states.** Neither will
proceed if the conditions for safely preserving local changes cannot be met.
Read the error message — it tells you which file caused the abort.

**`ORIG_HEAD` is overwritten by the next whole-tree reset.** If you run two
resets in a row, the first `ORIG_HEAD` is gone. Recover with `git reflog`
instead.

**Resetting in a detached HEAD state moves HEAD itself, not a branch.** If
you are not on a named branch, `reset` still works but the commits you leave
behind are only reachable via reflog. Create a branch before resetting if you
want to keep those commits.

## Worked examples

### Splitting an over-stuffed commit into two

You committed a bug fix and a refactor together. Now you want them as
separate commits.

```sh
# Undo the last commit; keep all changes unstaged in the working tree
git reset HEAD~1
```

```text
Unstaged changes after reset:
M    src/api.js
M    src/utils.js
```

Stage and commit just the bug fix:

```sh
git add -p src/api.js       # choose only the bug-fix hunks
git commit -m "Fix null-pointer dereference in parseToken"
```

Then commit the refactor:

```sh
git add src/api.js src/utils.js
git commit -m "Extract token validation into a helper"
```

### Rescuing work after an accidental --hard reset

You ran `git reset --hard HEAD~2` and immediately realized you needed one
of those commits.

```sh
# Find the lost commits in the reflog
git reflog
```

```text
d4e8b3a HEAD@{0}: reset: moving to HEAD~2
a1c72f9 HEAD@{1}: commit: Add payment retry logic
7f301bb HEAD@{2}: commit: Fix cart total rounding
e9a0c44 HEAD@{3}: checkout: moving from develop to feature/cart
```

The two lost commits are at `HEAD@{1}` and `HEAD@{2}`. Restore the branch
to where it was before the reset:

```sh
git reset --hard HEAD@{1}
```

Or recover just one specific commit:

```sh
git cherry-pick 7f301bb
```

### Undoing a faulty merge while preserving local edits

You pulled from upstream and the merge introduced conflicts you want to
discard, but you also have in-progress local edits that have not been staged.

```sh
git pull origin main
```

```text
Auto-merging checkout.js
CONFLICT (content): Merge conflict in checkout.js
Automatic merge failed; fix conflicts and then commit the result.
```

You decide you are not ready to merge yet and want to return to your
pre-pull state without losing your in-progress edits:

```sh
git reset --merge ORIG_HEAD
```

`--merge` resets the files involved in the merge back to their pre-pull
state while leaving your other unstaged edits untouched. `--hard ORIG_HEAD`
would have discarded those edits.

### Snapshot-and-return workflow for interrupted work

You are mid-feature when an urgent fix is needed on `main`. Your working
tree is not in a committable state, but you need to switch branches cleanly.

```sh
# Save a rough snapshot commit (message does not matter)
git commit -a -m "WIP snapshot"
git switch main

# ... apply the urgent fix, commit, switch back ...

git switch feature/my-work
# Dissolve the snapshot: puts HEAD back one commit, changes stay unstaged
git reset HEAD~1
```

Your working tree is exactly as you left it and there is no stray WIP
commit polluting the branch history. See the *stash* chapter for a
lighter-weight alternative that avoids the snapshot commit entirely.

## Recovery

If you reset the branch pointer too far back, recover the original tip from
the reflog:

```sh
git reflog                   # find the entry just before the reset
git reset --hard HEAD@{1}    # substitute the correct reflog index
```

If you used `--hard` and lost uncommitted working-tree changes, there is no
general Git recovery path — those changes were never stored as objects. Check
whether your editor has a local history buffer (VS Code's Timeline, JetBrains'
Local History) before concluding they are gone.

See *Getting out of jams* for more undo recipes, including recovering commits
that were amended or rebased away and untangling diverged branches after an
accidental push of a rewritten branch.

## See also

- *commit* — the command `reset --soft` most commonly precedes; understanding
  how commits are built makes reset behavior clearer.
- *add* — `git reset <pathspec>` is the exact inverse of `git add <pathspec>`.
- *restore* — the modern, more explicit alternative for the path-form of reset
  (`git restore --staged <file>`).
- *revert* — the safe alternative to `reset` on already-pushed commits; adds a
  new commit rather than rewriting history.
- *rebase* — interactive rebase with `edit` or `drop` achieves many of the
  same history-rewriting goals as reset, with a step-by-step interface.
- *stash* — a lighter-weight alternative to the snapshot-and-reset pattern
  when you need to park in-progress changes temporarily.
- *Getting out of jams* — step-by-step rescue procedures for the most common
  reset-related disasters.
