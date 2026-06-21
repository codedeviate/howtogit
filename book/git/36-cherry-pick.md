# cherry-pick

Apply the changes introduced by one or more existing commits onto the current
branch, creating a new commit for each.

## Mental model

Every commit in Git records a *diff* — the delta between its parent tree and
its own tree. `git cherry-pick` takes that diff, replays it on top of your
current HEAD, and records the result as a brand-new commit. The new commit has
a different hash (it has a different parent, a different timestamp, and
possibly a different author date) but carries the same logical change.

Think of cherry-pick as a targeted copy, not a move. The source commit stays
exactly where it was; you are grafting an equivalent patch onto a different
branch.

```text
main:    A──B──C──D           (D introduced the bug fix you need)

feature: E──F──G              (your current branch, before)

After: git cherry-pick D

feature: E──F──G──D'          (D' is the replayed patch; D remains on main)
```

Cherry-pick uses the same three-way merge machinery as `git merge`. If the
context around the changed lines differs enough from what the patch expects,
you get a conflict, and you resolve it the same way you would a merge
conflict.

## Synopsis

```text
git cherry-pick [--edit] [-n] [-m <parent-number>] [-s] [-x] [--ff]
                [-S[<keyid>]] <commit>...
git cherry-pick (--continue | --skip | --abort | --quit)
```

## Everyday usage

Copy a single commit to the current branch:

```sh
git cherry-pick a3f9c1b
```

Copy a range of commits (picks all commits reachable from `feature` but not
from the current HEAD):

```sh
git cherry-pick main..feature
```

Copy several non-contiguous commits in one command:

```sh
git cherry-pick a3f9c1b e72d44f 09ab231
```

Stage the changes without creating commits yet — useful when you want to
combine multiple picks into a single commit:

```sh
git cherry-pick -n a3f9c1b e72d44f
git commit -m "Combine two upstream fixes"
```

Backport a fix to a maintenance branch and annotate the new commit with where
it came from:

```sh
git switch release/2.x
git cherry-pick -x a3f9c1b
```

Edit the commit message before the new commit is recorded:

```sh
git cherry-pick --edit a3f9c1b
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-e`, `--edit` | Open the editor to modify the commit message before committing | Adapting an upstream message to a backport context |
| `-x` | Append `(cherry picked from commit ...)` to the commit message (only when the pick applies cleanly; the line is not added if you resolve conflicts manually) | Backporting between public branches so the provenance is traceable |
| `-n`, `--no-commit` | Apply changes to the index and working tree without creating a commit | Combining multiple picks into one commit, or inspecting before committing |
| `-m <n>`, `--mainline <n>` | Specify which parent (1-based) is the mainline when picking a merge commit | Required when the commit to pick is a merge commit |
| `-s`, `--signoff` | Append a `Signed-off-by` trailer to the commit message | Projects requiring DCO sign-off |
| `-S[<keyid>]`, `--gpg-sign` | GPG-sign the resulting commit | Maintaining a verified-commit policy on the target branch |
| `--ff` | Fast-forward HEAD if the current commit is the parent of the picked commit | Applying a linear series cleanly without creating redundant merge objects |
| `--allow-empty` | Preserve commits that were initially empty | Carrying intentional empty commits (e.g. CI trigger points) across branches |
| `--empty=(drop\|keep\|stop)` | Control what happens when a picked commit becomes empty due to prior changes | `drop` to silently skip redundant commits; `keep` to preserve them; `stop` (default) to pause and inspect |
| `--strategy=<strategy>` | Choose a merge strategy (e.g. `ort`, `recursive`) | Switching strategies when the default produces avoidable conflicts |
| `-X<option>`, `--strategy-option=<option>` | Pass an option through to the merge strategy | Trying `-Xpatience` when context-line mismatches cause unnecessary conflicts |
| `--rerere-autoupdate` | Let rerere automatically stage its resolved hunks | Speeding up repetitive conflict resolution on a long backport series |
| `--continue` | Resume after resolving conflicts | Picking up a multi-commit sequence after fixing conflicts |
| `--skip` | Skip the current conflicting commit and continue the sequence | Intentionally omitting one commit from a range pick |
| `--abort` | Cancel the entire operation and restore pre-pick state | Abandoning a pick that is too conflicted to proceed |
| `--quit` | Clear the sequencer state without restoring the working tree | Keeping partial progress while discarding the sequencer bookkeeping |

## Best practices

**Prefer merging or rebasing over cherry-picking for whole-branch integration.**
Cherry-pick duplicates commits — the same logical change exists twice in
history under different hashes. If you later merge the original branch, Git
has no way to know those patches are equivalent, and the same change can
appear twice in the final log or cause spurious conflicts. Reserve
cherry-pick for cases where you genuinely need only *some* commits from
another branch, not the whole thing.

**Use `-x` when backporting to shared branches.** The annotation
`(cherry picked from commit abc1234)` lets anyone who bisects or audits the
maintenance branch trace the fix back to its origin. Omit `-x` only when
picking from a private or short-lived branch where the source hash is
meaningless to future readers.

**Pick the smallest meaningful unit.** If the commit you need is entangled
with unrelated changes, consider splitting it on a scratch branch first (see
the *commit* chapter on `--patch` staging), then picking the focused result.
A clean pick is easier to review and much easier to revert if something goes
wrong.

**Resolve conflicts promptly during a sequence.** When picking a range and a
conflict appears, Git halts with the sequencer state recorded in
`.git/sequencer`. Fix the conflict, stage the resolved files, then run
`git cherry-pick --continue`. Leaving the repository in a mid-pick state
invites accidental edits that complicate resolution.

