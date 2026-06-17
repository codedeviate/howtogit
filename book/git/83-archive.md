# archive

Package any tree, commit, or tag from your repository into a tar or zip
archive — without checking anything out.

## Mental model

Every commit in git points to a tree object: a complete snapshot of every
tracked file at that point in time. `git archive` walks that tree and writes
the files directly into a tar or zip container. No working tree is created,
no index is modified, and no temporary files are scattered around your disk.

The key distinction that trips people up is the difference between giving
`git archive` a **tree ID** versus a **commit or tag ID**:

- A tree ID carries no timestamp, so each file in the archive gets the
  current wall-clock time as its modification time.
- A commit or tag ID carries the commit timestamp, so every file gets that
  time — which means archives of the same commit are bit-for-bit
  reproducible regardless of when you run the command.

For release tarballs, always use a tag or commit, not a bare tree hash.

```text
tag / commit ──> tree ──> git archive ──> .tar.gz / .zip
  (timestamp      (file                    (reproducible
   embedded)       snapshots)               by default)
```

Git embeds the commit ID in a global extended pax header when producing tar
output, and as a file comment in zip output. You can recover it later with
`git get-tar-commit-id`.

## Synopsis

```text
git archive [--format=<fmt>] [--list] [--prefix=<prefix>/]
            [-o <file> | --output=<file>]
            [--add-file=<file>] [--add-virtual-file=<path>:<content>]
            [--mtime=<time>] [--worktree-attributes]
            [--remote=<repo> [--exec=<git-upload-archive>]]
            <tree-ish> [<path>...]
```

## Everyday usage

Create a release tarball from a tag and write it to a file:

```sh
git archive --prefix=myapp-1.2.0/ -o myapp-1.2.0.tar.gz v1.2.0
```

The format is inferred from the `.tar.gz` extension. The `--prefix` option
adds a top-level directory inside the archive — without it, the files land
in the root of the archive, which surprises users who extract it.

Create a zip archive of the current HEAD:

```sh
git archive -o latest.zip HEAD
```

Archive only a subdirectory (e.g., the `docs/` tree):

```sh
git archive -o docs-snapshot.zip HEAD docs/
```

Pipe directly to tar for an immediate extract — useful for deploying to a
staging server without storing an intermediate file:

```sh
git archive --prefix=deploy/ HEAD | tar -x -C /var/www/staging/
```

List all formats supported on the current installation:

```sh
git archive --list
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--format=<fmt>` | Choose the output format (`tar`, `zip`, `tar.gz`, `tgz`, or any custom format) | When the format cannot be inferred from the output filename |
| `-o <file>`, `--output=<file>` | Write to a file instead of stdout | Almost always; piping to stdout is for chaining with tar |
| `--prefix=<prefix>/` | Prepend a directory prefix to every path in the archive | Release tarballs — consumers expect a top-level folder |
| `-l`, `--list` | Print all available archive formats and exit | Before scripting, to check what formats are registered |
| `--add-file=<file>` | Bundle an untracked file into the archive | Adding a generated `configure` script or build artifact |
| `--add-virtual-file=<path>:<content>` | Inject an in-memory file without it existing on disk | Embedding a version string or build metadata |
| `--mtime=<time>` | Override the modification time stamped on every entry | Reproducible builds that must match a specific timestamp |
| `--worktree-attributes` | Read `.gitattributes` from the working tree in addition to the archived tree | Tweaking `export-ignore` rules after committing |
| `--remote=<repo>` | Fetch the archive from a remote repository instead of the local one | Packaging a version from a server without a full clone |
| `--exec=<cmd>` | Override the path to `git-upload-archive` on the remote side | Non-standard server installations |
| `-v`, `--verbose` | Report progress to stderr | Large repositories where you want confirmation it is running |
| `-<digit>` (zip) | Set zip compression level, `0` (store only) through `9` (best ratio) | Balancing archive size against CPU time |

## Best practices

**Always include a `--prefix`.** Without a prefix, all files land directly in
whatever directory the user extracts into. Anyone who extracts a prefix-less
archive in their home directory ends up with `README.md` next to their `Music`
folder. The convention `<project>-<version>/` matches what users expect from
release tarballs and what packaging tools (rpm, dpkg, Homebrew) require.

**Use a tag as `<tree-ish>` for releases.** Tags are stable and carry the
commit timestamp, producing bit-for-bit reproducible archives. A branch name
like `HEAD` or `main` is a moving target — fine for dev snapshots but not for
releases.

**Leverage `export-ignore` in `.gitattributes` to keep archives clean.**
Files and directories marked `export-ignore` are silently omitted from the
archive. This is the right place to exclude test suites, CI configuration, and
development tooling that consumers of your release do not need.

```text
# .gitattributes
tests/           export-ignore
.github/         export-ignore
.editorconfig    export-ignore
```

**Use `export-subst` to embed version metadata.** Mark a file (e.g.
`VERSION`) with the `export-subst` attribute and git will expand
`$Format:%H$`, `$Format:%D$`, and similar placeholders when archiving.
Consumers of your tarball get the exact commit hash without needing git
itself.

