# checkout

Switch to a branch, create a new branch, restore working-tree files, or
inspect a commit in detached-HEAD mode.

## Mental model

`git checkout` is the Swiss-army knife of navigation. It does two
conceptually different things depending on whether you pass it a branch/commit
name or a path:

**Branch/commit mode** — moves `HEAD` to point at a different branch (or
directly at a commit). Git then rewrites the index and working tree to match
the target. Your uncommitted local modifications are carried along if they do
not conflict.

**Path mode** — leaves `HEAD` exactly where it is and instead overwrites
specific files in the working tree (and optionally the index) with a version
from somewhere else: the index, a commit, or any tree-ish.

```text
                      ┌─ branch mode ──► moves HEAD + rewrites tree
git checkout <target> ┤
                      └─ path mode ────► overwrites files, HEAD stays put
```

A third mode — **detached HEAD** — puts `HEAD` directly on a commit object
instead of on a branch. Any commits you make in this state are reachable only
from `HEAD`; once you leave, they become orphaned and will eventually be
garbage-collected unless you give them a branch or tag.

> Modern Git (2.23+) splits these responsibilities across two dedicated
> commands: *switch* for branch navigation and *restore* for file restoration.
> `git checkout` still works and is ubiquitous in scripts and documentation,
> but the newer commands are less ambiguous for interactive use.

## Synopsis

```text
git checkout [-q] [-f] [-m] [<branch>]
git checkout [-q] [-f] [-m] --detach [<branch>]
git checkout [-q] [-f] [-m] [--detach] <commit>
git checkout [-q] [-f] [-m] [[-b|-B|--orphan] <new-branch>] [<start-point>]
git checkout [-f] <tree-ish> [--] <pathspec>...
git checkout [-f|--ours|--theirs|-m|--conflict=<style>] [--] <pathspec>...
git checkout (-p|--patch) [<tree-ish>] [--] [<pathspec>...]
```

## Everyday usage

Switch to an existing branch:

```sh
git checkout main
git checkout feature/login
```

