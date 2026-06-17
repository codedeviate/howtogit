# Getting out of jams: git

Every git user hits a wall at some point — a detached HEAD, a rejected push,
a secret that slipped into a commit. This chapter is an indexed field guide to
those moments. Each entry names the symptom, explains what is really happening,
and gives numbered steps you can copy-paste straight into a terminal.

---

## Detached HEAD

**What it means.** HEAD normally points to a branch name, which in turn
points to a commit. "Detached HEAD" means HEAD points directly to a commit
SHA rather than to any branch. Any commits you make here belong to no branch
and will be garbage-collected once you move away.

**Why it happens.** You checked out a specific commit hash, a tag, or a
remote-tracking reference directly:

```sh
git checkout v1.4.0        # tag
git checkout abc1234       # raw SHA
git checkout origin/main   # remote ref, not a local branch
```

**How to get out.**

1. If you haven't made any commits, just return to a branch:

   ```sh
   git switch main
   # or: git checkout main
   ```

2. If you made commits you want to keep, give them a branch first:

   ```sh
   git switch -c my-experiment
   # Now HEAD is attached to the new branch and your commits are safe.
   ```

3. If you made commits you don't want, simply switch away (they will
   eventually be collected by `git gc`):

   ```sh
   git switch main
   ```

**How to avoid it.** When you want to explore an old commit, create a branch
at the same time: `git switch -c explore-v1.4 v1.4.0`. When checking out a
remote branch, use `git switch feature` (without the `origin/` prefix) — git
will automatically create a local tracking branch named `feature` that follows
`origin/feature`, as long as no local branch of that name already exists.

---

## Merge conflicts and rebase conflicts

**What it means.** Two commits changed the same lines and git cannot decide
which version to keep. It pauses and asks you to resolve the conflict
manually before continuing.

**Why it happens.** During `git merge`, two branches both modified the same
region of a file. During `git rebase`, each replayed commit is applied in
sequence; if a commit conflicts with the current state of the branch, the
rebase pauses at that commit.

**How to get out — merge conflict.**

1. Identify the conflicting files:

   ```sh
   git status
   # "both modified: src/config.js" means there's a conflict
   ```

2. Open each conflicting file. Find the conflict markers and decide what the
   final content should be:

   ```text
   <<<<<<< HEAD
   const timeout = 5000;
   =======
   const timeout = 3000;
   >>>>>>> feature/fast-requests
   ```

   Edit the file to the correct result, removing all `<<<<<<<`, `=======`,
   and `>>>>>>>` lines.

3. Stage the resolved file and finish the merge:

   ```sh
   git add src/config.js
   git merge --continue
   # git will open the editor for the merge commit message
   ```

   Or, if you want to abort entirely and restore the pre-merge state:

   ```sh
   git merge --abort
   ```

**How to get out — rebase conflict.**

1. Resolve the conflicting file the same way as above.

2. Stage the resolved file, then continue the rebase:

   ```sh
   git add src/config.js
   git rebase --continue
   ```

3. If the conflicting commit is empty after resolution (it was entirely
   superseded by a prior commit), skip it:

   ```sh
   git rebase --skip
   ```

4. To abandon the rebase and restore the original branch:

   ```sh
   git rebase --abort
   ```

**How to avoid it.** Rebase onto the target branch frequently rather than
letting branches diverge for weeks. See *rerere* — git can remember how you
resolved a particular conflict and replay that resolution automatically next
time.

---

## "Updates were rejected (non-fast-forward)" on push

**What it means.** The remote branch has commits that your local branch does
not have. Pushing would discard those commits on the remote, so git refuses.

**Why it happens.** Someone else pushed to the same branch while you were
working, or you amended / rebased commits that were already on the remote.

**How to get out.**

*Case 1: Someone else pushed new commits — you just need to integrate them.*

1. Pull the remote changes and rebase your work on top:

   ```sh
   git pull --rebase origin main
   ```

2. Resolve any conflicts that arise (see the previous entry), then push:

   ```sh
   git push origin main
   ```

*Case 2: You rewrote history (amend, rebase) on a branch only you own.*

1. Use `--force-with-lease` instead of `--force`. It pushes only if the
   remote tip matches what you last fetched, protecting against overwriting
   someone else's concurrent push:

   ```sh
   git push --force-with-lease origin my-feature
   ```

