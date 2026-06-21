# release

Create, inspect, and manage GitHub Releases — versioned snapshots of your
project paired with release notes and downloadable assets.

## Mental model

A GitHub Release wraps three things together: a **git tag** (the exact
commit being released), **release notes** (human-readable changelog), and
zero or more **binary assets** (compiled binaries, checksums, archives).

Releases live in the GitHub UI at the `Releases` tab and are surfaced by
package managers, CI scripts, and users who want a stable download without
cloning the full repository.

The lifecycle has three phases:

1. **Draft** — created but invisible to the public. Useful for staging notes
   and assets before the announcement.
2. **Published** — visible. May be flagged as `prerelease` (alpha/beta) or
   as `latest` (the default download users see).
3. **Immutable** — once a repository enables release immutability, a
   published release's tag and assets are locked. Draft releases remain
   editable until published.

`gh release` mirrors this lifecycle exactly. You can create a draft, upload
assets, edit notes, then flip it to published — or do it all in one command.
Tags are created automatically from the default branch if they do not already
exist; use `--verify-tag` to enforce that the tag must already exist first.

## Synopsis

```text
gh release create  [<tag>] [<files>...]
gh release list    [flags]
gh release view    [<tag>]
gh release edit    <tag>
gh release delete  <tag>
gh release download [<tag>] [flags]
gh release upload  <tag> <files>...
gh release delete-asset <tag> <asset-name>
gh release verify  [<tag>]
gh release verify-asset [<tag>] <file-path>
```

All subcommands accept `-R`/`--repo [HOST/]OWNER/REPO` to target a repository
other than the one inferred from the current directory.

## Everyday usage

### Listing releases

See what has been shipped:

```sh
gh release list
```

```text
TITLE         TYPE    TAG NAME    PUBLISHED
v2.1.0        Latest  v2.1.0      about 2 days ago
v2.0.1                v2.0.1      about 3 weeks ago
v2.0.0                v2.0.0      about 2 months ago
v1.9.0-rc1    Pre-    v1.9.0-rc1  about 3 months ago
```

Exclude drafts and pre-releases to see only stable releases:

```sh
gh release list --exclude-drafts --exclude-pre-releases
```

### Viewing a release

Inspect the latest release:

```sh
gh release view
```

Inspect a specific tag:

```sh
gh release view v2.1.0
```

Open it in a browser:

```sh
gh release view v2.1.0 --web
```

### Creating a release interactively

Run without arguments and `gh` walks you through a prompt sequence:

```sh
gh release create
```

### Creating a release non-interactively

The most common one-liner for a new stable release:

```sh
gh release create v2.2.0 --title "v2.2.0" --notes "Bug fixes and performance improvements."
```

Let GitHub generate the changelog automatically from merged pull requests:

```sh
gh release create v2.2.0 --generate-notes
```

Use notes from an annotated git tag:

```sh
gh release create v2.2.0 --notes-from-tag
```

Create a draft first, review it in the browser, then publish later:

```sh
gh release create v2.2.0 --draft --title "v2.2.0" --notes-file CHANGELOG.md
```

Mark a release as a pre-release:

```sh
gh release create v2.2.0-rc1 --prerelease --title "v2.2.0 Release Candidate 1" --generate-notes
```

### Attaching assets at creation time

Pass file paths after the tag. To give an asset a custom display label,
append `#Label text` to the path:

```sh
gh release create v2.2.0 \
  ./dist/myapp-linux-amd64.tar.gz \
  './dist/myapp-darwin-arm64.tar.gz#macOS (Apple Silicon)' \
  ./dist/checksums.txt
```

Glob patterns work too:

```sh
gh release create v2.2.0 ./dist/*.tar.gz ./dist/checksums.txt
```

### Editing an existing release

Publish a draft:

```sh
gh release edit v2.2.0 --draft=false
```

Update the release notes from a file:

```sh
gh release edit v2.2.0 --notes-file /path/to/release_notes.md
```

Rename a tag after the fact:

```sh
gh release edit v2.2.0 --tag v2.2.0-final
```