Switch back to the previous branch (the `-` shorthand means "wherever I just
was"):

```sh
git checkout -
```

Create a new branch and switch to it immediately:

```sh
git checkout -b feature/payments
git checkout -b hotfix/null-ptr origin/main   # start from a specific point
```

Restore a single file to the version in the index (discard working-tree
edits):

```sh
git checkout -- src/api.js
```

Restore a file to the version from a specific commit:

```sh
git checkout HEAD~2 -- src/api.js
git checkout a3f9c1 -- config/routes.rb
```

Check out a commit in detached-HEAD mode for read-only inspection:

```sh
git checkout v2.4.0        # tag
git checkout a3f9c1        # any commit hash
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-b <new-branch>` | Create `<new-branch>` and switch to it | Start new work from the current or a named start point |
| `-B <new-branch>` | Create `<new-branch>`, or reset it if it exists, then switch | Re-use a branch name during iterative experimentation |
| `-d` / `--detach` | Detach HEAD at the target commit rather than tracking a branch | Inspect a commit or run throwaway experiments |
| `--orphan <new-branch>` | Create a new unborn branch; the first commit on it will have no parents and start a disconnected history | GitHub `gh-pages` branch; publishing a clean subtree |
| `-f` / `--force` | Proceed even when the index or working tree differs from HEAD, and even if there are untracked files in the way | Blow away local changes intentionally |
| `-m` / `--merge` | Three-way merge local modifications into the target branch instead of refusing | Carry in-progress work to a different branch |
| `--conflict=<style>` | Set the conflict marker style (`merge`, `diff3`, `zdiff3`) when used with `-m` | Prefer `diff3` for more context in conflict hunks |
| `--ours` | During a merge conflict, check out stage 2 (the current branch's version) | Resolve a conflict by keeping your side entirely |
| `--theirs` | During a merge conflict, check out stage 3 (the incoming version) | Resolve a conflict by accepting the other side entirely |
| `-p` / `--patch` | Interactively pick hunks to restore from the index or a tree-ish | Selectively discard only some edits in a file |
| `-t` / `--track` | Set the upstream tracking reference when creating a branch | Wire a new branch to its remote counterpart for `git pull`/`push` |
| `--no-track` | Do not configure upstream even if `branch.autoSetupMerge` is set | Local-only branch that should never push |
| `-q` / `--quiet` | Suppress feedback messages | Scripting; reduce noise in CI logs |
| `--recurse-submodules` | Also update submodule working trees to match the superproject commit | Repos with submodules where you want everything in sync |
| `--no-overlay` | Remove files that appear in the index and working tree but not in the target `<tree-ish>` | Make a subdirectory match a commit exactly |
| `--pathspec-from-file=<file>` | Read pathspecs from a file rather than the command line | Scripted restores of a large or programmatically generated file list |

## Best practices

**Prefer `-b` over a separate `git branch` + `git checkout` pair.** The
combined form is atomic: if the branch name is invalid or already exists the
command fails before moving HEAD, leaving you on your original branch.

**Always use `--` before pathspecs.** When a filename could be confused with a
branch name, omit the separator and Git favors the branch interpretation. The
`--` sentinel tells Git unambiguously that what follows is a path, not a
branch or commit:

```sh
git checkout -- hotfix   # restores a file named "hotfix"
git checkout hotfix      # switches to the branch named "hotfix"
```

**Name detached-HEAD work before leaving.** When you check out a commit hash
or tag directly, you are in detached-HEAD state. Any commits you make exist
only through `HEAD`. Before switching away, give those commits a branch:

```sh
git checkout -b experiment/v2-prototype
```

If you forget, use `git reflog` to find the last commit hash and then create
the branch retrospectively.

**Use `-b` with an explicit start point instead of switching first.** Rather
than checking out `main` and then branching, pass the start point directly.
This avoids accidentally picking up uncommitted changes from `main`:

```sh
git checkout -b fix/cache-bug origin/main
```

**Use the `switch` and `restore` commands for new scripts.** `git checkout`
conflates two unrelated operations. In scripts written today, prefer *switch*
for branch navigation and *restore* for file restoration — both are explicit
about intent and less prone to ambiguous-argument errors.

## Pitfalls & gotchas

**`--ours` and `--theirs` flip meaning during a rebase.** During `git rebase`,
"ours" is the branch being rebased *onto* (typically `main`), not your feature
branch. "Theirs" is your feature branch's work. This is the opposite of the
intuitive meaning during a plain `git merge`. When in doubt, inspect the
conflict markers before reaching for `--ours`/`--theirs`.

**`-f` silently discards uncommitted work.** Force-switching a branch with
`-f` will overwrite modified tracked files and delete untracked files that are
in the way. There is no undo. Check `git status` before using `-f`.

**Path-mode checkout does not stage the change.** Running
`git checkout HEAD~1 -- src/config.js` writes the old version into the working
tree and into the index simultaneously. The file shows up in `git status` as
"Changes to be committed". This surprises people who expect only the working
tree to be modified.

**Switching branches with staged changes sometimes silently carries them.**
If your staged changes do not conflict with the target branch, Git moves the
staging area along with you. Your staged diff on branch A will still be staged
after switching to branch B. This is convenient but can cause an accidental
commit on the wrong branch.

**Detached-HEAD commits are easy to lose.** Any commits made in detached-HEAD
state exist only through the `HEAD` reference. The moment you run another
`git checkout`, `HEAD` moves and those commits become unreachable. Git's
garbage collector will eventually delete them. Save them with a branch or tag
before navigating away.

**Argument ambiguity between branches and files.** If a file and a branch
share a name, `git checkout <name>` switches to the branch. Git warns about
this situation but does not error. Always use `--` when operating on paths to
eliminate the ambiguity.

## Worked examples

### Starting a feature branch from a remote base

You want to begin work on a payment integration, tracking the team's `origin/main`:

```sh
git fetch origin
git checkout -b feature/stripe-payments origin/main
```

```text
Switched to a new branch 'feature/stripe-payments'
Branch 'feature/stripe-payments' set up to track remote branch 'main' from 'origin'.
```

The new branch starts at the same commit as `origin/main` and is wired for
tracking, so `git pull` and `git push` work without extra arguments.

### Rescuing a file you accidentally deleted

You deleted `src/auth/token.js` and already staged the deletion:

```sh
git checkout HEAD -- src/auth/token.js
```

Git restores the file from the last commit into both the working tree and the
index, cancelling the staged deletion. Confirm with `git status`.

### Inspecting an old release without losing your work

You are debugging a regression and want to run the tests against the `v1.8.0`
tag without touching your current branch:

```sh
git stash push -m "WIP: payment refactor"
git checkout v1.8.0
```

```text
Note: switching to 'v1.8.0'.

You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you made in this
state without impacting any branches by switching back to a branch.
```

Run your tests, then return to your branch and restore the stash:

```sh
git checkout feature/stripe-payments
git stash pop
```

### Selectively discarding edits with --patch

You edited `services/email.js` in two unrelated ways and want to keep one
change but throw away the other:

```sh
git checkout -p -- services/email.js
```

Git presents each hunk interactively (`y` accept, `n` skip, `s` split,
`e` edit manually). Accepting a hunk restores that portion of the file from
the index, discarding your working-tree edit for that hunk only.

### Resolving a merge conflict by choosing one side entirely

You are in the middle of a merge and `config/database.yml` has a conflict.
The current branch's version is correct:

```sh
git checkout --ours -- config/database.yml
git add config/database.yml
```

Or if the incoming branch is correct:

```sh
git checkout --theirs -- config/database.yml
git add config/database.yml
```

Mark the file resolved and continue as usual with `git commit`.

## Recovery

**Switched to the wrong branch and lost staged changes:** staged changes that
did not conflict were silently carried over. They are still in the index.
Switch back and your staged diff will be there.

**Made commits in detached-HEAD state and then navigated away:** find the
orphaned commit in the reflog and create a branch pointing at it:

```sh
git reflog
# find the hash, e.g. e7a3f12
git checkout -b rescue/detached-work e7a3f12
```

**Restored a file from a commit with `git checkout <commit> -- <file>` by
mistake:** the original working-tree content is gone, but if you had not yet
staged it the index still holds the HEAD version. Run:

```sh
git checkout HEAD -- <file>
```

to get back to the committed version, then re-apply your edits.

**Accidentally discarded working-tree changes with `-f`:** if the changes were
never committed they are gone. If you had staged them at any point and Git's
`gc` has not yet run, they may still exist as loose objects. See *Getting out
of jams* for `git fsck --lost-found` techniques.

See *Getting out of jams* for broader undo recipes covering branch recovery and
lost commits.

## See also

- *switch* — the modern, unambiguous command for changing branches.
- *restore* — the modern, unambiguous command for restoring working-tree files.
- *branch* — creating, listing, and deleting branches without switching to them.
- *stash* — shelve work-in-progress before switching contexts.
- *reflog* — find and recover commits that became unreachable after detached-HEAD work.
- *rebase* — rewriting history; note the `--ours`/`--theirs` flip described above.
- *Getting out of jams* — recovering from force-checkouts and lost commits.
