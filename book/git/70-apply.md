# apply

Read a diff file and apply it to the working tree and/or the index, without
creating a commit.

## Mental model

A patch file is a text description of changes: which lines to remove and which
to add, in which file, at which location. `git apply` reads that description
and executes it — surgically editing your files as instructed.

The key distinction from `git am` is that `apply` is deliberately low-level:
it modifies files (and optionally the index), but it never creates a commit.
That makes it useful for importing a single diff snippet, testing whether a
patch would apply cleanly, or selectively applying parts of a larger patch
series.

```text
patch file  ──git apply──> working tree   (default)
patch file  ──git apply --index──> working tree + index
patch file  ──git apply --cached──> index only (working tree untouched)
patch file  ──git apply --check──> dry run (nothing written)
```

The patch does not have to come from Git. `git apply` accepts standard unified
diff output from GNU diff, `diff -u`, or any tool that produces the same
format. Outside a Git repository it behaves like a better version of
`patch(1)`.

When a hunk cannot apply — because the surrounding context lines no longer
match — `git apply` aborts the entire patch by default, leaving the working
tree untouched. Use `--reject` to apply only the hunks that succeed and write
the failures to `*.rej` files for manual resolution.

## Synopsis

```text
git apply [--stat] [--numstat] [--summary] [--check]
          [--index | --cached] [-N | --intent-to-add]
          [-3 | --3way] [--ours | --theirs | --union]
          [-R | --reverse] [--reject]
          [-p<n>] [-C<n>] [--directory=<root>]
          [--exclude=<path-pattern>] [--include=<path-pattern>]
          [--ignore-space-change | --ignore-whitespace]
          [--whitespace=<action>]
          [--recount] [--inaccurate-eof] [--unidiff-zero]
          [--apply] [--no-add] [--allow-empty]
          [--verbose | --quiet] [--unsafe-paths]
          [<patch>...]
```

Pass `-` as `<patch>` to read from standard input.

## Everyday usage

Inspect what a patch would change before touching any file:

```sh
git apply --stat feature.patch      # diffstat: files and line counts
git apply --check feature.patch     # dry run: exits non-zero if it would fail
```

Apply a patch to the working tree only (you still need to `git add`
afterwards):

```sh
git apply feature.patch
```

Apply a patch and immediately stage the result (equivalent to apply + add):

```sh
git apply --index feature.patch
```

Apply a patch received on stdin, for example piped from `curl`:

```sh
curl -s https://example.com/fix.patch | git apply --index -
```

Reverse a patch that was already applied (undo it):

```sh
git apply -R feature.patch
```

Apply as much as possible, writing rejected hunks to `*.rej` files:

```sh
git apply --reject partial.patch
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--stat` | Print a diffstat instead of applying | Preview the scope of a patch |
| `--numstat` | Machine-readable diffstat (decimal counts, full paths) | Scripting and automation |
| `--summary` | Show creations, renames, and mode changes | Understand structural changes at a glance |
| `--check` | Dry run — verify applicability without modifying anything | Validate a patch before applying it |
| `--index` | Apply to both working tree and index | Apply and stage in one step |
| `--cached` | Apply to the index only, leave working tree untouched | Construct staged content directly |
| `-N`, `--intent-to-add` | Mark new files added by the patch as intent-to-add in the index | When you want `git diff` to show new-file additions |
| `-3`, `--3way` | Fall back to a three-way merge when context does not match | Applying an old patch against an evolved codebase |
| `--ours`, `--theirs`, `--union` | Resolve three-way conflicts automatically (requires `--3way`) | Scripted, unattended patch application |
| `-R`, `--reverse` | Apply the patch backwards | Undo a previously applied patch |
| `--reject` | Apply matching hunks; write failures to `*.rej` files | Partial application with manual follow-up |
| `-p<n>` | Strip `<n>` leading path components from patch paths (default: 1) | Patches from foreign repositories with different path prefixes |
| `-C<n>` | Require at least `<n>` lines of context to match | Tighten or relax context matching |
| `--directory=<root>` | Prepend `<root>` to all paths in the patch | Apply a patch into a subdirectory |
| `--exclude=<pattern>` | Skip files matching a path pattern | Import a patch series while ignoring vendored files |
| `--include=<pattern>` | Only apply changes to files matching a pattern | Cherry-pick a subset of files from a large patch |
| `--ignore-space-change`, `--ignore-whitespace` | Ignore whitespace differences in context lines | Patch produced with different line endings or indentation |
| `--whitespace=<action>` | Control how trailing-whitespace errors are handled (`nowarn`, `warn`, `fix`, `error`, `error-all`) | Enforce or relax whitespace hygiene |
| `--recount` | Infer hunk line counts from the patch body | Apply hand-edited patches with incorrect hunk headers |
| `--inaccurate-eof` | Work around diffs that miss a missing-newline marker | Patches generated by buggy diff tools |
| `--apply` | Force application even when a "turns off apply" flag is present | Get diffstat output *and* apply the patch together |
| `--no-add` | Ignore additions; apply deletions only | Extract the common base between two files |
| `--allow-empty` | Succeed on patches that contain no diff | Pipelines where empty patches are normal |
| `--unsafe-paths` | Allow patches that reference paths outside the working area | Using `git apply` as a GNU `patch` replacement |
| `-v`, `--verbose` | Print more progress information to stderr | Diagnosing why a patch fails |
| `-q`, `--quiet` | Suppress all progress output | Silent scripted use |

