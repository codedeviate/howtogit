# bisect

Use binary search across commit history to find the exact commit that
introduced a bug or changed a property of the project.

## Mental model

Imagine 1 000 commits between a version you know works and the HEAD you
know is broken. Testing every commit by hand would take hours. Binary
search cuts that to roughly ten steps: test the commit in the middle,
decide "still broken" or "this one works", and halve the remaining range.
That is exactly what `git bisect` automates.

When you start a session you hand Git two anchor points: one commit where
the behaviour is **bad** and one where it was **good**. Git checks out the
midpoint, you test it and report back, and Git narrows the window. After
log₂(N) rounds it prints the first bad commit and leaves `refs/bisect/bad`
pointing at it.

```text
good ──────────────────────────────────── bad (HEAD)
          ^            ^            ^
          step 1       step 2       step 3
          "good"       "bad"        "bad" → culprit found
```

The working tree is **checked out** at each candidate commit, so your build
and test tooling runs against the real source code at that point in history.
When the session is finished, `git bisect reset` returns you to where you
started.

Git does not have to be searching for a regression. If the two poles are
called **old** and **new** instead of good and bad, you can locate the
first commit where any property appears — a fix, a naming change, a
performance improvement.

## Synopsis

```text
git bisect start [--term-(bad|new)=<term> --term-(good|old)=<term>]
                 [--no-checkout] [--first-parent]
                 [<bad> [<good>...]] [--] [<pathspec>...]
git bisect (bad|new|<term-new>)  [<rev>]
git bisect (good|old|<term-old>) [<rev>...]
git bisect skip       [(<rev>|<range>)...]
git bisect reset      [<commit>]
git bisect terms      [--term-(good|old) | --term-(bad|new)]
git bisect (visualize|view)
git bisect log
git bisect replay     <logfile>
git bisect run        <cmd> [<arg>...]
git bisect help
```

## Everyday usage

### Manual bisect — three-step session

```sh
git bisect start
git bisect bad              # current HEAD is broken
git bisect good v1.8.0      # this tag was working

# Git checks out the midpoint.
# Build/test, then mark it:
git bisect good             # or: git bisect bad

# Repeat until Git prints the culprit:
# "abc1234 is the first bad commit"

git bisect reset            # restore HEAD and clean up
```

### Supply anchors on the start line

```sh
git bisect start HEAD v1.8.0 -- src/
# HEAD is bad, v1.8.0 is good, only consider commits touching src/
```

### Automated bisect with a test script

```sh
git bisect start HEAD v1.8.0 --
git bisect run ./scripts/check.sh
git bisect reset
```

`check.sh` exits 0 when the build/test passes (good) and 1 when it fails
(bad). Git drives the whole search without further input.

### Skip an untestable commit

```sh
git bisect skip                  # skip the currently checked-out commit
git bisect skip v2.5..v2.6       # skip an entire range
```

### Inspect progress

```sh
git bisect log                   # show every decision made so far
git bisect visualize             # open gitk (or git log) showing candidates
git bisect visualize --oneline   # compact list in the terminal
```

## Key options

| Option / subcommand | What it does | When to use it |
|---------------------|--------------|----------------|
| `start` | Begin (or restart) a bisect session | Always the first step |
| `bad [<rev>]` | Mark a commit as bad (contains the bug) | After each checkout, or at start |
| `good [<rev>]` | Mark a commit as good (bug absent) | After each checkout, or at start |
| `skip [<rev>...]` | Tell Git to skip untestable commits | Build broken, flaky test, unrelated failure |
| `reset [<commit>]` | End the session and restore HEAD | When done or abandoning mid-session |
| `run <cmd>` | Automate by delegating to a script | When you have a reliable pass/fail test |
| `log` | Print the record of all decisions | Reviewing progress; saving for replay |
| `replay <file>` | Re-execute a saved log | Recovering from a wrong mark |
| `visualize` / `view` | Open gitk or `git log` on remaining suspects | Quick visual sanity-check |
| `terms` | Show which terms (good/bad or custom) are active | Mid-session reminder |
| `--no-checkout` | Update `BISECT_HEAD` but do not touch the working tree | Non-filesystem tests |
| `--first-parent` | Follow only first-parent on merge commits | Pinning regressions to a merge, ignoring branch history |
| `--term-bad=<term>` / `--term-new=<term>` | Use a custom label instead of "bad" | Searching for a fix, a new feature, a performance change |
| `--term-good=<term>` / `--term-old=<term>` | Use a custom label instead of "good" | Same as above, paired with `--term-bad`/`--term-new` |

## Best practices

**Mark the anchors precisely before you start searching.** The wider your
good–bad range, the more steps bisect needs. If you have a rough idea
which release introduced the problem, start from there rather than the
project's first commit. Every halving you do manually with a tighter range
saves a round inside the session.

**Automate whenever you have a reliable test.** A hand-run bisect is error-
prone: it is easy to mark a commit wrong after a distraction. `git bisect
run` eliminates that risk. Even a one-liner is enough:

```sh
git bisect run sh -c "make -q && ./bin/test_case"
```

**Use `skip` freely for build failures unrelated to the bug.** If the
midpoint commit simply does not compile due to an unrelated issue, skip it.
Git will find another candidate nearby. Do not mark it bad — that would
poison the search.

**Restrict the search with a pathspec.** If you know the bug lives in a
subsystem, pass `-- <path>` to `start`. Git will only consider commits that
touched those paths, dramatically reducing the search space.

