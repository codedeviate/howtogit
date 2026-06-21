# rerere

Record a conflict resolution once and replay it automatically every time the
same conflict reappears.

## Mental model

The name stands for "reuse recorded resolution." The idea is simple: the first
time you resolve a merge or rebase conflict, git rerere photographs both sides
of the conflict and the resolution you produced. The next time Git encounters
a conflict whose two sides look identical to a previously photographed pair,
rerere silently patches your working tree with the recorded answer — no manual
work required.

Rerere stores its data in `.git/rr-cache/`. Each conflict gets a directory
named after a hash of the conflict's two sides. Inside that directory Git keeps
the pre-resolution conflict (`preimage`) and, once you resolve and record it,
the post-resolution file (`postimage`).

```text
First encounter                   Future encounter
────────────────────────────────  ──────────────────────────────────────
conflict appears in file          same conflict appears again
  │                                 │
  ▼                                 ▼
rerere records preimage           rerere finds matching preimage
  │                                 │
  ▼                                 ▼
you resolve manually              rerere patches working tree from postimage
  │                                 │
  ▼                                 ▼
rerere records postimage          you confirm with git diff, then git add
```

Rerere is most valuable on long-lived topic branches that are repeatedly
rebased onto a fast-moving base. Without rerere, every rebase step that hits
the same conflict forces a manual re-resolution. With rerere, only the first
resolution is manual; every subsequent one is automatic.

By default, rerere never touches the index on its own — after it applies a
recorded resolution you still need to inspect the result and `git add` the
files. This is intentional: rerere's replay is a three-way merge of the old
preimage, old postimage, and new conflict, and the result deserves a sanity
check before it is staged. (Setting `rerere.autoUpdate = true`, or passing
`--rerere-autoupdate` to merge/rebase, makes rerere stage cleanly-resolved
files into the index automatically.)

## Synopsis

```text
git rerere [clear | forget <pathspec>... | diff | status | remaining | gc]
```

Running `git rerere` with no subcommand is the normal automated path: Git
calls it for you at the right moments (after a failed merge, after a rebase
step, after a commit of a merge result). You rarely need to invoke it manually
except to use one of the diagnostic or maintenance subcommands.

## Everyday usage

### Enable rerere for a repository

Rerere is off by default for new repositories. Turn it on once per repository:

```sh
git config rerere.enabled true
```

To enable it globally for all repositories on the machine:

```sh
git config --global rerere.enabled true
```

### Let rerere work automatically during a merge

With `rerere.enabled true` you do not need to invoke `git rerere` yourself.
Attempt a merge that conflicts:

```sh
git merge feature/payments
# Auto-merging src/checkout.js
# CONFLICT (content): Merge conflict in src/checkout.js
# Automatic merge failed; fix conflicts and then commit the result.
```

Git has already called `git rerere` internally and recorded the preimage. Open
the file, resolve the conflict markers, then commit as normal:

```sh
# edit src/checkout.js — resolve the conflict markers
git add src/checkout.js
git commit
```

Git calls `git rerere` again on commit, recording the postimage. Next time the
same conflict surfaces it will be resolved automatically.

### Check what rerere will record

Before staging anything, see which files rerere considers to have in-flight
conflicts:

```sh
git rerere status
```

```text
src/checkout.js
```

### See what rerere has already applied

After rerere auto-resolves a conflict, verify the result before staging:

```sh
git rerere diff
```

This shows the diff between the recorded preimage and the current working tree
state — useful to confirm rerere applied exactly what you intended the first
time.

### Find conflicts rerere cannot auto-resolve

During a rebase, some conflicts may be untrackable (conflicting submodules, for
example). List them:

```sh
git rerere remaining
```

Files listed here need manual attention even if rerere resolved others.

### Discard a bad recorded resolution

If you resolved a conflict incorrectly the first time, delete the record so
rerere does not repeat the mistake:

```sh
git rerere forget src/checkout.js
```

You can pass multiple paths. After forgetting, resolve the conflict manually
again and the corrected resolution will be recorded in its place.

### Reset all rerere state for an aborted merge

If you decide to abort a merge or rebase entirely:

```sh
git merge --abort
# or
git rebase --abort
```

`git rebase [--skip|--abort]` (and `git am [--skip|--abort]`) call `git rerere clear` automatically,
discarding in-progress rerere metadata for the abandoned operation. You can also
call it directly:

```sh
git rerere clear
```

### Prune stale records

Records accumulate in `.git/rr-cache/` over time. Clean up old ones:

```sh
git rerere gc
```

By default, unresolved conflicts older than 15 days and resolved conflicts
older than 60 days are pruned.

## Key options

| Subcommand | What it does | When to use it |
|---|---|---|
| *(none)* | Record or replay a conflict resolution | Called automatically; rarely needed by hand |
| `clear` | Discard rerere state for the current in-progress operation | Aborting a merge or rebase manually |
| `forget <pathspec>` | Delete recorded resolutions for specific files | A previous resolution was wrong |
| `diff` | Show diff between recorded preimage and current working tree | Verify what rerere applied |
| `status` | Print files with conflicts rerere will record | Audit what is in flight |
| `remaining` | Print files rerere cannot auto-resolve | Find conflicts still needing manual work |
| `gc` | Prune old records from `.git/rr-cache/` | Periodic housekeeping |

Configuration variables that control rerere behavior:

| Variable | Default | Effect |
|---|---|---|
| `rerere.enabled` | `false (auto-enabled if .git/rr-cache exists)` | Must be `true` to activate rerere in a new repository |
| `rerere.autoUpdate` | `false` | When `true`, rerere updates the index with the resolved contents after a clean replay |
| `gc.rerereUnresolved` | 15 days | Age at which unresolved records are pruned by `gc` |
| `gc.rerereResolved` | 60 days | Age at which resolved records are pruned by `gc` |

## Best practices

**Enable rerere globally.** There is no downside to having rerere active in
every repository. Set `rerere.enabled = true` in your global config and forget
about it. The `.git/rr-cache/` overhead is negligible.

**Always inspect with `git rerere diff` before staging.** Rerere's replay is a
three-way merge. If the surrounding code has changed significantly since the
original resolution, the result may be subtly wrong. Use `git rerere diff` and
`git diff` together to gain confidence before running `git add`.

**Use `git rerere forget` promptly when you spot a bad resolution.** If a
recorded resolution is incorrect, remove it immediately. Left in place it will
silently replicate the same mistake on every future rebase step or re-merge —
potentially producing code that compiles and passes tests but behaves
incorrectly.

**Pair rerere with a rebase-based workflow.** Rerere pays dividends when you
keep topic branches current by rebasing onto `main` frequently. The first
rebase step forces a manual resolution; every subsequent rebase step that
replays the same commit through the same changed lines is handled automatically.
Without rerere that cost is paid every time. See the *rebase* chapter for the
broader workflow.

**Run `git rerere gc` as a scheduled maintenance step.** In repositories with
heavy branching activity the rr-cache can grow to hundreds of entries. Wiring
`git rerere gc` into a periodic CI job or `git maintenance` keeps it lean. See
the *gc* and *maintenance* chapters for integration points.

## Pitfalls & gotchas

**Rerere is disabled by default in new repositories.** The most common reason rerere "doesn't work"
is that `rerere.enabled` was never set (Git auto-enables it in repos where it was previously used,
i.e. where `.git/rr-cache/` already exists, but you must set it explicitly in a fresh repository).
Confirm it is active:

```sh
git config rerere.enabled
# should print: true
```

**By default, rerere never stages files.** After rerere resolves a conflict
automatically, the working tree file is updated but the index is not. You must
run `git add <file>` yourself. Forgetting this leaves you with a resolved
working tree that Git still considers conflicted, and the next `git status`
will still show the file under "Unmerged paths". (If you set
`rerere.autoUpdate = true` or pass `--rerere-autoupdate` to `git merge` or
`git rebase`, rerere will update the index automatically after a clean replay.)

**A changed context can silently produce a wrong result.** Rerere performs a
three-way merge between the original preimage, the original postimage, and the
new conflict. If the lines surrounding the conflict have changed substantially
since the first resolution, the three-way merge may succeed while producing
semantically broken code. Always verify the output with `git rerere diff`.

**Rerere cannot track all conflict types.** Conflicting submodule pointers,
conflicting file modes, and certain binary conflicts cannot be recorded.
`git rerere remaining` lists these so you know they need manual attention.

