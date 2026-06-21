# show

Inspect any Git object — commit, tag, tree, or file blob — and display its
contents along with the diff it introduces.

## Mental model

Everything stored in a Git repository is an *object*: commits, trees
(directories), blobs (file contents), and annotated tags. Each object has a
40-character SHA-1 name. `git show` is the universal lens for looking at any
one of those objects.

For the most common case — a commit — `git show` prints the commit header
(author, date, message) followed by the unified diff of the changes that
commit introduced. Think of it as `git log -1` plus `git diff` combined into a
single, focused view.

For other object types the output changes accordingly:

- **Annotated tag** — shows the tag message, then recurses into whatever the
  tag points at (usually a commit).
- **Tree** — lists filenames, like `git ls-tree --name-only`.
- **Blob** — prints the raw file contents with no diff.

The default target is `HEAD`, so a bare `git show` always means "show me the
last commit on the current branch".

```text
Object store
 ┌────────┐   ┌────────┐   ┌────────┐   ┌────────┐
 │ commit │   │  tag   │   │  tree  │   │  blob  │
 │ header │   │ message│   │ names  │   │  raw   │
 │ + diff │   │ + obj  │   │        │   │ content│
 └────────┘   └────────┘   └────────┘   └────────┘
       ^
  git show (default)
```

## Synopsis

```text
git show [<options>] [<object>...]
```

`<object>` can be any revision expression: a commit hash, branch name, tag,
`HEAD~3`, `v1.4.0^{commit}`, `main:path/to/file`, and so on. When omitted,
`HEAD` is used.

## Everyday usage

Show the most recent commit on the current branch:

```sh
git show
```

Show a specific commit by hash (abbreviated is fine):

```sh
git show a3f9c1
```

Show a commit at the tip of another branch:

```sh
git show feature/login
```

Show what a tag points at (tag message first, then the commit):

```sh
git show v2.0.0
```

Show the contents of a file as it existed in a specific commit:

```sh
git show HEAD~2:src/config.js
```

Show a commit with a compact file-change summary instead of the full diff:

```sh
git show --stat a3f9c1
```

Show just the commit message, no diff:

```sh
git show -s a3f9c1
git show --no-patch a3f9c1    # same effect
```

Show a commit with a custom format (hash and subject only):

```sh
git show --format="%h %s" --no-patch a3f9c1
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-s`, `--no-patch` | Suppress the diff; show only the commit header | Quickly read a commit message without noise |
| `--stat` | Replace the full diff with a filename/lines-changed summary | Get a high-level picture of what changed |
| `--name-only` | Show only the names of changed files | Feed into scripts or check which files a commit touched |
| `--name-status` | Show file names plus a status letter (A/M/D/R/…) | See what happened to each file at a glance |
| `--oneline` | Abbreviate commit to one line (short hash + subject) | Compact header when you don't need the full message |
| `--format=<fmt>` / `--pretty=<fmt>` | Control commit header format (`oneline`, `short`, `medium`, `full`, `fuller`, `raw`, `format:<string>`) | Custom output for scripts or aliases |
| `--abbrev-commit` | Show a short hash prefix instead of 40 characters | Readable terminal output |
| `-U<n>`, `--unified=<n>` | Show `<n>` lines of diff context (default 3) | More context when reviewing complex changes |
| `--word-diff` | Highlight changed words within lines instead of whole lines | Review prose or config-file changes |
| `--color-moved` | Color blocks of moved code differently from additions/deletions | Identify refactors that only moved code |
| `--show-signature` | Verify GPG signature and show the verification result | Confirm a signed commit is authentic |
| `--raw` | Show diff in raw format (object hashes, mode changes) | Scripting and plumbing use |
| `-p`, `--patch` | Explicitly request a patch diff (on by default for commits) | Force patch output when another option suppressed it |

## Best practices

**Use `HEAD~N` and branch names, not raw hashes, when exploring.** `git show
HEAD~3` and `git show feature/auth` are self-documenting in shell history.
Hashes are essential for precision (a review comment, a script) but awkward
for interactive use.

**Pair `--stat` with the full diff for large commits.** Run `git show --stat
<commit>` first to understand the scope of the change, then drop `--stat` to
read the diff for files that need scrutiny. This is faster than scrolling past
hundreds of diff lines looking for the one file you care about.

**Use `<commit>:<path>` to recover a previous file version.** The
`git show HEAD~1:src/app.js` form prints the file exactly as it was — useful
for copying a snippet, or piping to a file for a manual comparison.

**Combine `--format` with `-s` for lightweight aliases.** A common alias is:

```sh
git config --global alias.msg 'show -s --format=%B'
```

Running `git msg HEAD~2` then prints just the full commit body, with no diff
and no header clutter.

**Prefer `--name-only` or `--name-status` in scripts.** When a script needs
to act on files that a commit touched, these options produce stable, parseable
output without parsing unified-diff syntax.

