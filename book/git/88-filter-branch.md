# filter-branch

Rewrite every commit in a branch by applying shell-based filters to the tree,
environment, message, parents, or commit object itself.

## Mental model

Every commit in a Git repository is immutable — its SHA-1 hash is derived from
its content, its parent hashes, and its metadata. When you need to change
something that appears in many commits (a leaked password, a wrong email
address, a file that was never supposed to be tracked), you cannot edit commits
in place. You must create a parallel chain of new commits with the undesired
content removed or corrected.

`git filter-branch` does this by walking a set of commits in topological order
and, for each one, running one or more shell commands — the *filters* — that
transform the commit. The output of each filter becomes the input for the next.
When all filters have run, `git filter-branch` calls `git commit-tree` to
assemble a new commit object from the transformed pieces. The branch pointer is
then advanced to the last rewritten commit.

```text
Original history:   A -- B -- C -- D  (branch HEAD)
                                         |
                    filters run on every commit
                                         |
Rewritten history:  A'-- B'-- C'-- D' (branch HEAD, new SHAs)

Original saved at:  refs/original/refs/heads/<branch>
```

The original commits are not deleted immediately — they are backed up under
`refs/original/`. They remain in the object database until garbage collection
removes them, giving you a safety net.

**A critical caveat before you start:** Git's own documentation marks
`filter-branch` as deprecated and strongly recommends `git filter-repo` for new
work. `filter-branch` is architecturally slow (it shells out for every commit),
prone to silent data corruption with non-ASCII filenames or BSD/GNU userland
differences, and leaves many traps for the unwary. This chapter documents
`filter-branch` accurately because it remains widely available and because
existing scripts depend on it — but treat it as a last resort. For any
non-trivial rewrite, evaluate `git filter-repo` first.

## Synopsis

```text
git filter-branch [--setup <command>]
                  [--subdirectory-filter <directory>]
                  [--env-filter <command>]
                  [--tree-filter <command>]
                  [--index-filter <command>]
                  [--parent-filter <command>]
                  [--msg-filter <command>]
                  [--commit-filter <command>]
                  [--tag-name-filter <command>]
                  [--prune-empty]
                  [--original <namespace>]
                  [-d <directory>]
                  [-f | --force]
                  [--state-branch <branch>]
                  [--] [<rev-list-options>...]
```

Filters are applied in the order they appear in the synopsis — `--env-filter`
before `--tree-filter` before `--index-filter`, and so on. Multiple filters can
be combined in one invocation.

## Everyday usage

Remove a file from every commit on the current branch (fast, index-only):

```sh
git filter-branch --index-filter \
    'git rm --cached --ignore-unmatch secrets.env' \
    --prune-empty -- --all
```

Fix a wrong email address across all commits:

```sh
git filter-branch --env-filter '
    if [ "$GIT_AUTHOR_EMAIL" = "old@example.com" ]; then
        GIT_AUTHOR_EMAIL="correct@example.com"
        GIT_AUTHOR_NAME="Correct Name"
    fi
    if [ "$GIT_COMMITTER_EMAIL" = "old@example.com" ]; then
        GIT_COMMITTER_EMAIL="correct@example.com"
        GIT_COMMITTER_NAME="Correct Name"
    fi
' -- --all
```

Extract a subdirectory and make it the new repository root:

```sh
git filter-branch --subdirectory-filter lib/mypackage -- --all
```

Update tags to point to the rewritten commits (append to any invocation that
rewrites commits referenced by tags):

```sh
git filter-branch --tag-name-filter cat -- --all
```

## Key options

| Option | What it does | When to use it |
|---|---|---|
| `--env-filter <cmd>` | Runs `<cmd>` before creating each commit; set or modify `GIT_AUTHOR_*` / `GIT_COMMITTER_*` variables | Fix wrong author name, email, or timestamps |
| `--tree-filter <cmd>` | Checks out each commit's tree into a temporary directory, runs `<cmd>` with that directory as cwd, then re-indexes everything | Modify or delete files when you need full working-tree access; very slow |
| `--index-filter <cmd>` | Like `--tree-filter` but operates on the index directly without checking out files | Remove or rename tracked files; significantly faster than `--tree-filter` |
| `--msg-filter <cmd>` | Reads the original commit message on stdin; writes the new message on stdout | Strip SVN IDs, add trailers, reformat messages |
| `--commit-filter <cmd>` | Replaces the `git commit-tree` call; receives the tree SHA and parent flags as arguments, must print the new commit SHA | Skip commits entirely; apply per-commit logic; use `skip_commit "$@"` to drop a commit |
| `--parent-filter <cmd>` | Receives the parent string on stdin, writes the new parent string on stdout | Graft histories; add or remove parents |
| `--tag-name-filter <cmd>` | Called for every tag pointing to a rewritten object; original tag name on stdin, new name on stdout | Keep tags in sync after a rewrite; `--tag-name-filter cat` passes names through unchanged |
| `--subdirectory-filter <dir>` | Rewrites history to use `<dir>` as the project root, discarding all other paths | Split a subdirectory into its own repository |
| `--prune-empty` | Drops commits that become empty (identical tree to parent) after filtering | Avoid cluttering history with no-op commits; cannot be combined with `--commit-filter` |
| `--setup <cmd>` | Runs `<cmd>` once before the loop; defines shell functions or variables shared by other filters | Factor out common logic used by multiple filters |
| `--original <namespace>` | Override the backup location for original refs (default: `refs/original`) | Avoid collisions when running filter-branch more than once |
| `-d <directory>` | Use a custom temporary directory for tree checkout (e.g. a tmpfs path) | Speed up `--tree-filter` on large repositories |
| `-f`, `--force` | Allow running even if `refs/original/` already exists or the temporary directory is present | Re-run after a failed or aborted rewrite |
| `--state-branch <branch>` | Load and save the old-to-new SHA mapping to a named branch | Incremental rewrites of very large repositories |