**`git rerere clear` discards in-flight state, not stored resolutions.** If
you call `git rerere clear` hoping to erase a bad recorded resolution, nothing
changes in `.git/rr-cache/`. Use `git rerere forget <pathspec>` to delete a
stored resolution. `clear` only discards the metadata for an operation that is
currently in progress.

**Conflict marker size mismatches prevent recording.** If a file uses a
non-standard conflict marker size (set via `.gitattributes`) and
`conflict-marker-size` is not configured consistently, rerere may fail to
detect the conflict markers and will silently skip recording.

## Worked examples

### Long-lived feature branch rebased repeatedly onto main

Your team lands several commits to `main` each week. You maintain
`feature/checkout-v2`, which touches `src/checkout.js` in the same region that
`main` also modifies. You need to stay current.

Enable rerere first (if not already done globally):

```sh
git config rerere.enabled true
```

Rebase onto `main` for the first time:

```sh
git switch feature/checkout-v2
git rebase main
# CONFLICT (content): Merge conflict in src/checkout.js
# error: could not apply a1b2c3d... Refactor checkout flow
```

Rerere has recorded the preimage. Resolve the conflict manually:

```sh
# open src/checkout.js, fix the conflict markers
git add src/checkout.js
git rebase --continue
```

Rerere records the postimage. A week later, rebase again after more commits
have landed on `main`:

```sh
git rebase main
# CONFLICT (content): Merge conflict in src/checkout.js
# Resolved 'src/checkout.js' using previous resolution.
```

Rerere has replayed the resolution. Verify it looks correct before accepting:

```sh
git rerere diff     # confirm the applied patch is sensible
git diff            # review the full working tree state
git add src/checkout.js
git rebase --continue
```

No manual conflict resolution needed on the second (or third, or fourth)
rebase.

### Identifying and correcting a bad recorded resolution

During code review your colleague spots that the auto-resolved `src/pricing.js`
has a duplicated function body — rerere applied an earlier resolution that was
itself incorrect.

Forget the bad record for that file:

```sh
git rerere forget src/pricing.js
```

Abort the current rebase so you can redo the conflicting step cleanly:

```sh
git rebase --abort
git rebase main
# CONFLICT (content): Merge conflict in src/pricing.js
```

This time rerere has no stored answer for this conflict. Resolve it correctly:

```sh
# edit src/pricing.js carefully
git rerere diff     # double-check the working tree matches your intent
git add src/pricing.js
git rebase --continue
```

Rerere records the corrected postimage. Future rebases will use the right
resolution.

### Auditing rerere state during an ongoing rebase

A rebase across many commits is in progress and you want to know which files
rerere has handled and which still need work.

Files rerere will record (in-flight conflicts):

```sh
git rerere status
```

```text
src/api/auth.js
src/api/payments.js
```

Files rerere cannot auto-resolve:

```sh
git rerere remaining
```

```text
vendor/stripe
```

The submodule `vendor/stripe` needs a manual resolution; the two `.js` files
are handled automatically. Fix the submodule pointer, stage everything, then
continue:

```sh
# update vendor/stripe to the correct commit
git add vendor/stripe src/api/auth.js src/api/payments.js
git rebase --continue
```

## Recovery

If rerere has applied a resolution that leaves the repository in a bad state,
abort the current operation and forget the offending record:

```sh
git rebase --abort          # or: git merge --abort
git rerere forget src/bad-file.js
```

Then restart the merge or rebase. This time rerere has no stored answer for
that file and will stop for manual resolution.

If you want to discard all rr-cache entries and start fresh (rarely needed):

```sh
rm -rf .git/rr-cache
```

This is safe: rerere records are derived data. Repository history and your
working tree are unaffected. You simply lose the accumulated resolution
shortcuts and will need to re-resolve conflicts manually until new records
build up again.

See *Getting out of jams* for broader undo recipes, including recovering from
aborted merges and rebases.

## See also

- *merge* — the primary operation where rerere saves repeated conflict work.
- *rebase* — rerere is especially valuable when rebasing long-lived branches
  frequently onto a moving base.
- *mergetool* — launch a GUI diff tool to resolve conflict markers by hand
  instead of editing them in a text editor.
- *gc* — `git gc` triggers `git rerere gc` as part of routine repository
  housekeeping.
- *maintenance* — schedule periodic gc runs to keep rr-cache lean over time.
