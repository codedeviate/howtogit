# revert

Create a new commit that undoes the changes introduced by one or more earlier
commits, leaving the full history intact.

## Mental model

Every commit in Git is permanent — you cannot delete a commit that has already
been shared. `git revert` works around this by going forward, not backward: it
reads the diff that a target commit introduced, flips it (additions become
deletions, deletions become additions), and records the result as a brand-new
commit on top of HEAD.

```text
Before:
  A ── B ── C ── D   (HEAD)

After git revert C:
  A ── B ── C ── D ── C'  (HEAD)
               C' undoes exactly what C added
```

The repository's object database is append-only. C is still there, still
reachable, still auditable. The revert is itself a permanent record: it
documents what was undone and when. This is the fundamental difference between
`revert` and `reset`: `reset` moves a branch pointer to an earlier commit
(rewriting or discarding history), while `revert` adds to history. Use
`revert` whenever the commit you want to undo has already been pushed to a
shared remote.

Internally, reverting is a three-way merge. Git takes the state at the target
commit's parent as the "base", the current HEAD as "ours", and the inverse of
the target diff as "theirs". If other commits have touched the same lines
since the target commit was created, a conflict can arise — the same way
merging two branches can conflict.

## Synopsis

```text
git revert [--[no-]edit] [-n] [-m <parent-number>] [-s] [-S[<keyid>]] <commit>...
git revert (--continue | --skip | --abort | --quit)
```

## Everyday usage

Revert the most recent commit:

```sh
git revert HEAD
# editor opens for the commit message; save and close to complete
```

Revert a specific earlier commit by its hash:

```sh
git revert a3f9c1b
```

Revert without opening the editor (accept the generated message as-is):

```sh
git revert --no-edit HEAD
```

Revert a range of commits, creating one revert commit per original commit:

```sh
git revert --no-edit HEAD~3..HEAD
```

Stage the revert changes but do not commit yet — useful when you want to
combine several reverts into a single commit:

```sh
git revert -n HEAD~2 HEAD~1 HEAD
git commit -m "Revert the broken payment refactor"
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-e`, `--edit` | Open the commit-message editor before committing (default in a terminal) | Explain *why* the commit is being reverted |
| `--no-edit` | Skip the editor and use the generated message | Quick reverts in scripts or when the message is self-explanatory |
| `-n`, `--no-commit` | Apply the inverse diff to the index and working tree but do not commit | Combine several reverts into one commit, or inspect changes before committing |
| `-m <parent-number>` | Specify which parent of a merge commit is the mainline (1-based) | Required when reverting a merge commit, which has two parents |
| `--cleanup=<mode>` | Control how the commit message is cleaned up before storage | Use `scissors` to get a clear conflict-marker section in the message |
| `-s`, `--signoff` | Append a `Signed-off-by` trailer to the message | Projects requiring DCO sign-off |
| `-S[<keyid>]`, `--gpg-sign` | GPG-sign the revert commit | Maintaining a verified-commits policy |
| `--no-gpg-sign` | Override `commit.gpgSign` config for this operation | Suppress signing when it is not needed |
| `--strategy=<strategy>` | Use a specific merge strategy | Rare; prefer the default strategy |
| `-X<option>`, `--strategy-option` | Pass an option to the merge strategy | e.g. `-Xours` to auto-resolve conflicts in favour of HEAD |
| `--rerere-autoupdate` | Let rerere automatically stage its recorded resolution | Speed up repeated conflict resolution on long revert sequences |
| `--no-rerere-autoupdate` | Prevent rerere from auto-staging | Inspect rerere's suggestion before accepting it |
| `--reference` | Use a short `--pretty=reference` citation in the message body instead of the full object name | Cleaner, more readable revert messages |
| `--continue` | Resume a revert sequence after resolving conflicts | After `git add` on conflicted files |
| `--skip` | Skip the current commit in a multi-commit revert sequence | When the commit's changes are already absent and reverting would produce an empty diff |
| `--abort` | Cancel the entire revert sequence and restore HEAD to its pre-revert state | When you decide not to proceed |
| `--quit` | Clear the sequencer state without restoring HEAD | When you have already committed partial reverts and want to stop cleanly |

## Best practices

**Always explain why the commit is being reverted.** Git generates a subject
line for you (`Revert "Add payment gateway"`), but the body contains only
the bare `This reverts commit <hash>.` line. Use the editor to record the
defect number, the incident, or the reasoning. A
future reader looking at `git log` deserves to understand what went wrong.

```text
Revert "Add payment gateway"

This reverts commit a3f9c1b.

The gateway integration broke 3DS authentication for Visa cards
(incident INC-2847). Reverting until the provider fixes their SDK.
```

**Use `--no-edit` only in automation, not in interactive work.** The generated
message is a bare minimum. In CI or scripted hotfix pipelines `--no-edit` is
fine; when you are working interactively, open the editor and add context.

**Combine related reverts with `-n`.** When reverting a feature that spans
several commits, revert them all with `--no-commit` first, then write a
single cohesive commit message that explains the full picture. One revert
commit is easier to read in `git log` than four separate ones.

**Watch commit order when reverting a range.** Git reverts commits in the
range newest-first. If commit B depends on commit A, reverting B before A is
the correct order — which is also the natural order Git uses for a range like
`A..B`.

