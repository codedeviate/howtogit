# fsck

Verify the integrity and connectivity of every object in the repository's
object database.

## Mental model

Git stores everything — commits, trees, blobs, tags — as content-addressed
objects: the file name is the SHA-1 hash of the content. That design means a
single bit-flip produces a detectable mismatch: the stored hash no longer
matches the actual content.

`git fsck` exploits this property in two passes:

1. **Validity pass.** For each object it reads, fsck recomputes the hash and
   checks the internal structure (valid author line, parseable tree entries,
   well-formed tag, etc.). A mismatch or a malformed structure is reported as
   corruption.

2. **Connectivity pass.** Starting from every known root — branch tips, tags,
   the index, and reflogs — fsck walks the object graph and flags any object
   that is referenced but absent (*missing*), or any object that is present
   but reachable from nowhere (*dangling* or *unreachable*).

```text
refs/heads/*, tags/*, index, reflogs
          │
          └─── walk object graph ───> flag missing objects
                                       flag dangling/unreachable objects
                                       verify hash of every object visited
```

Dangling objects are not corruption. They are the normal residue of deleted
branches, amended commits, reset heads, and rebases. Git's garbage collector
(`git gc`) eventually prunes them, but only after the configured grace period.
fsck surfaces them so you can inspect or recover them before they disappear.

## Synopsis

```text
git fsck [--tags] [--root] [--unreachable] [--cache] [--no-reflogs]
         [--[no-]full] [--strict] [--verbose] [--lost-found]
         [--[no-]dangling] [--[no-]progress] [--connectivity-only]
         [--[no-]name-objects] [--[no-]references] [<object>...]
```

## Everyday usage

Run a full integrity check (the default — checks all refs, the index, and
reflogs):

```sh
git fsck
```

Show every unreachable object along with dangling ones — useful when hunting
for a dropped commit:

```sh
git fsck --unreachable
```

List dangling objects with human-readable names that describe how each object
was referenced:

```sh
git fsck --dangling --name-objects
```

Write dangling blobs and commits to `.git/lost-found/` so you can inspect
their content:

```sh
git fsck --lost-found
ls .git/lost-found/commit/    # each filename is a dangling commit SHA-1
ls .git/lost-found/other/     # dangling blobs and trees
```

Suppress dangling-object noise when you only care about hard errors:

```sh
git fsck --no-dangling
```

Skip the reflog scan (finds commits that used to be in a branch but were later
removed and are no longer referenced by any current ref):

```sh
git fsck --no-reflogs
```

## Key options

| Option | What it does | When to use it |
|---|---|---|
| `--unreachable` | Print objects that exist but are not reachable from any ref | Audit leftover objects after branch deletions |
| `--[no-]dangling` | Print or suppress objects present but never directly used (default: on) | Suppress noise when hunting only hard errors |
| `--lost-found` | Write dangling objects to `.git/lost-found/` | Recover content from dropped commits or stashes |
| `--name-objects` | Include a rev-parse-compatible name alongside each SHA-1 | Make unreachable output human-readable |
| `--connectivity-only` | Check only that referenced objects exist; skip deep content validation | Faster check on large repos; will miss blob corruption |
| `--no-full` | Restrict check to loose objects in the main object directory only | Limit the check to loose objects in `$GIT_DIR/objects`; skips the main repo's pack files (`$GIT_DIR/objects/pack`) and alternate object pools |
| `--strict` | Catch file modes with the group-write bit set, created by old Git versions | New projects; avoid on established repos with legacy objects |
| `--no-reflogs` | Exclude reflogs from the set of reachability roots | Find commits that have fallen out of all current refs even if still referenced by a reflog |
| `--root` | Report root commit nodes | Auditing repos that should have exactly one root |
| `--tags` | Report tag objects | Auditing tag integrity |
| `--cache` | Treat index entries as additional reachability roots | Include staged-but-uncommitted objects in the walk |
| `--verbose` | Print every object examined | Diagnosing where in the object graph a walk stalls |
| `--[no-]progress` | Force or suppress the progress indicator on stderr | Use `--no-progress` in scripts; `--progress` in TTY-less CI |
| `--[no-]references` | Control whether to verify the refs database via `git refs verify` (default: on) | Disable when only checking object integrity, not ref consistency |

## Best practices

**Run `git fsck` before and after risky operations on critical repositories.**
Before a destructive rebase or a `filter-repo` run, a clean fsck output
confirms the starting state is sound. After the operation, a second run
confirms nothing was corrupted in transit.

**Pipe output through `grep` to separate signal from noise.** A healthy repo
will report dozens of dangling objects — normal residue from everyday work.
Restrict attention to hard problems:

```sh
git fsck 2>&1 | grep -v "^dangling"
```

**Use `--lost-found` as the first recovery step, not a last resort.** When
you realize a stash drop, a reset, or a force-push discarded work, run
`--lost-found` immediately — before `git gc` runs and permanently removes the
objects. The default grace period is two weeks, but shared server
configurations may be shorter.

**Automate a periodic fsck on bare server repositories.** Disk errors and
filesystem bugs are silent until they compound. A weekly cron job running
`git fsck --no-dangling` on every bare clone provides an early-warning system
that catches corruption before it spreads to every developer's clone.

**Prefer `fsck.skipList` over silencing entire message classes.** If a legacy
repository has a handful of known-bad objects that pre-date your ownership,
list their SHA-1s in `fsck.skipList` rather than setting
`fsck.<msg-id> = ignore`. The skip list is surgical; a message-class ignore
hides all future instances of that problem class silently.

## Pitfalls & gotchas

