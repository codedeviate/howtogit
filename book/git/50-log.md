# log

Walk the commit graph and display commit history with configurable filtering,
formatting, and diff output.

## Mental model

Every commit in a Git repository is a node in a directed acyclic graph. Each
node points to one or more parent commits. `git log` is a graph-walking
engine: it starts at one or more named entry points (branches, tags, HEAD, or
any revision expression), follows parent links backwards through history, and
prints each commit it visits.

The walk is filtered in two stages:

1. **Commit limiting** — decide which commits to include based on author,
   date, message content, affected paths, or ancestry constraints.
2. **Commit formatting** — decide how to render each included commit: one
   line, full metadata, a patch, a diffstat, or a custom template.

Both stages are independent. You can filter to the last ten commits touching
`src/auth/` and render each one as a full patch, or you can look at three
years of history and render it as a single-line graph. Understanding this
separation makes the many options feel organized rather than overwhelming.

```text
All commits reachable from <revision>
        │
        ▼  commit limiting (--since, --author, --grep, -- <path> …)
        │
        ▼  commit ordering (--topo-order, --date-order, --reverse)
        │
        ▼  commit formatting (--oneline, --pretty, --stat, -p …)
        │
        ▼  output
```

By default, `git log` starts at HEAD and outputs commits in reverse
chronological order with the medium format (hash, author, date, and full
message).

## Synopsis

```text
git log [<options>] [<revision-range>] [[--] <path>...]
```

Key forms:

```text
git log                              # history of current branch from HEAD
git log <branch>                     # history of another branch
git log <since>..<until>             # commits reachable from <until> but not <since>
git log <branch1>...<branch2>        # symmetric difference (commits on either side)
git log -- <path>...                 # only commits that touched these paths
git log -L <start>,<end>:<file>      # trace a line range across history
git log -L :<funcname>:<file>        # trace a function across history
```

## Everyday usage

Show a compact, one-line-per-commit view of the current branch:

```sh
git log --oneline
```

```text
a3f9c1d Fix null-pointer dereference in parseToken
7b2e8fa Add login validation with rate limiting
c1d4a0b Initial project scaffold
```

Show a decorated graph of all branches and tags — the most common starting
point for understanding a repository's topology:

```sh
git log --oneline --graph --decorate --all
```

Show commits from the last week by a specific author:

```sh
git log --since="1 week ago" --author="Alice"
```

Show only commits that touched a particular file:

```sh
git log -- src/auth/login.js
```

Show the changes each commit introduced (full patch):

```sh
git log -p
```

Show a diffstat summary per commit — useful for understanding scope without
reading every diff:

```sh
git log --stat
```

Show only commits on your feature branch that are not yet on `main`:

```sh
git log main..HEAD
```

Show commits whose message contains a search term:

```sh
git log --grep="rate limit"
```

Show the last five commits:

```sh
git log -5
```

## Key options

### Commit limiting

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-<n>` / `-n <n>` | Limit output to `<n>` commits | Quick look at recent history |
| `--since=<date>`, `--after=<date>` | Show commits newer than `<date>` | Scoping a time window |
| `--until=<date>`, `--before=<date>` | Show commits older than `<date>` | Scoping a time window |
| `--author=<pattern>` | Filter by author name/email (regex) | Reviewing one person's work |
| `--committer=<pattern>` | Filter by committer name/email (regex) | Distinguish author from committer |
| `--grep=<pattern>` | Filter by commit message (regex) | Finding commits about a topic |
| `--all-match` | Require all `--grep` patterns to match (default: any) | Narrowing multiple keywords |
| `--invert-grep` | Exclude commits matching `--grep` | Filtering out noise |
| `-i` / `--regexp-ignore-case` | Case-insensitive regex matching | Grep without worrying about case |
| `--no-merges` | Exclude merge commits | Cleaner linear history view |
| `--merges` | Show only merge commits | Auditing integration points |
| `--first-parent` | Follow only first parent of merges | Trunk-focused history on busy repos |
| `--all` | Start from all refs (branches, tags, HEAD) | Whole-repository overview |

### Commit formatting

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--oneline` | One line per commit: abbreviated hash + subject | Default compact view |
| `--pretty=<fmt>` / `--format=<fmt>` | Built-in or custom format string | Scripting or bespoke display |
| `--abbrev-commit` | Shorten the hash to a unique prefix | Readability in terminals |
| `--decorate` | Show branch/tag names next to commits | Seeing where refs point |
| `--graph` | ASCII graph of the branch topology | Visualizing merges |
| `--stat` | Diffstat (files changed, insertions, deletions) per commit | Judging scope of each commit |
| `--shortstat` | One-line summary of total changes | Even more compact than `--stat` |
| `--name-only` | List changed filenames only | Quick file-level overview |
| `--name-status` | Filenames with status letters (A/M/D/R) | Spotting renames and deletions |
| `-p` / `--patch` | Full unified diff per commit | Code review in the terminal |
| `--date=<format>` | Control date rendering (relative, iso, short, …) | Readable dates in custom formats |
| `--follow` | Continue history past renames (single file) | Tracking a file that was renamed |
| `-L <start>,<end>:<file>` | Show evolution of a line range | Archaeology on a specific block of code |
| `-L :<funcname>:<file>` | Show evolution of a function by name | Tracing when a function changed |