**How to avoid it.** Never rebase or amend commits that have been pushed to
a shared branch (e.g. `main`, `develop`). On personal feature branches it
is acceptable, but communicate with your team. Enable branch protection on
`main` to prevent accidental force-pushes.

---

## Committed to the wrong branch

**What it means.** You made one or more commits on `main` (or another branch)
when they should have gone on a feature branch, or vice versa.

**Why it happens.** You forgot to create or switch to a feature branch before
starting work.

**How to get out.**

*Move the last N commits to a new branch (commits not yet pushed).*

1. Create the correct branch at the current HEAD:

   ```sh
   git switch -c feature/my-work
   ```

2. Go back to the original branch and remove the commits with a hard reset:

   ```sh
   git switch main
   git reset --hard origin/main
   # main is now back to the remote tip; feature/my-work has the commits
   ```

   If something goes wrong, the discarded commits are still reachable via
   `git reflog` for ~90 days — see *Recover deleted commits and branches via
   the reflog* later in this chapter.

*Cherry-pick one commit onto an existing branch.*

1. Note the SHA of the commit to move:

   ```sh
   git log --oneline -5
   ```

2. Switch to the target branch and cherry-pick:

   ```sh
   git switch correct-branch
   git cherry-pick <sha>
   ```

3. Remove the commit from where it shouldn't be:

   ```sh
   git switch wrong-branch
   git reset --hard HEAD~1   # if it's the latest commit and not yet pushed
   ```

   As above, if you reset too far, `git reflog` will show you the previous
   HEAD so you can recover.

**How to avoid it.** Run `git branch` or check your shell prompt before
starting work. Many teams configure their prompt to show the current branch.

---

## Undo the last commit — soft vs mixed vs hard reset vs revert

**What it means.** You want to un-do a commit, but the right tool depends on
whether you want to keep the changes and where you want them to land.

**Why it happens.** Wrong message, wrong files staged, premature commit.

**How to get out.** Pick the mode that matches your goal:

| Goal | Command |
|------|---------|
| Keep changes staged, re-commit with a different message | `git reset --soft HEAD~1` |
| Keep changes in working tree (unstaged), re-stage selectively | `git reset HEAD~1` (mixed, the default) |
| Discard the commit and all its changes entirely | `git reset --hard HEAD~1` |
| Undo a commit that is already pushed (safe for shared branches) | `git revert HEAD` |

Steps for each:

1. **Soft reset** — changes remain in the index, ready to recommit:

   ```sh
   git reset --soft HEAD~1
   git commit -m "Better commit message"
   ```

2. **Mixed reset** (default) — changes return to the working tree, unstaged:

   ```sh
   git reset HEAD~1
   # edit / re-stage as needed
   git add -p
   git commit -m "Corrected commit"
   ```

3. **Hard reset** — changes are gone (recoverable via reflog for ~90 days):

   ```sh
   git reset --hard HEAD~1
   ```

4. **Revert** — creates a new commit that undoes the previous one; history
   is preserved and the branch can still be pushed normally:

   ```sh
   git revert HEAD
   # an editor opens for the revert commit message; save and close
   ```

**How to avoid it.** Use `git commit --amend` to fix the most recent commit
message or add a forgotten file, as long as you haven't pushed yet. For
anything beyond the last commit, lean on `git rebase -i`.

---

## Recover deleted commits and branches via the reflog

**What it means.** A branch was deleted, a `git reset --hard` discarded
commits, or a rebase went wrong. The commits appear to be gone.

**Why it happens.** Commits that are no longer reachable from any branch or
tag are "dangling" — git's garbage collector will remove them, but they
remain in the reflog for 90 days by default.

**How to get out.**

1. Inspect the reflog to find the SHA of the lost commit:

   ```sh
   git reflog
   ```

   Output looks like:

   ```text
   8f44520 HEAD@{0}: reset: moving to HEAD~1
   6530db9 HEAD@{1}: commit: Add login validation
   8f44520 HEAD@{2}: commit: Fix null pointer
   ```

   The commit you want is `6530db9`.

2. Restore it to a new branch:

   ```sh
   git switch -c recovered-work 6530db9
   ```