```text
# .gitattributes
VERSION   export-subst
```

```text
# VERSION
commit: $Format:%H$
ref:    $Format:%D$
```

**Prefer `-o` over shell redirection for format inference.** When you write
`git archive ... > myapp.tar.gz`, git sees only stdout and cannot infer the
format; you must add `--format=tar.gz`. When you write `-o myapp.tar.gz`, git
reads the extension and picks the format automatically.

## Pitfalls & gotchas

**Forgetting `--prefix` produces a "tarbomb".** Extracting a prefix-less
archive drops all files directly into the current directory. If you are
testing a tarball before a release, always extract into a fresh temporary
directory first.

**Submodules are not included.** `git archive` only knows about files tracked
in the top-level repository. If your project uses submodules, none of the
submodule contents appear in the archive. You must either archive each
submodule separately and merge the results, or switch to a different packaging
strategy.

**Tree IDs produce non-reproducible archives.** If you pass a raw tree hash
(`HEAD^{tree}`) the modification time of every entry becomes the current time.
Two runs of the same command one second apart produce different archives. This
is usually undesirable; pass a commit or tag instead. The only reason to use a
bare tree ID is when you deliberately want to strip the pax commit-ID header
from tar output.

**`--worktree-attributes` reads your local checkout, not the archived tree.**
If `.gitattributes` in your working tree differs from the one in the commit
being archived, the working-tree version wins. This can cause unexpected
inclusions or exclusions. Keep your working tree `.gitattributes` in sync, or
rely on `$GIT_DIR/info/attributes` for overrides that should never be
committed.

**Remote archives are subject to server-side restrictions.** When using
`--remote`, the remote server runs `git-upload-archive` and may refuse
arbitrary `<tree-ish>` expressions — often only tags and branch tips are
permitted. Check the remote's `uploadArchive` configuration if you receive an
unexpected rejection.

**Custom tar formats must be configured before use.** Formats like `tar.xz`
or `tar.bz2` do not exist by default. You must configure them first with
`git config tar.<format>.command`. Running `git archive --list` after
configuring confirms they are registered.

## Worked examples

### Packaging a release

The project is tagged `v2.5.0`. Create a tarball and a zip ready to upload to
GitHub Releases.

```sh
# Tarball
git archive --prefix=myapp-2.5.0/ -o myapp-2.5.0.tar.gz v2.5.0

# Zip (for Windows users who prefer it)
git archive --prefix=myapp-2.5.0/ -o myapp-2.5.0.zip v2.5.0
```

Verify the top-level directory is present before publishing:

```sh
tar tzf myapp-2.5.0.tar.gz | head -5
```

```text
myapp-2.5.0/
myapp-2.5.0/README.md
myapp-2.5.0/LICENSE
myapp-2.5.0/src/
myapp-2.5.0/src/main.c
```

Confirm the commit ID is embedded in the tarball:

```sh
git get-tar-commit-id < myapp-2.5.0.tar.gz
```

```text
a3f9c1e8b2d47f601c8453d09e4f2a18b7c3e561
```

### Deploying to a server without a full clone

You want to push the current HEAD to a staging server over SSH. The server has
git installed but you do not want to clone the full history there.

```sh
git archive --prefix=app/ HEAD \
  | ssh deploy@staging.example.com 'tar -x -C /var/www/ --strip-components=1'
```

The `--strip-components=1` on the receiving end removes the `app/` prefix
after extraction, landing files directly in `/var/www/`.

### Adding a generated file not tracked by git

Your build process creates a `configure` script that should ship in the
release tarball but is intentionally absent from the repository. Bundle it
alongside the archived tree:

```sh
autoconf                          # generates ./configure
git archive \
  --prefix=myapp-3.0/ \
  --add-file=configure \
  -o myapp-3.0.tar.gz HEAD
```

Because `--add-file` uses the last active `--prefix`, `configure` lands at
`myapp-3.0/configure` in the archive.

### Configuring a custom xz format

Register the format once (stored in your global or project git config):

```sh
git config tar.tar.xz.command "xz -c"
```

Then use it like any built-in format:

```sh
git archive --format=tar.xz --prefix=myapp-4.0/ -o myapp-4.0.tar.xz v4.0.0
# or, with the format inferred from the extension:
git archive --prefix=myapp-4.0/ -o myapp-4.0.tar.xz v4.0.0
```

## Recovery

`git archive` is entirely read-only — it never writes to the repository,
modifies the index, or changes any branch pointer. There is nothing to undo.
If the output file is wrong, delete it and re-run with corrected options.

If you discover after publishing that a release archive contains files that
should have been excluded, add `export-ignore` to `.gitattributes`, commit
that change, re-tag if necessary (see the *tag* chapter), and regenerate the
archive.

See *Getting out of jams* for help recovering from problems with the commits
or tags you are archiving, rather than the archive operation itself.

## See also

- *tag* — creating and managing the version tags used as `<tree-ish>`.
- *commit* — understanding commit objects and how timestamps are stored.
- *Getting out of jams* — recovering from bad commits or tags before archiving.