### Revision ranges

| Notation | Meaning |
|----------|---------|
| `A..B` | Commits reachable from B but not from A (commits added since A) |
| `A...B` | Symmetric difference: commits on either side but not the common ancestor |
| `^A B` | Same as `A..B` (explicit exclusion) |
| `HEAD~3` | The commit three steps before HEAD |
| `origin/main..HEAD` | Commits in your branch not yet on the remote |

## Best practices

**Use `--oneline --graph --decorate --all` as your default overview.** This
single invocation shows the entire reference graph in a compact form. Alias it
to something short:

```sh
git config --global alias.lg "log --oneline --graph --decorate --all"
```

Then `git lg` gives you the topology at a glance.

**Filter by path to understand a file's history.** Before reading a file,
look at its history first:

```sh
git log --oneline -- src/payments/checkout.js
```

The `--` separator is not always required but is unambiguous: everything
after `--` is a path, not a branch name.

**Use `--follow` when a file has been renamed.** Without it, the log stops
at the rename commit. With it, Git threads through the rename and continues
showing older commits under the original name:

```sh
git log --follow -- src/payments/checkout.js
```

**Prefer `origin/main..HEAD` over guessing a base commit.** When reviewing
your own branch before pushing, this range shows exactly the commits that
will travel:

```sh
git log --stat origin/main..HEAD
```

**Use `-L :<funcname>:<file>` for function-level archaeology.** Instead of
grepping through the log manually, let Git trace the function for you:

```sh
git log -L :parseToken:src/auth/token.js
```

Git infers the function boundary from language-specific heuristics (or
`.gitattributes`). Every commit that changed the function body appears with
its diff, even if other parts of the file changed at the same time.

**Use `--no-merges` when reviewing a linear history.** On a repository with
frequent merges, merge commits dominate the log. `--no-merges` hides them and
surfaces the actual work:

```sh
git log --oneline --no-merges main..feature/payments
```

**Combine `--grep` with `-i` and `--all-match` carefully.** Multiple
`--grep` patterns are ORed by default. Add `--all-match` to require all of
them, and `-i` to go case-insensitive:

```sh
git log --grep="payment" --grep="stripe" --all-match -i
```

## Pitfalls & gotchas

**`git log <file>` without `--` can be ambiguous.** If a branch and a file
share a name, Git may interpret the argument as a branch. Always use `--` to
separate revision arguments from path arguments:

```sh
git log -- config    # unambiguous: show history of the file named "config"
```

**History simplification hides commits by default when filtering by path.**
When you give `git log -- <path>`, Git uses default history simplification:
it follows only the parent that explains the final state of the file, which
can make commits disappear. If you suspect a commit is missing, add
`--full-history`:

```sh
git log --full-history -- src/auth/login.js
```

**`--all` does not mean "everything ever".** It includes all refs (branches,
tags, HEAD) but not commits that are not reachable from any ref. Commits
dangling after a `git reset` or `git branch -D` are not shown. Use `git
reflog` to find those.

**`--graph` implies `--topo-order`.** The topological ordering can cause
surprising jumps in timestamps. Older commits may appear above newer ones to
keep branch lines readable. This is correct behavior, not a bug.

**`--since` and `--until` use the author date, not the committer date.**
Rebased commits keep their original author date. A commit written last year
and rebased today will still appear in `--since="last year"` output, even
though it was rebased recently.