3. Or, if you want to reset the current branch back to that point:

   ```sh
   git reset --hard 6530db9
   ```

For a deleted branch, look at the branch-specific reflog:

```sh
git reflog show deleted-branch-name
```

If the branch is already gone from the reflog listing, check `HEAD` — the
commits will appear there as long as you haven't run `git gc` since the
deletion.

See the *reflog* chapter for the full `@{n}` and time-based syntax.

**How to avoid it.** Before a destructive operation (hard reset, branch
delete, force-push), note the current SHA with `git log --oneline -1`. If
something goes wrong you have the hash ready.

---

## Safely undo a commit that was already pushed

**What it means.** A commit is on a shared branch (e.g. `main`) and needs to
be undone without rewriting history for collaborators.

**Why it happens.** A bug slipped through, a migration script ran, or a file
was accidentally committed.

**How to get out.**

1. Use `git revert` to create a new commit that undoes the bad one. This is
   always safe on shared branches because it only adds a commit:

   ```sh
   git revert <bad-sha>
   git push origin main
   ```

   To revert a merge commit, specify which parent to return to (usually `1`,
   the main-line parent):

   ```sh
   git revert -m 1 <merge-sha>
   ```

2. If you must rewrite history on a branch you own (e.g. a feature branch in
   review), use `--force-with-lease` rather than `--force`:

   ```sh
   git reset --hard HEAD~1
   git push --force-with-lease origin my-feature
   ```

   `--force-with-lease` will refuse if someone else pushed to the branch
   since your last fetch, preventing accidental data loss. The discarded
   commit remains reachable via `git reflog` for ~90 days if you need to
   recover it.

**How to avoid it.** Require pull-request reviews before merging to `main`.
Enable branch protection rules so direct pushes to `main` are blocked.

---

## A secret got committed (and pushed)

**What it means.** A password, API key, private key, or other credential
ended up in a commit. Because the secret is in history — not just the working
tree — deleting the file is not enough.

**Why it happens.** A `.env` file was not listed in `.gitignore`, credentials
were hardcoded for a quick test, or an IDE auto-staged a config file.

**How to get out.**

**Step 0 — rotate the secret immediately.** Assume it is compromised. Revoke
and regenerate the token, key, or password before anything else.

1. Remove the secret from history using `git filter-repo` (preferred over
   the older `git filter-branch`; install it via your package manager):

   ```sh
   git filter-repo --path secrets.env --invert-paths
   # removes secrets.env from every commit in history
   ```

   Or replace the secret value itself everywhere it appears:

   ```sh
   git filter-repo --replace-text <(echo 'MY_SECRET_VALUE==>REDACTED')
   ```

2. Force-push the rewritten history (coordinate with all collaborators first
   — they will need to re-clone or rebase):

   ```sh
   git push --force-with-lease --all
   git push --force-with-lease --tags
   ```

3. Ask GitHub/GitLab/Bitbucket to purge cached views of the old commits
   (each platform has a "cached data" removal tool or support process).

4. Add the file to `.gitignore` so it cannot be accidentally staged again:

   ```sh
   echo "secrets.env" >> .gitignore
   git add .gitignore
   git commit -m "Ignore secrets.env"
   ```

**How to avoid it.** Add secrets files to `.gitignore` before creating them.
Use a secrets manager or environment variables injected at runtime. Install a
pre-commit hook (e.g. `detect-secrets` or `gitleaks`) to scan for credential
patterns before every commit.

---

## "fatal: refusing to merge unrelated histories"

**What it means.** You tried to merge or pull two branches that have no
common ancestor — their histories are completely separate trees.

**Why it happens.** You initialized a repository locally (`git init`) and
then tried to pull from a remote that was initialized separately, or you
are merging two repositories that were never related.

**How to get out.**

1. If the merge is intentional (e.g. importing a separate project), allow it
   explicitly:

   ```sh
   git merge origin/main --allow-unrelated-histories
   # resolve any conflicts, then commit
   ```

2. If you hit this during a `git pull`, pass the flag the same way:

   ```sh
   git pull origin main --allow-unrelated-histories
   ```

