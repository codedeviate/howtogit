# restore

Restore working tree files or index entries to a known state without moving
the current branch.

## Mental model

Git tracks three places where a file's content can live:

1. **The repository** — committed history, addressed by commit hashes, branch
   names, or tags.
2. **The index (staging area)** — the draft of the next commit, built up with
   `git add`.
3. **The working tree** — the files you actually edit on disk.

`git restore` is a targeted copy operation between those layers. You name a
source (a commit, a tree, or the index itself) and a destination (the working
tree, the index, or both), and Git copies the content across. The branch
pointer and commit history are never touched.

```text
Repository ──--source=<tree>──> Index (--staged) ──> Working tree (default)
Index (default source) ──────────────────────────> Working tree (default)
```

Before `git restore` was introduced in Git 2.23, these operations were split
across `git checkout` (working tree) and `git reset` (index). The dedicated
command makes intent explicit: restoring content is a separate concern from
switching branches or rewriting history.

> **Note:** The man page still marks this command as experimental. The
> interface has been stable in practice since Git 2.23, but the `--help` text
> carries the caveat.

## Synopsis

```text
git restore [<options>] [--source=<tree>] [--staged] [--worktree] [--] <pathspec>...
git restore [<options>] [--source=<tree>] [--staged] [--worktree]
            --pathspec-from-file=<file> [--pathspec-file-nul]
git restore (-p|--patch) [<options>] [--source=<tree>] [--staged] [--worktree]
            [--] [<pathspec>...]
```

## Everyday usage

Discard uncommitted edits to a file in the working tree:

```sh
git restore README.md
```

Unstage a file (move it out of the index without touching the working tree):

```sh
git restore --staged README.md
```

Unstage and also discard the working-tree changes in one step:

```sh
git restore --staged --worktree README.md
```

Restore a file to its state in a specific commit:

```sh
git restore --source=HEAD~2 src/config.js
```

Discard all uncommitted changes in the current directory:

```sh
git restore .
```

Discard all uncommitted changes in the entire repository regardless of where
you are in the tree:

```sh
git restore :/
```

Interactively choose which hunks to discard:

```sh
git restore -p src/api.js
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--staged` / `-S` | Restore the index (unstage) | Undo a `git add` |
| `--worktree` / `-W` | Restore the working tree (default when neither flag given) | Explicitly target the working tree alongside `--staged` |
| `--source=<tree>` / `-s <tree>` | Use a commit, branch, or tag as the source instead of the index | Pull an older version of a file into the working tree or index |
| `--patch` / `-p` | Interactively select hunks to restore | Discard only part of a file's changes |
| `--ours` | When restoring from the index during a merge conflict, use the ours (stage 2) version | Resolve a conflict by keeping your branch's side |
| `--theirs` | Use the theirs (stage 3) version from the index | Resolve a conflict by accepting the incoming side |
| `--merge` / `-m` | Recreate the three-way conflict markers for unmerged paths | Re-open a conflict you accidentally resolved |
| `--conflict=<style>` | Override the conflict presentation style (`merge`, `diff3`, `zdiff3`) | Prefer `diff3` for more context around conflict markers |
| `--ignore-unmerged` | Skip unmerged paths without aborting | Restore a subset of files when a merge is in progress |
| `--overlay` | Never remove files when restoring | Prevent `--source` from deleting files absent in the source tree |
| `--no-overlay` | Remove tracked files absent from the source tree (default) | Make the working tree exactly match a given tree |
| `--recurse-submodules` | Also restore submodule working trees | Update a submodule to the commit recorded in the superproject |
| `--pathspec-from-file=<file>` | Read paths from a file instead of the command line | Automate restores with long or generated path lists |
| `--quiet` / `-q` | Suppress progress messages | Scripting |

## Best practices

**Prefer `git restore` over `git checkout -- <file>`.** The older form mixes
path-restoring and branch-switching in one command, making the intent unclear
to readers and error-prone in scripts. `git restore` says exactly what it
does.

**Use `--staged` first, then `--worktree` separately when unsure.** Running
`git restore --staged --worktree` discards both your staged and unstaged work
in one shot — an operation you cannot undo. If you only want to unstage, leave
`--worktree` off. You can always discard the working-tree changes afterward if
you decide to.

**Use `--source` to safely examine an old file version.** When you need to
compare or copy logic from a file at an older commit, restore it with
`--source=<commit>` and then decide whether to keep the result or revert to
the index. The old commit is untouched.

**Pair `--patch` with careful review.** Interactive hunk selection (the same
UI used by `git add -p`) lets you discard only the noise in a file while
keeping meaningful changes. Treat each hunk as a decision, not a formality.

**Quote globs to let Git expand them.** When restoring all files matching a
pattern (e.g., `'*.c'`), quote the glob. If the shell expands it, only files
already in the working tree are matched; if Git expands it, files that were
deleted but still exist in the index are also restored.

