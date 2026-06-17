# send-email

Send a collection of commits as formatted patch emails directly to a mailing
list or maintainer.

## Mental model

Many open-source projects — the Linux kernel, Git itself, U-Boot, and
hundreds more — accept contributions through email rather than pull requests.
A contributor emails patches to a mailing list; maintainers review them inline,
reply with comments, and eventually apply the accepted patches with
`git am`.

`git send-email` is the bridge between your local commits and that email
workflow. It reads one or more patch files (typically produced by
`git format-patch`), opens an SMTP connection, and delivers each patch as a
proper RFC 2822 email. Threading, reply-to chains, cover letters, and Cc
lists are all handled automatically.

```text
Local commits
   └─ git format-patch ──> .patch files
                               └─ git send-email ──> SMTP ──> mailing list
```

Think of `git format-patch` as your word processor (it shapes the content)
and `git send-email` as your mail client (it delivers it). The two are
designed to be used together, but `send-email` also accepts raw mbox files
or revision ranges, so you can pass format-patch arguments directly on the
command line and skip the intermediate files entirely.

## Synopsis

```text
git send-email [<options>] (<file>|<directory>)...
git send-email [<options>] <format-patch-options>
git send-email --dump-aliases
git send-email --translate-aliases
```

## Everyday usage

### Configure SMTP once, then send patches

Add your mail server settings to `~/.gitconfig` (or the repo's `.git/config`
for project-specific accounts):

```sh
git config --global sendemail.smtpServer smtp.gmail.com
git config --global sendemail.smtpServerPort 587
git config --global sendemail.smtpEncryption tls
git config --global sendemail.smtpUser you@gmail.com
```

### Send the last commit

```sh
git send-email HEAD~1
```

`send-email` runs `format-patch` internally, generates the patch file, and
prompts for `To:`, `Cc:`, and subject if they are not configured.

### Send a range of commits

```sh
git send-email origin/main..my-feature
```

Each commit becomes one email. They are threaded as replies to the first
email in the series by default.

### Generate patch files first, review them, then send

```sh
git format-patch --cover-letter -o outgoing/ origin/main
# edit outgoing/0000-cover-letter.patch to fill in the summary
git send-email outgoing/
```

Separating the two steps gives you a chance to inspect the exact bytes that
will be sent before committing to delivery.

### Do a dry run before sending

```sh
git send-email --dry-run origin/main
```

`--dry-run` performs every step — generates patches, resolves recipients,
prints what it would do — without opening an SMTP connection. Use this to
catch addressing mistakes before they reach the list.

### Annotate patches interactively before sending

```sh
git send-email --annotate outgoing/
```

Your editor opens for each patch so you can add notes or adjust headers
before delivery.

## Key options

### Composing

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--to=<address>` | Set the primary `To:` recipient(s) | Required; the mailing list or maintainer address |
| `--cc=<address>` | Add a `Cc:` address | Cc a co-author or subsystem reviewer |
| `--bcc=<address>` | Add a `Bcc:` address | Blind-copy yourself or an archive |
| `--from=<address>` | Override the sender address | When your committer identity differs from your mail account |
| `--subject=<string>` | Set the email subject (first patch or cover letter) | Rarely needed; `format-patch` sets this from the commit title |
| `--in-reply-to=<msg-id>` | Thread the series as a reply to an existing Message-ID | Re-rolling a patch series so it nests under the original thread |
| `--compose` | Open an editor to write a cover-letter-style introduction | Send a short explanation before the first patch |
| `--annotate` | Open each patch in an editor before sending | Review and add notes to individual patches |
| `--reply-to=<address>` | Set a `Reply-To:` header | Redirect replies to a different address than `--from` |

### Sending

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--smtp-server=<host>` | SMTP server hostname or IP | Specify your mail provider's server; defaults to localhost if unset and no sendmail binary is found |
| `--smtp-server-port=<port>` | Override the default port | Use `587` for STARTTLS submission |
| `--smtp-encryption=<tls\|ssl>` | Encryption mode (`tls` = STARTTLS, `ssl` = implicit TLS on port 465) | Always use one of these; never send on plain port 25 |
| `--smtp-user=<user>` | SMTP authentication username | Required by most hosted mail providers |
| `--smtp-pass[=<pw>]` | SMTP password (omitting the whole option lets `git credential` prompt) | Avoid putting passwords on the command line |
| `--smtp-auth=<mechanisms>` | Restrict SMTP-AUTH mechanisms (e.g. `PLAIN LOGIN`) | When your server requires a specific mechanism |
| `--no-smtp-auth` | Disable SMTP authentication | Relay-only servers on localhost |
| `--sendmail-cmd=<cmd>` | Use a local sendmail-compatible binary instead of SMTP | When routing through `msmtp`, `sendmail`, etc. |
| `--batch-size=<n>` | Reconnect after every *n* messages | Some servers (e.g. smtp.163.com) cap messages per session |
| `--relogin-delay=<sec>` | Wait this many seconds before reconnecting | Use with `--batch-size` |

