# push

Upload local branch commits to a remote repository, advancing its branch
pointers to match yours.

## Mental model

Every repository is a self-contained database of objects and refs. When you
commit locally, only your copy changes. `git push` is the act of transmitting
those objects across the network and updating the remote's branch pointer to
match your local one.

Git enforces one constraint by default: the update must be a *fast-forward*.
A fast-forward means the remote's current tip is an ancestor of the commit you
are pushing — in other words, you are only adding new commits on top of what
is already there, never discarding history.

```text
Before push:

  local:   A---B---C  (feature)
  remote:  A---B      (origin/feature)

After git push:

  remote:  A---B---C  (origin/feature)
```

If someone else has pushed in the meantime, the remote's tip is no longer an
ancestor of your local tip, and Git refuses the push to protect their work.
The solution is to integrate their changes first (see the *fetch* and *pull*
chapters) and then push again.

Pushing also sets a *tracking relationship*: once a branch has an upstream,
plain `git push` (with no arguments) knows where to send commits.

## Synopsis

```text
git push [--all | --branches | --mirror | --tags] [--follow-tags]
         [--atomic] [-n | --dry-run]
         [-f | --force]
         [--force-with-lease[=<refname>[:<expect>]] [--force-if-includes]]
         [-d | --delete] [--prune]
         [-u | --set-upstream]
         [-o <string> | --push-option=<string>]
         [--[no-]signed | --signed=(true|false|if-asked)]
         [--no-verify]
         [-q | --quiet] [-v | --verbose]
         [--repo=<repository>]
         [<repository> [<refspec>...]]
```

## Everyday usage

Push the current branch to its configured upstream (the most common
invocation after the upstream is set up):

```sh
git push
```

Push a branch for the first time and set the upstream tracking reference so
future pushes and pulls need no arguments:

```sh
git push -u origin feature/login
```

Push to a specific remote and branch by name:

```sh
git push origin main
```

Push the current branch to the identically-named branch on origin without
having to type the branch name:

```sh
git push origin HEAD
```

Delete a remote branch you no longer need:

```sh
git push origin --delete feature/old-experiment
# shorthand with the empty-src refspec:
git push origin :feature/old-experiment
```

Push all local tags to the remote:

```sh
git push --tags
```

Push annotated tags that point at commits you are pushing (usually the right
choice over `--tags`):

```sh
git push --follow-tags
```

Preview what would be pushed without actually sending anything:

```sh
git push --dry-run
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-u`, `--set-upstream` | Set the upstream tracking reference for the pushed branch | First push of a new branch |
| `-f`, `--force` | Overwrite the remote ref even if not a fast-forward | After a rebase or amend on a private branch |
| `--force-with-lease` | Force only if the remote ref hasn't changed since your last fetch | Safer alternative to `--force` on shared branches |
| `--force-if-includes` | Verify remote-tracking ref changes are locally integrated; use alongside `--force-with-lease` | Extra safety when background fetches may silently refresh remote-tracking refs |
| `-n`, `--dry-run` | Do everything except actually send objects | Verify what would be pushed before committing |
| `--all`, `--branches` | Push all branches under `refs/heads/` | Sync a full local mirror to a remote |
| `--tags` | Push all tags under `refs/tags/` | Publish all tags alongside commits |
| `--follow-tags` | Push only annotated tags reachable from the pushed commits | Standard release tagging workflow |
| `-d`, `--delete` | Delete the listed refs from the remote | Clean up merged remote branches |
| `--prune` | Remove remote branches that have no local counterpart | Keep the remote in sync after local branch deletions |
| `--atomic` | Succeed or fail all ref updates as a unit | Multiple refs that must land together or not at all |
| `-o <str>`, `--push-option=<str>` | Pass an arbitrary string to remote pre/post-receive hooks | Custom CI signals (e.g. `ci.skip`) |
| `--no-verify` | Skip the pre-push hook | Emergency bypass — fix the hook issue afterward |
| `--mirror` | Push all refs including remotes; force-update or delete on the remote to match locally | Migrating a repository to a new hosting location |
| `--signed=(true\|false\|if-asked)` | GPG-sign the push request | Servers that validate signed pushes via hooks |
| `-q`, `--quiet` | Suppress output except errors | Scripts and CI pipelines |
| `-v`, `--verbose` | Show updated refs and additional detail | Diagnosing unexpected push behaviour |

## Best practices

**Set the upstream once, then push without arguments.** Running `git push -u
origin feature/auth` the first time records `origin/feature/auth` as the
upstream. Every subsequent `git push` on that branch sends to the right place
without any arguments. Configure `push.autoSetupRemote = true` globally to
have Git do this automatically on every first push.

**Prefer `--force-with-lease` over `--force`.** When you rebase a branch and
need to overwrite the remote, `--force` is a blunt instrument — it pushes
regardless of what anyone else may have added. `--force-with-lease` checks
that the remote ref still matches your remote-tracking ref and refuses if
someone else has pushed in the meantime. This catches the most common
force-push foot-gun with almost no extra effort.

**Use `--follow-tags` for releases instead of `--tags`.** `--tags` pushes
every tag in your repository, including old, incomplete, or local-only tags.
`--follow-tags` pushes only annotated tags reachable from the commits being
pushed — exactly what a release workflow needs.

**Delete merged remote branches promptly.** Stale remote branches accumulate
and confuse teammates. After a branch is merged via a pull request, delete it:

```sh
git push origin --delete feature/done
```

