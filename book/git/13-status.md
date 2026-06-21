# status

Show what has changed between your working tree, the index, and HEAD — without
modifying anything.

## Mental model

Git tracks three distinct layers for every file in your repository:

```text
HEAD (last commit)
      │
      ▼
   Index (staging area)  ◄── git add
      │
      ▼
 Working tree            ◄── your editor
```

`git status` compares all three layers at once and reports:

1. **Staged changes** — differences between HEAD and the index. These go into
   your next commit.
2. **Unstaged changes** — differences between the index and the working tree.
   These will *not* go into your next commit unless you stage them first.
3. **Untracked files** — files in the working tree that Git has never seen.

Nothing is written, moved, or deleted. `git status` is always safe to run.

## Synopsis

```text
git status [<options>] [--] [<pathspec>...]
```

## Everyday usage

Run a plain status to see everything at once:

```sh
git status
```

```text
On branch feature/login
Your branch is up to date with 'origin/feature/login'.

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/auth.js

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   src/user.js

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        tests/auth.test.js
```

Get a compact one-line-per-file summary — useful inside a shell prompt or a
quick scan:

```sh
git status -s
```

```text
M  src/auth.js
 M src/user.js
?? tests/auth.test.js
```

The left column is the index state; the right column is the working-tree state.
`M ` (left column only) means a staged modification; ` M` (right column only)
means an unstaged modification; `??` means untracked.

Show the branch and tracking information alongside the short format:

```sh
git status -sb
```

```text
## feature/login...origin/feature/login
M  src/auth.js
 M src/user.js
?? tests/auth.test.js
```

Limit the report to a specific path or directory:

```sh
git status src/
```

Show ignored files (normally hidden):

```sh
git status --ignored
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-s`, `--short` | One-line-per-file output with two-letter status codes | Quick scans, shell prompts |
| `-b`, `--branch` | Prefix short output with branch and tracking info | Combine with `-s` for a dense summary |
| `--show-stash` | Print the count of stash entries if any exist | Reminder that stashed work is pending |
| `--porcelain[=<version>]` | Stable machine-readable output (v1 or v2) | Scripts and tools that parse status |
| `--long` | Human-readable long format (the default) | Normal interactive use |
| `-v`, `--verbose` | Also show the diff of staged changes; `-vv` adds unstaged diff | Review exactly what will be committed |
| `-u[<mode>]`, `--untracked-files[=<mode>]` | Control untracked-file reporting: `no`, `normal`, or `all` | `no` for speed in large trees; `all` to expand new directories |
| `--ignored[=<mode>]` | Show ignored files; modes: `traditional`, `no`, `matching` | Auditing `.gitignore` rules |
| `-z` | NUL-terminate entries instead of newline; implies `--porcelain=v1` | Robust script parsing when paths may contain spaces |
| `--ahead-behind` / `--no-ahead-behind` | Show or suppress the ahead/behind count vs upstream | `--no-ahead-behind` speeds up status on slow network mounts |
| `--renames` / `--no-renames` | Enable or disable rename detection | Override user config in scripts |
| `--find-renames[=<n>]` | Enable rename detection with an optional similarity threshold | Fine-tune when files are only partially renamed |
| `--ignore-submodules[=<when>]` | Hide submodule changes; values: `none`, `untracked`, `dirty`, `all` | Suppress noise from submodule churn |

## Best practices

**Run `git status` before every commit.** Glancing at the output catches
forgotten files, accidental deletions, and leftover debug code before they
become part of history. The habit costs two seconds and has saved many
developers from embarrassing commits.

**Use `-v` when the diff matters.** The plain output tells you *which* files
changed; `-v` shows *what* changed in staged files. Running `git status -v`
before committing is a lightweight alternative to `git diff --cached` and
keeps the review in one place.

**Use `--porcelain` in scripts — never rely on the long format.** The
long-format output is documented as subject to change. `--porcelain=v1` (or
`v2` for richer metadata including object names and file modes) is stable
across Git versions and ignores user colour configuration. Combine with `-z`
for safety when file names may contain spaces or newlines:

```sh
git status --porcelain -z | while IFS= read -r -d '' entry; do
  status="${entry:0:2}"
  file="${entry:3}"
  printf '%s  ->  %s\n' "$status" "$file"
done
```

**Prefer `-sb` over bare `-s` in a shell prompt.** The branch line tells you
at a glance whether you are ahead or behind the remote, which matters before a
push.

