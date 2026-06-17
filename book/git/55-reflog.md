# reflog

Show, manage, and recover from Git's local record of every position
HEAD and branch tips have ever occupied.

## Mental model

Every time a reference moves — you commit, switch branches, rebase,
reset, merge, cherry-pick, or pull — Git appends an entry to a log file
stored under `.git/logs/`. That log is the reflog. It is purely local: it
never leaves your machine during a push or fetch, and it is never shared
with collaborators.

Think of the reflog as a personal undo stack for references. Each entry
records the old SHA-1, the new SHA-1, a timestamp, the identity of the
person who made the change, and a short description of what happened.

```text
old SHA-1 -> new SHA-1   identity   timestamp   description
  a3f9c1      8b4d72     you        2 hours ago  commit: Fix null pointer
  8b4d72      HEAD       you        3 hours ago  commit: Add login form
```

The most important reflog is `HEAD`, which records every position HEAD has
occupied. Each branch also has its own reflog under
`.git/logs/refs/heads/<branch>`.

You refer to reflog entries with the `@{n}` syntax: `HEAD@{0}` is the
current position, `HEAD@{1}` is where HEAD was before the last operation,
`HEAD@{2}` two operations ago, and so on. You can also use time-based
syntax: `HEAD@{1.hour.ago}` or `main@{yesterday}`.

The reflog is the safety net that makes destructive operations — hard
resets, rebases, amends — survivable. As long as a commit was ever
reachable from a local ref, its SHA-1 appears in the reflog and can be
retrieved.

## Synopsis

```text
git reflog [show] [<log-options>] [<ref>]
git reflog list
git reflog expire [--expire=<time>] [--expire-unreachable=<time>]
        [--rewrite] [--updateref] [--stale-fix]
        [--dry-run | -n] [--verbose] [--all [--single-worktree] | <refs>...]
git reflog delete [--rewrite] [--updateref]
        [--dry-run | -n] [--verbose] <ref>@{<specifier>}...
git reflog drop [--all [--single-worktree] | <refs>...]
git reflog exists <ref>
```

## Everyday usage

Show the reflog for HEAD (the default):

```sh
git reflog
```

```text
8b4d72a (HEAD -> main) HEAD@{0}: commit: Add rate limiting
a3f9c1b HEAD@{1}: reset: moving to HEAD~1
f7e2c80 HEAD@{2}: commit: Fix null pointer in parseToken
```

Show the reflog for a specific branch:

```sh
git reflog show feature/login
```

Show the last ten entries (the reflog accepts any `git log` option):

```sh
git reflog -10
```

Show entries with full dates instead of relative times:

```sh
git reflog --date=iso
```

Find the SHA-1 of where HEAD was three moves ago:

```sh
git show HEAD@{3}
```

Find where the branch `main` was yesterday:

```sh
git show main@{yesterday}
```

List all refs that have a reflog:

```sh
git reflog list
```

Check whether a reflog exists for a ref:

```sh
git reflog exists refs/heads/main
```

## Key options

`git reflog show` accepts all options that `git log` accepts. The options
below cover the most useful ones for each subcommand.

| Option | Subcommand | What it does | When to use it |
|--------|-----------|--------------|----------------|
| `<ref>` | `show` | Show the reflog for the named ref (default: `HEAD`) | Inspect a branch's movement history |
| `-n <number>` | `show` | Limit output to the last `n` entries | Keep the output manageable |
| `--date=<format>` | `show` | Format timestamps (`relative`, `iso`, `short`, `local`, `raw`) | Correlate with wall-clock time |
| `--oneline` | `show` | Condense each entry to one line | Quick scanning |
| `--all` | `expire`, `drop` | Apply to every ref's reflog | Repository-wide view or bulk pruning |
| `--single-worktree` | `expire`, `drop` | Limit `--all` to the current worktree | Multi-worktree repositories |
| `--expire=<time>` | `expire` | Prune entries older than `<time>` (default: `gc.reflogExpire`, 90 days) | Reclaim space in old repositories |
| `--expire-unreachable=<time>` | `expire` | Prune unreachable entries older than `<time>` (default: 30 days) | Faster pruning of abandoned work |
| `--rewrite` | `expire`, `delete` | Adjust predecessor SHA-1s after pruning to keep entries internally consistent | Repair scenarios |
| `--updateref` | `expire`, `delete` | Move the ref to `<ref>@{0}` if the previous top entry was pruned | Rare repair scenarios |
| `--stale-fix` | `expire` | Also prune entries pointing at broken (unreachable, object-missing) commits | Repairing corruption from old Git versions |
| `-n` / `--dry-run` | `expire`, `delete` | Show what would be pruned without doing it | Safe preview before destructive runs |
| `--verbose` | `expire`, `delete` | Print each pruned entry | Audit trails |

