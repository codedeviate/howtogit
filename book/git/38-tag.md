# tag

Mark a specific commit with a permanent, human-readable name — typically to
record a release point.

## Mental model

Every commit has a hash: `a3f9c1d…`. Hashes are precise but meaningless to
humans. A tag is a named pointer into the object database that says "this
commit is `v2.4.0`". Once created, the name never moves on its own (unlike a
branch, which advances with every new commit).

Git has two kinds of tags:

- **Lightweight tag.** A bare ref — a file in `refs/tags/` that contains a
  commit hash and nothing more. Think of it as a sticky note.
- **Annotated tag.** A full object stored in the object database. It records
  the tagger name and email, a creation timestamp, a message, and optionally a
  GPG signature. Think of it as a signed certificate.

```text
Lightweight:  refs/tags/v2.4.0 ──> commit a3f9c1d

Annotated:    refs/tags/v2.4.0 ──> tag object ──> commit a3f9c1d
                                   (tagger, date, message, sig)
```

The distinction matters: commands like `git describe` ignore lightweight tags
by default, and many hosting platforms show the annotated tag message on the
release page. Use annotated tags for anything you intend to share.

## Synopsis

```text
# Create
git tag [-a | -s | -u <key-id>] [-f] [-m <msg> | -F <file>] [-e]
        <tagname> [<commit> | <object>]

# List
git tag [-l | --list] [--sort=<key>] [-n[<num>]] [--contains <commit>]
        [--no-contains <commit>] [--points-at <object>]
        [--merged <commit>] [--no-merged <commit>] [<pattern>...]

# Delete
git tag -d <tagname>...

# Verify
git tag -v <tagname>...
```

## Everyday usage

Create an annotated tag at HEAD for a release:

```sh
git tag -a v1.0.0 -m "First stable release"
```

Create a lightweight tag (useful for private bookmarks):

```sh
git tag wip-before-refactor
```

Tag a specific earlier commit by its hash:

```sh
git tag -a v0.9.1 -m "Backfill release tag" 7c3e8a2
```

List all tags:

```sh
git tag
```

List tags matching a pattern (shell wildcard):

```sh
git tag -l 'v1.*'
```

List tags with the first line of their annotation:

```sh
git tag -n
```

List tags with up to three annotation lines:

```sh
git tag -n3
```

Push a single tag to the remote:

```sh
git push origin v1.0.0
```

Push all local tags that the remote does not yet have:

```sh
git push origin --tags
```

Delete a local tag:

```sh
git tag -d v0.9.0-rc1
```

Delete a remote tag:

```sh
git push origin --delete v0.9.0-rc1
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-a`, `--annotate` | Create an unsigned annotated tag object | All public/release tags |
| `-s`, `--sign` | Create a GPG-signed annotated tag using your default key | Release tags that need authenticity guarantees |
| `-u <key-id>`, `--local-user=<key-id>` | Sign with a specific GPG key | Multiple signing identities on one machine |
| `--no-sign` | Override `tag.gpgSign = true` in config | Create an unsigned tag when signing is globally enforced |
| `-f`, `--force` | Replace an existing tag rather than fail | Retag during local-only development; avoid after pushing |
| `-d`, `--delete` | Delete one or more tags by name | Removing a mistaken or superseded tag |
| `-v`, `--verify` | Verify the GPG signature of a tag | Confirming a signed release before using it |
| `-m <msg>`, `--message=<msg>` | Set the tag message from the command line; implies `-a` | Short release notes |
| `-F <file>`, `--file=<file>` | Read the tag message from a file; use `-` for stdin; implies `-a` | Long changelogs or templated messages |
| `-e`, `--edit` | Open the editor even when `-m` or `-F` supplied the message | Fine-tune a scripted or templated message before saving |
| `-l`, `--list` | List tags, optionally filtered by a shell-wildcard pattern | Browsing or scripting tag lists |
| `-n[<num>]` | Print `<num>` lines of the annotation alongside the tag name; implies `--list` | Quick overview of release notes |
| `--sort=<key>` | Sort output by the given key; prefix `-` for descending; `version:refname` sorts semantically | Listing tags in version order |
| `--contains <commit>` | List only tags that contain the given commit; implies `--list` | Finding which releases include a specific fix |
| `--no-contains <commit>` | List only tags that do not contain the given commit | Finding releases before a particular change |
| `--points-at <object>` | List only tags pointing at the given object; implies `--list` | Finding what a specific commit was tagged as |
| `--merged <commit>` | List tags reachable from the given commit | Finding all releases included in a branch |
| `--no-merged <commit>` | List tags not reachable from the given commit | Finding releases not yet integrated |
| `--format=<format>` | Custom output format using `%(fieldname)` placeholders | Scripting and automation |