**Test after picking, especially on maintenance branches.** A patch that
applies cleanly at the hunk level does not guarantee correct behavior in the
target codebase. The surrounding code may have diverged since the original
commit was written. Run at minimum the tests that exercise the changed area
before pushing.

## Pitfalls & gotchas

**Picking a merge commit requires `-m`.** A merge commit has two or more
parents. Git cannot determine which side represents the mainline without
being told. Omitting `-m` causes an immediate error. Pass `-m 1` to treat
the first parent as the mainline, which is the branch that was active when
the merge was made.

**Duplicate commits after merging the source branch later.** If you
cherry-pick commit D from `feature` into `main`, and then later merge
`feature` into `main`, the same change appears in history twice under
different hashes. `git log` will show both; `git blame` will attribute lines
to whichever commit landed last. Use cherry-pick with the awareness that the
source branch should not be merged back unless you are prepared to deal with
this duplication.

**Empty-commit behavior is not obvious.** If the change you are picking has
already been applied to the target branch by another path, the resulting
commit is empty — no diff. By default (`--empty=stop`) Git halts and asks
what to do. During a long range pick this can be surprising. Use
`--empty=drop` to silently skip such commits when you know the target branch
has overlapping history.

**`--no-commit` picks up anything already staged.** When you use `-n` and
there are already staged changes in your index, those changes will be
included in whatever commit you eventually run. This is intentional and
useful, but if you are not expecting it, you can accidentally bundle
unrelated work into one commit. Check `git diff --cached` before committing.

**Conflict markers follow the merge layout.** The `<<<<<<< HEAD` side is your
current branch; the `>>>>>>> <hash>` side is the commit being picked. Read
and resolve them exactly as you would a merge conflict.

**`--abort` discards all in-progress picks.** If you are in the middle of a
ten-commit range pick and abort, Git restores the branch pointer to the state
before the very first commit in the sequence. Any commits that had already
been created during the sequence are still reachable through the reflog, but
your branch pointer is rolled back.

## Worked examples

### Backporting a security fix to a maintenance branch

Your team has just merged a security fix (`e8b3f12`) into `main`. The same
vulnerability exists in the `release/3.2` maintenance branch.

```sh
# Start from the maintenance branch
git switch release/3.2

# Pick the fix and annotate it with its origin
git cherry-pick -x e8b3f12
```

If it applies cleanly, Git creates a new commit on `release/3.2` with the
message from `e8b3f12` plus the annotation line:

```text
Fix SQL injection in user search endpoint

(cherry picked from commit e8b3f12a94c1d7b0e5f3a...)
```

Run your test suite, then push the maintenance branch.

### Picking a range with a conflict mid-sequence

You want to port three commits from `experiment` to `main`:

```sh
git switch main
git cherry-pick experiment~3..experiment   # picks the three newest commits
```

The second commit conflicts. Git halts:

```console
error: could not apply 7a4c91b... Refactor query builder
hint: After resolving the conflicts, mark them with
hint: "git add/rm <pathspec>", then run
hint: "git cherry-pick --continue".
```

Open the conflicting file, resolve the conflict markers, then continue:

```sh
git add src/query.js
git cherry-pick --continue
```

Git applies the third commit automatically and finishes the sequence. To
abandon the entire operation instead:

```sh
git cherry-pick --abort
```

Your branch returns to the state before the first pick.

### Combining multiple upstream commits into one

You want to pull two small upstream refactoring commits into a feature branch
as a single clean commit:

```sh
git switch my-feature

# Apply both sets of changes to the index without committing
git cherry-pick -n c3d1e2f 88fa012

# Verify what will be committed
git diff --cached

# Create one unified commit
git commit -m "Apply upstream query-builder refactors"
```

### Picking a merge commit

A hotfix was delivered as a merge commit `m1a2b3c` on `main`, and you need
it on `hotfix/4.1`. The merge's first parent is `main`, so pass `-m 1`:

```sh
git switch hotfix/4.1
git cherry-pick -m 1 m1a2b3c
```

Without `-m`, Git refuses: `is a merge but no -m option was given`.

### Retrying a conflicted pick with a different strategy

The default merge strategy produces conflicts because the surrounding context
lines have shifted significantly since the original commit. Try the
`patience` diff algorithm:

```sh
# First attempt fails with conflicts; abort it
git cherry-pick a3f9c1b
git cherry-pick --abort

# Retry with a more careful context-matching strategy
git cherry-pick -Xpatience a3f9c1b
```

## Recovery

To undo the most recent cherry-pick commit while keeping the changes staged:

```sh
git reset --soft HEAD~1
```

To discard both the commit and the changes:

```sh
git reset --hard HEAD~1
```

To create a proper inverse commit instead of erasing history — the right
choice after pushing — see the *revert* chapter.

If you used `--abort` but want to recover commits that were created before
the abort, they are still reachable through the reflog:

```sh
git reflog
# Identify the hash of the last commit made during the sequence, then
git cherry-pick <that-hash>
```

See *Getting out of jams* for broader undo recipes, including recovering from
a hard reset.

## See also

- *revert* — create an inverse commit to undo a change without rewriting history.
- *rebase* — replay an entire branch's commits onto a new base; prefer over
  cherry-pick when you want to move all commits from one branch to another.
- *commit* — details on commit messages, `--allow-empty`, and staging with `--patch`.
- *merge* — the three-way merge machinery that cherry-pick relies on for
  conflict resolution.
- *Getting out of jams* — undoing picks and resolving a stuck sequencer.