## Best practices

**Check the reflog before declaring data lost.** Before reaching for a
backup or asking a colleague for their copy, run `git reflog`. If the
commit was ever on your machine, the SHA-1 is there. Only a `git gc` run
after the default 30-day unreachable-entry window will have removed it.

**Use `HEAD@{n}` as a safe target for `git reset`.** When recovering from
a bad rebase or reset, find the pre-operation entry in the reflog and reset
directly to its SHA-1 rather than guessing with `HEAD~n`. The entry
description (`rebase: start`, `reset: moving to ...`) tells you exactly
which operation to undo.

```sh
git reflog
# Find the entry just before the bad operation, e.g. HEAD@{4}
git reset --hard HEAD@{4}
```

**Combine `--date=iso` with `grep` when the list is long.** Time-based
selectors like `HEAD@{2.days.ago}` can be imprecise on machines with
irregular git activity. Displaying ISO timestamps and grepping for a known
time window is more reliable.

```sh
git reflog --date=iso | grep "2026-06-15"
```

**Do not rely on `git reflog` in CI or shared environments.** The reflog is
local-only. Clones start with no reflog at all. Do not write scripts that
assume the reflog is present or complete outside a developer workstation.

**Let `git gc` manage expiry automatically.** You rarely need to run
`git reflog expire` by hand. The defaults — 90 days for reachable entries,
30 days for unreachable ones — strike a sensible balance between safety and
disk usage. Override them with `gc.reflogExpire` and
`gc.reflogExpireUnreachable` in your git config if the defaults do not suit
your workflow.

```sh
git config --global gc.reflogExpire 180.days
git config --global gc.reflogExpireUnreachable 90.days
```

## Pitfalls & gotchas

**The reflog does not exist in a fresh clone.** Cloning downloads objects
and references but not `.git/logs/`. If you clone a repository and
immediately check the reflog, it will be empty or contain only the initial
checkout entry. This catches people who expect to see a remote team
member's history in the reflog.

**`@{n}` counts operations, not commits.** A rebase of ten commits is one
reflog entry for the final HEAD position (plus internal entries during the
rebase). Do not assume `HEAD@{10}` is ten commits back — it is ten HEAD
movements back, which may span a single rebase or a single merge.

**Time-based selectors depend on the local clock.** `HEAD@{1.week.ago}` is
evaluated against your system clock at the moment you run the command. If
your clock was wrong or you changed time zones, the entry you get may not
be what you expect. Verify with `--date=iso` when precision matters.

**Reflog entries are not immutable.** Running `git reflog expire
--expire=all --all` or `git reflog drop --all` permanently removes entries.
After `git gc` runs (automatically or on demand), entries past the expiry
window are gone and the associated loose objects may be garbage-collected.

**Rebasing creates many entries quickly.** An interactive rebase of a
twenty-commit branch can add dozens of entries to the HEAD reflog. If
something went wrong mid-rebase, the entry you need is buried. Use
`--oneline` and grep the description column:

```sh
git reflog --oneline | grep "rebase: start"
```

**`git reflog show` is `git log -g --abbrev-commit --pretty=oneline` under
the hood.** Most `git log` options work, but options that imply a graph
traversal (like `--graph`) produce confusing output because the reflog is a
linear sequence, not a DAG.

## Worked examples

### Recovering commits after a hard reset