## Best practices

**Always use annotated tags for releases.** A lightweight tag is just a
pointer; it carries no authorship, no timestamp, and no message. Tools like
`git describe`, hosting platforms, and package managers expect annotated tags.
Run `git tag -a v2.0.0 -m "Release v2.0.0"` — the three extra characters save
you confusion later.

**Follow a consistent naming scheme and stick to it.** The most widely
understood scheme is `v<major>.<minor>.<patch>` following Semantic Versioning
(`v1.4.0`, `v1.4.1`, `v2.0.0-rc1`). Consistency lets shell wildcards work
cleanly (`git tag -l 'v1.4.*'`) and makes `--sort=version:refname` useful.

**Tag the commit, not the branch tip.** A branch tip changes with every push.
Before tagging, confirm you are on the exact commit you intend to mark — check
with `git log -1 --oneline`. If you tag HEAD immediately after merging and
before anyone pushes again, this is usually fine; otherwise supply the commit
hash explicitly.

**Sign release tags when authenticity matters.** If users download release
tarballs or pull your tag by name, a GPG-signed tag lets them verify that the
tag came from you and that the tagged commit has not been replaced. Configure
`user.signingKey` in git config once, then use `git tag -s` for every release.

**Push tags explicitly; do not rely on `--follow-tags` as your only path.**
Tags are not pushed with `git push` by default. A common workflow is to push
the branch, then immediately push the tag:

```sh
git push origin main
git push origin v1.4.0
```

Using `git push --follow-tags` pushes only reachable annotated tags
automatically, but it is easy to forget that the flag exists. An explicit push
makes intent clear in CI logs and scripts.

**Never move a published tag.** Once a tag has been pushed and others may have
fetched it, moving it with `-f` creates a silent divergence: your copy and
their copy point to different commits under the same name. If you tagged the
wrong commit, acknowledge the mistake publicly (see *Pitfalls & gotchas*) and
publish a corrected tag under a new name.

## Pitfalls & gotchas

**Tags are not pushed automatically.** `git push origin main` leaves all your
local tags behind. Many developers have shipped a release and only discovered
the tag was missing when the CI pipeline or package registry tried to read it.
Always push the tag as a separate step.

**Deleting a remote tag requires a separate command.** `git tag -d v0.9.0`
removes the tag locally but leaves it on the remote. To remove both:

```sh
git tag -d v0.9.0
git push origin --delete v0.9.0
```

Forgetting the second step means the tag lives on indefinitely for anyone who
pulls from the remote.

**`-f` after publishing is a trap.** Force-retagging a published tag updates
your local ref and updates the remote if you force-push the tag, but other
people who already fetched the old tag will not receive the update on a normal
`git pull` or `git fetch`. They silently keep the old commit under the same
name. See the On Re-tagging discussion in `git tag --help` and the Recovery
section below for the correct procedure.

**Lightweight tags are invisible to `git describe`.** `git describe` finds the
nearest annotated tag reachable from a commit. If you used lightweight tags
for releases, `git describe` will skip them and either report a much older
annotated tag or fail entirely. Retrofit annotated tags with:

```sh
git tag -a -f v1.2.0 v1.2.0 -m "v1.2.0"
```

(This replaces the lightweight tag locally; push the new object with
`git push origin --force v1.2.0` — after notifying anyone who uses the tag.)

**Pattern-matching requires `-l`.** Running `git tag v1.*` does not list tags
matching `v1.*`; it tries to create a tag named `v1.*`. You need `-l` (or
`--list`) when supplying a pattern:

```sh
git tag -l 'v1.*'   # correct
git tag 'v1.*'      # creates a tag named literally "v1.*"
```

