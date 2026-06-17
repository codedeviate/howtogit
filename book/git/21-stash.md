# stash

Shelve uncommitted changes so you can switch context, then restore them later.

## Mental model

Git requires a clean working tree for many operations — switching branches,
pulling upstream changes, applying a patch. `git stash` solves this without
forcing you to make a half-baked commit.

Under the hood, a stash entry is two commit objects stored outside normal
branch history:

```text
       .----W   (working tree state)
      /    /
-----H----I     (index / staging area state)
```

`H` is the HEAD commit at the time you stash. `I` captures the index. `W`
captures the working tree. The latest stash is referenced by `refs/stash`;
older entries live in its reflog and are addressed as `stash@{0}` (most
recent), `stash@{1}`, `stash@{2}`, and so on. The integer shorthand also
works: `2` is equivalent to `stash@{2}`.

Running `git stash` with no arguments is identical to `git stash push`. The
working tree and index are restored to HEAD, and your changes wait in the
stash stack until you `pop` or `apply` them.

## Synopsis

```text
git stash push [-p | --patch] [-S | --staged] [-k | --[no-]keep-index]
               [-u | --include-untracked] [-a | --all] [-q | --quiet]
               [(-m | --message) <message>] [--] [<pathspec>...]
git stash list [<log-options>]
git stash show [-u | --include-untracked | --only-untracked] [<diff-options>] [<stash>]
git stash pop  [--index] [-q | --quiet] [<stash>]
git stash apply [--index] [-q | --quiet] [<stash>]
git stash drop [-q | --quiet] [<stash>]
git stash branch <branchname> [<stash>]
git stash clear
git stash create [<message>]
git stash store [(-m | --message) <message>] [-q | --quiet] <commit>
git stash export (--print | --to-ref <ref>) [<stash>...]
git stash import <commit>
```

## Everyday usage

Save all tracked modifications and index changes, then return to a clean tree:

```sh
git stash
# shorthand for: git stash push
```

Give the stash a descriptive message so you can identify it later:

```sh
git stash push -m "half-finished login refactor"
```

List all stash entries:

```sh
git stash list
```

```text
stash@{0}: On main: half-finished login refactor
stash@{1}: WIP on feature/checkout: a3f9c12 Add cart total
```

See what a stash contains before restoring it:

```sh
git stash show -p stash@{1}
```

Restore the most recent stash and remove it from the stack:

```sh
git stash pop
```

Restore a specific stash without removing it from the stack:

```sh
git stash apply stash@{1}
```

Stash only the changes that are already staged:

```sh
git stash push --staged -m "unrelated hotfix staged for later"
```

Stash everything including untracked files:

```sh
git stash push --include-untracked -m "spike with new dependencies"
```

Delete a stash entry you no longer need:

```sh
git stash drop stash@{0}
```

Wipe the entire stash stack:

```sh
git stash clear
```

## Key options

| Option | Applies to | What it does | When to use it |
|--------|------------|--------------|----------------|
| `-m <msg>` / `--message <msg>` | `push` | Label the stash entry | Any time; makes `list` readable |
| `-u` / `--include-untracked` | `push`, `show` | Include untracked files in the stash and clean them up | New files not yet added to the index |
| `--only-untracked` | `show` | Show only untracked files in the stash diff | Inspecting which new files were stashed |
| `-a` / `--all` | `push` | Include untracked and ignored files | Temporarily clearing build artefacts |
| `-k` / `--keep-index` | `push` | Leave already-staged changes intact; stash only unstaged changes | Test staged changes in isolation before committing |
| `--no-keep-index` | `push` | Override the implicit `--keep-index` set by `--patch` | Stash everything including what is staged |
| `-p` / `--patch` | `push` | Interactively choose hunks to stash | Stash only part of a file's changes |
| `-S` / `--staged` | `push` | Stash only staged changes | Park staged-but-not-yet-committed work for later |
| `--index` | `pop`, `apply` | Restore the index state in addition to the working tree | When staging state matters, e.g. after `git add -p` |
| `-q` / `--quiet` | most subcommands | Suppress informational messages | Scripts and aliases |
| `--print` | `export` | Print exported commit chain to stdout without storing it | Transferring stashes between machines via scripts |
| `--to-ref <ref>` | `export` | Store the exported commit chain at a named ref | Sharing stashes via push/fetch |

## Best practices

**Always give stashes a message.** The default label "WIP on branchname"
becomes meaningless once you have several entries. A two-second description
(`git stash push -m "auth middleware — broken redirect"`) saves minutes of
archaeology with `git stash show` later.

**Prefer `apply` over `pop` when uncertain.** `pop` removes the stash entry
after applying it. If you hit conflicts, the entry is gone. Use `apply` to
keep the safety net intact, inspect the result, then `drop` manually once you
are satisfied.

**Keep the stash stack short.** Stashes are not branches. They do not track
diverging work, have no relationship to each other, and fall off the reflog
after 90 days by default. If you need to park work for more than a day or
two, create a real branch with a `git commit`.

**Use `--keep-index` to test staged changes in isolation.** When you have
staged some changes and want to verify they build or pass tests without
unstaged noise, `git stash push --keep-index` shelves only the unstaged
changes. The index is left intact for a clean test run, then `pop` brings
back the rest.

