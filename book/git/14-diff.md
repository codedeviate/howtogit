# diff

Show changes between the working tree, the index, commits, or arbitrary files.

## Mental model

Git tracks three distinct "copies" of your project at any given time:

```text
Working tree  ──  what is on disk right now
Index         ──  the staged snapshot (draft of the next commit)
Repository    ──  the committed history of tree objects
```

`git diff` is a window between any two of those layers, or between any two
commits in history. Depending on how you call it, it answers a different
question:

| Invocation | Question answered |
|---|---|
| `git diff` | What have I changed but not yet staged? |
| `git diff --cached` | What have I staged but not yet committed? |
| `git diff HEAD` | What have I changed since the last commit (staged + unstaged)? |
| `git diff A B` | How does commit B differ from commit A? |
| `git diff A...B` | What did branch B add since it diverged from branch A? |

The output is a unified diff: lines starting with `-` existed in the
"before" snapshot; lines starting with `+` exist in the "after" snapshot;
lines starting with a space are unchanged context. Each changed region is
called a hunk, introduced by a `@@` header that names the surrounding
function or line numbers.

## Synopsis

```text
git diff [<options>] [<commit>] [--] [<path>...]
git diff [<options>] --cached [--merge-base] [<commit>] [--] [<path>...]
git diff [<options>] [--merge-base] <commit> [--] [<path>...]
git diff [<options>] [--merge-base] <commit> <commit> [--] [<path>...]
git diff [<options>] <commit>..<commit> [--] [<path>...]
git diff [<options>] <commit>...<commit> [--] [<path>...]
git diff [<options>] <blob> <blob>
git diff [<options>] --no-index [--] <path> <path> [<pathspec>...]
```

## Everyday usage

See unstaged changes (working tree vs. index):

```sh
git diff
```

See staged changes (index vs. last commit — what `git commit` would record):

```sh
git diff --cached
# --staged is an exact synonym
git diff --staged
```

See everything changed since the last commit — staged and unstaged together:

```sh
git diff HEAD
```

Compare two commits by hash or branch name:

```sh
git diff main feature/auth
git diff abc1234 def5678
```

Use the triple-dot form to see only what a branch added since it diverged
from another branch (equivalent to diffing from the common ancestor):

```sh
git diff main...feature/auth
```

Limit the diff to specific files or directories:

```sh
git diff -- src/auth.js
git diff HEAD -- src/
```

Get a summary of which files changed and by how many lines, without the full
diff text:

```sh
git diff --stat
git diff --stat main..feature/auth
```

Show only the names of changed files:

```sh
git diff --name-only HEAD~3
```

Compare two arbitrary files on disk, outside any repository:

```sh
git diff --no-index old-version.js new-version.js
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--cached` / `--staged` | Compare index against a commit (default: HEAD) | Review exactly what will be committed |
| `--stat` | Show a diffstat summary instead of the full patch | Quick overview of scope |
| `--name-only` | List only the names of changed files | Scripting, feeding to `xargs` |
| `--name-status` | List names with A/M/D/R status letters | See the type of change at a glance |
| `-U<n>` | Show `<n>` lines of context (default 3) | Narrow (`-U0`) for patch review; wider for more context |
| `-w` / `--ignore-all-space` | Ignore all whitespace differences | Ignore reformatting-only changes |
| `-b` / `--ignore-space-change` | Ignore changes in the amount of whitespace | Ignore indent normalization |
| `--word-diff` | Show differences word-by-word rather than line-by-line | Prose and config files |
| `--color-moved` | Color moved code blocks distinctly from added/removed lines | Spot refactors that shuffle code around |
| `--diff-algorithm=<algo>` | Choose `myers` (default), `minimal`, `patience`, or `histogram` | `patience` and `histogram` often produce cleaner hunks |
| `-M` / `--find-renames` | Detect renamed files | See renames instead of delete + add pairs |
| `-C` / `--find-copies` | Detect copies as well as renames | Track file duplications |
| `--diff-filter=<letters>` | Limit output to Added/Deleted/Modified/Renamed/etc. | Show only new files: `--diff-filter=A` |
| `-S<string>` | Find hunks where the occurrence count of `<string>` changes | Locate when a specific symbol was introduced or removed |
| `-G<regex>` | Find hunks whose patch text matches a regex | Search for any change touching a pattern |
| `--merge-base` | Use the merge base of the two endpoints as the "before" side | Explicit alternative to the `...` notation |
| `--no-index` | Compare two arbitrary paths on disk | Diff files outside a repository |
| `-R` | Swap the before and after sides | See the inverse of a change |
| `--exit-code` | Exit 1 if there are differences, 0 if not | Use in scripts and CI checks |
| `--quiet` | Suppress all output; implies `--exit-code` | Fastest way to test for any difference in a script |
| `-W` / `--function-context` | Show the whole surrounding function as context | Understand a change without opening an editor |
| `--check` | Warn about conflict markers and whitespace errors | Quick pre-commit sanity check |