### Threading and recipients

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--[no-]thread` | Add `In-Reply-To`/`References` headers (on by default) | Disable only for lists that reject threaded patches |
| `--[no-]chain-reply-to` | Each patch replies to the previous one (chained) vs. all reply to the first (off by default) | Enable for deeply threaded review workflows |
| `--[no-]signed-off-by-cc` | Auto-Cc addresses from `Signed-off-by` trailers (on by default) | Disable when you do not want all signers notified |
| `--suppress-cc=<category>` | Stop auto-Cc for `self`, `author`, `sob`, `body`, `all`, etc. | Prevent self-Cc, or tighten who gets notified |
| `--cc-cmd=<command>` | Run a command once per patch to generate extra Cc addresses | Automated per-patch routing based on changed files |

### Administering

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--dry-run` | Do everything except send | Always run this first on an unfamiliar list |
| `--confirm=<mode>` | When to pause for confirmation: `always`, `never`, `cc`, `compose`, `auto` | `always` for peace of mind; `never` for scripted sends |
| `--[no-]validate` | Check patches for lines over 998 chars and run `sendemail-validate` hook | On by default; only disable if a hook is incorrectly blocking valid patches |
| `--quiet` | Print one line per email instead of verbose output | CI or scripted sends |
| `--force` | Send even if safety checks fail | Last resort |
| `--dump-aliases` | Print configured alias names, one per line | Inspect which aliases are available |

## Best practices

**Configure SMTP credentials in `~/.gitconfig`, not on the command line.**
Passwords typed on the command line appear in shell history. Set
`sendemail.smtpUser` and rely on `git credential` for the password:

```sh
git config --global sendemail.smtpUser you@example.com
# git-credential prompts on first use, then caches the password
```

**Always do a `--dry-run` before sending to a real list.** A mis-addressed
patch reaching a high-traffic kernel mailing list is embarrassing and
cannot be recalled. `--dry-run` costs nothing.

**Use `format-patch --cover-letter` for series of more than one patch.**
A cover letter gives reviewers context before they read individual patches.
Edit the generated `0000-cover-letter.patch` to explain the motivation,
any design choices, and what has changed since the previous version.

**Thread re-rolls under the original series.** When you revise patches
after review feedback, use `--in-reply-to` with the Message-ID of your
original cover letter (or first patch). This keeps the entire discussion
in one thread, making it easy for maintainers to track the history.

```sh
git send-email --in-reply-to="<20260101123456.1234-1-you@example.com>" \
               -v2 origin/main
```

**Let `--signed-off-by-cc` stay enabled.** The default behaviour of
auto-Cc'ing anyone in a `Signed-off-by` trailer is intentional: those
people already agreed to be associated with the work and should see the
review discussion.

**Store per-project addresses in a `sendemail.identity` subsection.** If
you contribute to multiple lists with different To/Cc defaults, use
identities rather than typing addresses each time:

```ini
[sendemail "kernel"]
    to = linux-kernel@vger.kernel.org
    cc = subsystem-maintainer@example.com
    smtpUser = you@example.com
```

Then send with:

```sh
git send-email --identity=kernel origin/main
```

**Use `--suppress-cc=self` when you don't want to Cc yourself.** By
default your own address can end up in the Cc list when it appears in
trailer lines. Suppress it with:

```sh
git config --global sendemail.suppressCc self
```

## Pitfalls & gotchas

**Gmail requires an app password or OAuth2, not your account password.**
Google disabled regular password authentication for SMTP. Generate an
app-specific password at `security.google.com/settings/security/apppasswords`,
or configure `smtpAuth = OAUTHBEARER` with a credential helper. Trying
to authenticate with your normal password will produce an authentication
error.

**Microsoft Outlook no longer supports app-specific passwords.**
For `smtp.office365.com` you must use OAuth2 with `smtpAuth = XOAUTH2`.
`git send-email` automatically applies `--outlook-id-fix` for that server
because Outlook rewrites Message-IDs and breaks threading otherwise. Use
`--no-outlook-id-fix` only if you are sure the server does not rewrite
Message-IDs.

**Patches can arrive out of order if your MTA reorders messages.**
Threading via `In-Reply-To` depends on Message-IDs being preserved end-to-end.
Some corporate mail gateways strip or rewrite these headers. Use
`--smtp-debug=1` to watch the SMTP conversation and confirm Message-IDs are
being transmitted correctly.

**`--chain-reply-to` is off by default for a reason.** Chained threading
(each patch replying to the previous) makes following a series harder in
most MUAs. Stick with the default (all patches reply to the first message)
unless the target list specifically requires chained mode.