### Uploading assets to an existing release

Add an asset that was missed at creation:

```sh
gh release upload v2.2.0 ./dist/myapp-windows-amd64.zip
```

Replace an asset that was uploaded with a mistake:

```sh
gh release upload v2.2.0 ./dist/myapp-windows-amd64.zip --clobber
```

### Deleting an asset

```sh
gh release delete-asset v2.2.0 myapp-windows-amd64.zip
```

Skip the confirmation prompt in scripts:

```sh
gh release delete-asset v2.2.0 myapp-windows-amd64.zip --yes
```

### Downloading release assets

Download all assets from a specific release:

```sh
gh release download v2.2.0
```

Download only matching files from the latest release (`--pattern` or `--archive` is required
when no tag is given):

```sh
gh release download --pattern '*.tar.gz'
```

Multiple patterns:

```sh
gh release download v2.2.0 -p '*.tar.gz' -p 'checksums.txt'
```

Download source archive instead of release assets:

```sh
gh release download v2.2.0 --archive=tar.gz
```

Save to a specific directory:

```sh
gh release download v2.2.0 --dir ./downloads
```

### Verifying release attestations

Verify the latest release has a valid cryptographically signed attestation:

```sh
gh release verify
```

Verify a specific release:

```sh
gh release verify v2.2.0
```

Verify that a locally downloaded asset matches the attestation:

```sh
gh release verify-asset v2.2.0 ./dist/myapp-linux-amd64.tar.gz
```

### Deleting a release

Delete a release while keeping the git tag:

```sh
gh release delete v2.2.0
```

Delete both the release and the tag:

```sh
gh release delete v2.2.0 --cleanup-tag
```

## Key options

### create

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-t` / `--title` | Set the release title | Non-interactive creation |
| `-n` / `--notes` | Release notes as a string | Short changelogs inline |
| `-F` / `--notes-file` | Read notes from a file (or `-` for stdin) | Longer changelogs in a file |
| `--generate-notes` | Auto-generate notes via GitHub API | Projects using pull requests with good titles |
| `--notes-from-tag` | Use annotated tag message as notes | Tag-centric workflows |
| `--notes-start-tag` | Starting tag for generated notes range | Skip older history in auto-generated notes |
| `-d` / `--draft` | Save as draft, not published | Stage the release before announcing |
| `-p` / `--prerelease` | Mark as pre-release | Alpha/beta/RC builds |
| `--latest` | Control whether this is the "Latest" release | Backfill a patch without displacing a newer latest |
| `--target` | Branch or commit SHA for tag auto-creation | Releasing from a branch other than main |
| `--verify-tag` | Abort if the tag does not already exist remotely | Enforce tag-first discipline |
| `--fail-on-no-commits` | Fail if no new commits since last release | CI guard against accidental re-releases |
| `--discussion-category` | Open a GitHub Discussion alongside the release | Community announcement releases |

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-L` / `--limit` | Maximum number to fetch (default 30) | Paginate a long release history |
| `-O` / `--order` | `asc` or `desc` (default `desc`) | Chronological ascending for scripting |
| `--exclude-drafts` | Omit drafts | Show only public releases |
| `--exclude-pre-releases` | Omit pre-releases | Show only stable releases |
| `--json fields` | Output selected fields as JSON | Scripting and automation |
| `-q` / `--jq` | Filter JSON with a jq expression | Extract a specific field |

### download

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-p` / `--pattern` | Glob filter for asset filenames | Download only specific files |
| `-A` / `--archive` | Download source archive (`zip` or `tar.gz`) | Source-only fetches |
| `-D` / `--dir` | Target directory (default `.`) | Organise downloads |
| `-O` / `--output` | Write a single asset to a specific path (use `-` for stdout) | Scripting |
| `--clobber` | Overwrite existing files | Re-download updated assets |
| `--skip-existing` | Skip files that already exist locally | Idempotent download scripts |

### edit

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--draft` | Toggle draft state (`--draft=false` to publish) | Publish a previously staged draft |
| `--prerelease` | Mark the release as a prerelease | Flag an already-published release as alpha/beta/RC |
| `--latest` | Explicitly mark as latest | Set after backfilling a patch |
| `-t` / `--title` | Update the title | Correct a typo |
| `-n` / `--notes` | Replace notes with a string | Quick inline correction |
| `-F` / `--notes-file` | Replace notes from a file | Bulk notes update |
| `--tag` | Rename the tag | Fix a mis-tagged release |
| `--target` | Update target branch or SHA | Correction of release point |
| `--verify-tag` | Abort if new tag does not exist remotely | Safety check when renaming |
| `--discussion-category` | Start a discussion when publishing a draft | Community releases |

