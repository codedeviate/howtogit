# format-patch

Turn commits into email-ready patch files that can be reviewed, applied, and
archived outside of a shared repository.

## Mental model

`git format-patch` serialises commits as UNIX mailbox messages. Each commit
becomes one `.patch` file (or one mbox message on stdout) containing three
parts:

1. An email header — `From:`, `Date:`, and `Subject:` derived from the commit
   author, date, and first line of the commit message.
2. The remainder of the commit message as the email body.
3. The diff itself, separated from the body by a line containing only `---`.

```text
Commit object  ──format-patch──>  0001-fix-login.patch
                                   ├── email headers  (From, Date, Subject)
                                   ├── commit message body
                                   ├── ---
                                   └── diff -p --stat output
```

The fixed timestamp `Mon Sep 17 00:00:00 2001` in the `From` line is a magic
marker that tools like `file(1)` use to recognise format-patch output rather
than a real mailbox.

The round-trip counterpart is `git am`, which reads these files and replays the
commits. Because the patch carries author identity and the full log message,
the resulting commit is faithful to the original — not a squash or a
cherry-pick with a generic message.

This mechanism predates GitHub pull requests. It remains the contribution
workflow for projects like the Linux kernel and Git itself, which conduct code
review on mailing lists. Even when email is not the delivery channel, the
format is useful: the files are self-documenting, can be archived, and apply
cleanly with `git am`.

## Synopsis

```text
git format-patch [-<n>] [--stdout] [-o <dir>]
                 [--cover-letter] [--subject-prefix=<prefix>]
                 [--to=<email>] [--cc=<email>]
                 [-v <n> | --reroll-count=<n>]
                 [--in-reply-to=<message-id>] [--thread[=<style>]]
                 [--rfc[=<rfc>]] [--base[=<commit>]]
                 [--notes[=<ref>]] [--interdiff=<previous>]
                 [--range-diff=<previous>]
                 [<common-diff-options>]
                 [ <since> | <revision-range> ]
```

## Everyday usage

Export every commit on the current branch that is not in `origin/main`:

```sh
git format-patch origin/main
```

Git writes one numbered `.patch` file per commit in the current directory:

```text
0001-Add-rate-limiting-to-login-endpoint.patch
0002-Extract-token-validation-into-a-helper.patch
```

Export only the last three commits:

```sh
git format-patch -3
```

Export a specific range and write the files to a `patches/` directory:

```sh
git format-patch -o patches/ origin/main..HEAD
```

Export exactly one commit by its hash:

```sh
git format-patch -1 a3f9c1b
```

Preview all patches concatenated to stdout — useful for piping to `git am`:

```sh
git format-patch --stdout origin/main
```

Apply those patches on another branch in one step:

```sh
git format-patch --stdout origin/main | git am -3
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-<n>` | Export the topmost `<n>` commits | Quick single- or few-commit export |
| `-o <dir>` | Write files into `<dir>` (created if absent) | Keep patches out of the repo root |
| `--stdout` | Print all patches to stdout as one mbox stream | Piping directly to `git am` |
| `--cover-letter` | Generate a `0000-cover-letter.patch` with a shortlog and diffstat | Multi-patch series; fill in summary before sending |
| `--subject-prefix=<prefix>` | Replace the default `[PATCH]` tag in the subject line | Per-project conventions, e.g. `[PATCH subsystem]` |
| `--to=<email>` | Add a `To:` header to every generated message | Embed recipient so `git send-email` picks it up |
| `--cc=<email>` | Add a `Cc:` header to every generated message | Copy maintainers or reviewers automatically |
| `-v <n>` / `--reroll-count=<n>` | Mark the series as the `<n>`-th revision; prepends `v<n>` to filenames and appends it to the subject prefix (e.g. `[PATCH v2 1/3]`) | Resending a revised patch series after review |
| `--rfc[=<rfc>]` | Prepend `RFC` (or custom string) before `PATCH` in subject | Experimental patches sent for discussion, not application |
| `--in-reply-to=<message-id>` | Set `In-Reply-To:` so the patch threads under an existing message | Responding to a review thread on a mailing list |
| `--thread[=<style>]` | Add `In-Reply-To` and `References` headers to thread the series (`shallow` or `deep`) | Keep a series readable as a thread in mail clients |
| `--ignore-if-in-upstream` | Skip any commit whose patch content is already reachable from the upstream | Avoid resubmitting already-merged work |
| `--always` | Include commits that introduce no change (normally omitted) | Carry documentation-only or merge-point commits |
| `--base[=<commit>]` | Record the base tree information block in the first message | Help reviewers identify which tree the series applies to |
| `--notes[=<ref>]` | Append git notes after the `---` line | Carry review commentary that is not part of the commit message |
| `--interdiff=<previous>` | Insert an interdiff into the cover letter | Show reviewers what changed between patch series versions |
| `--range-diff=<previous>` | Insert a range-diff into the cover letter | Alternative to `--interdiff`; uses `git range-diff` format |
| `-n` / `--numbered` | Always include `n/m` numbering in the subject, even for a single patch | Consistency when series size varies across revisions |
| `-N` / `--no-numbered` | Never include `n/m` numbering | Single patches that should not look like part of a series |
| `--start-number <n>` | Start the sequence at `<n>` instead of 1 | Appending to an existing partially-sent series |
| `--numbered-files` | Use plain numbers as filenames, without the commit subject appended | Scripting workflows that do not need human-readable names |
| `--signature=<sig>` / `--no-signature` | Override or suppress the Git version signature appended to each patch | Cleaner output; suppress the default `-- \n2.x.y` trailer |
| `--suffix=.<sfx>` | Change the filename extension from `.patch` | Some review tools or mail filters expect `.txt` |
| `-s` / `--signoff` | Add a `Signed-off-by:` trailer using your committer identity | Projects requiring DCO sign-off |
| `-k` / `--keep-subject` | Do not strip or add `[PATCH]` from the first line of the commit message | Preserving custom subject prefixes already in the message |
| `--binary` | Include binary diffs; implies `--full-index` automatically | Patches that add images or other binary assets |
| `--root` | Treat the revision argument as a range even when it is a single commit | Export everything from the very first commit |
| `-q` / `--quiet` | Suppress the list of generated filenames on stdout | Scripting |

