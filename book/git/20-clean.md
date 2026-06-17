# clean

Remove untracked files from the working tree.

## Mental model

Git tracks three kinds of files in your working tree: tracked files (Git
knows about them), ignored files (listed in `.gitignore` or similar rules),
and untracked files (everything else — new files you have created but never
staged). `git clean` targets that third category.

Think of it as the complement to `git restore`. While `git restore` resets
the content of tracked files back to what Git knows, `git clean` sweeps away
the files Git does not know about at all.

```text
Working tree files
├── tracked        ← git restore handles these
├── ignored        ← git clean -x or -X can reach these
└── untracked      ← git clean targets these by default
```

Because deleted files cannot be recovered from Git's history (Git never
recorded them), `git clean` is intentionally conservative: it requires an
explicit force flag by default and will not descend into untracked
subdirectories unless you ask. Always use `--dry-run` first to see exactly
what would be removed.

## Synopsis

```text
git clean [-d] [-f] [-i] [-n] [-q] [-e <pattern>] [-x | -X] [--] [<pathspec>...]
```

## Everyday usage

Preview what would be removed without actually deleting anything:

```sh
git clean -n
git clean -nd    # also show untracked directories
```

Remove untracked files (force is required by default):

```sh
git clean -f
```

Remove untracked files and untracked directories:

```sh
git clean -fd
```

Review interactively before committing to any deletion:

```sh
git clean -i
```

Remove everything that would be ignored by a fresh checkout — build
artifacts, compiled output, editor caches:

```sh
git clean -fdx
```

Remove only ignored files, leaving your untracked source files alone:

```sh
git clean -fdX
```

Restrict cleaning to a specific path:

```sh
git clean -fd -- src/generated/
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-n`, `--dry-run` | Show what would be removed; delete nothing | Always run this first |
| `-f`, `--force` | Actually perform the deletion (required unless `clean.requireForce` is false) | Every real clean operation |
| `-d` | Recurse into untracked directories | When you also want to remove new folders |
| `-i`, `--interactive` | Show files and enter an interactive menu | When you want to approve or filter individual items |
| `-q`, `--quiet` | Suppress the list of removed files; report errors only | Scripts and CI where the output is noise |
| `-e <pattern>`, `--exclude=<pattern>` | Exclude additional paths matching `<pattern>` on top of standard ignore rules | Protect specific files during a broad clean |
| `-x` | Also remove files that are ignored by `.gitignore` rules | Wipe build products for a pristine rebuild |
| `-X` | Remove *only* ignored files, keep untracked source | Rebuild artifacts without touching hand-created files |

`-x` and `-X` are mutually exclusive.

## Best practices

**Dry-run before every destructive clean.** Make `git clean -nd` a habit.
The two-second check has saved many developers from wiping a half-finished
config file they forgot to stage.

**Use `-i` when the file list is unfamiliar.** The interactive mode lets
you review each file, filter by pattern, or select by number before
anything is deleted. It is the safest way to clean a directory you have
not tidied recently.

**Prefer `-X` over `-x` for rebuild workflows.** If your goal is to ensure
a fresh build, you almost always want to wipe build artifacts while keeping
your untracked source files. `-X` does exactly that; `-x` is a broader
sledgehammer that also removes untracked source you have not staged yet.

**Protect files with `-e` when running broad cleans in CI.** If your
pipeline generates a credentials file or a local config that should survive
the clean, pass `-e .env.local` (or the appropriate pattern) rather than
relying on a `.gitignore` entry that might not be committed.

**Leave `clean.requireForce = true` in place.** The force requirement is a
safety rail. Removing it in your global config means a mistyped command has
no second chance.

## Pitfalls & gotchas

**Deleted files are gone for good.** Unlike modifications to tracked files,
there is no `git restore` that brings back a file Git never recorded. If you
run `git clean -f` and remove a file you needed, your only options are your
editor's undo history, a filesystem-level backup, or luck.

**`-d` without a pathspec can be surprisingly aggressive.** If you have
created an entire feature directory without staging any of it, `git clean -fd`
will delete every file in that directory. Always use `-n` first when `-d` is
in play.

**Nested Git repositories are protected.** Git will refuse
to remove a directory that contains its own `.git` subdirectory unless you
pass `-f` twice (`-ff`). This protects accidentally vendored submodules and
any directory that carries its own `.git` folder.

**`-x` reaches everything your ignore rules cover, including directory-level
patterns.** A pattern like `build/` in `.gitignore` covers everything inside
that directory. Running `git clean -fx` will remove the entire contents of
`build/`. That is usually what you want, but be aware it reaches files you
may not have listed individually.

**Interactive mode ignores `clean.requireForce`.** When you pass `-i`, the
force requirement is waived because the interactive prompts provide their
own safety guarantee. This is intentional behavior documented in the man page.

## Worked examples

### Preparing a pristine build environment

Your CI server shares a workspace between runs. Old object files and
generated headers are causing spurious test failures. You want to remove
every ignored artifact but leave any untracked source files the developer
may have added.

```sh
# Preview what will be removed
git clean -ndX
```

```text
Would remove build/
Would remove dist/
Would remove src/generated/schema.pb.h
Would remove .cache/
```

```sh
# Perform the clean
git clean -fdX
```

The build directory is now in the same state it would be after a fresh clone,
minus only the ignored files.

### Surgically removing untracked files with interactive mode

You have been experimenting and your working tree has several new files: a
scratch script, a test fixture, and a notes file you want to keep.

```sh
git clean -i
```

```text
Would remove scratch.py
Would remove tests/fixtures/sample_big.json
Would remove NOTES.md
*** Commands ***
    1: clean                2: filter by pattern    3: select by numbers
    4: ask each             5: quit                 6: help
What now>
```

Choose option **3** (select by numbers) and enter `1 2` to select only
`scratch.py` and the fixture. Press Enter with an empty line to return to
the menu, then choose **1** to clean. `NOTES.md` is left untouched.

### Excluding a file during a broad clean

You want to wipe all untracked and ignored files but keep a local `.env.local`
file that is not committed and not in `.gitignore`:

```sh
# Preview
git clean -ndx -e .env.local

# Execute
git clean -fdx -e .env.local
```

The `-e` pattern takes precedence over `-x`, so `.env.local` survives even
though everything else that is untracked or ignored is removed.

## Recovery

There is no Git-native recovery path for files removed by `git clean`. Git
never recorded them, so there is nothing to restore from the object database.

Before running any destructive clean, stash untracked files to create a
recoverable snapshot:

```sh
git stash --include-untracked
```

See *stash* for how to pop or drop the stash once you are done. See
*Getting out of jams* for broader recovery recipes including situations
where the stash itself has been dropped.

If you have already run `git clean -f` and realize you needed a file, check:

1. Your editor's local history (VS Code, JetBrains, and others keep
   per-file undo history on disk independently of Git).
2. Your operating system's trash or Time Machine snapshot.
3. Any open terminal buffer that may still show the file's contents.

## See also

- *restore* — reset the content of tracked files to their last committed state.
- *stash* — temporarily shelve untracked and modified files before a clean.
- *Getting out of jams* — recovering from accidental deletions and other
  destructive operations.
