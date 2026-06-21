# worktree

Check out multiple branches simultaneously into separate directories, all
backed by a single repository clone.

## Mental model

A normal clone gives you one working tree: one directory, one `HEAD`, one
index. `git worktree` lets you attach additional working trees to that same
repository. Each linked worktree has its own `HEAD`, its own index, and its
own in-progress changes — but they all share the same object database and the
same branch namespace.

```text
~/.git/               ← single object database, all branches
  worktrees/
    hotfix/           ← per-worktree HEAD + index
    experiment/       ← per-worktree HEAD + index

~/project/            ← main worktree  (branch: main)
~/project-hotfix/     ← linked worktree (branch: hotfix)
~/project-experiment/ ← linked worktree (detached HEAD)
```

Think of linked worktrees as cheap, instant checkouts that do not require a
second clone. Switching between them is as fast as `cd`, and each one keeps
its own uncommitted work without any stashing.

The repository enforces one rule: a branch can only be checked out in one
worktree at a time. If `hotfix` is already open in another worktree, a second
`add` of the same branch is rejected — unless you use `--force`.

## Synopsis

```text
git worktree add [-f] [--detach] [--checkout] [--lock [--reason <string>]]
                 [--orphan] [(-b | -B) <new-branch>] <path> [<commit-ish>]
git worktree list [-v | --porcelain [-z]]
git worktree lock [--reason <string>] <worktree>
git worktree move <worktree> <new-path>
git worktree prune [-n] [-v] [--expire <expire>]
git worktree remove [-f] <worktree>
git worktree repair [<path>...]
git worktree unlock <worktree>
```

## Everyday usage

Create a linked worktree for a new branch based on `HEAD`:

```sh
git worktree add ../hotfix
# Creates branch "hotfix" from HEAD and checks it out at ../hotfix
```

Create a worktree for an existing branch:

```sh
git worktree add ../review feature/payments
```

Create a worktree with an explicit new branch name:

```sh
git worktree add -b fix/login-timeout ../login-fix main
```

List all worktrees, including branch and commit:

```sh
git worktree list
```

```text
/home/alice/project          abc1234 [main]
/home/alice/hotfix           def5678 [hotfix]
/home/alice/login-fix        ghi9012 [fix/login-timeout]
```

Remove a worktree once the work is done (the branch is not deleted):

```sh
git worktree remove ../hotfix
```

Clean up stale administrative records for worktrees deleted without `remove`:

```sh
git worktree prune
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-b <branch>` | Create `<branch>` from `<commit-ish>` and check it out | Starting fresh topic work in its own directory |
| `-B <branch>` | Like `-b` but resets the branch if it already exists | Reuse a branch name after it was already created |
| `-d` / `--detach` | Check out in detached HEAD mode | Throwaway investigation; no branch needed |
| `-f` / `--force` | Override the "branch already checked out" safety check | Rare: open the same branch in two places simultaneously |
| `--lock` | Lock the worktree immediately after `add` | Worktrees on removable drives or network shares |
| `--reason <string>` | Record why the worktree is locked (with `lock` or `add --lock`) | Document context for teammates or future self |
| `--no-checkout` | Create the worktree without populating the working tree | Preparing a sparse checkout before files land |
| `--orphan` | Create the worktree with an empty index and an unborn branch | Starting a new branch with no history |
| `--guess-remote` | Base the new branch on a matching remote-tracking branch | Quickly mirror remote branches locally |
| `-n` / `--dry-run` | With `prune`: show what would be removed without removing it | Safely preview stale-record cleanup |
| `-v` / `--verbose` | With `list`: show more detail; with `prune`: report removals | Diagnosing which worktrees are known to git |
| `--porcelain` | With `list`: machine-readable output stable across git versions | Scripting and tooling |
| `--expire <time>` | With `prune`: only remove records older than `<time>` | Conservative cleanup |

## Best practices

**Keep linked worktrees beside, not inside, the main worktree.** Place them
as siblings in the parent directory (e.g. `../hotfix`) rather than as
subdirectories. Git will not add sibling directories to the main worktree's
index, whereas nested paths can confuse tools that scan the working tree
recursively.

**Name the path after the branch.** When `git worktree add ../hotfix` is run
without an explicit branch name, git creates a branch called `hotfix`. Keeping
the directory name and branch name in sync makes `git worktree list` output
immediately readable and avoids confusion months later.

**Use worktrees instead of stash for context-switching.** If you are mid-way
through feature work and an urgent bug comes in, open a new worktree on
`main` rather than stashing. Your feature work stays exactly as you left it;
there is no stash to pop and no risk of conflicts when you return. See the
*stash* chapter for the cases where stash is still the right tool.

**Lock worktrees on removable or network locations.** If a worktree lives on
a USB drive or a network mount that is not always present, run
`git worktree lock --reason "on external drive" ../worktree-name` to prevent
git from pruning its administrative records when the path is temporarily
unavailable.

**Remove worktrees explicitly.** `git worktree remove` cleans up both the
directory and the administrative records in `.git/worktrees/`. Deleting the
directory with `rm -rf` leaves stale records behind. `git worktree prune`
will eventually clean them up but only after the configured expiry period
(`gc.worktreePruneExpire`, default 3 months).

