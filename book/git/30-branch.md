# branch

List, create, rename, copy, or delete branch pointers in the repository.

## Mental model

A branch in Git is nothing more than a named pointer to a single commit.
When you add commits on a branch, Git advances that pointer forward
automatically. The entire chain of history behind the pointer is what you
think of as "the branch", but the branch itself is only the tip.

```text
main ──────────────────> C3
                          |
              feature ──> C4 ──> C5
```

Because branches are just pointers (a 41-byte file under `.git/refs/heads/`),
creating and deleting them is essentially free. There is no copying of files,
no reorganizing history — Git writes or removes a small ref file.

Every local branch can optionally track an *upstream branch*, usually a
remote-tracking ref like `origin/main`. Git uses that relationship to report
how far ahead or behind you are, and to know where to push or pull by
default. `git branch` is the low-level tool for managing all of this:
listing branches, creating them from a specific commit, renaming, copying,
setting tracking, and deleting.

`git branch` creates a branch but does not switch to it. To create and
switch in one step, use `git switch -c <name>` (see the *switch* chapter).

## Synopsis

```text
# List
git branch [-v | -vv] [-a | -r] [--merged | --no-merged] [--contains <commit>]
           [--sort=<key>] [--format=<format>] [--list] [<pattern>...]

# Create
git branch [--track[=(direct|inherit)] | --no-track] [-f]
           <branch-name> [<start-point>]

# Rename / copy
git branch (-m | -M) [<old-branch>] <new-branch>
git branch (-c | -C) [<old-branch>] <new-branch>

# Delete
git branch (-d | -D) [-r] <branch-name>...

# Tracking
git branch (-u | --set-upstream-to=<upstream>) [<branch-name>]
git branch --unset-upstream [<branch-name>]

# Miscellaneous
git branch --show-current
git branch --edit-description [<branch-name>]
```

## Everyday usage

List all local branches (current branch is marked with `*`):

```sh
git branch
```

```text
* feature/login
  fix/null-pointer
  main
```

List branches with their latest commit hash and subject:

```sh
git branch -v
```

```text
* feature/login   3a1c9f2 Add JWT validation middleware
  fix/null-pointer 7f02d3c Fix null-pointer in parseToken
  main             a4e8b10 Release v2.1.0
```

Add a second `-v` to also show upstream tracking information:

```sh
git branch -vv
```

```text
* feature/login   3a1c9f2 [origin/feature/login: ahead 2] Add JWT validation middleware
  fix/null-pointer 7f02d3c [origin/fix/null-pointer] Fix null-pointer in parseToken
  main             a4e8b10 [origin/main] Release v2.1.0
```

Show both local and remote-tracking branches:

```sh
git branch -a
```

Create a new branch pointing to the current `HEAD`:

```sh
git branch feature/search
```

Create a new branch from a specific commit, tag, or other branch:

```sh
git branch hotfix/login-crash v2.1.0
git branch experiment main~3
```

Delete a branch that has been fully merged:

```sh
git branch -d feature/login
```

Force-delete a branch regardless of merge status:

```sh
git branch -D experiment
```

Rename the current branch:

```sh
git branch -m feature/serach feature/search
```

Show just the name of the current branch (useful in scripts):

```sh
git branch --show-current
```

List branches already merged into `main` (candidates for deletion):

```sh
git branch --merged main
```

List branches not yet merged:

```sh
git branch --no-merged main
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-v` / `-vv` | Show commit hash, subject, and upstream relationship; `-vv` additionally shows the linked worktree path | Quickly audit branch state and divergence |
| `-a` / `--all` | List both local and remote-tracking branches | Get a complete picture of all refs |
| `-r` / `--remotes` | List (or delete) remote-tracking branches only | Inspect or clean up stale remote refs |
| `-d` / `--delete` | Delete a branch if fully merged into its upstream or `HEAD` | Safe cleanup after a merge |
| `-D` | Shortcut for `--delete --force`; deletes regardless of merge status | Remove an abandoned or squash-merged branch |
| `-m` / `--move` | Rename a branch, carrying its reflog and config | Fix a typo; rename after a scope change |
| `-M` | Shortcut for `--move --force`; overwrites the target if it exists | Force a rename |
| `-c` / `--copy` | Copy a branch along with its config and reflog | Experiment off a branch without destroying it |
| `-C` | Shortcut for `--copy --force`; overwrites the target if it exists | Force a copy |
| `-f` / `--force` | Reset an existing branch pointer to a new start point | Move a branch tip without checking it out |
| `-t` / `--track` | Set up upstream tracking when creating a branch | Establish the push/pull relationship explicitly |
| `--no-track` | Do not set up upstream tracking | Suppress auto-tracking from `branch.autoSetupMerge` |
| `-u <upstream>` | Change (or set) the upstream of an existing branch | Fix a mis-configured tracking relationship |
| `--unset-upstream` | Remove upstream configuration from a branch | Detach a local branch from its remote |
| `--show-current` | Print the current branch name; prints nothing in detached HEAD | Scripting and prompt integrations |
| `--merged [<commit>]` | Filter to branches whose tips are reachable from `<commit>` | Find branches safe to delete |
| `--no-merged [<commit>]` | Filter to branches not reachable from `<commit>` | Find branches that still need merging |
| `--contains [<commit>]` | Filter to branches that contain `<commit>` in their history | Find which branches carry a specific fix |
| `--no-contains [<commit>]` | Filter to branches that do not contain `<commit>` | Find branches that still need a patch applied |
| `--sort=<key>` | Sort output by a ref field; prefix `-` for descending | Sort by `-committerdate` to see most-active branches first |
| `--format=<format>` | Custom output using `%(fieldname)` placeholders | Build scripts or dashboards with precise output |
| `--list` | Treat the argument as a glob pattern, not a branch name | Filter: `git branch --list 'fix/*'` |
| `--edit-description` | Open an editor to write a description for the branch | Document purpose for `format-patch` cover letters |

## Best practices

**Name branches with a prefix that signals intent.** Common conventions are
`feature/`, `fix/`, `hotfix/`, `chore/`, and `experiment/`. Prefixes keep
`git branch` output scannable and enable glob filtering:

```sh
git branch --list 'fix/*'
```

Avoid spaces and special characters. Stick to alphanumerics, hyphens, and
forward slashes.

**Branch from an up-to-date starting point.** A feature branch should start
from the current tip of `main` (or whatever your integration branch is),
not from a stale local snapshot. Fetch before creating:

```sh
git fetch origin
git branch feature/payments origin/main
```

**Set upstream tracking so status, pull, and push work without arguments.**
When a branch has an upstream configured, `git status` shows how many
commits you are ahead or behind, which is useful information every time you
glance at the repo. Set it at push time:

```sh
git push -u origin feature/payments
```

Or after the fact:

```sh
git branch --set-upstream-to=origin/feature/payments
```

**Keep branch names stable after sharing.** As soon as you push a branch
and others reference it, renaming it with `-m` orphans their remote-tracking
refs. Rename only branches that exist solely on your own machine. If you
must rename a pushed branch, also delete the old remote branch and push the
new name, then notify collaborators.

**Prune stale remote-tracking refs regularly.** Remote-tracking branches
are not removed automatically when the remote deletes them. Use:

```sh
git fetch --prune
```

Or enable pruning permanently:

```sh
git config --global fetch.prune true
```

**Confirm with `--merged` before a bulk cleanup.** Before deleting a group
of old branches, check that they are genuinely merged:

```sh
git branch --merged main
```

Delete only branches confirmed to be in that list. Use `-D` sparingly —
force deletion discards any commits reachable only from that branch.

## Pitfalls & gotchas

**`git branch <name>` creates but does not switch.** This trips up beginners
who create a branch, keep committing on `main`, and then wonder why the
branch is empty. Use `git switch -c <name>` when you mean to start work
immediately. Check your current branch with `git branch --show-current`
before committing.

**`-d` refuses to delete an unmerged branch.** Git protects you: if the
branch contains commits not reachable from its upstream (or from `HEAD`
when there is no upstream), `-d` fails with an error message. This is
almost always the right behavior. Use `-D` only when you are certain the
work is already elsewhere or truly abandoned.