## Best practices

**Always work on a fresh clone.** Before running any `filter-branch` command,
clone the repository to a throwaway directory:

```sh
git clone --no-local /path/to/repo /tmp/repo-rewrite
cd /tmp/repo-rewrite
```

`--no-local` forces Git to copy objects over the transport layer rather than
hard-linking them, so the rewrite directory is fully independent. (A
`file://` URL achieves the same effect without the flag.) If anything goes
wrong you still have the original.

**Rewrite all refs together.** Passing `-- --all` rewrites every branch and
tag. Rewriting only one branch while leaving others untouched is the leading
cause of old-and-new history becoming intertwined. Pass `--tag-name-filter cat`
at the same time to keep annotated tags attached to the correct commits.

**Use `--index-filter` instead of `--tree-filter` whenever possible.**
`--tree-filter` checks out the entire working tree for every commit. On a
repository with 50 000 files and 10 000 commits, that is five hundred million
file operations. `--index-filter` manipulates the index directly and is orders
of magnitude faster.

**Add `--ignore-unmatch` when removing files.** The file you are removing will
not be present in every commit. Without `--ignore-unmatch`, `git rm --cached`
returns a non-zero exit status for commits where the file does not exist, and
`filter-branch` aborts.

```sh
git rm --cached --ignore-unmatch path/to/secret.key
```

**Verify before distributing.** After the rewrite, confirm the sensitive
content is gone:

```sh
git log --all --full-history -- path/to/secret.key
git grep 'password123' $(git rev-list --all)
```

**Shrink the repository after removing large files.** Filtering does not
immediately reclaim disk space — the old objects remain until garbage
collected. After confirming the rewrite is correct:

```sh
# Remove the backup refs left by filter-branch
git for-each-ref --format="%(refname)" refs/original/ \
    | xargs -n 1 git update-ref -d

# Expire reflogs
git reflog expire --expire=now --all

# Collect garbage
git gc --prune=now
```

Or clone the result to a clean repository:

```sh
git clone file:///tmp/repo-rewrite /path/to/clean-repo
```

## Pitfalls & gotchas

**Only the filtered branches are rewritten.** If you pass `HEAD` instead of
`-- --all`, only the current branch gets new SHAs. Other branches still point
to the old commits. When team members fetch and merge, old and new history will
be merged back together, restoring whatever you tried to remove.

**`--subdirectory-filter` does not automatically rewrite all branches.**
Pass `-- --all` explicitly to rewrite every branch, not just the current one.

**Tags are not automatically updated.** Running filter-branch without
`--tag-name-filter` leaves existing tags pointing to original (unfiltered)
commit objects. The sensitive content remains reachable. Always include
`--tag-name-filter cat` when the goal is to truly remove something.

**Annotated tag signatures are stripped unconditionally.** Any GPG-signed tag
that points to a rewritten commit will have its signature removed. There is no
way to preserve signatures through a rewrite. Notify key maintainers so they
can re-sign after the rewrite.

**`--commit-filter` and `--prune-empty` are mutually exclusive.** If you need
to drop empty commits while using a commit filter, use the built-in helper
`git_commit_non_empty_tree "$@"` inside the filter instead:

```sh
git filter-branch --commit-filter '
    git_commit_non_empty_tree "$@"
' HEAD
```

**Shell portability bites silently on macOS.** The `sed`, `xargs`, and `date`
commands differ between BSD (macOS) and GNU (Linux). A filter that works on
Linux may silently produce wrong output on macOS, or vice versa. Test on the
same OS where the rewrite will run, and prefer POSIX-portable constructs.

**Filenames with spaces or non-ASCII characters break naive filters.** Shell
pipelines like `git ls-files | grep ... | xargs git rm` will mishandle
filenames containing spaces or characters that the shell quotes. Use `-z` / `-0`
flags throughout:

```sh
git ls-files -z | grep -z pattern | xargs -0 git rm --cached
```

**`refs/original/` is not a true backup.** The backup dereferences annotated
tags to their underlying commits. If you restore from `refs/original/` and
re-run filter-branch, you will lose the annotated tag objects. Keep an
out-of-band backup (a bundle or a separate clone) before any rewrite.

**Commit messages are not updated.** If commit messages reference other commit
SHAs, those references will point to non-existent (old) objects after the
rewrite. Use `--msg-filter` with a sed replacement if you need to update
cross-references.

**Performance is genuinely terrible.** A repository with tens of thousands of
commits and files can take hours. If the run is interrupted, use `--force` to
restart (after verifying the partial state is safe). For large repositories,
point `-d` at a RAM-backed filesystem to reduce I/O:

```sh
# Linux
git filter-branch -d /dev/shm/git-rewrite --index-filter '...' -- --all

# macOS: create a RAM disk first
diskutil erasevolume HFS+ RAMDisk $(hdiutil attach -nomount ram://2097152)
git filter-branch -d /Volumes/RAMDisk/rewrite --index-filter '...' -- --all
```

## Worked examples

### Remove a committed secret from all history

A credential file `config/database.yml` was committed six months ago and has
propagated through dozens of commits. It must be completely expunged.

```sh
# Work in a fresh clone
git clone file:///path/to/original /tmp/scrub && cd /tmp/scrub

# Remove the file from every commit on every branch and tag
git filter-branch --force --index-filter \
    'git rm --cached --ignore-unmatch config/database.yml' \
    --prune-empty --tag-name-filter cat -- --all
```

Verify the file is gone from all reachable history:

```sh
git log --all --full-history -- config/database.yml
# should produce no output
```

Clean up backup refs and reclaim disk space:

```sh
git for-each-ref --format="%(refname)" refs/original/ \
    | xargs -n 1 git update-ref -d
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

Force-push all branches and tags to the remote (coordinate with your team
first — everyone must re-clone or rebase):

```sh
git push origin --force --all
git push origin --force --tags
```

Rotate the leaked credential immediately. Removing it from Git history does
not invalidate any key or password that was already exposed.

### Extract a subdirectory into a standalone repository

A monorepo contains `packages/logging/` which has grown large enough to
deserve its own repository.

```sh
git clone file:///path/to/monorepo /tmp/logging-extract && cd /tmp/logging-extract

# Rewrite all branches so that packages/logging/ becomes the root
git filter-branch --subdirectory-filter packages/logging -- --all
```

The result has all the commit history that touched `packages/logging/`, with
paths relative to that directory. Commits that never touched `packages/logging/`
are pruned automatically by `--subdirectory-filter`.

Push to a new remote:

```sh
git remote set-url origin git@github.com:org/logging.git
git push --all
git push --tags
```

### Fix a wrong author email across the entire repository

An early contributor committed under `dev@localhost` instead of their real
address. All commits, branches, and tags must be corrected.

```sh
git clone file:///path/to/repo /tmp/email-fix && cd /tmp/email-fix

git filter-branch --env-filter '
    OLD_EMAIL="dev@localhost"
    CORRECT_NAME="Alice Smith"
    CORRECT_EMAIL="alice@example.com"

    if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]; then
        GIT_AUTHOR_NAME="$CORRECT_NAME"
        GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
        export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL
    fi
    if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]; then
        GIT_COMMITTER_NAME="$CORRECT_NAME"
        GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
        export GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
    fi
' --tag-name-filter cat -- --all
```

Confirm the change:

```sh
git log --all --format="%ae %ce" | sort -u
# dev@localhost should no longer appear
```

## Recovery

If the rewrite produced wrong results, the originals are saved under
`refs/original/`:

```sh
# List what was saved
git for-each-ref refs/original/

# Restore a branch (e.g. main)
git checkout -B main refs/original/refs/heads/main

# Once confident the originals are no longer needed, delete the backups
git for-each-ref --format="%(refname)" refs/original/ \
    | xargs -n 1 git update-ref -d
```

If you already deleted `refs/original/` but have not yet garbage-collected,
the original commit objects may still be in the object database. Check
`git reflog` and the `ORIG_HEAD` ref:

```sh
git reflog show HEAD
```

For a complete guide to recovering from a botched history rewrite, see
*Getting out of jams*.

## See also

- *replace* — lightweight history grafting without rewriting all SHAs; a
  non-destructive alternative for many use cases.
- *rebase* — the right tool for dropping or editing a small number of recent
  commits interactively; see the *rebase* chapter for `--interactive` and
  `--autosquash` workflows.
- *reflog* — finding original commit SHAs after a rewrite goes wrong.
- *gc* — reclaiming disk space after backup refs are removed.
- *Getting out of jams* — recovering from a rewrite that corrupted history.
