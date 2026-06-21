# range-diff

Compare two versions of a patch series to see exactly what changed between
iterations.

## Mental model

When you rebase a branch, revise commits after a review, or port a series of
patches from one base to another, the individual commits change — their hashes
are new, their diffs may be slightly different, and some commits may appear or
disappear. A plain `git diff` between the two branch tips tells you only what
the net result is; it says nothing about which commits were modified or added.

`git range-diff` answers a different question: *how did the patch series
itself evolve?*

It works by treating each commit range as a set of patches and computing a
"diff of diffs". For each pair of commits from the two ranges, it generates
both patches and then diffs those patches against each other. A cost matrix
tells it which old commit corresponds to which new commit (a minimum-cost
bipartite matching problem solved with the Jonker-Volgenant algorithm). The
result is a side-by-side listing: old commit on the left, matched new commit
on the right, with the inner diff showing exactly what changed in the patch
itself.

```text
Before rebase / old iteration          After rebase / new iteration
─────────────────────────────────────  ──────────────────────────────────────
1:  f00dbal  Fix the crash             1:  decafe1  Fix the crash
2:  c0debee  Add a helpful message     2:  cab005e  Add a helpful message
3:  bedead   TO-UNDO                   (removed)
(none)                                 3:  0ddba11  Prepare for the inevitable
```

The output uses a single-character symbol in each line to summarise the
relationship:

- `=` — the patch is identical (only the hash changed, e.g. due to a rebase)
- `!` — the patch changed; the inner diff follows
- `<` — the commit exists only in the old range (was dropped)
- `>` — the commit exists only in the new range (was added)

## Synopsis

```text
git range-diff [--color=[<when>]] [--no-color] [<diff-options>]
               [--no-dual-color] [--creation-factor=<factor>]
               [--left-only | --right-only] [--diff-merges=<format>]
               [--remerge-diff]
               ( <range1> <range2> | <rev1>...<rev2> | <base> <rev1> <rev2> )
               [[--] <path>...]
```

There are three ways to name the two commit ranges:

```sh
# Two explicit ranges
git range-diff origin/main..v1  origin/main..v2

# Three-dot notation (symmetric difference shorthand)
git range-diff v1...v2

# Two tips sharing a common base
git range-diff origin/main  my-topic@{1}  my-topic
```

## Everyday usage

After an interactive rebase, compare what changed from the previous version of
your branch:

```sh
git range-diff @{u} @{1} @
```

`@{u}` is the upstream tracking branch (e.g. `origin/main`), `@{1}` is the branch as it was before the rebase (saved in the reflog), and `@` is the current HEAD.

Compare two explicit range references when reviewing a re-rolled patch series:

```sh
git range-diff origin/main..topic-v1  origin/main..topic-v2
```

Use the three-argument form to compare two branches from the same base without
spelling out the ranges twice:

```sh
git range-diff origin/main  topic-v1  topic-v2
```

Limit the comparison to a particular file to cut noise when only some commits
touched a specific path:

```sh
git range-diff origin/main  topic-v1  topic-v2  -- src/auth.c
```

Suppress the color output for piping into a pager or file:

```sh
git range-diff --no-color origin/main  topic-v1  topic-v2
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--no-dual-color` | Color lines purely by the outer +/- markers, ignoring the inner diff's original colors | Simpler terminal output when dual-color is visually confusing |
| `--creation-factor=<percent>` | Tune the cost threshold (default 60) for deciding whether a changed commit is a rewrite or a new commit | Increase when large refactors are incorrectly shown as delete+add; decrease when unrelated commits are incorrectly matched |
| `--left-only` | Show only commits present in the first (old) range | Audit what was dropped from a series |
| `--right-only` | Show only commits present in the second (new) range | Audit what was added in the new iteration |
| `--diff-merges=<format>` | Include merge commits using the specified diff format (merge commits are ignored by default) | When the range includes merges that you care about |
| `--remerge-diff` | Shorthand for `--diff-merges=remerge`; shows only conflicts resolved on top of Git's auto-merge | Reviewing how a merge conflict was resolved across rebase iterations |
| `--[no-]notes[=<ref>]` | Pass through to `git log` to include or exclude commit notes | When patches carry notes that are part of the review record |
| `--color=[<when>]` | Control color output (`always`, `never`, `auto`) | Scripting or forcing color in a CI log |
| `-- <path>...` | Limit both ranges to commits that touch the given paths | Reducing noise when only a subset of files is relevant |

## Best practices

**Run it immediately after every rebase.** The reflog entry `@{1}` points to
the branch tip before the rebase for as long as the reflog retains it. The
three-argument invocation `git range-diff @{u} @{1} @` becomes a muscle-memory
post-rebase check — it confirms you did not accidentally drop a commit or
introduce an unintended change while resolving conflicts.

**Paste the output into code review comments.** When you re-roll a patch series
after a review, attaching the `range-diff` to the cover letter (or pull-request
description) lets reviewers focus only on what changed rather than re-reading
the entire series. Tools like `git format-patch` support `--range-diff` for
this reason.

**Interpret `=` commits carefully.** A `=` means the patch content is
identical, but it does not mean the commit is meaningless — its position in
the series may have changed, or it may now apply to a different base. Read the
summary line to confirm the commit landed in the right place.