**How to avoid it.** When creating a new repository, do not check the "add a
README" box on the hosting service if you already have local commits you plan
to push. Either initialize the remote empty or clone before adding files.

---

## Line-ending / .gitattributes surprises (CRLF/LF)

**What it means.** Files are shown as modified, diffs are full of `^M`
characters, or the same file is checked out differently on Windows versus
macOS/Linux even though nothing meaningful changed.

**Why it happens.** Windows uses CRLF (`\r\n`) and Unix uses LF (`\n`). If
`core.autocrlf` is set inconsistently across contributors, git silently
converts line endings on checkout and commit, creating spurious diffs.

**How to get out.**

1. Add a `.gitattributes` file to the repository root to declare the policy
   once for everyone, regardless of their `core.autocrlf` setting:

   ```sh
   # .gitattributes
   # normalize all text files to LF in the repository
   * text=auto

   # force LF for shell scripts
   *.sh text eol=lf

   # force CRLF for Windows batch files
   *.bat text eol=crlf

   # treat binary files as binary — never touch line endings
   *.png binary
   *.jpg binary
   *.pdf binary
   ```

2. After adding `.gitattributes`, normalize existing files in the working
   tree to match the new policy:

   ```sh
   git add --renormalize .
   git commit -m "Normalize line endings via .gitattributes"
   ```

3. Tell collaborators to re-checkout their working trees after pulling the
   commit, or the stale line endings in their local files will cause spurious
   diffs. Stash or commit any uncommitted changes first — `git reset --hard`
   will discard them:

   ```sh
   git stash          # if you have uncommitted work to preserve
   git rm --cached -r .
   git reset --hard
   git stash pop      # restore stashed work, if applicable
   ```

**How to avoid it.** Commit a `.gitattributes` file as the first commit in
every new repository. The `text=auto` rule is the safe default: git detects
text files and normalizes them to LF in the repository, converting to the
platform line ending on checkout.

---

## Accidentally committed a huge file

**What it means.** A large binary (compiled artifact, dataset, video, log
file) ended up in the repository. Even after deletion, it bloats every clone
because the blob is still in history.

**Why it happens.** The file was not listed in `.gitignore`, or someone ran
`git add .` without thinking.

**How to get out.**

*If the commit is not yet pushed — rewrite locally.*

1. Remove the file from the last commit without touching it on disk:

   ```sh
   git rm --cached path/to/bigfile.bin
   git commit --amend --no-edit
   ```

*If the commit is already pushed — rewrite history.*

1. Use `git filter-repo` to strip the file from every commit:

   ```sh
   git filter-repo --path path/to/bigfile.bin --invert-paths
   ```

2. Force-push all refs:

   ```sh
   git push --force-with-lease --all
   git push --force-with-lease --tags
   ```

3. Collaborators must re-clone or run `git fetch --prune` followed by a
   rebase, because their remotes still reference the old objects.

4. Add the file to `.gitignore` immediately:

   ```sh
   echo "path/to/bigfile.bin" >> .gitignore
   git add .gitignore
   git commit -m "Ignore bigfile.bin"
   ```

For ongoing large-file storage needs, consider Git LFS (`git lfs track
"*.bin"`), which stores large blobs outside the main repository object store.

**How to avoid it.** Maintain a thorough `.gitignore` and never use `git add
.` on directories that may contain build artifacts or data files. A
pre-commit hook that rejects files over a size threshold (e.g. 5 MB) catches
accidents before they reach the repository.

---

## "Unable to create '.git/index.lock'" / stale lock

**What it means.** Git refuses to run because another git process appears to
be using the index.

**Why it happens.** A previous git command crashed or was killed without
cleaning up its lock file. The file `.git/index.lock` is normally created at
the start of an operation and deleted at the end; if the process never
finished, the lock file is left behind.

**How to get out.**

1. Confirm that no other git process is actually running:

   ```sh
   ps aux | grep git
   ```

2. If nothing is running, delete the stale lock file:

   ```sh
   rm -f .git/index.lock
   ```

3. Retry your original command.

**How to avoid it.** Do not kill git processes with `kill -9` (SIGKILL) — use
`Ctrl-C` (SIGINT) which allows the process to clean up. If your IDE and
terminal both run git on the same repository simultaneously, they may
occasionally collide; let one finish before running the other.