## Best practices

**Run `git diff --cached` before every commit.** It shows exactly what
`git commit` will freeze into history — not what you think you staged, but
what Git actually has. Make it muscle memory.

**Narrow the scope with paths.** When a repo has many files in flight,
`git diff -- path/to/file.js` filters noise immediately. Pass a directory to
diff everything beneath it.

**Prefer `...` (triple-dot) for branch comparisons.** `git diff main..feature`
includes any commits on `main` that are not yet on `feature`, which produces
noise when `main` has moved on. `git diff main...feature` diffs from the
point the branch diverged, so you see only what the feature branch
contributed.

**Use `--stat` first, then drill in.** On large diffs, `--stat` gives you a
map before you descend into patch text. Once you know which files matter,
diff them individually.

**Try `--histogram` for restructured code.** The default Myers algorithm
sometimes produces confusing hunks when functions are reordered.
`--diff-algorithm=histogram` often produces cleaner, more readable output on
real-world code.

**Use `--word-diff` for prose and configuration.** Line-based diffs on
documentation or long configuration values show entire lines as changed when
only one word moved. `--word-diff` makes the actual change obvious.

**Enable copy detection globally if you also duplicate files.** `git diff`
porcelain (and `git log`) detects renames by default (`diff.renames = true`
out of the box). If your project also duplicates files and you want copies
detected, add `diff.renames = copies` to your `~/.gitconfig`. To re-enable
rename detection on a system or shared config that has explicitly set
`diff.renames = false`, add `diff.renames = true`.

## Pitfalls & gotchas

**`git diff` with no arguments shows nothing when everything is staged.** If
you ran `git add -A`, the working tree and the index are identical, so plain
`git diff` produces no output. Use `git diff --cached` to see what is staged.
New users often think nothing changed when in fact everything is staged and
ready to commit.

**`..` and `...` mean opposite things between `log` and `diff`.** In
`git log A..B`, the double-dot means "commits reachable from B but not A."
In `git diff A..B`, the double-dot means the same as `git diff A B` — the
difference between the two tips. The triple-dot `git diff A...B` means "from
the common ancestor to B," which corresponds more closely to what
`git log A..B` shows. This asymmetry trips up almost everyone at some point.

**Renamed files appear as delete + add in plumbing commands and on old or
misconfigured installations.** `git diff` porcelain (and `git log`) detects
renames by default — `diff.renames` is `true` out of the box. However,
lower-level plumbing commands such as `git diff-files` and `git diff-index`
do not perform rename detection regardless of config. If rename detection is
unexpectedly absent (e.g. a shared config has set `diff.renames = false`),
pass `-M` / `--find-renames` to force it for a single invocation, or restore
the default with `diff.renames = true` in your `~/.gitconfig`.

**Whitespace-only changes hide in plain diffs but break patches.** A diff
that looks empty with `-w` may still apply differently than you expect.
Trailing whitespace and mixed tabs/spaces are silent bugs in patch
workflows. Use `--check` to surface them before they cause problems.

