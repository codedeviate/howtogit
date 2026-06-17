# request-pull

Generate a formatted summary asking an upstream project to pull your changes.

## Mental model

`git request-pull` is an email-first workflow tool that predates GitHub pull
requests by years. The Linux kernel, Git itself, and many other projects that
operate over mailing lists still use it today.

The mental model is simple: you have pushed your work to a public repository
that the upstream maintainer can reach. You now need to send them a message
that says "starting from commit X, please pull everything up to commit Y from
this URL". `git request-pull` writes that message for you. It prints to
standard output — you then paste or pipe it into your email client.

The output contains three parts:

1. The branch description (from `git branch --edit-description`, if set).
2. A `git log`-style summary of the commits between `<start>` and `<end>`.
3. The URL and ref the upstream should pull from.

Git verifies that the `<end>` commit is actually reachable at the given URL
and emits a warning if the two do not match. This catches the common mistake
of generating a pull request before the push has completed.

```text
Local branch ──git push──> Public repo
                                │
                        git request-pull
                                │
                                ▼
                    Formatted message ──email──> Upstream maintainer
```

## Synopsis

```text
git request-pull [-p] <start> <URL> [<end>]
```

## Everyday usage

The typical workflow: you have branched from a tag or commit that the upstream
already has, done some work, pushed it to your public fork, and now want to
ask the upstream to pull.

Generate a pull request message from tag `v2.3` to your current HEAD:

```sh
git request-pull v2.3 https://github.com/you/project
```

Send the output directly to your email client (here, `mutt`):

```sh
git request-pull v2.3 https://github.com/you/project | mutt -s "Pull request: add TLS 1.3 support" maintainer@example.org
```

Include the full patch text in the message body (useful for small changes
where you want the maintainer to review inline without fetching):

```sh
git request-pull -p v2.3 https://github.com/you/project
```

When your local branch name differs from the remote branch name — for example
you pushed `feature/tls` as `for-upstream` — use the `<local>:<remote>`
syntax for `<end>`:

```sh
git push origin feature/tls:for-upstream
git request-pull v2.3 https://github.com/you/project feature/tls:for-upstream
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-p` | Include patch text in the output | Small patches you want reviewable inline, or projects that prefer patch-in-email |
| `<start>` | The commit already in upstream history to begin the summary from | Always required; typically a tag (`v1.0`) or a known shared commit |
| `<URL>` | The repository URL the upstream should fetch from | Always required; must be publicly reachable by the maintainer |
| `<end>` | The commit to end the summary at (defaults to `HEAD`); accepts `<local>:<remote>` | When your local ref name differs from the pushed ref name |

## Best practices

**Push before you run `git request-pull`.** The command checks whether the
tip commit is reachable at the given URL. If it is not, Git warns you. Always
verify the push succeeded before generating the message.

**Use a tag or a well-known shared commit as `<start>`.** The `<start>`
argument names a commit that the upstream already has. Using a release tag
(`v1.0`, `v2.3.1`) is unambiguous. Using a branch name from the upstream
(such as `origin/main`) works too, but the resolved commit may advance between
your push and the maintainer's pull, making the log summary incomplete.

**Set a branch description to give context.** Maintainers appreciate a short
paragraph explaining what a series does before they read the commit list. Set
one with:

```sh
git branch --edit-description
```

`git request-pull` includes that description at the top of the output
automatically.

**Use the `<local>:<remote>` form when you rename on push.** Kernel
contributors routinely push a topic branch under a different remote name
(`master:fixes-for-v6.9`). Without the colon form, Git generates the wrong
fetch refspec in the output and the maintainer's pull will fail.

**Redirect output to a file for review before sending.** Long patch series
benefit from a quick sanity check:

```sh
git request-pull v2.3 https://github.com/you/project > /tmp/pull-request.txt
less /tmp/pull-request.txt
```

## Pitfalls & gotchas

**Warning: "No match for commit ... found at ..."** Git could not find your
`<end>` commit at the given URL. The most common cause is forgetting to push,
or pushing to a different remote than the one in the URL. Re-push and
regenerate.