**Avoid stacking "Reapply Reapply" subject lines.** If you later need to
re-apply a reverted commit, do not blindly revert the revert. Use
`git cherry-pick` on the original commit, or revert the revert but immediately
amend the message to something meaningful and shorter.

## Pitfalls & gotchas

**Reverting a merge commit requires `-m`.** A merge commit has two parents.
Git does not know which parent represents the mainline (the branch you merged
into). Without `-m 1` (or `-m 2`) the command fails with an error. `-m 1`
almost always means "the branch the merge landed on" — verify with
`git log --oneline --graph` before deciding.

**Reverting a merge does not prevent future merges from re-introducing the
same changes.** Once you revert a merge commit, Git considers those commits to
have already been incorporated. If you later re-merge the same branch, only
commits made *after* the original merge are brought in. To re-introduce the
reverted work you must revert the revert commit first, or cherry-pick
individual commits manually.

**A clean working tree is required.** `git revert` refuses to start if you
have uncommitted modifications. Stash or commit your work-in-progress first.

```sh
git stash
git revert HEAD
git stash pop
```

**Conflicts are possible.** If later commits modified the same lines that the
target commit introduced, the three-way merge will conflict. Resolve conflicts
the same way you would during a merge: edit the conflicted files, `git add`
them, then `git revert --continue`. To abandon the revert entirely, run
`git revert --abort`.

**`-n` leaves the index in a modified state.** After `--no-commit`, your
index contains staged revert changes. `git status` shows them as staged files.
This is intentional — finish with `git commit` when you are satisfied with
the combined diff.

**Repeatedly reverting reverts produces unwieldy subject lines.** Reverting a
revert yields `Reapply "Add payment gateway"`, and further reverts nest as
`Reapply "Reapply "<original-subject>""`, and so on indefinitely.
When re-applying previously reverted work, prefer `git cherry-pick` on the
original commit, or rewrite the message after reverting the revert.

## Worked examples

### Reverting a bad hotfix on a shared branch

You merged a hotfix this morning. It broke production. The offending commit is
`d4e9ab2`. The branch has been pushed and your teammates have pulled it, so
rewriting history is off the table.

```sh
# confirm what d4e9ab2 changed before reverting
git show d4e9ab2

# revert it — explain the incident in the editor
git revert d4e9ab2
```

The editor opens with a pre-filled subject line. Add context in the body:

```text
Revert "Fix null check in order processor"

This reverts commit d4e9ab2.

Caused NullPointerException for orders without a shipping address
(incident INC-3012). Reverting until a proper fix is in place.
```

Save, close, and push:

```sh
git push origin main
```

The bad code is gone from the live codebase. Both the original commit and the
new revert commit remain in history, giving a full audit trail.

### Reverting a multi-commit feature in one step

A three-commit feature (API layer, service layer, UI) must be pulled due to a
compliance issue. The commits are `b1`, `b2`, `b3` (oldest to newest). You
want to undo all three in a single, clearly-explained commit.

```sh
# stage the inverse of all three without committing
git revert -n b1 b2 b3
```

Git applies each inverse diff to the index. Review the staged changes:

```sh
git diff --staged
```

When satisfied, commit with a single informative message:

```sh
git commit -m "Revert feature/pci-logging (compliance block)

Reverts commits b1, b2, b3.

PCI-DSS audit found that request-body logging in the API layer
captures raw card numbers. Reverting until a scrubbing layer
is in place. Tracked in JIRA-8821."
```

### Reverting a merge commit

Your team merged `feature/dark-mode` into `main` three days ago. The feature
ships a setting that corrupts user preferences on iOS. You need to revert the
merge.

```sh
# find the merge commit
git log --oneline --graph main | head -15
```

```text
*   f7c3d01 Merge branch 'feature/dark-mode'
|\
| * 9a1b2c3 Add dark-mode toggle
| * 4d5e6f7 Persist theme preference
* | 8g9h0i1 Fix checkout button alignment
```

The merge commit is `f7c3d01`. Its first parent (`8g9h0i1`) is the main branch
tip before the merge; its second parent (`9a1b2c3`) is the feature branch.
Declaring parent 1 as the mainline means "keep what main had; undo what the
feature added":

```sh
git revert -m 1 f7c3d01
```

This produces a commit that restores `main` to its pre-merge state without
touching the commits on `feature/dark-mode` themselves.

## Recovery

To cancel a revert that is in progress (conflicts not yet resolved):

```sh
git revert --abort
```

If the revert has been committed but not yet pushed, roll back with `reset`:

```sh
git reset --soft HEAD~1   # uncommit, keep changes staged
git reset HEAD~1          # uncommit and unstage (working tree intact)
```

If the revert has already been pushed to a shared branch, undo it by reverting
the revert:

```sh
git revert HEAD           # creates a new commit that cancels the last revert
```

See *Getting out of jams* for more undo recipes and guidance on choosing
between `reset`, `restore`, and `revert`.

## See also

- *commit* — the `-m`, `--no-edit`, `-s`, and `-S` flags work the same way.
- *cherry-pick* — applying a specific commit's changes to a different branch;
  the complement of revert.
- *reset* — moving a branch pointer backward; the right tool when history has
  not yet been shared.
- *Getting out of jams* — choosing between revert, reset, and restore.