You ran `git reset --hard` to a commit several steps back, discarding work
you needed. The branch pointer no longer points at the commits you lost.

```sh
git reflog
```

```text
d9a1c03 (HEAD -> feature/auth) HEAD@{0}: reset: moving to d9a1c03
7f3e812 HEAD@{1}: commit: Add JWT refresh logic
4b2a990 HEAD@{2}: commit: Implement token expiry
d9a1c03 HEAD@{3}: commit: Scaffold auth module
```

The two commits you lost are at `HEAD@{1}` (`7f3e812`) and `HEAD@{2}`
(`4b2a990`). Reset back to the most recent of the lost commits:

```sh
git reset --hard HEAD@{1}
```

Your branch now points at `7f3e812` again — both lost commits restored.

### Recovering a dropped stash

You ran `git stash drop` on the wrong stash entry. The stash reference is
gone but the commit object still exists in the object database.

Find the stash object via the stash reflog:

```sh
git reflog show refs/stash
```

```text
b5c7f21 refs/stash@{0}: WIP on main: 8b4d72a Add rate limiting
a91e034 refs/stash@{1}: WIP on main: f7e2c80 Fix null pointer
```

`refs/stash@{1}` is the dropped entry. Apply its SHA-1 directly:

```sh
git stash apply a91e034
```

Or create a branch from it so you can inspect it first:

```sh
git checkout -b recovered-stash a91e034
```

### Finding when a file was in a known-good state

You know `src/config.js` was correct sometime last week but cannot identify
the commit. Use `--date=iso` to find reflog entries from that period:

```sh
git reflog --date=iso | grep "2026-06-10"
```

```text
c3d44f1 HEAD@{2026-06-10 14:23:11 +0200}: commit: Update DB pool settings
```

Inspect the file at that commit:

```sh
git show c3d44f1:src/config.js
```

If this is the right version, restore it to the working tree:

```sh
git checkout c3d44f1 -- src/config.js
```

### Diagnosing an interrupted rebase

Your rebase was interrupted by conflicts and you are not sure what state
the repository is in. Read the reflog to reconstruct the sequence:

```sh
git reflog -20 --oneline
```

```text
e1a3c55 HEAD@{0}: rebase (pick): Add input validation
9b2f440 HEAD@{1}: rebase (pick): Extract helper functions
3d7c118 HEAD@{2}: rebase: checkout main
8b4d72a HEAD@{3}: rebase: start
```

The entry at `HEAD@{3}` (`8b4d72a`) is where HEAD was before the rebase
began. To abort the rebase cleanly:

```sh
git rebase --abort
```

If rebase state was already cleaned up and `--abort` is not available,
reset directly to the pre-rebase SHA-1:

```sh
git reset --hard 8b4d72a
```

## Recovery

The reflog is itself the primary recovery mechanism for most local
catastrophes. If entries have already been pruned by `git gc`, the objects
may still exist as loose objects in the database for a short window after
expiry — use `git fsck --unreachable` to locate dangling commits before
they are collected.

To reduce the risk of losing reflog coverage before you need it, increase
the expiry windows:

```sh
git config --global gc.reflogExpire 180.days
git config --global gc.reflogExpireUnreachable 90.days
```

There is no way to reverse a completed `git reflog expire` or `git reflog
drop` run. The entries — and any objects they exclusively referenced — are
gone once garbage collection has run.

See *Getting out of jams* for step-by-step undo recipes that use reflog
entries as recovery targets.

## See also

- *reset* — the most common reason to need the reflog; `git reset --hard
  HEAD@{n}` is the canonical recovery pattern.
- *rebase* — interactive rebases generate many reflog entries; know how to
  read them before rebasing large branches.
- *stash* — stash entries have their own reflog at `refs/stash` and can be
  recovered the same way as lost commits.
- *log* — `git reflog show` is built on `git log -g`; all log options
  apply.
- *gc* — controls when reflog entries expire via `gc.reflogExpire` and
  `gc.reflogExpireUnreachable`.
- *Getting out of jams* — the troubleshooting chapter with concrete undo
  recipes anchored on reflog entries.