**Tags name objects, not just commits.** You can tag any Git object —
a tree, a blob, even another tag. This is rarely useful in day-to-day work,
but it means `git tag -a` on an arbitrary object hash works. Verify what you
are tagging with `git cat-file -t <hash>` if you are unsure.

## Worked examples

### Tagging a release with a changelog message

Your team is cutting `v3.1.0`. You want the tag to contain a brief changelog
so the release page on GitHub shows useful information.

```sh
# Confirm you're on the right commit
git log -1 --oneline
# a3f9c1d Merge pull request #198: Add retry logic for transient errors

# Write the message in an editor (opens $GIT_EDITOR)
git tag -a v3.1.0

# Or supply it on the command line
git tag -a v3.1.0 -m "$(cat <<'EOF'
Release v3.1.0

Changes since v3.0.2:
- Add retry logic for transient network errors (#198)
- Fix race condition in connection pool teardown (#201)
- Bump minimum Go version to 1.22
EOF
)"

# Push the tag
git push origin v3.1.0
```

On GitHub, the text between the tag name and the end of the message appears
as the release description when you create a release from the tag.

### Sorting tags by version number to find the latest release

Tags sorted lexicographically put `v1.10.0` before `v1.9.0`. Use semantic
version sorting instead:

```sh
git tag -l --sort=-version:refname 'v*'
```

```text
v3.1.0
v3.0.2
v3.0.1
v3.0.0
v2.4.0
...
```

The `-` prefix reverses the order so the newest tag appears first. This is
useful in scripts that need to derive the previous release:

```sh
PREV=$(git tag -l --sort=-version:refname 'v*' | sed -n '2p')
echo "Comparing v3.1.0 against $PREV"
git log ${PREV}..v3.1.0 --oneline
```

### Finding which release first included a specific commit

A bug was fixed in commit `7c3e8a2`. You want to know which release tag
first contained that fix:

```sh
git tag -l --contains 7c3e8a2 --sort=version:refname | head -1
```

```text
v2.3.1
```

The `--contains` filter lists every tag reachable from the given commit.
Sorting by version and taking the first result gives you the earliest release.

### Creating and verifying a signed release tag

Assuming a GPG key is configured (`user.signingKey` in git config):

```sh
git tag -s v4.0.0 -m "Release v4.0.0"
```

Verify the signature before distributing the tag:

```sh
git tag -v v4.0.0
```

```text
object a3f9c1d...
type commit
tag v4.0.0
tagger Alice <alice@example.com> 1750000000 +0200

Release v4.0.0
gpg: Signature made ...
gpg: Good signature from "Alice <alice@example.com>"
```

A collaborator who has imported your public key can run the same `git tag -v`
after fetching the tag to confirm its authenticity.

## Recovery

**Deleted a local tag by mistake.** If the tag still exists on the remote,
fetch it back:

```sh
git fetch origin tag v1.4.0
```

If the tag existed only locally and is gone, you can recreate it by pointing
to the commit hash — find the hash in `git log` or `git reflog`, then:

```sh
git tag -a v1.4.0 <commit-hash> -m "Restore v1.4.0"
```

**Tagged the wrong commit before pushing.** Delete the local tag and recreate
it on the correct commit:

```sh
git tag -d v1.4.0
git tag -a v1.4.0 <correct-commit> -m "Release v1.4.0"
```

**Tagged the wrong commit after pushing.** This is the hard case. Moving a
published tag will confuse anyone who already fetched it. The recommended
approach is to publish a corrected tag under a new name (e.g. `v1.4.1` or
`v1.4.0-fixed`) and announce the mistake. If you must reuse the same name,
tell affected users to delete their local copy and re-fetch:

```sh
# On each affected machine:
git tag -d v1.4.0
git fetch origin tag v1.4.0
```

Then on your side, force-push the corrected tag:

```sh
git tag -f v1.4.0 <correct-commit>
git push --force origin v1.4.0
```

See *Getting out of jams* for broader undo recipes involving published history.

## See also

- *commit* — creating the commits that tags point to.
- *describe* — generating version strings from the nearest annotated tag.
- *push* — getting tags onto the remote with `--tags` or `--follow-tags`.
- *log* — `git log v1.3.0..v1.4.0` to list commits between two tags.
- *Getting out of jams* — recovering from published-history mistakes.
