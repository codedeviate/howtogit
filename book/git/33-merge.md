# merge

Integrate the history of one branch into another by creating a merge commit
or advancing the branch pointer via fast-forward.

## Mental model

Every branch in Git is just a pointer to a commit. When you merge, Git finds
the common ancestor of the two branch tips, then combines the work done on
each side since that ancestor into a unified result.

There are two outcomes depending on the shape of the history:

**Fast-forward** — when the current branch has not diverged at all from the
branch you are merging in, Git simply moves the current branch pointer
forward to the tip of the incoming branch. No new commit is created. The
history remains a straight line.

```text
Before:
  main:    A---B---C
                    \
  feature:            D---E

After fast-forward merge of feature into main:
  main:    A---B---C---D---E
```

**True merge** — when both branches have new commits since they diverged,
Git performs a three-way merge using the common ancestor as the base. If the
changes do not overlap, Git resolves them automatically and records the
result in a new merge commit with two parents. If they do overlap, Git pauses
with a conflict for you to resolve manually.

```text
Before:
  main:    A---B---C---G
              \
  feature:     D---E---F

After true merge (H is the merge commit):
  main:    A---B---C---G---H
              \           /
  feature:     D---E---F
```

Before the operation begins, Git saves the current branch tip as `ORIG_HEAD`
so you can undo the merge if needed.

## Synopsis

```text
git merge [--ff | --no-ff | --ff-only] [--squash] [--no-commit]
          [-m <msg>] [-F <file>] [-s <strategy>] [-X <option>]
          [--no-verify] [--allow-unrelated-histories]
          [--[no-]rerere-autoupdate] [--autostash]
          [-S[<keyid>]] [<commit>...]
git merge (--continue | --abort | --quit)
```

## Everyday usage

Merge a feature branch into the current branch (typically `main`):

```sh
git switch main
git merge feature/login
```

Merge and always produce a merge commit, even if fast-forward is possible.
This preserves the fact that the work was done on a separate branch:

```sh
git merge --no-ff feature/login
```

Merge only if a fast-forward is possible; refuse and exit non-zero otherwise:

```sh
git merge --ff-only origin/main
```

Squash all commits from the incoming branch into the index, then commit them
as a single new commit on the current branch:

```sh
git merge --squash feature/login
git commit -m "Add login feature"
```

Abort an in-progress merge after conflicts arise:

```sh
git merge --abort
```

Resume after resolving conflicts manually:

```sh
# edit conflicting files, then:
git add src/auth.js
git merge --continue
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--ff` | Fast-forward when possible; create a merge commit otherwise (default) | Normal day-to-day merges |
| `--no-ff` | Always create a merge commit, even when fast-forward is possible | Preserve branch topology in history |
| `--ff-only` | Refuse to merge if it cannot be fast-forwarded | Keep a linear history; fail loudly if diverged |
| `--squash` | Apply the combined changes to the index without recording a merge commit | Deliver a branch as one clean commit |
| `--no-commit` | Perform the merge but stop before creating the commit | Inspect or tweak the merge result before recording it |
| `-m <msg>` | Set the merge commit message | Customize the auto-generated message |
| `-F <file>` | Read the merge commit message from a file | Multi-line messages prepared in advance |
| `-s <strategy>` | Select the merge strategy (`ort`, `octopus`, `ours`, `resolve`, `subtree`) | Override the default strategy |
| `-X <option>` | Pass a strategy-specific option (e.g. `-X ours`, `-X theirs`) | Auto-resolve conflicts by favoring one side |
| `--no-verify` | Skip the pre-merge and commit-msg hooks | Emergency bypass; fix the hook issue afterward |
| `--allow-unrelated-histories` | Merge histories with no common ancestor | Joining two independent repositories |
| `--autostash` | Automatically stash dirty working tree before merging and re-apply after | Merge without needing a clean working tree |
| `--abort` | Discard the in-progress merge and restore the pre-merge state | Give up after hitting conflicts |
| `--continue` | Conclude a paused merge after resolving conflicts | Resume after editing conflict markers |
| `--quit` | Forget the in-progress merge without touching the working tree | Abandon the state machine, keep your edits |
| `-S[<keyid>]` | GPG-sign the resulting merge commit | Verified merge commits on GitHub/GitLab |
| `--verify-signatures` | Abort if the incoming branch tip is not signed with a valid key | Enforce signed-commit policy |

## Best practices

**Always merge into a clean working tree.** Git warns you if you have
uncommitted changes, and `--abort` may not fully restore them afterward.
Run `git status` before merging; stash or commit anything in flight.

**Prefer `--no-ff` when merging feature branches into long-lived branches.**
With the default fast-forward, the branch structure is lost from history.
`--no-ff` leaves an explicit record that a set of commits was developed
together and then integrated, which makes `git log --graph` and `git bisect`
more informative.

**Set `merge.ff=false` in your project config to make `--no-ff` the default**
for that repository:

```sh
git config merge.ff false
```

**Use `--squash` only when the branch-internal history is noise.** Squash
merges collapse the entire branch into one commit, which is convenient for
tiny spikes or work-in-progress branches but destroys the record of
individual changes. Use it deliberately; do not squash feature branches
that other people will rebase on.

**Set `merge.conflictStyle = diff3` or `zdiff3` to improve conflict
readability.** The default style shows only your side and their side.
`diff3` also shows the common ancestor, which makes it far easier to
understand what each side actually changed:

```sh
git config --global merge.conflictStyle diff3
```