### delete

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--cleanup-tag` | Also delete the git tag | Full rollback of a mis-release |
| `-y` / `--yes` | Skip confirmation prompt | Scripting |

## Best practices

**Create a draft first for major releases.** Use `--draft` to prepare the
release offline, upload and verify assets, preview the notes in the GitHub
UI, then publish with `gh release edit v1.0.0 --draft=false`. Drafts are
invisible to users and to any CI that watches for new release events.

**Use `--generate-notes` for consistent changelogs.** GitHub's Release Notes
API groups merged pull requests by label (bug, enhancement, etc.) according
to your `.github/release.yml` policy. The result is a structured, reviewable
changelog that requires no manual writing. Pair it with `--notes-start-tag`
to scope the range when releases are close together.

**Tag before you release in strict environments.** Create the git tag locally
and push it before running `gh release create`:

```sh
git tag -a v2.2.0 -m "Release v2.2.0"
git push origin v2.2.0
gh release create v2.2.0 --verify-tag --generate-notes
```

The `--verify-tag` flag aborts the command if the push failed — safer than
letting `gh` auto-create a tag from whatever the remote default branch
happens to be at that moment.

**Attach checksums alongside binaries.** Include a `checksums.txt` (SHA-256
of every binary) as a release asset. Users can verify their download without
needing GitHub Attestations, and you can verify with both:

```sh
shasum -a 256 dist/*.tar.gz > dist/checksums.txt
gh release create v2.2.0 dist/*.tar.gz dist/checksums.txt
```

**Automate releases in CI with `GH_TOKEN`.** In GitHub Actions the
workflow-scoped `GITHUB_TOKEN` has `contents: write` permission and is
sufficient for `gh release create`. Set it as `GH_TOKEN` rather than
calling `gh auth login`:

```yaml
- name: Create release
  env:
    GH_TOKEN: ${{ github.token }}
  run: |
    gh release create "$TAG" --generate-notes ./dist/*.tar.gz
```

See *auth* for the broader token and scope discussion.

**Use `--fail-on-no-commits` in automated pipelines.** If a release
pipeline runs on a schedule, this flag prevents a no-op second release
when no code has changed since the previous release.

## Pitfalls & gotchas

**Auto-created tags point to the remote default branch tip, not your local
HEAD.** If you have local commits that you have not pushed, running
`gh release create v1.0.0` without `--verify-tag` creates a tag on whatever
the default branch is on GitHub at that moment — possibly not your intended
commit. Always push commits before creating a release.

**`--generate-notes` also sets the title if you omit `--title`.** This is
usually convenient, but if your merge commit titles are noisy, the
auto-generated title may be unexpected. Pass `--title` explicitly to stay in
control.

**`--clobber` on `upload` is destructive if the upload fails.** The command
deletes the existing asset before uploading the replacement. If the network
drops mid-upload, the original asset is gone with no automatic recovery.
Have the source file confirmed ready before using this flag.

**Downloading without a tag requires `--pattern` or `--archive`.** Running
`gh release download` with no tag and no filter flag errors out. Always
specify at least one filter flag when omitting the tag.

**`--cleanup-tag` on `delete` removes the git tag from the remote.** Deleting
a release without `--cleanup-tag` leaves the tag in place — other automation
that watches tags may still trigger on it. Delete both together unless you
intentionally want to preserve the tag for re-release.

**Release immutability locks assets after publishing.** Once a repository
enables immutability and a release is published, `delete-asset` and
`upload --clobber` will fail. Draft releases remain editable. Plan uploads
carefully before publishing.

## Worked examples

### Full release workflow with auto-generated notes

Build and test locally, then create a tagged release with generated notes and
built binaries in one step:

```sh
# Build the binaries
make dist

# Create checksums
shasum -a 256 dist/*.tar.gz > dist/checksums.txt

# Push the tag first
git tag -a v3.0.0 -m "Release v3.0.0"
git push origin v3.0.0

# Create the release
gh release create v3.0.0 \
  --title "v3.0.0" \
  --generate-notes \
  dist/*.tar.gz \
  dist/checksums.txt
```

```text
https://github.com/acme/myapp/releases/tag/v3.0.0
```

### Staged draft release with team review

Prepare the release while the team reviews the notes:

```sh
# Create as draft with release notes from a prepared file
gh release create v3.1.0 \
  --draft \
  --title "v3.1.0" \
  --notes-file CHANGELOG.md \
  dist/*.tar.gz

# Open the draft in a browser to share with the team
gh release view v3.1.0 --web

# After approval, publish
gh release edit v3.1.0 --draft=false
```

### Backfilling a patch release without displacing "Latest"

You release v2.1.1 as a critical security fix for users on the v2.x line,
but v3.0.0 is already the latest stable release. Publish v2.1.1 without
moving the "Latest" badge:

```sh
git tag -a v2.1.1 -m "Security patch for v2.x line"
git push origin v2.1.1

gh release create v2.1.1 \
  --title "v2.1.1 (security patch)" \
  --notes "Fixes CVE-2026-12345. Upgrade recommended for all v2.x users." \
  --latest=false
```

### Downloading binaries in a CI install script

```sh
# Download only the Linux tarball from the latest release into /tmp
gh release download \
  --repo acme/myapp \
  --pattern '*linux-amd64*.tar.gz' \
  --dir /tmp/myapp

tar -xf /tmp/myapp/*.tar.gz -C /usr/local/bin/
```

### Verifying a downloaded asset with attestation

After downloading, confirm the asset is authentic before executing it:

```sh
gh release download v3.0.0 --pattern 'myapp-linux-amd64.tar.gz'
gh release verify-asset v3.0.0 myapp-linux-amd64.tar.gz
```

```text
✓ Attestation verified for myapp-linux-amd64.tar.gz
```

### Cleaning up a botched release

You released v3.1.0 with the wrong binaries before anyone downloaded them.
Roll it back completely:

```sh
gh release delete v3.1.0 --cleanup-tag --yes
```

Then rebuild, push the corrected tag, and recreate the release as shown in
the first worked example above.

## Recovery

**Released the wrong commit?** Delete the release and tag, correct the tag
locally, force-push it, and recreate:

```sh
gh release delete v3.1.0 --cleanup-tag --yes
git tag -d v3.1.0
git tag -a v3.1.0 <correct-sha> -m "Release v3.1.0"
git push origin v3.1.0 --force
gh release create v3.1.0 --title "v3.1.0" --generate-notes
```

**Wrong asset uploaded and release not yet published?** Replace the asset
while it is still a draft:

```sh
gh release upload v3.1.0 dist/corrected-asset.tar.gz --clobber
```

**Notes contain a typo after publishing?** Edit the release in place; this
does not require re-publishing:

```sh
gh release edit v3.1.0 --notes-file corrected-notes.md
```

**Release is published and the repository is immutable?** Assets cannot be
replaced. Document the errata in the release notes via `gh release edit`,
and consider creating a new patch release.

See *Getting out of jams* for broader recovery patterns including
force-pushing tags and resetting git history.

## See also

- *auth* — `gh release create` requires a token with `contents: write`
  scope; see *auth* for how to grant it.
- *repo* — repository settings control release immutability and the default
  branch used when auto-creating tags.
- *attestation* — `gh attestation` provides lower-level cryptographic
  attestation verification independent of a specific release.
- *run* — GitHub Actions workflows commonly trigger on `release` events;
  use `gh run` to inspect those triggered workflow runs.