---

## Submodule out of sync / empty submodule directory

**What it means.** A subdirectory that should contain a submodule is empty,
or the submodule is pinned to an older commit than what `.gitmodules` or the
parent commit records.

**Why it happens.** The repository was cloned without `--recurse-submodules`,
or the parent repository was updated to point at a newer submodule commit and
you haven't run the update command yet.

**How to get out.**

1. Initialize and fetch any submodules that have never been populated:

   ```sh
   git submodule update --init --recursive
   ```

2. After pulling new commits in the parent repository, bring submodules to
   the commit recorded by the parent:

   ```sh
   git submodule update --recursive
   ```

3. To see which submodules are out of sync:

   ```sh
   git submodule status
   # lines starting with '-' are not initialized
   # lines starting with '+' are checked out at a different commit than recorded
   ```

4. If a submodule URL changed (e.g. the upstream moved), sync the config and
   then update:

   ```sh
   git submodule sync --recursive
   git submodule update --init --recursive
   ```

**How to avoid it.** Clone with `git clone --recurse-submodules <url>`. Set
the global option so future clones always recurse:

```sh
git config --global submodule.recurse true
```

See the *submodule* chapter for the full lifecycle.

---

## HTTPS vs SSH authentication failures

**What it means.** Git fails with "authentication failed", "Permission denied
(publickey)", or "could not read Username" when pushing or fetching.

**Why it happens.**

- **HTTPS:** Your stored credentials are out of date (password changed, token
  expired, or two-factor authentication enabled since you last pushed).
- **SSH:** The public key is not uploaded to the hosting service, or the
  wrong key is being offered (common when you have multiple SSH identities).

**How to get out — HTTPS.**

1. Generate a personal access token (PAT) with repo scope on GitHub/GitLab
   (account settings → developer settings → tokens).

2. Erase the cached credential and try again — git will prompt for the new
   token:

   ```sh
   git credential reject <<EOF
   protocol=https
   host=github.com
   EOF
   git fetch
   ```

   Or, on macOS, clear the keychain entry via Keychain Access and let git
   re-prompt.

**How to get out — SSH.**

1. Check which key is being offered:

   ```sh
   ssh -vT git@github.com 2>&1 | grep "Offering"
   ```

2. If the wrong key is offered, specify the correct one in `~/.ssh/config`:

   ```sh
   Host github.com
       IdentityFile ~/.ssh/id_ed25519_github
       IdentitiesOnly yes
   ```

3. Confirm the public key is uploaded to the hosting service (GitHub:
   Settings → SSH and GPG keys).

4. Test the connection:

   ```sh
   ssh -T git@github.com
   # Expected: "Hi <username>! You've successfully authenticated..."
   ```

**How to avoid it.** Prefer SSH with a key protected by `ssh-agent` for
day-to-day work. For CI/CD environments where SSH keys are impractical, use
short-lived HTTPS tokens scoped to the minimum required permissions.

---

## "detected dubious ownership in repository"

**What it means.** Git refuses to operate on a repository because the
directory is owned by a different user than the one running the git command.

**Why it happens.** Introduced in git 2.35.2 as a CVE fix. Common triggers:

- Running git as root in a directory owned by a regular user (e.g. `sudo git
  pull`).
- A Docker container running as a different UID than the files were created
  with.
- A shared filesystem where the repository was created by a different account
  than the one you're using now.

**How to get out.**

1. The correct fix is to run git as the same user who owns the directory.
   Check who owns it:

   ```sh
   ls -la /path/to/repo | head -3
   ```

2. If this is a trusted repository and you intentionally need to run git as a
   different user (e.g. in a container), mark the directory safe for your
   current user:

   ```sh
   git config --global --add safe.directory /path/to/repo
   ```

   Use `*` only in controlled environments (e.g. a dedicated CI container
   where all content is trusted):

   ```sh
   git config --global --add safe.directory '*'
   ```

3. In Docker, the cleanest fix is to align UIDs:

   ```dockerfile
   RUN useradd -u 1001 appuser
   USER appuser
   ```

**How to avoid it.** Do not mix `sudo git` and regular user git on the same
repository. In containers, make the UID of the running process match the UID
that owns the repository files.