## Pitfalls & gotchas

**`git show` on a merge commit produces a combined diff by default.** The
combined diff (`--diff-merges=dense-combined`) only shows lines that differ
from *both* parents, which means most of the merge is hidden. If you want to
see all changes relative to the first parent, use `--diff-merges=first-parent`
(or its shorthand `--dd`, which also implies `-p` and applies to regular commits too). To see diffs against each parent separately, use
`--diff-merges=separate`.

**Bare `git show` shows HEAD, not the working tree.** A common confusion: you
edited a file, ran `git show`, and the change is not there. `git show` reads
committed objects — it knows nothing about uncommitted edits. Use `git diff`
for working-tree comparisons.

**`-s` and `--no-patch` are synonyms but their names mislead.** `-s` stands
for "suppress diff", not "short". It is documented as `--no-patch` in newer
Git versions; both work.

**`<commit>:<path>` needs the path relative to the repository root.** If you
are deep in a subdirectory and run `git show HEAD:widget.js`, Git looks for
`widget.js` at the root of the repo, not your current directory. Use the full
repo-root-relative path, e.g. `git show HEAD:src/components/widget.js`.

**Annotated tags and lightweight tags behave differently.** `git show v1.0`
on an annotated tag prints the tag message *then* the commit. On a lightweight
tag (which is just a pointer to a commit) there is no tag message, and output
looks identical to `git show <commit>`. Use `git cat-file -t v1.0` to check
which type you have.

**`--word-diff` can be misleading for code.** Word-level diffing works well
for prose but is noisy for code where a single-character rename spans multiple
tokens. Use it deliberately, not as a default.

## Worked examples

### Reviewing a colleague's commit before merging

Your teammate pushed `feature/payments`. You want to understand what changed
before you approve the pull request.

Start with the big picture:

```sh
git show --stat origin/feature/payments
```

```text
commit d4e89f1
Author: Ana Costa <ana@example.com>
Date:   Mon Jun 16 14:32:09 2025 +0200

    Add Stripe webhook handler

 src/webhooks/stripe.js   | 87 ++++++++++++++++++++++++++++++++++++++++++
 src/webhooks/index.js    |  3 ++
 tests/webhooks/stripe.js | 62 +++++++++++++++++++++++++++++
 3 files changed, 152 insertions(+)
```

Now read the diff for just the source file you care about:

```sh
git show origin/feature/payments -- src/webhooks/stripe.js
```

If the commit is large and you want more context around each change:

```sh
git show -U10 origin/feature/payments -- src/webhooks/stripe.js
```

### Recovering the previous version of a config file

You accidentally overwrote `config/database.yml` and have not committed yet,
but you want the content as it was two commits ago.

```sh
git show HEAD~2:config/database.yml
```

To restore it in place:

```sh
git show HEAD~2:config/database.yml > config/database.yml
```

Or use `git restore` with a source commit (see the *restore* chapter for that
approach).

### Checking what a release tag contains

Your deployment pipeline triggers on annotated tags. Before tagging, verify
the tag message and the commit it wraps:

```sh
git show v3.1.0
```

```text
tag v3.1.0
Tagger: Thomas Bjork <thomas@example.com>
Date:   Tue Jun 17 09:00:00 2025 +0200

Release 3.1.0 — performance improvements and bug fixes

commit 7b2a94c
Author: Thomas Bjork <thomas@example.com>
Date:   Mon Jun 16 18:45:00 2025 +0200

    Bump version to 3.1.0

diff --git a/package.json b/package.json
...
```

To show only the tag object's message without the commit diff:

```sh
git show -s --format=%B v3.1.0
```

### Inspecting a file's content at a branch tip

You want to compare how `src/auth.js` looks on `main` versus `feature/oauth`
without checking either branch out:

```sh
git show main:src/auth.js > /tmp/auth-main.js
git show feature/oauth:src/auth.js > /tmp/auth-oauth.js
diff /tmp/auth-main.js /tmp/auth-oauth.js
```

Or, if your terminal supports side-by-side diffing, pipe through `diff -y`.

## Recovery

`git show` is purely read-only — it cannot modify history or the working tree,
so there is nothing to undo. If you ran `git show HEAD~2:path/file > path/file`
and overwrote a file accidentally, recover with:

```sh
git restore path/file          # restore from the index (last staged version)
git restore --source HEAD path/file  # restore from HEAD
```

See *Getting out of jams* for broader undo recipes.

## See also

- *log* — traverse and filter history across many commits; `git show` is
  `git log -1 -p` in spirit.
- *diff* — compare the working tree or index to a commit without picking a
  single commit to inspect.
- *restore* — overwrite working-tree files from a commit or the index.
- *tag* — creating and listing annotated and lightweight tags.
- *Getting out of jams* — recovering from accidental file overwrites and
  lost commits.