**Prefer bare clones as a worktree host for server-side or multi-branch
workflows.** A bare repo has no main working tree of its own, making every
working tree a linked one. Clone with `git clone --bare <url> project.git`
and then add worktrees at `project-main/`, `project-staging/`, and so on.
This avoids the awkwardness of a branch occupying the "main" slot permanently.

## Pitfalls & gotchas

**A branch can only be checked out in one worktree at a time.** Attempting to
add a worktree for a branch already open elsewhere fails with a message like
`fatal: 'hotfix' is already checked out at '/home/alice/hotfix'`. Use
`--force` to override, but two worktrees on the same branch will see each
other's committed changes immediately — committing in both simultaneously
produces a diverged branch.

**Deleting the directory does not remove the administrative records.** If you
`rm -rf ../hotfix` instead of running `git worktree remove ../hotfix`, git
still thinks that worktree exists. `git worktree list` shows it as missing or
prunable. Run `git worktree prune` to clean up, or `git worktree repair` if
the directory was moved rather than deleted.

**The main worktree cannot be removed.** `git worktree remove` only applies
to linked worktrees. The main worktree (created by `git init` or `git clone`)
is permanent for the lifetime of that clone. If you need to work without a
fixed main working tree, start from a bare clone.

**Per-worktree state does not follow you when you `cd`.** Each worktree has
its own `HEAD`, index, and mid-operation state (`MERGE_HEAD`,
`CHERRY_PICK_HEAD`, and so on). Running `git status` in the wrong directory
will show a completely different picture than expected. Always verify your
working directory with `pwd` or a shell prompt that shows the current path
before running git commands.

**Refs inside `refs/bisect`, `refs/worktree`, and `refs/rewritten` are per-worktree, not
shared.** A bisect session started in one worktree is invisible in another.
This is usually desirable, but it can surprise you if you expect
`git bisect reset` in the main worktree to clean up a bisect started in a
linked one. See the *bisect* chapter for details.

**Moving the main worktree manually breaks linked worktrees.** Linked
worktrees record the path back to `.git` as an absolute path. Moving the
main repository directory with `mv` causes every linked worktree to lose its
back-reference. Fix this by running `git worktree repair` from inside the
moved main worktree's new location.

## Worked examples

### Handling a hotfix without leaving feature work

You are deep in a feature branch when a P1 bug is reported against `main`.

```sh
# From inside your feature worktree
git worktree add -b hotfix/payment-crash ../payment-hotfix main
cd ../payment-hotfix
```

Fix the bug, commit, and push:

```sh
# (edit the file)
git add src/payments.js
git commit -m "Fix null dereference on expired card"
git push origin hotfix/payment-crash
```

Return to your feature work instantly — nothing has changed:

```sh
cd ../myproject
```

When the hotfix branch is merged and no longer needed, clean up:

```sh
git worktree remove ../payment-hotfix
git branch -d hotfix/payment-crash
```

### Running two versions of the app side by side

You want to compare the behaviour of `main` against an experimental renderer
without switching branches back and forth.

```sh
# main is already checked out in ~/myproject
git worktree add -b experiment/new-renderer ../myproject-experiment main
```

Run both servers simultaneously in separate terminals:

```sh
# Terminal 1 — current main
cd ~/myproject && npm start -- --port 3000

# Terminal 2 — experimental branch
cd ~/myproject-experiment && npm start -- --port 3001
```

Compare them in the browser at the same time. When the experiment is settled,
remove the worktree:

```sh
git worktree remove ~/myproject-experiment
```

### Recovering from a manually moved repository

You moved your main repository from `~/old-name` to `~/new-name` using `mv`,
and now `git status` in a linked worktree at `~/hotfix` fails:

```text
fatal: not a git repository: /Users/alice/old-name/.git
```

Fix the broken back-reference from inside the new main worktree location:

```sh
cd ~/new-name
git worktree repair
```

Git rewrites the `gitdir` file in each linked worktree to point at the new
location. Verify everything is connected:

```sh
git worktree list
```

```text
/Users/alice/new-name   abc1234 [main]
/Users/alice/hotfix     def5678 [hotfix]
```

## Recovery

Remove a worktree and discard any uncommitted changes inside it:

```sh
git worktree remove --force ../linked-worktree
```

If you deleted a worktree directory manually and want to clean up the stale
administrative records:

```sh
git worktree prune --dry-run   # preview what will be removed
git worktree prune             # remove stale records
```

If a worktree directory was moved manually, re-link it to the repository
without losing your work:

```sh
cd /new/path/to/linked-worktree
git worktree repair
```

If a worktree is locked and you cannot remove or move it, unlock it first:

```sh
git worktree unlock <worktree>
git worktree remove <worktree>
```

See *Getting out of jams* for strategies when a worktree is left in a
mid-merge or mid-rebase state with no straightforward way to abort.

## See also

- *branch* — creating and deleting the branches that worktrees check out.
- *checkout* — the single-worktree equivalent for switching branches; also
  explains detached HEAD mode.
- *stash* — a lighter alternative for context-switching when a full worktree
  is more than the task requires.
- *rebase* — running an interactive rebase inside a dedicated worktree keeps
  the main worktree clean during the operation.
- *bisect* — bisect sessions are per-worktree; run a bisect in a linked
  worktree to avoid interrupting ongoing work.
- *Getting out of jams* — recovering from mid-operation states left in a
  linked worktree.