**Write a meaningful merge message.** The auto-generated "Merge branch X"
message is the bare minimum. When merging a long-lived feature, add a line
describing the scope of the work.

## Pitfalls & gotchas

**Fast-forward erases branch topology.** After a fast-forward merge there is
no commit in history that says "this is where the feature branch was merged."
`git log --oneline` shows a straight line with no indication that these
commits were developed on a side branch. If traceability matters, use
`--no-ff`.

**`--squash` does not record a merge relationship.** After `git merge
--squash`, Git does not set `MERGE_HEAD`, so the next `git commit` creates an
ordinary commit, not a merge commit. The source branch is not recorded as
merged; `git branch --merged` will not list it. If you later try to merge the
same branch again, Git will not know it has already been incorporated and
may produce unexpected conflicts.

**Merging with a dirty index is refused.** If your index has staged changes
relative to `HEAD`, Git will refuse to merge. Commit or unstage them first
with `git restore --staged`.

**`--abort` may not recover uncommitted working-tree changes.** If you had
dirty tracked files when you started the merge, `--abort` attempts to restore
them, but complex cases can leave the working tree in a partial state. Start
merges from a clean working tree.

**Reverted commits re-appear after a merge.** If commit X was made on branch
A and then reverted on branch B, merging A into B will re-introduce the
original change. Git's three-way merge sees the revert as "no net change" on
branch B and substitutes branch A's version. The fix is to revert the revert
before merging, or use `-X ours` to explicitly discard the incoming change.

**Octopus merges refuse complex conflicts.** Merging more than two branches
at once uses the `octopus` strategy, which does not perform interactive
conflict resolution. If any conflict requires manual intervention, the entire
octopus merge is refused and you must merge branches one at a time.

## Worked examples

### Merging a feature branch with an explicit merge commit

You have finished work on `feature/checkout` and want to integrate it into
`main` with a visible merge commit.

```sh
git switch main
git pull --ff-only origin main   # get the latest upstream first
git merge --no-ff feature/checkout
```

Git opens the editor with an auto-generated message. Edit it to describe the
feature, save, and close. The resulting graph:

```text
* 9f3a2c1  (HEAD -> main) Merge branch 'feature/checkout'
|\
| * d4e8f12  Add order summary to checkout page
| * b7a1c09  Implement payment provider selection
|/
* a3f0d88  (origin/main) Prepare release pipeline
```

### Resolving a conflict manually

You merge `feature/nav` into `main` and Git stops with a conflict in
`src/components/NavBar.jsx`.

```console
$ git merge feature/nav
Auto-merging src/components/NavBar.jsx
CONFLICT (content): Merge conflict in src/components/NavBar.jsx
Automatic merge failed; fix conflicts and then commit the result.
```

Open `src/components/NavBar.jsx`. The conflict markers look like this with
`merge.conflictStyle = diff3` enabled:

```text
<<<<<<< HEAD
  <nav className="nav-dark">
||||||| base
  <nav className="nav">
=======
  <nav className="nav-light">
>>>>>>> feature/nav
```

The `|||||||` section shows the original. `HEAD` changed it to dark;
the feature branch changed it to light. Decide which version is correct,
remove all conflict markers, and save. Then stage and continue:

```sh
git add src/components/NavBar.jsx
git merge --continue
```

Git creates the merge commit. If other files have conflicts, repeat the
edit-and-add cycle before running `--continue`.

### Squash-merging a short-lived spike

A teammate ran a proof-of-concept on `spike/graphql` across five messy
commits. You want the end result on `main` as a single, clean commit.

```sh
git switch main
git merge --squash spike/graphql
```

Git applies the combined diff to the index but does not commit. Review the
staged changes, then commit with a proper message:

```sh
git diff --staged          # review what will be committed
git commit -m "Introduce GraphQL endpoint for product search

Proof of concept extracted from spike/graphql. Supersedes the REST
endpoint added in a3f9c1. See docs/spikes/graphql.md."
```

The `spike/graphql` branch is not marked as merged, so delete it explicitly
when done:

```sh
git branch -D spike/graphql
```

### Auto-resolving conflicts with a strategy option

You are merging a maintenance branch that contains only whitespace cleanups,
and you know every conflict should favor the incoming branch:

```sh
git merge -X theirs maintenance/formatting
```

`-X theirs` passes the `theirs` option to the `ort` strategy, which resolves
every conflicting hunk by accepting the incoming side. Non-conflicting changes
are merged normally.

## Recovery

To undo a completed merge commit before pushing, reset to `ORIG_HEAD`:

```sh
git reset --merge ORIG_HEAD
```

`--merge` undoes the merge commit and cleans up conflict-related index
entries while preserving any uncommitted working-tree changes you had before
the merge.

To abort a merge that has stopped mid-flight due to conflicts:

```sh
git merge --abort
```

If `--abort` leaves the working tree in an unexpected state, or if you need
to undo a merge that has already been pushed, see *Getting out of jams* for
more targeted reset and revert recipes.

## See also

- *branch* — create and list branches before merging.
- *switch* — change to the target branch before running merge.
- *rebase* — an alternative to merging that rewrites commits onto a new base,
  producing a linear history.
- *cherry-pick* — integrate individual commits without merging an entire
  branch.
- *revert* — safely undo a merged commit by adding a new commit that cancels
  its changes.
- *mergetool* — launch a graphical three-way merge tool to resolve conflicts.
- *Getting out of jams* — undo a bad merge or recover from a conflict gone
  wrong.