**Custom `--pretty=format:` does not add a trailing newline; `tformat:` does.**
If you pipe `--pretty=format:%h` output to another tool and the last line is
missing a newline, switch to `--pretty=tformat:%h`. The `tformat:` variant
uses terminator semantics (newline after every entry) instead of separator
semantics (newline between entries).

**`-p` on merge commits shows no diff by default.** Merge commits have
multiple parents, and `git log -p` suppresses diffs for them unless you
specify a `--diff-merges` option. Use `--diff-merges=first-parent` for a
diff against the first parent:

```sh
git log -p --diff-merges=first-parent
```

## Worked examples

### Auditing recent changes to a module

Your team just deployed and something in the authentication module looks
wrong. Show every commit that touched `src/auth/` in the last two weeks,
with a diffstat:

```sh
git log --since="2 weeks ago" --stat -- src/auth/
```

```text
commit a3f9c1d
Author: Alice <alice@example.com>
Date:   Mon Jun 16 14:22:01 2026 +0200

    Throttle login attempts to 5 per minute per IP

 src/auth/login.js   | 18 ++++++++++++++++--
 src/auth/limiter.js |  5 +++++
 2 files changed, 21 insertions(+), 2 deletions(-)

commit 7b2e8fa
Author: Bob <bob@example.com>
Date:   Fri Jun 13 09:11:44 2026 +0200

    Add JWT expiry to token validator

 src/auth/token.js | 12 +++++++++---
 1 file changed, 9 insertions(+), 3 deletions(-)
```

Narrow further to commits by a specific person:

```sh
git log --since="2 weeks ago" --author="Alice" --stat -- src/auth/
```

### Understanding how a function evolved

You need to understand why `parseToken` behaves the way it does. Trace its
entire history:

```sh
git log --oneline -L :parseToken:src/auth/token.js
```

Git prints each commit that modified the function body, along with the exact
diff of the function at that point. Read from bottom to top to see the
function grow from its original form to the present.

### Comparing two branches before a merge

Before merging `feature/payments` into `main`, review what will land:

```sh
git log --oneline --stat main..feature/payments
```

Each commit is shown with the files it touches. If a commit touches
unexpected files, you can inspect it further with `git show <hash>`.

Check the same range for any commits that are pure merge noise:

```sh
git log --oneline --no-merges main..feature/payments
```

### Building a custom one-liner for scripting

You need a list of commit hashes and subjects since a given tag, suitable
for feeding to another script:

```sh
git log --pretty=tformat:"%h %s" v2.3.0..HEAD
```

```text
a3f9c1d Throttle login attempts to 5 per minute per IP
7b2e8fa Add JWT expiry to token validator
c1d4a0b Migrate payment provider to Stripe
```

The `tformat:` prefix ensures each line ends with a newline, making it safe
to pipe to `while read hash subject; do ...`.

### Visualizing a branchy repository

You have inherited a repository with many branches and want to understand
its topology before starting work:

```sh
git log --oneline --graph --decorate --all
```

```text
* a3f9c1d (HEAD -> main, origin/main) Throttle login attempts
| * 9f1b234 (feature/payments) Add Stripe webhook handler
| * 4d7e890 Scaffold payments module
|/
* 7b2e8fa Add JWT expiry to token validator
* c1d4a0b Initial project scaffold
```

The `*` marks commits, `/` and `|` draw branch lines, and the parenthetical
labels show where refs point.

## Recovery

`git log` is a read-only command: it cannot modify the repository. There is
nothing to undo.

If a range expression returns unexpected results, double-check the notation:
`A..B` means "reachable from B, not from A" — not "commits between A and B
chronologically". Test with `--oneline` first to confirm the set before
adding `-p` or other heavy output options.

If commits seem missing when filtering by path, see the *history
simplification* pitfall above and try `--full-history`.

For recovering commits that are no longer reachable from any ref (after a
reset or a deleted branch), see the *reflog* chapter, which walks Git's
internal operation log.

## See also

- *show* — display a single commit in full detail (patch + metadata).
- *blame* — annotate a file line-by-line with the commit that last changed each line.
- *reflog* — walk the local operation log to find commits not reachable from refs.
- *shortlog* — summarize `git log` output grouped by author.
- *diff* — compare two trees or commits without the commit metadata.
- *bisect* — binary-search the commit graph to find the commit that introduced a bug.
- *Getting out of jams* — recovering commits that appear to have been lost.