**Line-length validation catches real problems.** The `--validate` flag (on
by default) warns when a patch contains lines over 998 characters, the
RFC 5322 limit. This usually means a generated file ended up in the diff.
Split the commit or use `--transfer-encoding=quoted-printable` only if you
understand why the long lines are necessary.

**The `sendemail.*` config namespace conflicts with `sendmail.*`.** If you
have any `sendmail.*` variables in your git config (a common mistake),
`git send-email` will abort with a warning. Remove or rename those keys,
or set `sendemail.forbidSendmailVariables = false` to suppress the check.

**Passwords in config files are stored in plain text.** Set only
`sendemail.smtpUser` in `.gitconfig` and let `git credential` handle the
password. Never commit a config file that contains `smtpPass`.

## Worked examples

### Sending a single bug-fix patch to a mailing list

Your fix is in one commit on top of `origin/main`. The target list is
`patches@example-project.org`.

```sh
# Generate and inspect the patch first
git format-patch -1 HEAD -o /tmp/fix/
cat /tmp/fix/*.patch     # verify Subject, diff, and trailers

# Dry run
git send-email --to=patches@example-project.org --dry-run /tmp/fix/

# Send for real
git send-email --to=patches@example-project.org /tmp/fix/
```

On first run you will be prompted for your SMTP password. After that,
`git credential` caches it.

### Sending a multi-patch series with a cover letter

You have three commits that together implement a new feature. You want to
send them to the list as a numbered series with an introductory cover letter.

```sh
# Format patches: cover letter plus three numbered patches
git format-patch --cover-letter -n -o outgoing/ origin/main

# Fill in the cover letter subject and body
# (the generated file has placeholder text)
${EDITOR:-vi} outgoing/0000-cover-letter.patch

# Dry run to confirm addressing
git send-email --to=patches@example-project.org --dry-run outgoing/

# Send
git send-email --to=patches@example-project.org outgoing/
```

The resulting thread looks like:

```text
[PATCH 0/3] Implement feature X
  [PATCH 1/3] Add data model for X
  [PATCH 2/3] Wire up the API handler
  [PATCH 3/3] Add tests for X
```

### Re-rolling a series after review feedback

The maintainer asked for changes. You amend the commits, then re-send
as version 2, threaded under the original cover letter so the full
discussion history is in one place.

Find the Message-ID of your original cover letter from the list archive
or your sent-mail folder — it looks like
`<20260601090000.1234-1-you@example.com>`.

```sh
# Format v2 patches with the version tag
git format-patch --cover-letter -v2 -o outgoing-v2/ origin/main

# Edit the cover letter to summarize what changed since v1
${EDITOR:-vi} outgoing-v2/v2-0000-cover-letter.patch

# Send v2 as a reply to the v1 cover letter
git send-email \
    --to=patches@example-project.org \
    --in-reply-to="<20260601090000.1234-1-you@example.com>" \
    outgoing-v2/
```

The list now sees:

```text
[PATCH 0/3] Implement feature X           ← v1 original
  [PATCH 1/3] Add data model for X
  ...
  [PATCH v2 0/3] Implement feature X      ← v2 nested under v1
    [PATCH v2 1/3] Add data model for X
    ...
```

### Using msmtp instead of direct SMTP

If your environment blocks outbound SMTP or you prefer a local MTA,
route through `msmtp`:

```sh
git config --global sendemail.sendmailCmd "/usr/bin/msmtp"
# msmtp reads its own ~/.msmtprc for server and credentials
git send-email --to=patches@example-project.org outgoing/
```

`--sendmail-cmd` overrides `--smtp-server`; the two cannot be used together.

## Recovery

**Wrong recipient — email already sent.** Email cannot be recalled.
Send a follow-up to the same list/address acknowledging the error and,
if needed, resend the corrected patch with a note explaining the mistake.

**Sent to the right list but forgot `--in-reply-to` for a re-roll.**
The new series will appear as a separate thread. Reply manually to both
threads pointing to the other, so readers can find the full context.

**Authentication failure mid-series (some patches sent, some not).**
Note which patches were sent (check your outbox or the list archive),
then resend only the remaining patches by passing those specific `.patch`
files instead of the whole directory. Use `--in-reply-to` with the
Message-ID of the last successfully delivered patch so threading is
preserved.

**Accidentally sent a draft with placeholder text in the cover letter.**
Resend the full series with a corrected cover letter and add a note at the
top explaining the previous send was in error. Use `--in-reply-to` to
thread it under the draft so the context is clear.

See *Getting out of jams* for general advice on undoing local history
mistakes before they reach a mailing list.

## See also

- *format-patch* — generates the `.patch` files that `send-email` delivers.
- *am* — the receiving end: applies mailed patches to a repository.
- *commit* — `--signoff` adds the `Signed-off-by` trailer that mailing-list
  projects require.
- *Getting out of jams* — recovering from history mistakes before sending.