```sh
# correct: Git resolves the glob against the index
git restore '*.c'

# risky: the shell may miss deleted files
git restore *.c
```

## Pitfalls & gotchas

**Restoring the working tree is destructive and usually unrecoverable.**
`git restore` (without `--staged`) overwrites your working-tree file. The
content is not committed, not stashed, and not in any reflog. Verify with
`git diff` before running it if there is any chance you want those changes.

**`--staged` alone does not touch the working tree.** After `git restore
--staged README.md`, the file in your editor still shows the staged content.
The index is reset to HEAD, but your working-tree file is unchanged. This is
what you want when unstaging; remember it when you expected everything to
revert.

**Without `--source`, `--staged` restores from HEAD, not the previous index
state.** If you staged a change and then want the index to reflect an earlier
commit rather than HEAD, you must specify `--source=<commit>` explicitly.

**`--ours` and `--theirs` are swapped during a rebase.** During `git rebase`,
"ours" is the branch being rebased onto and "theirs" is the commit being
replayed — the opposite of a plain merge. If a resolution looks backwards,
check which operation is in progress.

**`--source` with `--no-overlay` (the default) can delete files.** If the
source tree does not contain a path that currently exists in the working tree,
Git removes it. Pass `--overlay` to suppress deletions and only update files
that exist in the source.

**The `--staged --worktree` combination has no safety net.** Unlike `git
stash`, there is no way to recover from `git restore --staged --worktree .`
after the fact. Use `git stash` instead when there is any uncertainty — see
the *stash* chapter.

## Worked examples

### Discarding accidental edits before a commit

You opened `src/db.js` to read some logic and accidentally saved changes you
do not want. The working tree is dirty but nothing is staged.

```sh
git diff src/db.js          # confirm the noise
```

```text
diff --git a/src/db.js b/src/db.js
index 4a2f1b3..7c9e801 100644
--- a/src/db.js
+++ b/src/db.js
@@ -42,6 +42,7 @@ function connect(url) {
+  console.log('debug');   // accidentally saved
   return pool.acquire();
```

Discard the change:

```sh
git restore src/db.js
git diff src/db.js          # empty — working tree matches index
```

### Unstaging a file added by mistake

You ran `git add .` and swept in a generated file you did not intend to
commit.

```sh
git status
```

```text
On branch feature/auth
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        new file:   dist/bundle.js
        modified:   src/auth.js
```

Unstage the generated file while keeping `src/auth.js` staged:

```sh
git restore --staged dist/bundle.js
git status
```

```text
On branch feature/auth
Changes to be committed:
        modified:   src/auth.js

Untracked files:
        dist/bundle.js
```

`dist/bundle.js` is back to untracked. Add it to `.gitignore` to prevent a
repeat.

### Pulling an old version of a file for comparison

A performance regression was introduced somewhere in the last week. You want
to restore the database module to an older state to run benchmarks.

```sh
# find the commit from around last week
git log --oneline --since="7 days ago" -- src/db.js
```

```text
a3f9c12 Refactor connection pool initialisation
8b2e041 Add retry logic on transient errors
```

Restore the file as it was just before the refactor:

```sh
git restore --source=8b2e041 src/db.js
```

The working tree now contains the older version. The index is unchanged — run
`git diff --staged` to confirm. If the benchmarks confirm a regression, commit
the restored file or use it to guide a targeted fix. If not, throw it away:

```sh
git restore src/db.js       # back to the version in the index
```

### Resolving a merge conflict by choosing one side

During a merge, `CHANGELOG.md` has conflicting edits on both branches. You
decide the incoming branch has the correct version.

```sh
git restore --theirs CHANGELOG.md
git add CHANGELOG.md
git merge --continue
```

To choose your branch's version instead:

```sh
git restore --ours CHANGELOG.md
git add CHANGELOG.md
git merge --continue
```

## Recovery

`git restore` on the working tree cannot be undone through Git — there is no
reflog for unstaged file content. Before running a broad restore, stash your
changes as a safety net:

```sh
git stash push -u -m "before bulk restore"
git restore .
# if you change your mind:
git stash pop
```

If you have already run `git restore --staged`, the working-tree content is
intact. Simply re-stage the file:

```sh
git add <file>
```

If you ran `git restore --staged --worktree` and the content is gone, check
whether your editor has an undo history or whether the OS has a recent backup.
Git has no record of content that was never committed.

See *Getting out of jams* for broader undo recipes, including recovering
content from the stash and the reflog.

## See also

- *add* — building the index that `--staged` restores from.
- *commit* — the snapshot that `--source=HEAD` and other refs point to.
- *stash* — a safe alternative when you want to set aside changes rather than
  discard them.
- *checkout* — the older command that `git restore` and `git switch` replaced
  for path-based and branch-switching operations respectively.
- *Getting out of jams* — recovering from destructive operations.