**Use `branch` to promote a long-lived stash.** If a stash grows stale
because the branch it came from has moved on, `git stash branch <name>`
creates a new branch at the original HEAD, applies the stash without
conflicts, and drops it. This is the safest way to revive an old stash.

## Pitfalls & gotchas

**Untracked files are not stashed by default.** Running `git stash` with no
flags only captures tracked, modified files and the index. New files you have
not yet run `git add` on remain in the working tree. Pass `-u` /
`--include-untracked` to capture them.

**Ignored files are not stashed even with `-u`.** The `-a` / `--all` flag is
needed to also stash ignored files such as build output or `.env` files. Use
this carefully — `--all` runs `git clean` on those files, which is
destructive if the stash is later lost.

**`pop` after conflicts leaves the stash entry on the stack.** If `pop`
encounters merge conflicts, the entry stays in the stash list so you can
retry. Resolve the conflicts, then call `git stash drop` manually. Do not
call `git stash pop` again — that would apply the next entry in the stack.

**Stash entries expire.** The reflog retains `refs/stash` entries for
`gc.reflogExpire` days (default 90). After that, `git gc` can prune them.
`git stash clear` makes them immediately eligible for pruning. Recover them
quickly (see Recovery below) or convert them to real commits.

**`--index` can fail if you have index conflicts.** The `--index` flag to
`pop` / `apply` tries to restore the staging-area state as well as the
working tree. If the current index already has conflicts, Git cannot apply
the saved index state on top and will report an error. Omit `--index` to
restore only the working tree in that case.

**`git stash save` is deprecated.** Older documentation and tutorials use
`git stash save <message>`. The modern equivalent is `git stash push -m
<message>`. The `save` subcommand is still functional but does not support
`<pathspec>` arguments.

## Worked examples

### Interrupting work to apply an urgent fix

You are mid-feature on `feature/payments` when you are asked to patch
`main` immediately.

```sh
# Save in-progress work with a descriptive label
git stash push -m "WIP: payment retry logic"

# Switch to main and apply the fix
git switch main
git commit -a -m "Fix null-pointer in order totals"
git push

# Return to the feature branch and restore your work
git switch feature/payments
git stash pop
```

If the pop produces conflicts, resolve them in the editor, then clean up the
stash entry that was left behind:

```sh
# resolve conflicts...
git add src/payment.ts
git stash drop
```

### Testing staged changes in isolation

You have staged a refactor of `src/auth.ts` and also have unstaged
experimental changes in the same file. You want to confirm the refactor
builds and passes tests before committing it.

```sh
# Stage just the refactor hunks
git add -p src/auth.ts

# Stash the unstaged experimental changes; leave the staged index alone
git stash push --keep-index -m "experimental auth ideas"

# Only the refactor is present — run the test suite
npm test

# Commit the clean, verified refactor
git commit -m "Extract token validation into AuthService"

# Restore the experimental work
git stash pop
```

### Pulling upstream changes into a dirty tree

Your local branch has uncommitted changes and `git pull` refuses to proceed
because they would conflict with incoming commits.

```sh
git stash push -m "local config tweaks"
git pull --rebase origin main
git stash pop
```

If the pop conflicts with the rebased commits, resolve them, stage the
resolved files, and then drop the now-applied stash entry:

```sh
# resolve conflicts in editor...
git add src/config.ts
git stash drop
```

### Promoting a stale stash to a branch

A stash created three weeks ago on `main` no longer applies cleanly because
`main` has moved on. Rather than fighting the conflicts manually, promote the
stash to a branch rooted at the commit it was created from.

```sh
git stash list
# stash@{2}: WIP on main: 4d8b3a1 Initial API scaffold

git stash branch fix/old-api-work stash@{2}
# Creates a branch at 4d8b3a1, applies the stash cleanly, drops stash@{2}
```

You now have a normal branch to rebase onto the current `main`, review, and
merge at your leisure. See the *rebase* chapter for how to bring it up to
date.

## Recovery

If you accidentally dropped a stash entry, it may still be reachable as an
unreferenced commit object before garbage collection runs. Search for it:

```sh
git fsck --unreachable \
  | grep commit \
  | cut -d' ' -f3 \
  | xargs git log --merges --no-walk --grep=WIP
```

Once you identify the commit hash, restore it to the stash stack:

```sh
git stash store -m "recovered stash" <commit-hash>
```

To undo a `git stash pop` that you did not intend (the stash was removed and
the changes are now in the working tree), simply re-stash before doing
anything else:

```sh
git stash push -m "re-stashed: accidentally popped"
```

To undo a `git stash apply` without losing the stash entry, discard the
working-tree changes that were just applied:

```sh
git restore .
# or, to also unstage anything that was restored to the index:
git reset HEAD
git restore .
```

See *Getting out of jams* for broader undo recipes involving lost commits and
branch recovery.

## See also

- *add* — building the index; relevant to `--keep-index` and `--staged` stash workflows.
- *commit* — when parked work should become a real snapshot instead of a stash.
- *branch* — `git stash branch` promotes a stash to a full branch.
- *rebase* — bringing a stash-derived branch up to date with the rest of history.
- *Getting out of jams* — recovering dropped stashes and resolving apply conflicts.
