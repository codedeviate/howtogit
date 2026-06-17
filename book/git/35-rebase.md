# rebase

Reapply a sequence of commits on top of a different base commit, rewriting
history to produce a cleaner, linear chain.

## Mental model

Every commit in Git points to a parent. A branch is just a pointer to the tip
of a chain of commits. When you rebase branch `topic` onto `main`, Git:

1. Finds the common ancestor of `topic` and `main`.
2. Takes each commit on `topic` that came after that ancestor and turns it into
   a patch.
3. Resets `topic` to point at the tip of `main`.
4. Replays those patches, one by one, producing new commit objects with new
   hashes — the same changes, but with `main`'s tip as their ancestry.

```text
Before:                         After git rebase main:

      A---B---C  topic                    A'--B'--C'  topic
     /                                   /
D---E---F---G  main         D---E---F---G  main
```

The prime marks (`A'`, `B'`, `C'`) are brand-new commit objects. The original
`A`, `B`, `C` still exist in the object database until garbage-collected —
they are simply no longer reachable from any branch pointer.

Interactive rebase (`-i`) adds an editing step: Git opens a to-do list of the
commits to be replayed and lets you reorder, squash, drop, or reword them
before any replaying happens. This makes `git rebase -i` the primary tool for
polishing a branch's history before a code review or merge.

## Synopsis

```text
git rebase [<upstream> [<branch>]]
git rebase --onto <newbase> [<upstream> [<branch>]]
git rebase -i [--autosquash] [--exec <cmd>] <upstream>
git rebase (--continue | --skip | --abort | --quit | --edit-todo | --show-current-patch)
```

## Everyday usage

Update a feature branch to include the latest work from `main`:

```sh
git switch feature/login
git rebase main
```

The same result, specifying the branch explicitly (Git will switch to it
first):

```sh
git rebase main feature/login
```

Interactively clean up the last four commits before opening a pull request:

```sh
git rebase -i HEAD~4
```

Git opens an editor showing the to-do list:

```text
pick a1b2c3 Add login form
pick d4e5f6 WIP wiring
pick 7890ab Fix typo in label
pick cdef01 Add tests for login
```

Change `pick` to the desired action, save, and close the editor. Common
actions:

| Action | Effect |
|--------|--------|
| `pick` | Keep commit as-is (default) |
| `reword` | Keep commit, edit its message |
| `edit` | Pause after applying so you can amend |
| `squash` | Fold into previous commit, combine messages |
| `fixup` | Fold into previous commit, discard this message |
| `drop` | Remove the commit entirely |
| `exec` | Run a shell command after the preceding commit |
| `break` | Pause here without applying any commit |

Collapse `fixup!` and `squash!` commits created with `git commit --fixup` or
`--squash` (see the *commit* chapter):

```sh
git rebase -i --autosquash origin/main
```

Transplant a topic branch from one base to another (see Worked examples):

```sh
git rebase --onto main next topic
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--onto <newbase>` | Set a different landing point for the replayed commits | Transplant a branch to a new base that differs from its upstream |
| `--keep-base` | Use the merge base as the landing point rather than the upstream tip | Sync with an upstream that has advanced without moving your commits' base |
| `-i`, `--interactive` | Open an editor to reorder, squash, drop, or reword commits | Polishing a branch before review |
| `--autosquash` | Automatically arrange `fixup!`/`squash!` commits in the to-do list | Used with `git commit --fixup`; usually paired with `-i` |
| `--autostash` | Stash dirty working tree before rebasing, reapply after | Rebase without a clean working tree |
| `-x <cmd>`, `--exec <cmd>` | Insert an `exec` line after every commit in the to-do list | Run tests or builds at each step |
| `--continue` | Resume after resolving a conflict or finishing an `edit` | Conflict resolution workflow |
| `--skip` | Discard the current conflicting commit and move on | When a commit is already superseded upstream |
| `--abort` | Stop and reset the branch to its state before the rebase started | Bail out entirely |
| `--quit` | Stop without resetting HEAD | Keep partial progress, clean up manually |
| `--edit-todo` | Re-open the interactive to-do list mid-rebase | Correct a mistake in the plan without aborting |
| `--show-current-patch` | Show the patch that caused a conflict or pause | Understand what Git is trying to apply |
| `-f`, `--force-rebase` | Recreate all commits as new objects even if fast-forward is possible | After reverting a merge, to re-merge cleanly |
| `--rebase-merges` | Preserve merge commits in the to-do list | Rebasing a branch with intentional merge topology |
| `--signoff` | Append `Signed-off-by` to every rebased commit | Projects requiring DCO sign-off |
| `-S`, `--gpg-sign` | GPG-sign every rebased commit | Verified commits on GitHub/GitLab |
| `--no-verify` | Skip the pre-rebase hook | Emergency use only |
| `--update-refs` | Force-update intermediate branch pointers within the rebased range | Rebasing a stack of dependent branches at once |
| `--root` | Rebase all commits reachable from the branch, including the root | Rewriting the entire history of a repository |
| `-X <option>`, `--strategy-option` | Pass an option to the merge strategy (e.g. `-X theirs`) | Resolve systematic conflicts automatically |