**`--exit-code` is not the default.** Scripts that do `if git diff ...; then`
will always take the truthy branch because `git diff` exits 0 even when there
are differences. You must add `--exit-code` (or `--quiet`, which implies it)
for the exit status to reflect whether a difference was found.

**Diffs against HEAD fail on an unborn branch.** On a brand-new repository
with no commits, `git diff HEAD` errors because HEAD does not yet point to a
commit. Use `git diff --cached` instead, which can show staged changes even
before the first commit.

## Worked examples

### Reviewing a staged change before committing

You have modified two files and staged both. Before committing, you want to
confirm what will actually be recorded.

```sh
git diff --cached
```

```text
diff --git a/src/auth.js b/src/auth.js
index 3a1c2d4..9e8f01b 100644
--- a/src/auth.js
+++ b/src/auth.js
@@ -42,7 +42,10 @@ function validateToken(token) {
   if (!token) {
     throw new Error('Token required');
   }
+  if (token.length < 32) {
+    throw new Error('Token too short');
+  }
   return jwt.verify(token, process.env.JWT_SECRET);
 }
```

The `+` lines are what will be added. Satisfied, you commit:

```sh
git commit -m "Enforce minimum token length in validateToken"
```

### Comparing a feature branch to main

You want to see everything your `feature/payments` branch added since it
diverged from `main`, ignoring any commits that landed on `main` in the
meantime:

```sh
git diff --stat main...feature/payments
```

```text
 src/payments/checkout.js  | 84 +++++++++++++++++++++++++++++++++++++++++++++
 src/payments/stripe.js    | 47 ++++++++++++++++++++++++++
 tests/payments.test.js    | 62 ++++++++++++++++++++++++++++++++++++
 3 files changed, 193 insertions(+)
```

Then drill into the file you care about most:

```sh
git diff main...feature/payments -- src/payments/stripe.js
```

### Spotting a moved block of code

A colleague refactored a module by extracting a helper function. The diff
looks cluttered because the same lines appear as both removed and added.
`--color-moved` paints moved blocks in a distinct color so you can
immediately see the extraction instead of a phantom delete and insert:

```sh
git diff --color-moved=zebra HEAD~1
```

### Checking for whitespace errors before pushing

`--check` surfaces trailing whitespace and conflict markers across all staged
changes:

```sh
git diff --cached --check
```

If it exits non-zero, Git prints the offending lines with their line numbers.
Fix them before committing to avoid noisy follow-up commits.

### Using diff in a CI script

A CI step that fails if any source or test file changed on a supposed
docs-only branch:

```sh
if ! git diff --quiet origin/main...HEAD -- src/ tests/; then
  echo "Non-docs files changed; failing CI."
  exit 1
fi
```

`--quiet` suppresses all output and implies `--exit-code`, so the exit status
reflects whether a difference was found.

## Recovery

`git diff` is a read-only operation — it never modifies the working tree,
index, or history. There is nothing to undo.

If you ran `git diff` expecting to see changes and saw nothing, the most
likely causes are:

- Everything is staged: run `git diff --cached`.
- You are on a detached HEAD or a new repo with no commits: compare
  explicitly, e.g. `git diff --cached` or `git diff <commit>`.
- The path argument did not match: check spelling and use `--` before paths
  to prevent ambiguous interpretation as a branch name.

See *Getting out of jams* for help recovering accidentally discarded
working-tree changes.

## See also

- *add* — staging the changes that `git diff --cached` will then show.
- *commit* — recording the staged snapshot into history.
- *status* — a compact summary of which files have changed, without the diff
  text.
- *log* — navigating commit history; combine with `-p` to show each commit's
  diff inline.
- *show* — display the diff introduced by a single commit.
- *stash* — set aside in-progress work so you can diff on a clean working
  tree.
- *Getting out of jams* — recovering accidentally discarded changes.