**Squash-merged branches appear unmerged.** When a pull request is merged
as a single squash commit, the original branch commits are not reachable
from `main`. `git branch --merged` will not list the branch, and `-d` will
refuse to delete it. Force-delete with `-D`. Projects that squash-merge
routinely often automate branch cleanup in CI rather than relying on the
safe-delete check.

**`-f` silently resets a branch pointer with no confirmation.** `git branch
-f <name> <start-point>` moves an existing branch to a different commit
immediately. There is no prompt and no undo other than the reflog. Verify
the target commit before running this.

**`--set-upstream` (without `-to`) is no longer supported.** The old flag
had confusing syntax and was removed. Always use `-u <upstream>` or
`--set-upstream-to=<upstream>`.

**Renaming the default branch affects all clones.** If you rename `master`
to `main`, every collaborator must update their local config:

```sh
git branch -m master main
git fetch origin
git branch --set-upstream-to=origin/main main
```

Co-ordinate with the team and update the remote's default branch setting
before making the rename.

## Worked examples

### Cleaning up merged feature branches after a sprint

Several feature branches were merged into `main` during the sprint. Find
and delete them:

```sh
git fetch --prune
git branch --merged main
```

```text
  feature/login
  feature/search
  fix/null-pointer
  main
```

`main` always appears in its own `--merged` output, so skip it. Delete the
rest:

```sh
git branch -d feature/login feature/search fix/null-pointer
```

```text
Deleted branch feature/login (was 3a1c9f2).
Deleted branch feature/search (was 8b44a01).
Deleted branch fix/null-pointer (was 7f02d3c).
```

### Sorting branches by most recent activity

On a long-lived repository with dozens of branches, find the most recently
active ones:

```sh
git branch --sort=-committerdate -v
```

```text
* feature/payments  a7d3e12 Add Stripe webhook handler
  hotfix/session    b2c9100 Fix session expiry check
  main              a4e8b10 Release v2.1.0
  feature/search    0c3af77 Initial search scaffold
```

The `-` prefix on `committerdate` sorts newest first. Make it the default:

```sh
git config --global branch.sort -committerdate
```

### Finding which branches contain a critical security fix

A fix for a vulnerability was committed as `d9f4a2b`. Before shipping,
verify that all active long-term-support branches include it:

```sh
git branch --contains d9f4a2b
```

```text
  lts/2.1
  lts/2.0
* main
```

`lts/1.9` is not in the list. It does not contain the fix and needs a
cherry-pick before that line ships (see the *cherry-pick* chapter).

### Fixing a mis-configured upstream

`git branch -vv` reveals the branch is tracking the wrong remote branch:

```sh
git branch -vv
```

```text
* feature/payments  a7d3e12 [origin/feature/search: ahead 5] Add Stripe webhook handler
```

Fix it:

```sh
git branch --set-upstream-to=origin/feature/payments
```

```text
Branch 'feature/payments' set up to track remote branch 'feature/payments' from 'origin'.
```

Confirm:

```sh
git branch -vv
```

```text
* feature/payments  a7d3e12 [origin/feature/payments: ahead 5] Add Stripe webhook handler
```

## Recovery

If you deleted a branch by mistake, its tip commit is still in the object
database and tracked in the reflog. Find the hash and recreate the pointer:

```sh
# Show recent HEAD movements across all branches
git reflog --all | head -30

# Once you have the hash, recreate the branch
git branch recovered-branch <commit-hash>
```

If you moved a branch pointer with `-f` to the wrong commit, look up the
previous tip in that branch's reflog:

```sh
git reflog show <branch-name>
```

```text
a7d3e12 feature/payments@{0}: branch: Reset to origin/main
3a1c9f2 feature/payments@{1}: commit: Add Stripe webhook handler
```

Restore the previous tip:

```sh
git branch -f feature/payments 3a1c9f2
```

See *Getting out of jams* for broader undo recipes, including recovering
commits after a force-push has overwritten a remote branch.

## See also

- *switch* — create and switch to a branch in one step with `git switch -c`.
- *checkout* — the older combined command for switching branches and restoring files.
- *merge* — integrate a finished branch into another.
- *rebase* — replay branch commits onto a new base.
- *cherry-pick* — apply individual commits from one branch onto another.
- *fetch* — update remote-tracking branches from the network.
- *Getting out of jams* — recovering deleted or lost branches via the reflog.
