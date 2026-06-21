# grep

Search for patterns across every file Git tracks — or across blobs in any
tree object — without leaving your repository.

## Mental model

`git grep` is a repository-aware search engine. Where a plain `grep -r`
walks the filesystem and stumbles over build artefacts, `node_modules`, and
binary blobs, `git grep` works from what Git knows: tracked files in the
working tree, the index, or any commit (or tag, or branch tip) you name.

Three search targets are available:

```text
Working tree  ──  the default; what is on disk right now
Index         ──  --cached; what is staged
Tree object   ──  git grep <pattern> <tree>; any commit/branch/tag
```

Because Git controls the file list, results are always relevant to the
project. Untracked files and anything listed in `.gitignore` are invisible
by default. When you need to go back in time — "was this constant defined in
the release-2.0 tag?" — you hand `git grep` a tree reference instead of
hunting through `git log` output.

## Synopsis

```text
git grep [-a | --text] [-I] [-i | --ignore-case] [-w | --word-regexp]
         [-v | --invert-match] [--full-name]
         [-E | --extended-regexp] [-G | --basic-regexp] [-P | --perl-regexp]
         [-F | --fixed-strings] [-n | --line-number] [--column]
         [-l | --files-with-matches] [-L | --files-without-match]
         [-z | --null] [-o | --only-matching] [-c | --count]
         [-q | --quiet]
         [--break] [--heading] [-p | --show-function]
         [-A <num>] [-B <num>] [-C <num>] [-W | --function-context]
         [(-m | --max-count) <num>] [--threads <num>]
         [-f <file>] [-e <pattern>]
         [--and | --or | --not | -e <pattern>...] [--all-match]
         [--cached | --untracked | --no-index]
         [--recurse-submodules]
         [<tree>...] [--] [<pathspec>...]
```

## Everyday usage

Search all tracked files for a string:

```sh
git grep 'TODO'
```

Case-insensitive search:

```sh
git grep -i 'deprecated'
```

Show line numbers alongside matches:

```sh
git grep -n 'MAX_RETRIES'
```

List only the filenames that contain a match — useful for piping:

```sh
git grep -l 'console\.log'
```

Search a specific subdirectory or file pattern:

```sh
git grep 'error_code' -- 'src/*.c'
```

Search across a past commit or branch:

```sh
git grep 'old_function_name' main
git grep 'old_function_name' v2.3.0
```

Show a few lines of context around each match:

```sh
git grep -n -C 3 'initDatabase'
```

Count matches per file rather than printing each line:

```sh
git grep -c 'import React'
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-n`, `--line-number` | Prefix each match with its line number | Navigate to matches in an editor |
| `-i`, `--ignore-case` | Match regardless of letter case | Searching identifiers with inconsistent casing |
| `-w`, `--word-regexp` | Match only at word boundaries | Avoid `count` matching `discount` |
| `-l`, `--files-with-matches` | Print only filenames, not matching lines | Feed to `xargs` or another command |
| `-L`, `--files-without-match` | Print only filenames that have no match | Audit which files lack a required header |
| `-v`, `--invert-match` | Print lines that do not match | Find files missing something expected |
| `-c`, `--count` | Print match count per file | Quick frequency survey |
| `-E`, `--extended-regexp` | POSIX extended regex (`+`, `?`, `\|`, `()`) | Most regex needs; cleaner than basic regex |
| `-P`, `--perl-regexp` | Perl-compatible regex (PCRE) | Lookaheads, lookbehinds, `\b`, `\K` |
| `-F`, `--fixed-strings` | Treat pattern as a literal string | Searching for `.` or `*` without escaping |
| `-A <num>` | Show `<num>` lines after each match | See what follows a match |
| `-B <num>` | Show `<num>` lines before each match | See what precedes a match |
| `-C <num>` | Show `<num>` lines before and after | General context around a match |
| `-W`, `--function-context` | Show the whole enclosing function | Understand a match without opening the file |
| `-p`, `--show-function` | Print the preceding function-name line above each match | Locate which function contains the match |
| `--cached` | Search the index instead of the working tree | Check what is staged |
| `--untracked` | Also search untracked files | Cast a wider net; includes new files |
| `--no-index` | Search outside a Git repo (like `grep -r`) | Scripts that may run in non-Git directories |
| `-e <pattern>` | Explicitly mark the next argument as the pattern | Required when the pattern starts with `-`; also used for Boolean combinations |
| `--and`, `--or`, `--not` | Combine multiple `-e` patterns with Boolean logic | Multi-condition searches |
| `--all-match` | Restrict to files where every `--or` pattern appears | Audit files that must contain two independent things |
| `-q`, `--quiet` | Exit 0/non-zero without printing | Shell conditionals and scripts |
| `-o`, `--only-matching` | Print only the matched portion of each line | Extract values rather than whole lines |
| `--color[=<when>]` | Highlight matches in colour (`always`, `never`, `auto`) | Terminal readability |
| `--break` | Print a blank line between results from different files | Visual separation in long output |
| `--heading` | Print the filename once above its matches instead of on every line | Cleaner output when many lines match per file |
| `--recurse-submodules` | Descend into active submodules | Monorepos with submodules |
| `-f <file>` | Read patterns from a file, one per line | Large or machine-generated pattern lists |
| `-m <num>`, `--max-count <num>` | Stop after `<num>` matches per file | Speed up exploratory searches |
| `--threads <num>` | Set the number of worker threads | Tune performance on large repositories |
| `-z`, `--null` | Delimit filenames with `\0` in output | Safe piping to `xargs -0` |

## Best practices

**Anchor searches to a path when you know where to look.** A project-wide
search for `id` returns thousands of hits. Narrowing to a subdirectory or
glob finds what you actually want in milliseconds:

```sh
git grep -n 'user_id' -- 'src/models/*.py'
```

**Use `-l` with `-z` when piping into `xargs`.** Filenames can contain
spaces. Combining `--null` with `xargs -0` handles them correctly:

```sh
git grep -lz 'console\.log' | xargs -0 sed -i '' 's/console\.log/logger.debug/g'
```

**Prefer `-E` or `-P` over the default basic regex.** Basic regex requires
backslash-escaping `+` and `|`. Extended (`-E`) or Perl (`-P`) regex are
far more readable for anything beyond a simple literal:

```sh
# Basic regex — confusing escapes required
git grep 'function\|method'

# Extended regex — clear alternation
git grep -E 'function|method'
```

**Search historical trees to answer "when did this change?"** Use known tags
or branch tips as the search target. Once you find the boundary, use `git
bisect` (see the *bisect* chapter) to narrow to a specific commit:

```sh
git grep 'legacyAuth' v1.0.0   # present in v1.0.0?
git grep 'legacyAuth' v2.0.0   # present in v2.0.0?
```

**Use `-q` in scripts instead of parsing output.** The exit code is
reliable: 0 means at least one match, 1 means no matches, 128 means an
error. Parsing text output is fragile by comparison:

```sh
if git grep -q 'set -e' scripts/deploy.sh; then
    echo "deploy.sh enables strict mode"
fi
```

**Configure defaults in your global config.** Always having line numbers and
extended regex avoids typing the same flags every day:

```sh
git config --global grep.lineNumber true
git config --global grep.patternType extended
```

## Pitfalls & gotchas

