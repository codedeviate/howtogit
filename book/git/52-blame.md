# blame

Annotate every line of a file with the commit and author that last changed it.

## Mental model

Think of `git blame` as a time-stamped margin note printed beside each line of
source code. For every line the output answers: *which commit introduced this
exact text, who wrote it, and when?*

Underneath, blame walks the commit graph backwards from HEAD (or a specified
revision), replaying the diffs in reverse until every line in the file has been
attributed to the commit that last touched it. Git follows whole-file renames
automatically, so a function that lived in `util.py` before a reorganisation and
now lives in `helpers/util.py` is still correctly attributed.

One detail worth internalising: blame shows the commit that *last* changed a
line, not the commit that *first* introduced it. If line 42 was written in
`a1b2c3` but a later commit `d4e5f6` only re-indented it, blame shows `d4e5f6`.
Use `-w` to make whitespace-only changes invisible to blame, and `--ignore-rev`
to skip entire bulk-formatting commits.

```text
commit history:  a1b2c3 ──> d4e5f6 ──> HEAD
                 └─ wrote       └─ reformatted
                    line 42        line 42
git blame result: shows d4e5f6 (unless -w or --ignore-rev suppresses it)
```

## Synopsis

```text
git blame [-c] [-b] [-l] [--root] [-t] [-f] [-n] [-s] [-e] [-p] [-w]
          [--incremental]
          [-L <range>] [-S <revs-file>] [-M] [-C] [-C] [-C]
          [--since=<date>]
          [--ignore-rev <rev>] [--ignore-revs-file <file>]
          [--color-lines] [--color-by-age] [--progress] [--abbrev=<n>]
          [--contents <file>] [<rev> | --reverse <rev>..<rev>] [--] <file>
```

## Everyday usage

Annotate the current HEAD version of a file:

```sh
git blame src/auth.py
```

Typical output — each line gets: abbreviated commit hash, author name, date,
line number, then the line itself:

```text
^a1b2c3d (Alice  2025-03-10 09:14:02 +0100  1) def authenticate(user, token):
d4e5f6a7 (Bob    2025-11-22 16:30:11 +0100  2)     if not token:
d4e5f6a7 (Bob    2025-11-22 16:30:11 +0100  3)         raise ValueError("empty token")
a1b2c3d4 (Alice  2025-03-10 09:14:02 +0100  4)     return _verify(user, token)
```

A leading `^` marks a boundary commit — the earliest commit in the requested
range. With no range that is the repository root; with a revision range
(e.g. `git blame v2.1.0..`) or `--since` it is the start of that range.

Narrow blame to a specific line range (lines 30 through 55):

```sh
git blame -L 30,55 src/auth.py
```

Narrow to a function by name (Git uses the same hunk-header regex as `git diff`):

```sh
git blame -L ':authenticate' src/auth.py
```

Blame an older revision rather than HEAD:

```sh
git blame v2.1.0 -- src/auth.py
```

Ignore whitespace-only changes (reformats, re-indents):

```sh
git blame -w src/auth.py
```

Show email addresses instead of author names:

```sh
git blame -e src/auth.py
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-L <start>,<end>` | Restrict annotation to a line range; also accepts `+<offset>`, `/<regex>/`, or `:<funcname>` | Focus on one function or section |
| `-w` | Ignore whitespace when comparing parent and child versions | Skip re-indent or reformat commits |
| `--ignore-rev <rev>` | Attribute lines changed by that commit to the previous touching commit | Skip a single bulk lint/format commit |
| `--ignore-revs-file <file>` | Read a list of revisions to ignore (same format as `fsck.skipList`) | Project-wide ignore list committed as `.git-blame-ignore-revs` |
| `-M[<num>]` | Detect lines moved or copied within the same file | Track refactored code blocks that were shuffled around |
| `-C[<num>]` | Detect lines moved or copied from other files modified in the same commit; use twice to also check the file-creation commit; use three times to check any commit | Track code moved across files |
| `-e` / `--show-email` | Show author email instead of name | Distinguish contributors who share a display name |
| `-f` / `--show-name` | Always show the filename the line came from | Useful after renames or copy-detection with `-C` |
| `-n` / `--show-number` | Show the line number in the original commit | Correlate with line numbers from an older version |
| `-s` | Suppress author name and timestamp | Compact output for scripting |
| `-l` | Show the full 40-character commit hash | Avoid hash collisions in very large repositories |
| `-t` | Show the raw Unix timestamp | Scripting or sorting by time |
| `--since=<date>` | Ignore commits older than the date; attribute those lines to the boundary commit | Show only recent changes in a long-lived file |
| `--reverse <rev>..<rev>` | Walk history forward — show the last revision in which a line existed | Track when a line was removed |
| `--first-parent` | Follow only the first parent at merge commits | See when a line arrived on an integration branch |
| `-p` / `--porcelain` | Machine-readable output with full commit metadata per block | Scripting and IDE integrations |
| `--line-porcelain` | Like `--porcelain` but repeats commit info for every line | Simpler parsing at the cost of verbosity |
| `--color-lines` | Color lines differently when they share a commit with the preceding line (cyan by default) to make same-commit runs visually distinct | Terminal readability when scanning a file |
| `--color-by-age` | Colour lines based on how old they are | Quick visual age map of a file |
| `--abbrev=<n>` | Use at least `n` hex digits for abbreviated hashes | Avoid collisions in large monorepos |
| `-b` | Show a blank SHA-1 for boundary commits | Cleaner display when `--root` is not set |
| `--root` | Do not treat root commits as boundaries | Annotate all the way back to the initial commit |
| `--show-stats` | Append statistics at the end of output | Quick summary of contributor distribution |
| `--contents <file>` | Annotate using the contents of `<file>` instead of the committed version | Blame an unsaved or modified working-tree file |

## Best practices

**Always pass `--` before the filename when there is any ambiguity.** If a
branch or tag has the same name as the file you want to blame, Git may
misinterpret the argument. `git blame -- auth.py` is unambiguous.

**Commit a `.git-blame-ignore-revs` file and configure `blame.ignoreRevsFile`
to point at it.** Bulk formatting commits (Prettier, Black, gofmt) pollute
blame output for months. Put their full hashes in a project-level file:

```sh
# .git-blame-ignore-revs
# Ran Black across the entire codebase 2026-05-01
e3f1a2b9c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9
```

Then tell every clone to use it automatically:

```sh
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

GitHub and GitLab both honour this file when rendering their blame views, so
committing it benefits everyone — including the web UI.

**Use `-w` alongside `--ignore-rev` for reformatting commits.** Some
reformatters change only indentation, not content. `-w` tells blame to ignore
whitespace differences when computing attribution, so even if a hash is not in
the ignore list, a purely cosmetic re-indent will not hijack the blame.

**Use `-C -C` when investigating copied code.** A single `-C` only examines
files modified in the same commit as the file being blamed. Two `-C` flags
extend the search to the commit that created the file, catching copy-paste from
an older module.

**Combine `-L` with a function-name pattern for focused investigation.** Rather
than scrolling through hundreds of lines, jump straight to the function in
question:

```sh
git blame -L ':parseToken' -- src/jwt.js
```

Git resolves the function boundary using the same hunk-header rules as `git
diff`, so this works out of the box for most languages without any configuration.

**Use porcelain output for tooling, not the default format.** When writing a
script that counts lines per author or feeds blame data into another tool, use
`--line-porcelain` rather than parsing the human-readable default format, which
can vary with terminal width and locale settings.

## Pitfalls & gotchas

**Blame shows who last *touched* a line, not who *wrote* it.** A bulk
search-and-replace, a copyright header update, or a trailing-whitespace fix can
make every line in a file attribute to the same housekeeping commit. Always
check with `-w` and `--ignore-rev` before concluding that an author owns a block
of code.

**Line ranges go stale.** If you bookmark "lines 40-60 of auth.py" and someone
inserts ten lines above that range in a later commit, your range now points at
different code. Prefer the function-name form (`-L ':funcname'`) whenever
possible — it re-anchors on every invocation.

**`-M` and `-C` are expensive on large files or deep histories.** Each
additional `-C` flag adds another full pass over the commit graph. On a file
with thousands of commits, triple `-C` can be slow. Use it deliberately rather
than adding it to an alias you run constantly.

**`--reverse` requires a range, not a single revision.** A common mistake is
writing `git blame --reverse v1.0 -- file`. Git accepts this and expands it to
`v1.0..HEAD` automatically, but being explicit avoids surprises when HEAD is
detached.

**Blame cannot show deleted lines.** If a line has been removed, blame cannot
tell you who deleted it — because the line no longer exists in the file. Use
`git log -S'<search string>'` (the pickaxe interface) or `git log -G'<regex>'`
to find the commit that removed a particular string. See the *log* chapter for
pickaxe details.

**The `^` prefix on a hash is a display marker, not ref syntax.** When you see
`^a1b2c3d` in blame output, it means that line has existed since a boundary
commit — the earliest commit in the requested range (the repository root when
no range is given, or the start of a revision range such as `v2.1.0..` or the
`--since` boundary when one is used). It is not the same `^` used in `HEAD^`
revision syntax.

**`--ignore-rev` can leave some lines unattributable.** When a commit is
ignored, lines it touched are reattributed to a nearby commit where possible.
Lines that were changed by the ignored commit and successfully attributed to
another commit are marked with `?` (if `blame.markIgnoredLines` is set). Lines
that could not be attributed to any other commit are marked with `*` (if
`blame.markUnblamableLines` is set). Check your config if attribution looks
wrong after adding a revision to the ignore list.

## Worked examples

### Finding who introduced a failing line

A test started failing overnight. The assertion on line 88 of `src/parser.py`
looks wrong. Find out when and why it changed:

```sh
git blame -L 88,88 -- src/parser.py
```

```text
f7c3a1d2 (Carol 2026-01-14 23:41:05 +0100 88)     assert result["status"] == "ok"
```

The commit is `f7c3a1d2`. Inspect the full change:

```sh
git show f7c3a1d2
```

The diff reveals that Carol changed `"success"` to `"ok"` to match a new API
contract, but the downstream test was not updated at the same time. You now have
the full context — author, date, commit message, and diff — to write the fix and
reference the original commit.

### Skipping a bulk-format commit

Your project ran Black over all Python files in commit `b0rked01`. Every Python
file now blames that commit for most of its lines. Add it to a project-level
ignore list and re-run blame:

```sh
# Record the full hash in the ignore file
printf '\n# Black reformat 2026-05-01\nb0rked01deadbeef1234567890abcdef12345678\n' \
  >> .git-blame-ignore-revs

