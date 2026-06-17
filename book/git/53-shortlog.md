# shortlog

Summarize commit history by author (or any grouping) in a format ready for
release notes and contributor reports.

## Mental model

`git shortlog` is a post-processor for commit history. Internally it does what
`git log` does — walks the ancestry graph — but instead of printing each
commit individually it collects them into buckets and prints one bucket per
author (or per whatever grouping you ask for). The output looks like:

```text
Alice Johnson (14):
      Add OAuth2 login flow
      Fix token expiry off-by-one
      ...

Bob Nakamura (7):
      Refactor middleware stack
      ...
```

Two design details are worth knowing up front.

First, `git shortlog` respects the mailmap. A contributor who has committed
under several email addresses or name variations is folded into a single entry
automatically. See the *Mapping authors* note in `gitmailmap(5)`.

Second, `git shortlog` can read from standard input instead of the repository.
Pipe `git log --pretty=short` into it and it works identically — useful in
scripts that already have log output in hand, or when running outside any
repository.

## Synopsis

```text
git shortlog [<options>] [<revision-range>] [[--] <path>...]
git log --pretty=short | git shortlog [<options>]
```

## Everyday usage

Show every contributor and their commit subjects for the whole history,
sorted alphabetically by name:

```sh
git shortlog HEAD
```

Show just the count per contributor, sorted from most commits to fewest:

```sh
git shortlog -sn HEAD
```

Typical output:

```text
   143  Alice Johnson
    89  Bob Nakamura
    52  Carol Wei
```

Include email addresses next to each name:

```sh
git shortlog -sne HEAD
```

Summarise only what is new since the last release tag:

```sh
git shortlog -sn v1.3.0..HEAD
```

Show contributors to a specific directory only:

```sh
git shortlog -sn HEAD -- src/auth/
```

Group by the `Reviewed-by` trailer to see who has reviewed the most work:

```sh
git shortlog -sn --group=trailer:reviewed-by HEAD
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-n`, `--numbered` | Sort by commit count descending instead of alphabetically | Leaderboard-style contributor lists |
| `-s`, `--summary` | Suppress commit subjects; show only the count and name | Quick contributor counts |
| `-e`, `--email` | Show each author's email address | Identifying duplicate identities before updating `.mailmap` |
| `--group=<type>` | Group by `author` (default), `committer`, `trailer:<field>`, or `format:<format>` | Grouping by reviewer, co-author, or any commit metadata |
| `-c`, `--committer` | Alias for `--group=committer` | When you want to see who landed commits, not who wrote them |
| `--format=<format>` | Replace commit subjects with a `git log --format` string | Showing short hashes or dates instead of subjects |
| `--date=<format>` | Format date fields used in `--group=format:<format>` | Grouping by month or year |
| `-w[<width>[,<indent1>[,<indent2>]]]` | Wrap output at `<width>` columns (default 76) | Fitting output into a terminal or email |
| `--since=<date>`, `--after=<date>` | Limit to commits newer than a date | Activity reports for a sprint or release cycle |
| `--until=<date>`, `--before=<date>` | Limit to commits older than a date | Historical snapshots |
| `--author=<pattern>` | Limit to commits whose author matches the pattern | Auditing a single contributor's work |
| `--no-merges` | Exclude merge commits | Counts that reflect only substantive work |
| `--first-parent` | Follow only the first parent of each merge | Summary of a trunk branch without feature-branch noise |
| `--all` | Include all refs, not just HEAD | Repository-wide contributor totals |

## Best practices

**Always pair `-s` with `-n` for contributor lists.** The combination
`-sn` produces output sorted by impact (most commits first) with no commit
subject noise. This is the idiomatic form used in almost every project's
release announcement.

**Exclude merge commits with `--no-merges`.** On repositories that merge
feature branches rather than rebasing, each merge commit is credited to the
person who pressed the merge button. That inflates their count and deflates
the counts of feature authors. `--no-merges` makes the numbers represent
actual authorship.

```sh
git shortlog -sn --no-merges v2.0.0..HEAD
```

**Use a revision range for release notes.** Running `git shortlog HEAD`
sums the entire project history, which is rarely what you want for a
changelog. Anchor both ends explicitly:

```sh
git shortlog -sn v1.4.0..v1.5.0
```

**Keep a `.mailmap` file.** Contributors change employers, use different
machines, or configure Git inconsistently. Without a `.mailmap`, the same
person appears as multiple authors. See the *log* chapter for how mailmap
interacts with history display, and `gitmailmap(5)` for the file format.