**Run with `--no-optional-locks` in background jobs.** When a CI script or
file-watcher calls `git status` in the background, it holds a brief write lock
that can block concurrent Git operations. Add the top-level flag to prevent it:

```sh
git --no-optional-locks status --porcelain
```

**Enable the untracked cache on large repositories.** In a tree with tens of
thousands of files, scanning for untracked files is the main cost of `git
status`. One-time configuration that pays off on every subsequent run:

```sh
git config core.untrackedCache true
git config core.fsmonitor true   # optional: also skip unmodified directories
```

## Pitfalls & gotchas

**A clean status does not mean your branch matches the remote.** `git status`
compares against HEAD — your *local* last commit — not against
`origin/main`. You can have a perfectly clean working tree and still be ten
commits behind the remote. Run `git fetch` first to update the remote-tracking
refs; the `git status` output will then reflect the true ahead/behind gap.

**Untracked directories are shown as a single entry.** By default (`-unormal`)
Git shows `new-directory/` rather than every file inside it. Run
`git status -uall` to expand them. This is easy to miss when you copy an
entire directory into your repo and see only one `??` line.

**The two-column short format is easy to misread.** The first character is the
*index* state; the second is the *working-tree* state. `MM` means a file is
both staged *and* has additional unstaged changes — the staged and unstaged
versions differ. Only the staged portion goes into the next commit.

**Ignored files hide silently.** Files matched by `.gitignore` do not appear
in the default output. If a file is missing from the report and you are
confused, run `git status --ignored` to reveal what is suppressed, then use
`git check-ignore -v <file>` to find which rule matched.

**Rename detection can produce false positives.** When you delete one file and
create another with similar content, Git may report `renamed: old -> new`.
If this is not actually a rename, use `git status --no-renames` to disable the
heuristic and see the true delete-plus-add picture.

## Worked examples

### Reviewing a full staging session before committing

You have been editing several files and want to be certain exactly what will
go into the next commit.

```sh
git status -v
```

The verbose flag appends the full staged diff below the file list:

```text
On branch main
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   src/cart.js

diff --git a/src/cart.js b/src/cart.js
index 3a4b5c6..7d8e9f0 100644
--- a/src/cart.js
+++ b/src/cart.js
@@ -42,6 +42,7 @@ function addItem(cart, item) {
+  validateStock(item);
```

You spot that a `console.log` you added for debugging is still staged. Unstage
the file, remove the log, re-stage, then commit:

```sh
git restore --staged src/cart.js
# remove the console.log in your editor
git add src/cart.js
git commit -m "Validate stock before adding item to cart"
```

### Parsing status output in a deployment script

A deployment script should abort if any tracked file has uncommitted changes.

```sh
#!/bin/sh
if git --no-optional-locks status --porcelain | grep -qv '^??'; then
  echo "ERROR: uncommitted changes detected, aborting deploy" >&2
  exit 1
fi
```

`grep -v '^??'` filters out untracked files so the check targets only staged
or unstaged modifications to tracked files. `--no-optional-locks` prevents
the background call from blocking parallel Git operations.

### Diagnosing a conflict state after a failed merge

After `git merge` reports conflicts, `git status` identifies the unmerged paths:

```sh
git status -s
```

```text
UU src/config.js
M  src/main.js
```

`UU` means both sides modified the file and Git could not auto-resolve it.
Open `src/config.js`, resolve the conflict markers, then stage the result:

```sh
# resolve conflicts in your editor
git add src/config.js
git status -s
```

```text
M  src/config.js
M  src/main.js
```

Both entries now show `M ` (left column) — fully staged, nothing unstaged.
Complete the merge commit as described in the *commit* chapter.

## Recovery

`git status` is read-only — it never modifies anything, so there is nothing to
undo from running it.

If you acted on what `git status` reported and want to reverse those actions:

- To unstage a file you just staged: `git restore --staged <file>`
- To discard working-tree changes you just discarded: see *Getting out of
  jams* — once discarded, changes can sometimes be recovered from the object
  database if they were ever staged.

## See also

- *add* — staging files that `git status` reports as unstaged or untracked.
- *commit* — recording the staged changes shown under "Changes to be committed".
- *diff* — viewing the exact line-level changes that `git status` summarises by
  filename.
- *restore* — unstaging or discarding the changes `git status` reports.
- *Getting out of jams* — recovering from accidental discards and other
  mistakes discovered through `git status`.