## Best practices

**Export into a dedicated directory.** Running `git format-patch -o patches/
origin/main` keeps the generated files out of the repository root and away
from `git status` noise. Add `patches/` to `.gitignore` if you work this way
regularly.

**Add a cover letter for any series longer than one patch.** A cover letter
gives reviewers the big picture: what the series does, how it is structured,
and any context that does not fit in individual commit messages. Generate it
with `--cover-letter` and fill in the `*** SUBJECT HERE ***` and
`*** BLURB HERE ***` placeholders before sending.

**Number revisions with `--reroll-count`.** When you revise a series after
review feedback, use `-v 2`, `-v 3`, and so on. The subject becomes
`[PATCH v2 1/3]` and filenames gain a `v2-` prefix so reviewers can tell
iterations apart and mail threads stay separate.

```sh
git format-patch --cover-letter -v 2 -o /tmp/myfeature-v2/ origin/main
```

**Use `--in-reply-to` to continue a thread.** When a reviewer posted comments,
grab the `Message-ID` of that message and thread your reply onto it:

```sh
git format-patch \
  --in-reply-to="<20260615123456.12345-1-reviewer@example.com>" \
  origin/main
```

Your revised series lands in the same mail thread rather than starting a new
one.

**Verify patches apply cleanly before sending.** Test the generated files on a
clean branch using `git am`. Discovering whitespace corruption or a wrong base
after sending wastes reviewers' time.

```sh
git checkout -b test-apply origin/main
git am /tmp/patches/*.patch
```

**Set per-project defaults in git config.** If a project requires a fixed
prefix or a default recipient, add a `[format]` section to the local config
rather than typing the same flags every time:

```sh
git config format.subjectPrefix "PATCH net"
git config format.to "netdev@vger.kernel.org"
git config format.coverLetter auto
git config format.outputDirectory /tmp/patches
```

## Pitfalls & gotchas

**Merge commits are silently dropped.** `format-patch` skips merge commits
entirely — a plain patch file cannot represent a merge. If your branch
contains merges, the series will not match the topology of the original
history. Rebase onto the target branch first (see the *rebase* chapter) to
produce a linear series before exporting.

**Email clients corrupt whitespace.** Sending patches through webmail (Gmail,
Outlook web) or through Thunderbird with word-wrap enabled mangles diff context
lines. Corrupted context lines cause `git am` to fail with "patch does not
apply". Use `git send-email` which sends raw text over SMTP, or test by sending
a patch to yourself and applying it with `git am` before submitting.

**`--thread` and `git send-email` threading conflict.** `git send-email` adds
its own threading headers by default. If you also run `git format-patch
--thread`, the two interact and the `In-Reply-To` chain can be wrong. Either
let `send-email` handle threading (the default) or pass `--no-thread` to
`send-email` when you want `format-patch` to control threading instead.

**The default output is the current directory.** Running `git format-patch
origin/main` drops `.patch` files right next to your source files unless you
use `-o`. This clutters `git status` output.