**Use `--group=trailer:co-authored-by` to credit pair-programming partners.**
Many teams follow the GitHub convention of adding `Co-authored-by` trailers
to commits. Shortlog can aggregate those:

```sh
git shortlog -sn --group=author --group=trailer:co-authored-by HEAD
```

The `--group` flag may be specified more than once; a commit is counted under
each matching group value.

## Pitfalls & gotchas

**`-n` alone does not suppress commit subjects.** The flag changes the sort
order but not the output format. Use `-sn` together, not just `-n`, when you
want the count-only summary.

**Merge commits double-count work on trunk-based repos.** On a repo where
all feature branches are merged (not rebased), every commit on a feature
branch appears once in the feature author's bucket and the merge commit
appears in the merger's bucket. Add `--no-merges` to eliminate the merge
entries; or use `--first-parent` to see only the trunk commits.

**The revision range is required when piping.** When reading from standard
input, `git shortlog` does not attach to the repository, so revision-range
expansion such as `HEAD` or tag names cannot be resolved. Pass the pre-expanded
commit list through `git log` and pipe it in instead:

```sh
git log --pretty=short v1.3.0..HEAD | git shortlog -sn
```

**Commit counts do not measure contribution quality.** A contributor who
writes ten small, focused commits will rank higher than one who writes a
single large architectural change. Use the numbers as a starting point for
recognition, not as a definitive ranking.

**`--group=trailer:<field>` silently ignores commits missing the trailer.**
Commits without the specified trailer are excluded from the count entirely.
If only some commits have `Reviewed-by` trailers, the resulting totals reflect
only those commits.

**`-w` line-wrapping applies to commit subjects, not to names.** The width
option wraps the individual commit-subject lines inside each author block. It
does not truncate long author names.

## Worked examples

### Generating a release announcement contributor list

Your project tags releases. You want the contributor section of the
`CHANGELOG` entry for `v2.1.0`:

```sh
git shortlog -sn --no-merges v2.0.0..v2.1.0
```

```text
    31  Alice Johnson
    18  Bob Nakamura
    12  Carol Wei
     5  David Osei
     3  Eve Martinez
```

To produce the formatted paragraph often seen in announcements ("Thanks to
Alice Johnson, Bob Nakamura, ..."), combine with `awk` or a simple shell
pipeline:

```sh
git shortlog -sn --no-merges v2.0.0..v2.1.0 | awk '{$1=""; print substr($0,2)}' | paste -sd ', '
```

### Reviewing activity on a single directory over the last quarter

You want to know who touched the authentication subsystem in the past 90 days,
excluding merge commits:

```sh
git shortlog -sne --no-merges --since="90 days ago" HEAD -- src/auth/
```

```text
    17  Alice Johnson <alice@example.com>
     9  Bob Nakamura <bob@example.com>
     2  Carol Wei <carol@example.com>
```

The `-e` flag reveals email addresses. If you see the same person listed
twice under different emails, that is a signal to add an entry to `.mailmap`.

### Grouping by reviewer trailer

Your team adds `Reviewed-by` trailers. You want a quarterly review leaderboard:

```sh
git shortlog -sn --group=trailer:reviewed-by --since="2026-01-01" HEAD
```

```text
    42  Alice Johnson
    27  Bob Nakamura
    15  Carol Wei
```

Only commits that carry the trailer are counted, so the total will be lower
than the total commit count if not all commits have been reviewed.

### Piping from git log for a custom format

You want to list each contributor alongside the short hash and subject of
their most recent commit — useful for a digest email. Use `--format` to
replace the default commit subject:

```sh
git shortlog --format="%h %s" -n HEAD
```

Each author block then shows `<hash> <subject>` instead of just the subject.

## Recovery

`git shortlog` is a read-only command. It never modifies refs, the index, or
the working tree, so there is nothing to undo.

If your contributor counts look wrong (duplicates, missing authors), the fix
is usually a `.mailmap` correction rather than anything in `git shortlog`
itself. See the *log* chapter for the mailmap format and how to verify it
with `git log --use-mailmap`.

## See also

- *log* — the underlying history traversal that `git shortlog` builds on;
  also covers `.mailmap` and `--format` strings.
- *blame* — attribute individual lines of a file to the commit that last
  changed them.
- *show* — inspect a single commit in full detail.
- *Getting out of jams* — if history looks wrong, this is the place to start.