**Use `--creation-factor` to fix mismatched pairings.** If the output shows a
large commit as deleted and an unrelated commit as added, `range-diff` has
decided they are too different to pair. Raise `--creation-factor` above the
default of 60 to force it to look harder for a match. Conversely, lower it if
superficially similar commits (e.g. one-line changes to a big file) are being
matched when they should be treated as independent.

**Limit paths in large repositories.** In a monorepo where a series touches
tens of thousands of lines across many subsystems, passing `-- <path>` narrows
the diff computation to commits relevant to a particular directory or file,
which cuts both runtime and output length dramatically.

## Pitfalls & gotchas

**The output is human-readable only.** The `range-diff` manual explicitly
states that the output format is not stable across Git versions and is not
intended for machine parsing. Do not script against it; use `git log --format`
or `git patch-id` instead if you need programmatic access.

**Passing `--stat` or other summary options may produce useless output.** Some
diff options affect the inner patch generation in ways `range-diff` does not
yet interpret meaningfully. Stick to color and path-limiting options unless the
output looks sensible.

**`@{1}` becomes stale.** The reflog entry `@{1}` is overwritten the next time
any operation moves the branch (another rebase, a reset, a new commit). If you
do not run `range-diff` immediately after the rebase, capture the pre-rebase
SHA explicitly before doing more work:

```sh
git rev-parse HEAD   # record this before rebasing
```

Then use the saved SHA in place of `@{1}`.

**Merge commits are silently skipped by default.** If your range includes merge
commits and you expect them to show up, add `--diff-merges=remerge` (or the
`--remerge-diff` shorthand). Without it, merges are omitted without any
warning.

**The three-dot form means something specific.** `git range-diff v1...v2` is
*not* the same as `git diff v1...v2`. It expands to `v1..v2 v2..v1` — the
symmetric difference of both ranges. Use the explicit two-range form if you
need to compare ranges that do not share the same base.

**Color output requires a capable terminal.** The dual-color mode (on by
default) uses background-color escape codes. In terminals that do not support
them, or when piping to a file, pass `--no-color` to avoid cluttered output.

## Worked examples

### Verifying a clean rebase

You have just rebased `feature` onto the latest `main` and want to confirm
that no commit changed unexpectedly during conflict resolution.

```sh
git range-diff @{u} @{1} @
```

Typical output when the rebase was clean:

```text
1:  a1b2c3d = 1:  e4f5a6b Add rate limiting to login endpoint
2:  7890abc = 2:  1234def Extend session expiry to 30 days
3:  fedcba9 = 3:  abcdef0 Update changelog
```

Every line shows `=` — the patches are identical. The new hashes are simply
because the parent commit changed during the rebase.

If one line shows `!`, expand the output (color is on by default in a
terminal) to read the inner diff and understand what was altered.

### Reviewing a re-rolled patch series

A colleague has sent v2 of a three-patch series. The first version is already
on `origin/topic-v1`; the new one is on `origin/topic-v2`. You want to see
only what changed without re-reading the whole series.

```sh
git range-diff origin/main  origin/topic-v1  origin/topic-v2
```

Sample output:

```text
-:  ------- > 1:  0a1b2c3 Add feature flag infrastructure
1:  f1e2d3c ! 2:  4d5e6f7 Implement dark-mode toggle
    @@ -3,7 +3,7 @@
      Author: Ada Lovelace <ada@example.com>

     -This commit adds a CSS class toggle on the body element.
     +This commit adds a CSS class toggle on the body element and
     +updates the test to cover the edge case in Safari.

    @@ -15,6 +15,8 @@
      -body.toggleClass('dark-mode');
     ++expect(document.body.classList).toContain('dark-mode');
2:  c0ffee1 = 3:  badf00d Docs: document the dark-mode toggle
```

Reading the output:

- Commit 1 of v2 (`0a1b2c3`) is new — it was added to the series.
- Commit 1 of v1 maps to commit 2 of v2 and is marked `!`: the commit
  message was expanded and a new test line was added to the diff.
- The docs commit transferred unchanged (`=`).

You can now comment specifically on the changed hunk rather than reviewing the
entire series from scratch.

### Comparing branches that diverged from the same base

Two developers each started from `origin/main` and implemented the same
feature independently. You want to see how their approaches differ at the
commit level.

```sh
git range-diff origin/main  alice/feature  bob/feature
```

Commits that both developers wrote equivalently appear as `=`. Commits that
one wrote but the other did not appear as `>` or `<`. This gives you a
high-level picture of where the implementations diverge before you read the
individual diffs.

## Recovery

`range-diff` is a read-only inspection command — it does not modify the
repository. There is nothing to undo.

If a rebase that you have already run produced unexpected changes, and you have
lost the pre-rebase SHA from `@{1}`, recover it from the reflog:

```sh
git reflog show HEAD
```

Identify the commit entry immediately before the rebase line, then use that
SHA in the three-argument form:

```sh
git range-diff origin/main  <pre-rebase-sha>  HEAD
```

See *Getting out of jams* for recovering a branch from the reflog after a
destructive rebase.

## See also

- *log* — the underlying patch generation that `range-diff` uses internally.
- *rebase* — the primary operation that creates the "before and after" ranges
  that `range-diff` compares.
- *reflog* — how to find the pre-rebase SHA when `@{1}` is no longer current.
- *format-patch* — patch-series workflow; supports `--range-diff` to embed
  the comparison in a cover letter.
- *Getting out of jams* — recovering a branch tip from the reflog after a
  rebase goes wrong.
