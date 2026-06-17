# commit

Record a snapshot of the staging area into the repository as a permanent
commit object.

## Mental model

The index (staging area) is a draft of your next commit. You build that draft
incrementally with `git add`, then freeze it with `git commit`. The commit
command does three things in sequence:

1. Writes the current index contents as a tree object in the object database.
2. Creates a commit object pointing to that tree, the current HEAD as parent,
   and your identity and timestamp as metadata.
3. Advances the current branch pointer to the new commit.

Nothing in the working tree changes. Files you have not staged are untouched.
Files you staged become part of history and are now safe to modify again.

```text
Working tree ──git add──> Index ──git commit──> Repository
                                                └── branch pointer advances
```

## Synopsis

```text
git commit [-m <msg>] [-a] [--amend] [--fixup=<commit>] [--squash=<commit>]
           [-s] [-S[<key-id>]] [-p] [-C <commit>] [-c <commit>]
           [--allow-empty] [--no-verify] [--date=<date>]
           [--author=<author>] [-- <pathspec>...]
```

## Everyday usage

Create a commit with a message on the command line:

```sh
git add src/login.js tests/login.test.js
git commit -m "Add login validation with rate limiting"
```

Open the configured editor to write a multi-line message:

```sh
git add -p          # interactively stage hunks
git commit          # editor opens with diff summary at the bottom
git commit -p       # or skip the staging step: pick hunks and commit in one go
```

Stage all modified and deleted tracked files, then commit in one step:

```sh
git commit -a -m "Fix typo in error message"
```

Amend the most recent commit (message, contents, or both):

```sh
git add forgotten-file.js
git commit --amend --no-edit    # add the file, keep the existing message
git commit --amend              # rewrite the message in the editor
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-m <msg>` | Set the commit message from the command line | Short, single-line messages |
| `-a` | Auto-stage all tracked modified/deleted files | Skip `git add` for quick fixes |
| `--amend` | Replace the previous commit with a new one | Fix the last commit before pushing |
| `--no-edit` | Keep the existing message when amending | Add a forgotten file silently |
| `--fixup=<commit>` | Create a `fixup!` commit targeting `<commit>` | Prep for `rebase --autosquash` |
| `--squash=<commit>` | Create a `squash!` commit targeting `<commit>` | Like `--fixup` but lets you edit the combined message |
| `-s` | Append a `Signed-off-by` trailer | Projects requiring DCO sign-off |
| `-S[<key-id>]` | GPG-sign the commit | Verified commits on GitHub/GitLab |
| `-p` / `--patch` | Interactively choose which hunks to stage and commit | Commit only part of a file's changes |
| `-C <commit>` | Reuse the message and authorship of `<commit>` exactly | Cherry-pick workflows |
| `-c <commit>` | Like `-C` but opens the editor to let you modify | Edit a message from another commit |
| `--allow-empty` | Permit a commit that introduces no file changes | Trigger CI, mark a deployment point |
| `--no-verify` | Skip the pre-commit and commit-msg hooks | Emergency; understand why the hook failed first |
| `--date=<date>` | Override the author date | Backfill work done at a known time |
| `--author=<author>` | Override the commit author | Committing on behalf of someone else |

## Best practices

**Write the subject line in the imperative mood, 50 characters or fewer.**
Think of it as completing the sentence "If applied, this commit will...".
"Add login validation" is right. "Added login validation" and "Adding login
validation" are not. The 50-character limit keeps it readable in `git log
--oneline`, GitHub pull-request lists, and email subjects.

**Separate the subject from the body with a blank line.** Many tools (GitHub,
`git shortlog`, `git format-patch`) split on that blank line. Without it the
entire message is treated as a subject.

**Explain the *why*, not the *what*.** The diff already shows what changed.
The commit message is the only place to record the context: the bug being
fixed, the constraint being respected, the decision that was made.

```text
Throttle login attempts to 5 per minute per IP

Brute-force attempts were succeeding in staging because the previous
rate limiter only counted by username, not source IP. CVE-2026-1234.

Refs: #412
```

**Stage deliberately, not with `git commit -a`.** The `-a` flag bypasses the
staging area entirely. It is convenient for solo work but can accidentally
include debug code, half-finished changes, or unrelated fixes in the same
commit.

**Keep commits small and focused.** Each commit should represent one logical
change. Reviewers can understand and approve small commits; large omnibus
commits make `git bisect` and `git revert` painful.

**Use `--fixup` to keep history clean during review cycles.** When a reviewer
asks for a change to commit `abc1234`, add a fixup commit and autosquash when
the branch is merged rather than amending in place.

## Pitfalls & gotchas

**Amending after pushing rewrites history.** `--amend` produces a new commit
object with a different hash. Any remote that already has the old commit will
diverge. Only amend commits that exist solely on your local machine. If you
have already pushed, ask yourself whether a follow-up commit is acceptable
instead.

**`-a` does not stage new (untracked) files.** It stages modifications and
deletions of already-tracked files. A new file you created this session is
invisible to `-a`; you must `git add` it explicitly.

**Empty commits are allowed with `--allow-empty` but confuse tools.** `git
bisect`, `git cherry-pick`, and some CI systems treat every commit as
potentially meaningful. Use empty commits sparingly and comment why in the
message.

**Hooks run by default.** The pre-commit hook runs linters, formatters, or
tests. If it fails, the commit is aborted — this is intentional. Use
`--no-verify` only as a last resort and fix the underlying issue as soon as
possible.

**The `--date` flag sets the author date, not the committer date.** If you
need to set both, use `GIT_COMMITTER_DATE` in the environment.

## Worked examples

### Staging only part of a file

You have made two unrelated edits to `api.js` — a bug fix and a refactor —
and want them in separate commits.

```sh
git add -p api.js
```

Git presents each changed hunk and asks: stage this hunk? (`y` yes, `n` no,
`s` split into smaller hunks, `e` edit manually). Stage just the bug-fix hunks
and commit:

```sh
git commit -m "Fix null-pointer dereference in parseToken"
```

Then stage and commit the refactor:

```sh
git add api.js
git commit -m "Extract token validation into a helper"
```

### Cleaning up a branch with fixup commits

Your branch has three commits. A reviewer asks you to fix a typo that was
introduced in the first commit (`a3f9c1`).

```sh
git add src/config.js
git commit --fixup=a3f9c1
```

Git creates a commit titled `fixup! Add environment config loader`.

When the branch is approved and ready to merge, squash the fixup in:

```sh
git rebase -i --autosquash origin/main
```

Git moves the `fixup!` commit immediately after `a3f9c1` and marks it for squash.

The result is a clean history without the typo ever appearing.

### Signing a commit with GPG

Assuming a GPG key is configured (`user.signingKey` in git config):

```sh
git commit -S -m "Release v1.4.0"
```

Verify the signature:

```sh
git log --show-signature -1
```

GitHub displays a "Verified" badge next to signed commits when the key is
uploaded to your account.

## Recovery

To undo the last commit while keeping the changes staged:

```sh
git reset --soft HEAD~1
```

To undo the last commit and unstage the changes (but keep them in the working
tree):

```sh
git reset HEAD~1
```

See *Getting out of jams* for more undo recipes, including recovering commits
that have been amended away.

## See also

- *What git really is* — the index (staging area) explained.
- *add* — building the index before committing.
- *rebase* — `--autosquash` to collapse fixup commits.
- *Getting out of jams* — undoing commits safely.
