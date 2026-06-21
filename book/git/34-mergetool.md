# mergetool

Launch a visual or text-based merge tool to resolve conflicts left behind by a
failed merge, rebase, or cherry-pick.

## Mental model

When Git cannot automatically reconcile two sides of a change it writes
conflict markers into the affected file and stops:

```text
<<<<<<< HEAD
result = a + b;
=======
result = a * b;
>>>>>>> feature/multiply
```

Your job is to edit every such file until it contains exactly the code you
want, then tell Git the conflict is resolved with `git add`. Doing that by
hand in a plain text editor works, but it is error-prone: it is easy to
leave a stray `<<<<<<<` line or accidentally delete a closing `}`.

`git mergetool` automates the tedious parts. For each conflicted file it:

1. Extracts three versions into temporary files: `LOCAL` (your branch),
   `REMOTE` (the branch being merged in), and `BASE` (their common
   ancestor).
2. Opens the configured tool with those three inputs and the `MERGED` output
   file.
3. Waits for you to finish resolving, then marks the file as resolved
   (or asks you whether it was resolved, for tools that do not report
   success via their exit code).

```text
                ┌────────────┐
   LOCAL  ──────┤            │
   BASE   ──────┤  mergetool ├────> MERGED (resolved)
   REMOTE ──────┤            │
                └────────────┘
```

Think of it as a structured wrapper around `git add`: the tool gives you a
side-by-side view so you can make an informed decision on every conflict
hunk, then `mergetool` stages the result for you.

## Synopsis

```text
git mergetool [--tool=<tool>] [-y | --[no-]prompt] [<file>...]
```

## Everyday usage

Run the tool on every conflicted file (most common invocation):

```sh
git merge feature/multiply      # merge fails with conflicts
git mergetool                   # open tool for each conflicted file
git commit                      # record the resolved merge
```

Resolve a specific file rather than all conflicts at once:

```sh
git mergetool src/pricing.js
```

Resolve all conflicted files under a directory:

```sh
git mergetool src/
```

Ask which tools are available on your system:

```sh
git mergetool --tool-help
```

Use a specific tool for this one invocation without changing your config:

```sh
git mergetool --tool=meld
```

Skip the per-file pre-invocation prompt (the chance to skip a path before the tool opens):

```sh
git mergetool --no-prompt
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-t <tool>`, `--tool=<tool>` | Use a specific merge tool (e.g. `meld`, `kdiff3`, `vimdiff`) | Override `merge.tool` for a single session |
| `--tool-help` | Print all tools recognised on this system | Discover what is available before configuring |
| `-y`, `--no-prompt` | Skip the per-file pre-invocation prompt (the chance to skip a path before the tool opens). Already the default when `--tool` or `merge.tool` is set. | Batch processing without file-skip prompts |
| `--prompt` | Always prompt before opening each file | Review each file name before the tool launches |
| `-g`, `--gui` | Use `merge.guitool` instead of `merge.tool` | Switch to a graphical tool when a display is available |
| `--no-gui` | Force `merge.tool`, ignoring `merge.guitool` and `mergetool.guiDefault` | Override a GUI default in a headless session |
| `-O<orderfile>` | Process files in the order given by a glob-per-line file | Resolve the most critical files first |

## Best practices

**Set `merge.tool` once in your global config.** Typing `--tool=meld` every
time is friction that leads people to skip the tool entirely. Pick the tool
that matches your workflow and commit to it:

```sh
git config --global merge.tool meld
```

**Disable backup files once you are comfortable.** By default Git writes a
`file.orig` backup beside every resolved file. That safety net is valuable
when you are learning, but it pollutes the working tree and can confuse
`git status`. Once you trust your tool, turn it off:

```sh
git config --global mergetool.keepBackup false
```

**Resolve one file at a time when a conflict is complex.** Pass the filename
explicitly. It is easier to focus on a single file than to tab through ten
in sequence. Come back to the remaining files with another `git mergetool`
call:

```sh
git mergetool src/config.js     # focus here first
# ... later ...
git mergetool                   # handle the rest
```

**Set `mergetool.<tool>.trustExitCode` for reliable tools.** The interactive
"Was the merge successful?" prompt exists because not every tool reports
success via its exit code. If your tool does, suppress the prompt:

```sh
git config --global mergetool.meld.trustExitCode true
git mergetool --no-prompt
```

**Use `mergetool.hideResolved` to reduce noise.** By default `LOCAL` and
`REMOTE` show the raw pre-resolution state. With `hideResolved` enabled Git
overwrites those files so only the hunks that still have conflicts are
visible — auto-resolved hunks disappear from the side panels:

```sh
git config --global mergetool.hideResolved true
```

**Pair `mergetool` with `rerere` on long-lived branches.** If you resolve
the same conflict repeatedly (common on a branch that tracks a fast-moving
main), enabling `rerere` lets Git remember your resolution and reapply it
automatically. See the *rerere* chapter for setup details.

## Pitfalls & gotchas

**The `.orig` files land in version-controlled directories.** If
`mergetool.keepBackup` is `true` (the default), Git writes `*.orig` files
next to every resolved file. Add `*.orig` to your global `.gitignore` or
they will eventually slip into a commit:

```sh
echo '*.orig' >> ~/.gitignore
git config --global core.excludesFile ~/.gitignore
```

**Closing the tool without saving does not automatically abort.** Most tools
exit with a non-zero code when you quit without writing, and `mergetool`
will ask whether the merge was successful. Answer `n` to skip the file —
Git leaves it conflicted so you can try again. If you answered `y` by
mistake, the conflict markers may still be present in the staged file. Check
with `git diff --check` before committing.