## Best practices

**Always run `--check` first on untrusted or unfamiliar patches.** It costs
nothing and catches conflicts before anything is written to disk. Make it a
habit before `--index` or `--cached`.

```sh
git apply --check incoming.patch && git apply --index incoming.patch
```

**Use `--3way` when applying against an evolved codebase.** Context lines
drift as history accumulates. Rather than failing outright, `--3way` attempts
a merge and leaves conflict markers in place — the same workflow you already
know from `git merge`. Without it, even a one-line context mismatch aborts
the entire patch.

**Prefer `--index` over a bare apply.** A bare `git apply` modifies files but
does not touch the index. You must then run `git add` on every changed file
before committing. Passing `--index` does both in a single step and is less
error-prone.

**Strip path prefixes deliberately with `-p`.** Standard `git diff` output
uses an `a/` and `b/` prefix on every path. The default `-p1` strips one
component, turning `a/src/main.c` into `src/main.c`. Patches from foreign
projects (Subversion exports, GNU diff output, mailing-list patches) often
have different prefix depths. Check with `--stat` first and adjust `-p`
accordingly.

**Use `--directory` to relocate a patch into a subdirectory.** When
integrating a standalone project's patch into a monorepo, `--directory` saves
hand-editing every path in the patch file.

```sh
git apply --directory=libs/mylib -p1 mylib-fix.patch
```

**Combine `--exclude` and `--include` to import partial patch series.** Large
patch sets from mailing lists often contain generated files (translations,
minified assets) you want to skip. Use `--exclude` to filter them out without
editing the patch.

## Pitfalls & gotchas

**`git apply` does not create a commit.** This surprises people who expect it
to behave like `git am`. If you want a full commit (with author, date, and
message from the patch), use `git am` instead. `git apply` is the lower-level
primitive.

**`--reject` leaves your working tree in a partially applied state.** After
`--reject`, some hunks are applied, others are not. Inspect every `*.rej`
file, apply its changes manually, delete the `.rej` files, then stage and
commit. Running `git apply` again on the same patch will fail because some
hunks are already in place.

**Context lines must match exactly by default.** Even a one-line difference in
surrounding context causes the hunk to fail. If you receive the error
`patch does not apply`, the most common causes are: the file has diverged from
the base the patch was created against, or whitespace differences (line
endings, indentation). Try `--ignore-whitespace` or `--3way` before
concluding the patch is broken.

**`--index` requires working tree and index to be in sync.** If you have
staged changes in the index that differ from the working tree for the same
file, `--index` raises an error even if the patch would apply cleanly to both
in isolation. Commit or stash your staged changes first.

**`-p0` retains the full path as written in the patch.** This is almost never
what you want when applying a Git-generated patch (which uses `a/`/`b/`
prefixes). Using `-p0` on such a patch causes Git to look for a directory
literally named `a/` at the repo root.