# Confirm blame now attributes lines to real authors
git blame --ignore-revs-file .git-blame-ignore-revs -- src/models.py
```

Make the ignore list automatic for every contributor and for the GitHub blame UI:

```sh
git config blame.ignoreRevsFile .git-blame-ignore-revs
git add .git-blame-ignore-revs
git commit -m "Add blame ignore-revs for Black reformat"
```

### Counting lines per author with porcelain output

Count which authors contributed the most lines to a file:

```sh
git blame --line-porcelain -- src/core.py \
  | grep '^author ' \
  | sort \
  | uniq -c \
  | sort -rn
```

```text
    142 author Alice
     61 author Bob
     23 author Carol
```

This works reliably because `--line-porcelain` emits an `author` header for
every single line, making the grep-sort-uniq pipeline straightforward.

### Tracking code that moved across files

A function in `lib/validate.py` looks like it was copied from `lib/util.py`.
Use double `-C` to follow the copy, and `-f` to show the originating filename:

```sh
git blame -C -C -f -- lib/validate.py
```

Lines that originated in `lib/util.py` will show that filename in the output,
together with the commit that first introduced them there. This confirms the
copy origin and reveals whether the two copies have since diverged.

## Recovery

`git blame` is a read-only inspection command — it never modifies the working
tree, the index, or the commit graph. There is nothing to undo.

If blame is returning confusing results, the most common causes are:

- A bulk-format commit is claiming attribution. Add it to
  `--ignore-revs-file` (or the project's `.git-blame-ignore-revs`) and re-run.
- Whitespace changes are masking the real author. Add `-w` and re-run.
- You are blaming the wrong revision. Confirm with
  `git log --oneline -5 -- <file>` that the expected revision is in the
  file's history.

See *Getting out of jams* for commit-level undo recipes if you need to reverse
a change that blame helped you identify.

## See also

- *log* — `git log -S` (pickaxe) and `git log -G` to find commits that added
  or removed a specific string; essential for tracking deleted lines that blame
  cannot show.
- *show* — inspect the full diff of the commit blame identifies.
- *diff* — compare file versions directly when you need to see what changed
  between two revisions.
- *bisect* — binary-search the commit graph when blame points to the wrong
  region and you need to narrow down a regression automatically.
- *Getting out of jams* — undoing changes once blame has identified the
  offending commit.