**`git mergetool` does not commit for you.** After the tool exits, the
resolved files are staged, but you must still run `git commit` to record the
merge. Forgetting this step leaves the repository in a mid-merge state that
confuses later commands.

**The continuation command differs depending on what caused the conflict.**
After a conflicted rebase you run `git rebase --continue` instead of
`git commit`. After a conflicted cherry-pick you run
`git cherry-pick --continue`. Running `git commit` directly in those
contexts creates a stray commit rather than advancing the rebase or
cherry-pick. See the *rebase* and *cherry-pick* chapters for details.

**Custom tools must set `mergetool.<tool>.cmd` correctly.** The four
environment variables `BASE`, `LOCAL`, `REMOTE`, and `MERGED` are exported
by Git before invoking the command. Getting the argument order wrong (some
tools expect `local remote base merged`) is a common source of confusing
three-way diffs. Test with a simple conflict before relying on a custom
tool in production.

**`--tool-help` output varies by platform.** The list is built from what
Git finds in `$PATH` at the time you run it. A tool that is installed but
not on `$PATH` will not appear. If your preferred tool is missing, verify
its binary is reachable before debugging the Git configuration.

## Worked examples

### Resolving a merge conflict with meld

Your branch `feature/pricing` diverged from `main`. A colleague also
touched `src/pricing.js` on `main` and the merge fails.

```sh
git switch feature/pricing
git merge main
```

```text
Auto-merging src/pricing.js
CONFLICT (content): Merge conflict in src/pricing.js
Automatic merge failed; fix conflicts and then commit the result.
```

Launch meld (assuming `merge.tool = meld`):

```sh
git mergetool src/pricing.js
```

Meld opens with three panels: LOCAL (your version) on the left, BASE in
the centre, REMOTE (the incoming side) on the right. Use the arrow buttons
to pull hunks from either side, edit the output panel directly for anything
that needs a custom blend, then save and close.

Git stages the result automatically. Finish the merge:

```sh
git commit
```

Git opens your editor with a pre-filled merge commit message. Save and
close to record the commit.

### Batch-resolving many files after a rebase

You are rebasing a long-running integration branch onto a new base commit
and fifteen files have conflicts.

```sh
git rebase --onto main upstream/main integration
```

```text
CONFLICT (content): Merge conflict in src/api/auth.js
CONFLICT (content): Merge conflict in src/api/users.js
... (13 more) ...
error: could not apply a1b2c3d... Add user session handling
```

Resolve them all in one pass, skipping the per-file prompt:

```sh
git mergetool --no-prompt
```

The tool opens once per file. Resolve and save each one; the tool advances
automatically. After the last file, continue the rebase:

```sh
git rebase --continue
```

If further commits in the rebase also have conflicts, the cycle repeats
until the rebase is complete.

### Setting up vimdiff with a custom layout

The default vimdiff layout opens four windows (LOCAL, BASE, REMOTE across
the top, MERGED filling the bottom). If you prefer three columns without
BASE you can configure a custom layout:

```sh
git config --global merge.tool vimdiff
git config --global mergetool.vimdiff.layout "LOCAL,MERGED,REMOTE"
```

Launch it:

```sh
git mergetool --tool=vimdiff
```

Vim opens with LOCAL on the left, MERGED (the editable buffer) in the
centre, and REMOTE on the right. Edit MERGED, resolve each conflict, then
save and quit:

```text
:wq      " save and mark as resolved
:cq      " quit without saving — mergetool will ask whether to retry
```

To use Neovim instead, set `--tool=nvimdiff` and configure
`mergetool.nvimdiff.layout` independently (it falls back to the vimdiff
layout if not set).

### Configuring a custom tool

Any editor or diff program can be wired in via `mergetool.<tool>.cmd`. The
shell command has access to four variables set by Git: `$BASE`, `$LOCAL`,
`$REMOTE`, and `$MERGED`.

Example using `kdiff3` at a non-standard path:

```sh
git config --global merge.tool kdiff3
git config --global mergetool.kdiff3.path /opt/local/bin/kdiff3
```

Example using an entirely custom invocation:

```sh
git config --global merge.tool myfancytool
git config --global mergetool.myfancytool.cmd \
  'myfancytool "$LOCAL" "$REMOTE" "$BASE" -o "$MERGED"'
git config --global mergetool.myfancytool.trustExitCode true
```

Verify the tool is recognised:

```sh
git mergetool --tool-help
```

## Recovery

If you want to abandon the resolution and start the underlying operation
over from scratch, abort it rather than trying to manually unwind staged
files:

```sh
# If you are mid-merge:
git merge --abort

# If you are mid-rebase:
git rebase --abort

# If you are mid-cherry-pick:
git cherry-pick --abort
```

Each command restores the working tree and index to the state before the
operation began. Any `.orig` backup files written by `mergetool` are left
behind — remove them with:

```sh
git clean -f "*.orig"
```

If you already ran `git commit` on a bad resolution, see *Getting out of
jams* for how to undo a merge commit or revert a botched resolution without
losing history.

## See also

- *merge* — the command that produces the conflicts `mergetool` resolves.
- *rebase* — conflicts during rebase are resolved the same way; continue
  with `git rebase --continue`.
- *cherry-pick* — conflicts during cherry-pick; continue with
  `git cherry-pick --continue`.
- *rerere* — record and replay conflict resolutions to avoid resolving the
  same conflict twice.
- *Getting out of jams* — how to abort a merge, undo a bad resolution, or
  recover a lost working-tree state.