## Best practices

**Rebase local, merge public.** Rebase is safe on commits that exist only on
your machine. The moment a commit has been pushed and others may have based
work on it, rewriting it breaks their history. Use merge for integrating
shared branches; use rebase for cleaning up your own work before it becomes
shared.

**Set `rebase.autoSquash = true` globally when using `--fixup` commits.**
If you regularly create `fixup!` commits with `git commit --fixup`, enabling
this config key means `git rebase -i` will always arrange them for you without
requiring the `--autosquash` flag every time.

```sh
git config --global rebase.autoSquash true
```

**Keep interactive rebases small.** Rebasing 50 commits interactively is
error-prone. If a branch has drifted that far, consider squashing the whole
branch into a handful of meaningful commits rather than carefully editing each
one.

**Run tests after rebasing with `--exec`.** When reshaping a branch, it is
easy to create intermediate states that do not build. The `--exec` flag inserts
a command after every replayed commit:

```sh
git rebase -i --exec "make test" origin/main
```

If any step fails, the rebase pauses so you can fix it before continuing.

**Prefer `--onto` over manual branch gymnastics when transplanting.** When you
need to move a set of commits to an entirely different base, `--onto` expresses
the intent clearly and lets Git figure out which commits to carry.

**Use `--update-refs` when working on a stack of branches.** If `feature/b` is
based on `feature/a` and `feature/a` is based on `main`, rebasing `feature/b`
onto a new `main` with `--update-refs` will also slide `feature/a`'s pointer
forward. Without it, `feature/a` would still point to the old commits.

## Pitfalls & gotchas

**Rebasing pushed commits causes divergence.** After `git push`, your branch
and the remote are in sync. If you rebase and push again, the hashes change and
the remote will reject the push unless you use `--force-with-lease`. Anyone who
has fetched the original commits now has a divergent history. Only force-push
to feature branches you own and have confirmed no one else is working from.

**"Ours" and "theirs" are swapped during rebase.** During a normal merge,
"ours" is your branch. During a rebase, Git replays your commits on top of
the upstream, so "ours" is the upstream content and "theirs" is your incoming
commit. This surprises people the first time they read a rebase conflict marker.

**Commits that duplicate upstream changes are silently dropped.** If a patch in
your branch is identical in content to one already merged upstream, Git skips it
during the rebase. This is usually the right behavior, but it can surprise you
if you expected that commit to appear in the result.

**Interactive rebase on a branch with merge commits drops those merges by
default.** A plain `git rebase -i` linearizes history and removes any merge
commits on your branch. Use `--rebase-merges` if preserving the topology
matters.

**`--autostash` can produce conflicts on reapplication.** The autostash
mechanism stashes your working tree, completes the rebase, then pops the stash.
If rebased code changed the same lines as your stashed work, the stash pop will
produce a conflict. Ensure your working tree is as clean as practical before
rebasing.

**Deleting a line in the to-do list silently drops the commit.** Unlike
changing `pick` to `drop`, deleting a line in the interactive editor removes
the commit without any confirmation (unless `rebase.missingCommitsCheck` is set
to `warn` or `error` in config). If you accidentally delete a line, abort and
start over.

## Worked examples

### Updating a feature branch to track main

Your `feature/payments` branch was cut from `main` three days ago. Other work
has landed on `main` since then and you want those changes available in your
branch.

```sh
git fetch origin
git switch feature/payments
git rebase origin/main
```

If there are no conflicts, the branch is silently updated. If a conflict
arises, Git pauses:

