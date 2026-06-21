# bundle

Package repository objects and refs into a single portable file for
offline transfer or archival.

## Mental model

A bundle is a self-contained snapshot of part of a repository — commits,
trees, blobs, and the refs that point to them — packed into one file you
can copy like any other file. Think of it as a transportable fetch
operation: the receiving end runs a fetch or clone against the bundle
file exactly as it would against a live remote, but no server process is
needed on the other side.

Internally a bundle is a pack file (the same format git uses on the
wire) with a small header listing the refs it contains and any
prerequisite commits the recipient must already have. When the
prerequisites are met, `git fetch` or `git clone` against the bundle
file is indistinguishable from fetching from a real remote.

```text
Sender                              Receiver
──────                              ────────
git bundle create repo.bundle ...
       │
  file copy (USB, email, scp …)
       │
       └──────────────────────────> git clone repo.bundle
                                    git fetch repo.bundle
```

Because a bundle only carries refs and the objects reachable from them,
it does not capture the working tree, the index, stash entries,
per-repository configuration, or hooks.

## Synopsis

```text
git bundle create [-q | --quiet | --progress] [--version=<version>]
                  <file> <git-rev-list-args>
git bundle verify [-q | --quiet] <file>
git bundle list-heads <file> [<refname>...]
git bundle unbundle [--progress] <file> [<refname>...]
```

Pass `-` as `<file>` to write the bundle to stdout (`create`) or to read
from stdin (all other subcommands).

## Everyday usage

Create a full bundle of every ref in the repository:

```sh
git bundle create backup.bundle --all
```

Verify that a bundle is valid and that your repository satisfies its
prerequisites:

```sh
git bundle verify backup.bundle
```

See which refs a bundle exposes:

```sh
git bundle list-heads backup.bundle
```

Clone a new repository from a bundle:

```sh
git clone -b main /path/to/backup.bundle ~/new-repo
```

Fetch updates from a bundle into an existing repository:

```sh
git fetch /path/to/incremental.bundle main:main
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `create <file> <rev-list-args>` | Pack objects and refs into a bundle file | Sending or archiving history |
| `verify <file>` | Check format validity and confirm prerequisites exist locally | Before importing any bundle received from outside |
| `list-heads <file>` | Print refs contained in the bundle | Discovering what a bundle offers |
| `unbundle <file>` | Import objects into the object database (plumbing; prefer `git fetch`) | Low-level scripting |
| `--all` | Include every ref (passed as a rev-list arg to `create`) | Full backups |
| `--progress` | Show progress on stderr even when not connected to a terminal | Scripted transfers where progress should be logged |
| `-q` / `--quiet` | Suppress progress output | Automated or cron jobs |
| `--version=<version>` | Force bundle format version (2 = SHA-1 only, 3 = supports extensions) | Compatibility with older Git installations |

## Best practices

**Tag the watermark after each incremental bundle.** Incremental bundles
depend on both sides agreeing where the last transfer ended. Keep a
dedicated tag (`last-usb-sync`, `lastR2bundle`, etc.) and advance it
immediately after creating each bundle. That tag becomes the prerequisite
for the next run.

```sh
git bundle create inc.bundle last-usb-sync..main
git tag -f last-usb-sync main
```

**Always verify before importing.** Run `git bundle verify` on every
bundle you receive from outside your control. It confirms the format is
sound and that your local repository has every prerequisite commit.
Discovering a missing prerequisite after a long copy operation wastes
time; verifying first costs seconds.

**Use `--all` for archival snapshots, rev-ranges for incremental
transfers.** A full `--all` bundle can be cloned from scratch on any
machine. A range bundle (`old..new`) is smaller but requires the
recipient to already have `old`. Choose based on whether the destination
is a blank machine or an existing mirror.

**Treat the bundle file as a remote, not a one-shot import.** After
cloning from a bundle, the `origin` remote URL points to that file path.
When you drop a newer bundle at the same path, `git pull` in the clone
just works. This makes bundles a clean drop-in for sneakernet update
workflows.

**Prefer `git fetch` over `git bundle unbundle` for consuming bundles.**
`unbundle` is plumbing intended for `git fetch` to call internally. Using
`git fetch <bundle-path> <refspec>` gives you proper remote-tracking
refs, ref-mapping, and familiar output.

## Pitfalls & gotchas

**The tip of a range must resolve to a named ref.** Git refuses to create
a bundle whose right-hand-side tip cannot be resolved to a named reference.
Bare commit hashes and relative expressions like `master~5` both fail:

```sh
git bundle create head.bundle $(git rev-parse HEAD)
# fatal: Refusing to create empty bundle.
git bundle create yesterday.bundle master~10..master~5
# fatal: Refusing to create empty bundle.
```

Ensure the right-hand-side tip of any range (the more-recent end) is a
branch name, tag, or `HEAD`. The left-hand side may be a relative
expression; for example, `master~10..master` is valid. Only the tip —
the right-hand side — must resolve to a named reference.

**Bundles do not include everything you might expect.** The index,
working tree, stash, reflogs, per-repository config, and hooks are all
absent. A bundle restores commit history, not a complete developer
environment.

**Prerequisites must be present on the receiving side.** An incremental
bundle created with `old..new` can only be fetched into a repository that
already contains `old`. If the recipient has been re-initialized or
diverged since the last sync, the verify step will report the missing
prerequisites and the fetch will fail. The remedy is a fresh full bundle.

**Cloning from a bundle sets the bundle file path as `origin`.** Moving
or deleting the bundle file breaks `git fetch` in the clone. After
cloning for a long-lived repository, update the remote URL to a real
remote immediately:

```sh
git remote set-url origin git@github.com:org/repo.git
```

**The watermark tag is only on the sender.** Nothing automatically
records on the receiving side where the last bundle left off. If the
sending repository is ever cloned fresh or the watermark tag is lost, you
must start again from a full bundle.

## Worked examples

### Full backup and restore

Create a complete archive of the current repository, named with today's
date:

```sh
git bundle create ~/backups/myrepo-$(date +%Y%m%d).bundle --all
```

To restore on another machine, clone directly from the file:

```sh
git clone ~/backups/myrepo-20260617.bundle ~/restored-repo
cd ~/restored-repo
git log --oneline -5
git branch -a
```

Because `--all` was used, every branch and tag is present. The result is
a fully functional clone.

### Sneakernet incremental sync across an air-gapped network

Machine A holds the authoritative repository. Machine B sits on an
isolated network. A USB drive carries bundles between them.

**Initial transfer — on machine A:**

```sh
cd /srv/repos/project
git bundle create /mnt/usb/project-full.bundle --all
git tag -f last-usb-sync main
```

**Initial import — on machine B:**

```sh
git clone -b main /mnt/usb/project-full.bundle ~/project
cd ~/project
```

**Subsequent transfers — after further work on machine A:**

```sh
cd /srv/repos/project
git bundle create /mnt/usb/project-inc.bundle last-usb-sync..main
git tag -f last-usb-sync main
```

Verify and pull on machine B after the drive arrives:

```sh
cd ~/project
git bundle verify /mnt/usb/project-inc.bundle
git pull /mnt/usb/project-inc.bundle main:main
```

### Sharing a topic branch without a shared remote

Your colleague has a clone of the same repository but no network access
to your fork. Bundle just the commits on your feature branch that they do
not have yet:

```sh
git bundle create feature-login.bundle origin/main..feature/login
```

Email or copy `feature-login.bundle` to your colleague. They apply it:

```sh
git bundle verify feature-login.bundle
git fetch ./feature-login.bundle feature/login:feature/login
git log --oneline feature/login
```

They can now review, test, or merge `feature/login` without you needing
a shared remote at all.

## Recovery

If a fetch from a bundle fails because prerequisites are missing, request
or re-create a full bundle rather than an incremental one:

```sh
# On the sender side — fall back to a complete bundle
git bundle create full-resync.bundle --all
```

If you cloned from a bundle and the file has since moved, update the
remote URL:

```sh
git remote set-url origin <new-file-path-or-real-remote>
```

See *Getting out of jams* for general recovery from broken or diverged
remote states.

## See also

- *clone* — `git clone` accepts a bundle file path as the source URL.
- *fetch* — the primary way to import refs from a bundle into an
  existing repository.
- *remote* — managing remote URLs, including fixing a bundle-backed
  origin after the file moves.
- *tag* — using tags as watermarks to track incremental bundle
  boundaries.
- *Getting out of jams* — recovering from broken or diverged repository
  states.