**`--unsafe-paths` opens a security risk.** Never use it on patches from
untrusted sources. A malicious patch could overwrite files outside the
repository — including dotfiles, cron jobs, or SSH keys.

**Binary patches need no special flag anymore.** Older documentation mentions
`--binary` as required for binary content. Modern Git always allows binary
patch application; the flag is a no-op and can be ignored.

## Worked examples

### Inspecting and applying a mailing-list patch

A contributor sends `0001-fix-null-deref.patch` by email (or via a download
link). Before touching the tree, inspect it:

```sh
git apply --stat 0001-fix-null-deref.patch
```

```text
 src/parser.c | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
```

Verify it applies cleanly to the current HEAD:

```sh
git apply --check 0001-fix-null-deref.patch
```

No output and exit code 0 means success. Now apply and stage in one step:

```sh
git apply --index 0001-fix-null-deref.patch
git commit -m "Fix null dereference in parser (from patch)"
```

If you want the original author and commit message preserved, use `git am`
instead:

```sh
git am 0001-fix-null-deref.patch
```

### Applying a patch from a foreign project with a different path layout

An upstream GNU project provides a patch with paths like
`mylib-1.4/src/util.c`. Your copy of the library lives under `libs/mylib/`.
The patch has no `a/`/`b/` prefix — it is a plain `diff -u` output, so the
prefix depth is 0 for the project root.

First, see how many path components separate the patch paths from your layout:

```sh
git apply --stat -p1 upstream.patch    # try stripping one component
```

```text
error: mylib-1.4/src/util.c: does not exist in index
```

```sh
git apply --stat -p2 upstream.patch    # strip two components
```

```text
 src/util.c | 8 ++++----
 1 file changed, 4 insertions(+), 4 deletions(-)
```

The files live under `libs/mylib/`, so prepend that with `--directory`:

```sh
git apply --check -p2 --directory=libs/mylib upstream.patch
git apply --index -p2 --directory=libs/mylib upstream.patch
```

### Salvaging a patch that no longer applies cleanly

A patch was prepared against a version of the file that has since been
refactored. The plain apply fails:

```sh
git apply feature.patch
```

```text
error: patch failed: src/auth.c:42
error: src/auth.c: patch does not apply
```

Try the three-way fallback:

```sh
git apply --3way feature.patch
```

If the content Git needs is in the object database (because the patch records
blob SHAs), this succeeds or leaves familiar conflict markers. Resolve them
with your editor or `git mergetool` (see the *mergetool* chapter), then stage
and commit normally.

If `--3way` also fails, use `--reject` to apply what is possible and fix the
rest manually:

```sh
git apply --reject feature.patch
# Edit src/auth.c, incorporating the hunks from src/auth.c.rej
rm src/auth.c.rej
git add src/auth.c
git commit -m "Apply feature patch (manually resolved conflicts)"
```

### Undoing a patch that was applied by mistake

You ran `git apply --index wrong.patch` and staged the result, but have not
yet committed. Reverse the patch:

```sh
git apply -R --index wrong.patch
```

The working tree and index are restored to their previous state. If you had
already committed, see *revert* or the *Getting out of jams* chapter for
commit-level undo strategies.

## Recovery

If `git apply` left your working tree in a broken partial state (for example
after `--reject`), discard all uncommitted changes and return to HEAD:

```sh
git restore .
```

If you applied with `--index` and want to unstage without touching the working
tree:

```sh
git restore --staged .
```

To undo a commit that was created immediately after a `git apply --index`,
keep the staged changes but remove the commit:

```sh
git reset --soft HEAD~1
```

See *Getting out of jams* for broader undo strategies including recovering
from an accidental `--cached` apply.

## See also

- *am* — apply a patch series as commits, preserving author and message.
- *format-patch* — generate patch files from commits, suitable for `git am` or `git apply`.
- *diff* — produce the unified diff output that `git apply` consumes.
- *add* — stage files after a bare `git apply` (without `--index`).
- *mergetool* — resolve conflicts left by `--3way`.
- *revert* — create a commit that undoes the effect of a previous commit.
- *Getting out of jams* — undo strategies when apply leaves the tree in a bad state.