```console
CONFLICT (content): Merge conflict in src/checkout.js
error: could not apply d4e5f6... Add Stripe webhook handler
hint: Resolve all conflicts manually, mark them with `git add`, and then run
hint: `git rebase --continue`.
```

Resolve the conflict, stage the file, and continue:

```sh
# edit src/checkout.js to resolve conflict markers
git add src/checkout.js
git rebase --continue
```

Git opens your editor to confirm or adjust the commit message, then replays
the remaining commits. Repeat for any further conflicts.

### Polishing a branch before a pull request

You have been working on a five-commit feature branch. Two commits are "WIP"
checkpoints that should be folded into their neighbors, and one commit message
needs rewording.

```sh
git rebase -i origin/main
```

The editor opens:

```text
pick 1a2b3c Add product search index
pick 4d5e6f WIP: search controller
pick 7a8b9c Wire up search controller to router
pick 0d1e2f WIP: missing pagination
pick 3a4b5c Add pagination to search results
```

Edit the to-do list:

```text
pick 1a2b3c Add product search index
squash 4d5e6f WIP: search controller
reword 7a8b9c Wire up search controller to router
squash 0d1e2f WIP: missing pagination
pick 3a4b5c Add pagination to search results
```

Save and close. Git will:

1. Squash `4d5e6f` into `1a2b3c`, prompting you to edit the combined message.
2. Replay `7a8b9c` and open the editor for a message update.
3. Squash `0d1e2f` into the now-reworded commit above.
4. Replay `3a4b5c` unchanged.

The result is three clean, well-named commits ready for review.

### Transplanting a topic branch with --onto

Your branch `feature/dark-mode` was accidentally branched from `staging`
instead of `main`. You want to move only the commits that belong to
`feature/dark-mode` — not those inherited from `staging` — onto `main`.

```text
    A---B---C  feature/dark-mode
   /
  D---E---F  staging
 /
o---o---o  main
```

```sh
git rebase --onto main staging feature/dark-mode
```

Git finds commits reachable from `feature/dark-mode` but not from `staging`
(that is, `A`, `B`, `C`) and replays them on top of `main`:

```text
             A'--B'--C'  feature/dark-mode
            /
o---o---o  main

  D---E---F  staging  (untouched)
```

The `staging`-only commits are not carried along.

### Autosquashing fixup commits

You have a three-commit branch. During review, a teammate points out a bug in
the first commit (`1a2b3c`). Create a fixup commit targeting it:

```sh
git add src/header.js
git commit --fixup=1a2b3c
```

Git creates a commit titled `fixup! Add responsive header component`. Collapse
it into place:

```sh
git rebase -i --autosquash origin/main
```

The to-do list opens with the fixup already moved below its target and marked
for folding:

```text
pick 1a2b3c Add responsive header component
fixup f9e8d7 fixup! Add responsive header component
pick 2b3c4d Add header unit tests
pick 5e6f7a Update navigation styles
```

Save without changes. The fixup disappears into `1a2b3c` and history stays
clean.

## Recovery

To abort a rebase in progress and restore the branch to its pre-rebase state:

```sh
git rebase --abort
```

To undo a completed rebase on a branch that has not yet been pushed, use
`ORIG_HEAD`, which rebase sets to the pre-rebase tip:

```sh
git reset --hard ORIG_HEAD
```

Note that `ORIG_HEAD` can be overwritten by subsequent reset-style operations.
If that has happened, use the reflog instead:

```sh
git reflog
# find the entry just before the rebase started, e.g.:
#   HEAD@{4}: commit: Add responsive header component
git reset --hard HEAD@{4}
```

To recover a branch that was rebased and force-pushed, and you need to get
back to the remote's previous state:

```sh
git fetch origin
git reset --hard origin/feature/my-branch@{1}   # the reflog of the remote ref
```

See *Getting out of jams* for additional undo recipes including recovering from
a force-push that discarded others' work.

## See also

- *branch* — creating and managing the branches that rebase rewrites.
- *merge* — the alternative to rebase for integrating branches; understand
  when to use each.
- *commit* — `--fixup` and `--squash` flags that feed into `rebase --autosquash`.
- *cherry-pick* — applying individual commits without a full rebase.
- *reflog* — finding and recovering commit hashes after a rebase rewrites them.
- *Getting out of jams* — recovering from a botched rebase.