**`--stdout` produces an mbox stream, not individual files.** Writing
`git format-patch --stdout origin/main > all.mbox` gives you a single mbox
file. Apply it with `git am < all.mbox`, not by listing individual patch files.

**`--ignore-if-in-upstream` compares patch content, not commit hashes.** A
commit that was cherry-picked with a different message still matches if the
diff is identical. Conversely, a commit with a trivial rebase conflict
resolution that changes one context line will not match and will be included
unexpectedly. Always review the output before sending.

**File names are truncated at 64 bytes by default.** Very long commit subjects
produce shortened filenames. Adjust with `--filename-max-length=<n>` if your
project's tooling expects the full subject in the filename.

## Worked examples

### Submitting a small feature series to a mailing list

You have three commits on `feature/rate-limit` that are not yet in
`origin/main`.

```sh
# Generate patches with a cover letter into a dedicated directory
git format-patch \
  --cover-letter \
  --subject-prefix="PATCH net" \
  --to="netdev@vger.kernel.org" \
  --cc="alice@example.com" \
  -o /tmp/rate-limit-v1/ \
  origin/main
```

This produces:

```text
/tmp/rate-limit-v1/0000-cover-letter.patch
/tmp/rate-limit-v1/0001-Add-rate-limit-infrastructure.patch
/tmp/rate-limit-v1/0002-Wire-rate-limiter-into-login-handler.patch
/tmp/rate-limit-v1/0003-Add-rate-limit-tests.patch
```

Open `0000-cover-letter.patch`, replace the placeholder subject and body, then
send with `git send-email`:

```sh
git send-email /tmp/rate-limit-v1/*.patch
```

### Revising a series after review feedback

A reviewer asked you to split the second commit and tighten the error messages.
After making the changes the branch now has four commits. Mark the new export
as v2 and include a range-diff so reviewers see exactly what changed:

```sh
git format-patch \
  --cover-letter \
  --reroll-count=2 \
  --subject-prefix="PATCH net" \
  --to="netdev@vger.kernel.org" \
  --in-reply-to="<20260615123456.12345-1-reviewer@example.com>" \
  --range-diff=feature/rate-limit-v1 \
  -o /tmp/rate-limit-v2/ \
  origin/main
```

Filenames now begin with `v2-` and each subject reads `[PATCH net v2 n/m]`.
The `--range-diff` flag inserts a diff-of-diffs in the cover letter so
reviewers immediately see what changed between v1 and v2 without reading every
patch from scratch.

### Transferring commits between machines without a shared remote

You have local commits on a laptop that the target machine cannot reach via a
remote.

On the laptop:

```sh
git format-patch --stdout origin/main > ~/Desktop/feature.mbox
```

Copy `feature.mbox` to the target machine (via USB, `scp`, etc.), then:

```sh
# On the target machine, on a clean branch tracking origin/main
git am -3 ~/feature.mbox
```

The `-3` flag asks `git am` to attempt a three-way merge if a patch does not
apply cleanly, which is more forgiving when the base has diverged slightly.

### Exporting a single historic commit by hash

You want to export commit `a3f9c1b` regardless of where it sits in history:

```sh
git format-patch -1 a3f9c1b -o /tmp/
```

This writes exactly one file, for example
`0001-Fix-off-by-one-in-parser.patch`, without any context about the
surrounding branch.

## Recovery

If `git am` chokes on a patch file you generated, abort and inspect:

```sh
git am --abort
```

Common causes and fixes:

- **Whitespace corruption** — regenerate with `git format-patch` and apply
  with `git am --whitespace=fix` to auto-correct trailing-whitespace issues.
- **Base mismatch** — check out the commit the patch was made against (or use
  `git am -3` to fall back to a three-way merge).
- **Merge commits in the range** — rebase the branch to linearise history
  before re-running `format-patch`.

If you accidentally generated patches with the wrong range or options, simply
delete the `.patch` files and re-run `git format-patch`. No repository state
is modified by generating patches.

See *Getting out of jams* for broader undo recipes, including recovering from a
partially applied `git am` session.

## See also

- *am* — apply patch files produced by `format-patch`.
- *send-email* — send the generated `.patch` files via SMTP without a GUI mail
  client.
- *rebase* — linearise a branch before exporting, and collapse fixup commits
  with `--autosquash` before generating the series.
- *commit* — writing good commit messages that become good patch subjects.
- *cherry-pick* — an alternative way to transplant individual commits when
  email delivery is not needed.
- *range-diff* — compare two versions of a patch series directly, outside of
  the cover-letter context.