**`<start>` must be in upstream history, not just your local history.** If
you pass a commit that the upstream does not have, the log summary covers more
than you intend and the maintainer cannot identify where to start the merge.
Always anchor to a shared tag or the upstream's branch tip.

**The generated URL and ref must be fetchable by the maintainer.** A URL on
`localhost` or an SSH remote that only you can reach is useless. Use an HTTPS
or public SSH URL for a hosting service (GitHub, GitLab, kernel.org) that the
maintainer can actually clone from.

**`-p` can produce very large output.** For a series of dozens of commits,
the patch output can run to thousands of lines. Many mailing lists reject
messages above a certain size. For large series, omit `-p` and let the
maintainer fetch; reserve `-p` for single-patch submissions.

**`git request-pull` does not send email.** It only prints to stdout. Piping
directly into `git send-email` does not work the way `format-patch` does —
use your regular mail client or a script to deliver the output.

## Worked examples

### Submitting a patch series to a mailing list

You maintain a fork of an open-source library. Upstream tags releases. You
have three commits built on top of `v4.1.0` that add WebSocket support, and
you have pushed them to your public fork.

```sh
# Push the work
git push origin websocket

# Verify the branch is live at the URL
git ls-remote https://github.com/you/library websocket
# 3a8f9c1  refs/heads/websocket

# Generate the pull-request message
git request-pull v4.1.0 https://github.com/you/library websocket
```

The output looks like:

```text
The following changes since commit d4e7a12... (v4.1.0):

  Release 4.1.0 (2026-03-10 14:22:01 +0000)

are available in the git repository at:

  https://github.com/you/library websocket

for you to fetch changes up to 3a8f9c1...:

  Add WebSocket handshake negotiation (2026-06-01 09:15:00 +0100)

----------------------------------------------------------------
Alice Smith (3):
      Add WebSocket frame parser
      Add WebSocket handshake negotiation
      Add integration tests for WebSocket echo server

 lib/websocket.c         | 182 +++++++++++++++++++++++++++++
 lib/websocket.h         |  38 ++++++
 tests/websocket_test.c  |  94 +++++++++++++++
 3 files changed, 314 insertions(+)
```

Copy this output, add a brief cover note at the top, and send to the project
mailing list.

### Pushing under a different remote branch name

The upstream project asks contributors to push to a branch named `for-<maintainer>`.
Your local branch is `fix/null-deref`.

```sh
# Push local branch under the name the project expects
git push origin fix/null-deref:for-torvalds

# Generate the message with the local:remote form for <end>
git request-pull v6.9 https://git.kernel.org/pub/scm/linux/kernel/git/you/linux fix/null-deref:for-torvalds
```

Git uses `fix/null-deref` to identify the local tip commit for the log
summary, and emits `for-torvalds` as the ref name the maintainer should fetch.
Without the colon form, Git would look for a ref named `fix/null-deref` on
the remote and fail to match.

### Including the patch for a single-commit fix

For a one-liner documentation fix, some maintainers prefer to receive the
patch inline rather than fetching a whole branch.

```sh
git push origin fix-typo
git request-pull -p v3.0 https://github.com/you/docs fix-typo
```

The `-p` flag appends the full patch text after the summary, giving
the maintainer everything they need to review and apply without cloning.

## Recovery

`git request-pull` is read-only: it never modifies the repository. If the
generated output is wrong, simply re-run with corrected arguments.

If you sent a pull request message with the wrong URL or the wrong `<start>`
commit, send a follow-up email to the mailing list noting the correction and
include the corrected `git request-pull` output.

If the upstream has already attempted a pull and gotten nothing (because you
had not pushed yet), push your branch and ask them to retry with `git fetch`
followed by `git merge FETCH_HEAD`, or resend the corrected request.

See *Getting out of jams* for help undoing any local commits before the push
stage.

## See also

- *format-patch* — create patch files suitable for `git am` or mailing list
  submission when the upstream does not want a fetch URL.
- *send-email* — send `format-patch` output directly from the command line.
- *am* — how the upstream applies a patch series received by email.
- *push* — the required step before `git request-pull` to make your commits
  publicly reachable.
- *Getting out of jams* — undoing local commits before they are pushed.