**Protect shared branches at the server level.** Never rely solely on client
behaviour. Configure branch protection rules on GitHub or GitLab so that
force-pushes to `main` and `release/*` are server-rejected regardless of what
any client sends.

**Validate with `--dry-run` before unusual pushes.** Before a push involving
multiple refspecs, `--delete`, or `--force`, add `-n` to see exactly which
refs would change without touching anything.

## Pitfalls & gotchas

**"Rejected — non-fast-forward" means someone else pushed first.** Fetch and
integrate their work, then push again. Never reach for `--force` as the first
response to a rejection on a shared branch.

**`--force` applies to all refspecs in the command.** When `push.default` is
`matching`, or when you list multiple refspecs, `--force` applies to all of
them — not just the one you had in mind. Use the `+` prefix on a specific
refspec to force only that one ref:

```sh
git push origin +feature/rebased
```

**Force-pushing rewrites public history.** Any collaborator who has already
fetched your branch will have a diverged copy after you force-push. They must
run `git fetch` and then reset or rebase on top of your new history. Agree
with your team before force-pushing anything someone else might have checked
out.

**`--force-with-lease` can be defeated by background fetches.** If your editor
or another tool runs `git fetch` automatically, the remote-tracking ref gets
updated even though you have not explicitly reviewed the new commits.
`--force-with-lease` then sees the remote as matching your tracking ref and
permits the push — which may silently overwrite a collaborator's commit. Add
`--force-if-includes` to require that any newly fetched commits appear in your
local reflog before the force push proceeds.

**Pushing tags is not automatic.** `git push` never sends tags unless you add
`--tags` or `--follow-tags`. A newly created tag is invisible to collaborators
until you push it explicitly.

**The pre-push hook can abort a push.** The hook receives the remote name, URL,
and list of refs being updated. If it exits non-zero the push is aborted — this
is intentional. Use `--no-verify` only as a last resort and fix the underlying
hook issue as soon as possible.

**Deleting a remote branch does not delete the local branch.** After
`git push origin --delete feature/done`, your local `feature/done` still
exists. Delete it separately with `git branch -d feature/done`.

## Worked examples

### Pushing a new feature branch

You have finished work on a local branch and want to share it for review.

```sh
# See what you are about to push
git log --oneline origin/main..HEAD
```

```text
3f2a1b8 Add rate limiting to login endpoint
c9d04e1 Extract auth middleware into its own file
```

```sh
# Push and set the upstream in one step
git push -u origin feature/rate-limit
```

```text
Enumerating objects: 11, done.
Counting objects: 100% (11/11), done.
Delta compression using up to 10 threads
Compressing objects: 100% (7/7), done.
Writing objects: 100% (7/7), 1.23 KiB | 1.23 MiB/s, done.
Total 7 (delta 4), reused 0 (delta 0), pack-reused 0
To github.com:acme/api.git
 * [new branch]      feature/rate-limit -> feature/rate-limit
Branch 'feature/rate-limit' set up to track remote branch 'feature/rate-limit' from 'origin'.
```

Future pushes on this branch require only `git push`.

### Safely pushing a rebased branch

A reviewer asked for changes. You rewrote commits with an interactive rebase
(see the *rebase* chapter). The remote branch now diverges from your local one,
so a plain push is rejected.

```sh
git rebase -i origin/main       # rewrite commits
git push --force-with-lease     # push only if nobody else has pushed
```

If a collaborator pushed to the same branch in the meantime, Git refuses:

```text
error: failed to push some refs to 'github.com:acme/api.git'
hint: Updates were rejected because the remote contains work that you do
hint: not have locally.
```

Fetch their work, reconcile, and try again:

```sh
git fetch origin
git rebase origin/feature/rate-limit
git push --force-with-lease
```

### Publishing a release with a tag

```sh
# Create a signed, annotated tag
git tag -a v2.1.0 -m "Release 2.1.0 — add rate limiting"

# Push commits and the new tag together
git push --follow-tags
```

`--follow-tags` sends the commits on the current branch plus any annotated
tags pointing at reachable commits. Lightweight bookmarking tags stay behind.

### Cleaning up a merged branch

```sh
# Confirm the branch is fully merged
git branch -r --merged origin/main | grep feature/done
```

```text
  origin/feature/done
```

```sh
# Delete on the remote and locally
git push origin --delete feature/done
git branch -d feature/done
```

## Recovery

If you pushed commits you did not intend to share, you have two options.

**Safe option — add a revert commit.** Never rewrites history, always safe on
a shared branch. Use the *revert* chapter for the mechanics:

```sh
git revert <bad-commit>
git push
```

**Destructive option — force-push to remove the commit.** Only appropriate if
you are certain nobody has fetched the bad commit yet:

```sh
git reset --hard HEAD~1      # remove the commit locally
git push --force-with-lease  # overwrite the remote
```

If collaborators already have the bad commit, they must run `git fetch` and
realign their local branches to the new remote state — coordinate with them
before doing this.

See *Getting out of jams* for recipes covering diverged branches and
recovering from an accidental force-push.

## See also

- *fetch* — download remote changes without merging; run before pushing when
  the remote may have advanced.
- *pull* — fetch and integrate in one step.
- *remote* — manage remote names and URLs.
- *branch* — list, create, and delete branches before pushing.
- *rebase* — rewrite local history cleanly before pushing to a shared branch.
- *tag* — create the annotated tags that `--follow-tags` will push.
- *Getting out of jams* — recovering from rejected or accidentally overwritten
  pushes.