```sh
git bisect start HEAD v2.0.0 -- lib/auth/
```

**Save the log before resetting.** If you might need to redo or audit the
session, capture it first:

```sh
git bisect log > bisect-session.log
git bisect reset
```

**Use custom terms when searching for a non-regression.** Labelling commits
"broken" and "fixed", or "slow" and "fast", makes the session self-
documenting and avoids the confusion of calling a desired state "bad".

```sh
git bisect start --term-old broken --term-new fixed
git bisect fixed            # HEAD has the fix
git bisect broken v3.0.0    # this tag is before the fix
```

## Pitfalls & gotchas

**Forgetting to call `reset` leaves your repo mid-session.** If you close
the terminal and come back, `git status` will show `(no branch, bisect in
progress)`. Run `git bisect reset` to escape.

**Marking a commit wrong invalidates all subsequent decisions.** A single
incorrect "good" or "bad" causes the algorithm to converge on the wrong
commit. If you suspect a mistake, check `git bisect log`, fix the file,
reset, and replay (see Recovery).

**`skip` adjacent to the culprit produces an ambiguous result.** If the
commit immediately before or after the real culprit is skipped, Git will
report a range of two commits rather than a single one. This is not a bug —
it is honest uncertainty. You still have to narrow the last step manually.

**`--first-parent` changes what counts as "reachable".** On a history with
many merge commits it gives cleaner attribution (you learn which merge
brought the bug in), but it may skip commits that are actually reachable
through a branch parent. Use it intentionally.

**Exit codes for `bisect run` are strict.** Exit 0 means good, 1–124 and
126–127 mean bad. Exit 125 means skip. Any other value aborts the session.
In particular, `exit(-1)` in C becomes 255 after truncation — that aborts
bisect. Make sure your test script's exit codes are well-defined.

**Dirty working trees block checkout.** Bisect checks out a different
commit at every step. If you have uncommitted changes that conflict, Git
will refuse to proceed. Either stash the changes before starting or use
`--no-checkout` if your test does not need a clean tree.

**Bisect history is stored in `.git`.** The session state lives in
`.git/refs/bisect/` and `.git/BISECT_*` files. Deleting the repo or
running `git bisect reset` removes it. Do not confuse "bisect reset" with
any destructive action — it is safe and idempotent.

## Worked examples

### Finding a regression in a web app

A feature that worked in the `v4.2.0` release is broken on `main`. You
have a test script `scripts/smoke.sh` that exits 0 on success.

```sh
git bisect start main v4.2.0 --
git bisect run scripts/smoke.sh
```

After roughly twelve steps, Git prints:

```text
d7a3c89f is the first bad commit
commit d7a3c89f...
Author: Jane Dev <jane@example.com>
Date:   Thu Mar 14 09:22:00 2026

    Refactor session token generation
```

```sh
git bisect reset
```

You now know exactly which commit to examine.

### Locating the commit that introduced a fix (alternate terms)

You have a security bug that was patched somewhere between `v3.0.0` and
`HEAD`, and you want to back-port the fix to an older branch. You need the
exact commit that introduced the fix.

```sh
git bisect start --term-old vulnerable --term-new patched
git bisect patched          # HEAD is already patched
git bisect vulnerable v3.0.0
```

At each step, run your security check and mark accordingly:

```sh
git bisect patched          # this commit has the fix
git bisect vulnerable       # this commit does not
```

Git converges and prints the first "patched" commit — the exact change you
want to cherry-pick.

```sh
git bisect reset
git cherry-pick <found-commit>
```

### Handling a mix of testable and untestable commits

A migration script broke the database schema at some point, but several
intermediate commits also have an unrelated build failure. Use `skip` to
step over them.

```sh
git bisect start HEAD v5.0.0 --
# Git checks out a candidate:
make 2>&1 | grep -q "Build failed" && git bisect skip || ./run_tests.sh
# or use a script that returns 125 on build failure:
git bisect run ./scripts/test-with-skip.sh
git bisect reset
```

`test-with-skip.sh`:

```sh
#!/bin/sh
make || exit 125          # skip commits that do not build
./run_tests.sh            # exit 0 = good, 1 = bad
```

### Reviewing and correcting a mistake mid-session

Halfway through a session you realise you marked step 3 incorrectly.

```sh
git bisect log > /tmp/bisect-correction.log
# Edit the file and remove the incorrect line, e.g.:
# Delete: git bisect good abc9876
git bisect reset
git bisect replay /tmp/bisect-correction.log
# Continue from the corrected state
```

## Recovery

If you are stuck inside a bisect session unexpectedly:

```sh
git bisect reset        # return to original HEAD, clear all bisect state
```

To return to the identified bad commit rather than the original HEAD:

```sh
git bisect reset bisect/bad
```

If you marked commits incorrectly and the search converged on the wrong
answer, save the log, edit out the bad marks, reset, and replay as shown in
the worked example above.

See *Getting out of jams* for broader undo recipes when bisect leaves
unrelated changes in the working tree.

## See also

- *log* — navigating history to choose good/bad anchor points.
- *commit* — keeping commits small and focused makes bisect faster and its
  results more actionable.
- *revert* — once bisect identifies the culprit commit, revert it cleanly.
- *cherry-pick* — back-port the identified fix commit to another branch.
- *Getting out of jams* — recovering a detached HEAD or unexpected working
  tree state left by a bisect session.