**Untracked and ignored files are invisible by default.** If you just created
a file that is not yet staged, `git grep` will not find it unless you add
`--untracked`. Vendor directories in `.gitignore` are always excluded unless you use
`--untracked --no-exclude-standard` (to add ignored files while staying inside
the Git context) or `--no-index` (to bypass Git's file list entirely).

**The default regex engine is basic, not extended.** Characters like `+`,
`?`, `|`, `(`, and `)` must be escaped or you must pass `-E`. A common
surprise: `git grep 'foo+bar'` matches the literal string `foo+bar`, not
"one or more `o`s followed by `bar`".

**`-w` (`--word-regexp`) uses C-locale word boundaries.** It treats any
non-alphanumeric, non-underscore character as a word separator. This matches
POSIX `grep` behaviour but can produce unexpected results with Unicode
identifiers.

**Searching a tree does not search the working tree.** `git grep 'foo' HEAD`
searches the committed HEAD snapshot, not your unsaved edits. To check
staged changes use `--cached`; to check the latest commit use `HEAD` as the
tree argument.

**Boolean expressions require `-e` for every pattern.** The `--and`, `--or`,
and `--not` operators only work when each pattern is introduced with `-e`.
Omitting `-e` makes Git treat the bare word as a pathspec:

```sh
# Wrong: 'FIXME' is interpreted as a pathspec limiter, not a pattern
git grep -e 'TODO' --and 'FIXME'

# Correct
git grep -e 'TODO' --and -e 'FIXME'
```

**Multi-threaded searches over the object store can be slower with
`--textconv`.** When grepping with `--cached` or a tree argument and text
conversion is involved, try `--threads=1` if performance is unexpectedly
poor.

## Worked examples

### Finding all call sites before renaming a function

You are renaming `fetchUser` to `getUser` across a Go codebase. Before
touching anything, map every call site:

```sh
git grep -n 'fetchUser' -- '*.go'
```

```text
api/handler.go:14:    u, err := fetchUser(ctx, id)
api/handler.go:87:    return fetchUser(ctx, req.UserID)
db/queries.go:32:func fetchUser(ctx context.Context, id int) (*User, error) {
internal/cache.go:11:    cached := fetchUser(ctx, key)
```

Get only the filenames for a bulk replacement, using `\0` as delimiter so
spaces in paths cause no problems:

```sh
git grep -lz 'fetchUser' -- '*.go' | xargs -0 sed -i '' 's/fetchUser/getUser/g'
```

Confirm no occurrences remain — the exit code should be 1:

```sh
git grep 'fetchUser' -- '*.go'
echo "exit: $?"
```

```text
exit: 1
```

### Auditing for a required copyright header

Your team requires every Python file to open with a copyright comment. Find
which files are missing it:

```sh
git grep -L 'Copyright (c) Acme Corp' -- '*.py'
```

```text
scripts/legacy_import.py
tests/fixtures/sample_data.py
```

Only those two files need the header; the rest already have it.

### Comparing a pattern across branches

You want to confirm whether a feature flag named `enable_new_checkout` was
present at the last release tag but has since been removed in `main`:

```sh
git grep -l 'enable_new_checkout' v3.0.0
git grep -l 'enable_new_checkout' main
```

If the first command lists files and the second prints nothing, the flag was
cleaned up after the release — or was never backported to the release branch,
depending on your workflow.

### Boolean search: lines that both define a symbol and mention a unit

Find every line in C headers that contains `#define` and also contains the
string `_MS` (a millisecond suffix convention):

```sh
git grep -e '#define' --and -e '_MS' -- '*.h'
```

Both patterns must match the same line. Without `--and`, `--or` is the
default and either pattern alone would qualify.

## Recovery

`git grep` is read-only — it never modifies the working tree, the index, or
history. There is nothing to undo from the grep itself.

If you piped `git grep -l` output into a command that modified files and
the result was wrong, restore the affected files with `git restore`:

```sh
# Restore a single file to its last committed state
git restore path/to/file.py

# Discard all working-tree changes
git restore .
```

See *Getting out of jams* for broader recovery strategies, including
recovering from unintended bulk edits triggered by `xargs` pipelines.

## See also

- *log* — search commit messages with `git log --grep`; combine with
  `git grep` to find both the code and the commit that introduced it.
- *bisect* — after `git grep` shows a pattern exists in one tag but not
  another, use `git bisect` to pinpoint the exact commit.
- *blame* — once `git grep -n` tells you the line, use `git blame` to see
  who last changed it and which commit introduced it.
- *add* — use `git grep -l` to build a targeted file list before staging
  with `git add`.
- *Getting out of jams* — recovering from bulk working-tree modifications
  driven by `xargs` pipelines built on `git grep -l` output.