**Dangling objects are normal — do not panic.** Every `git commit --amend`,
`git rebase`, `git reset`, and dropped stash leaves dangling objects. A long
list of `dangling commit` lines does not indicate corruption; it means Git's
safety net is doing its job. Focus on `missing` and `hash mismatch` lines.

**`--connectivity-only` misses blob corruption.** The fast path verifies that
referenced blobs exist but does not read and re-hash their contents. A silently
bit-flipped blob will pass `--connectivity-only` and fail a full scan. Use the
full scan for integrity audits; reserve `--connectivity-only` for quick
reachability checks on very large repositories.

**fsck cannot repair what it finds.** When fsck reports a missing or corrupt
object, the only remedy is to restore the object from a backup, a remote
clone, or another replica. The object database has no built-in redundancy: one
corrupt loose file or one flipped bit in a pack file is unrecoverable from the
local repo alone.

**Reflogs extend reachability — `--no-reflogs` changes what "dangling" means.**
With reflogs active (the default), a commit that was `HEAD` two weeks ago is
still reachable and will not be reported as dangling. Pass `--no-reflogs` when
you specifically want to find commits that are no longer in any reflog —
useful for auditing what `git gc --prune=now` would remove.

**`--strict` produces false positives on established repositories.** The
group-write file-mode check targets modes created by very old Git versions.
Running `--strict` on repositories such as the Linux kernel or Git itself
produces a flood of warnings about objects that are not actually harmful. Use
`--strict` only on repositories created with a recent Git version.

**A `hash mismatch` is a hardware or filesystem problem, not a Git bug.**
SHA-1 hash mismatches almost always trace to disk corruption, a failing drive,
a bad RAM stick, or a misbehaving network filesystem. Fix the underlying
hardware issue before attempting recovery; otherwise replacement objects may
also corrupt.

## Worked examples

### Recovering a dropped stash

You ran `git stash drop` on the wrong entry. The commit is gone from
`git stash list` but is still a dangling object inside the object database.

Write all dangling objects to `.git/lost-found/`:

```sh
git fsck --lost-found
```

```text
Checking object directories: 100% (256/256), done.
dangling commit 7f3a1b2c...
dangling commit d4e9f012...
```

Inspect each dangling commit to find the stash:

```sh
for sha in $(ls .git/lost-found/commit/); do
  echo "=== $sha ==="
  git log -1 --oneline "$sha"
done
```

Once you identify the correct SHA-1, apply the stash content or branch from
it:

```sh
# Apply the changes directly
git stash apply d4e9f012

# Or create a branch to review the diff first
git checkout -b recovered-stash d4e9f012
```

### Diagnosing a suspected corrupt repository

A colleague reports that `git log` occasionally exits with a "bad object"
error on the shared bare repository. Run a full check, suppressing
dangling-object noise:

```sh
git fsck --no-dangling 2>&1
```

```text
Checking object directories: 100% (256/256), done.
Checking connectivity: done.
missing blob a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
```

A `missing blob` means a file's content is referenced by a tree but the
object is absent. Identify which path points to the missing object:

```sh
git ls-tree -r --full-tree HEAD | grep a1b2c3d4
```

```text
100644 blob a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2	src/payment/retry.js
```

Restore the object from a healthy clone:

```sh
# On the healthy clone — extract the blob
git cat-file blob a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 > /tmp/retry.js

# Back on the corrupt repo — re-inject the object
git hash-object -w /tmp/retry.js
```

Confirm the fix with another fsck run:

```sh
git fsck --no-dangling
# Checking object directories: 100% (256/256), done.
# Checking connectivity: done.
```

### Finding orphaned commits after a force-push

A collaborator force-pushed and overwrote three commits on `main`. The commits
are gone from the branch but may still exist as dangling objects.

Run fsck without reflogs to list objects that are truly unreachable (not just
reflog-only reachable):

```sh
git fsck --unreachable --no-reflogs 2>&1 | grep "^unreachable commit"
```

```text
unreachable commit 9c3f1a2b...
unreachable commit 5d7e8f90...
unreachable commit 1a2b3c4d...
```

Inspect the chain to confirm these are the lost commits:

```sh
git log --oneline 9c3f1a2b
```

```text
9c3f1a2b Add payment gateway retry logic
5d7e8f90 Wire up retry config to environment
1a2b3c4d Add integration test for payment retries
```

Restore the work as a branch:

```sh
git branch recovered-payment-retries 9c3f1a2b
git push origin recovered-payment-retries
```

## Recovery

`git fsck` is strictly read-only — it never modifies the repository. There is
nothing to undo after running it.

If fsck reports **dangling objects** you want to keep, act before `git gc`
removes them. Use `--lost-found` to extract them, then create a branch or
re-apply them as a stash:

```sh
git fsck --lost-found
git checkout -b rescue-branch <dangling-commit-sha>
```

If fsck reports **missing or corrupt objects**, recovery requires an external
source — a remote clone, a backup, or a bundle. See *Getting out of jams* for
step-by-step recipes covering how to rehydrate a corrupt repository from a
remote and how to recover individual objects from a bundle.

## See also

- *Getting out of jams* — step-by-step recovery for corrupt repositories and
  lost commits.
- *stash* — `--lost-found` is the primary recovery tool when a stash entry is
  accidentally dropped.
- *reflog* — the first place to look for lost commits before reaching for
  fsck; reflogs cover the common cases faster and without filesystem
  side-effects.
- *gc* — the garbage collector that eventually prunes the dangling objects fsck
  surfaces; understand the grace-period settings before running
  `gc --prune=now`.
- *rebase* — heavy rebases leave many dangling objects; knowing that helps
  interpret fsck output after a rebase session.
- *bundle* — a portable object archive that can supply missing objects to a
  corrupt repository.
