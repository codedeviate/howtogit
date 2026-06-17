# clone

Copy a remote (or local) repository to your machine and wire up the
connection so you can fetch and push changes going forward.

## Mental model

When you clone a repository, Git does several things in one shot:

1. Creates a new directory (or uses the one you name) and initialises a
   fresh `.git` inside it.
2. Downloads every object — commits, trees, blobs, tags — from the source
   into that `.git/objects` store.
3. Creates a **remote** called `origin` pointing at the source URL, and
   records every remote branch as a remote-tracking branch under
   `refs/remotes/origin/`.
4. Checks out the branch the remote's `HEAD` points at (typically `main` or
   `master`) so you have a working tree immediately.

```text
Remote repository                     Local clone
──────────────────                    ────────────────────────────────
refs/heads/main ──────────────────>   refs/remotes/origin/main
refs/heads/feature-x ─────────────>   refs/remotes/origin/feature-x
                                       refs/heads/main  (checked out)
                                       .git/config:
                                         remote.origin.url = <url>
                                         remote.origin.fetch = +refs/heads/*:refs/remotes/origin/*
```

The remote-tracking branches are read-only snapshots. Your local `main` is a
real branch that starts at the same commit; from that point on the two evolve
independently until you `fetch`, `pull`, or `push`.

A shallow clone (`--depth`) truncates history at a given depth, giving you
a working tree without downloading the entire project timeline. A partial
clone (`--filter`) goes further and defers downloading file contents until
they are actually needed.

## Synopsis

```text
git clone [<options>] <repository> [<directory>]

git clone <url>
git clone <url> <directory>
git clone --branch <name> <url>
git clone --depth <n> <url>
git clone --filter=blob:none <url>
git clone --recurse-submodules <url>
git clone --bare <url>
git clone --mirror <url>
```

## Everyday usage

Clone a GitHub repository into a new directory named after the project:

```sh
git clone https://github.com/org/myproject.git
# result: ./myproject/
```

Clone into a specific directory name:

```sh
git clone https://github.com/org/myproject.git ~/code/proj
```

Clone and immediately check out a branch other than the default:

```sh
git clone --branch develop https://github.com/org/myproject.git
```

Shallow clone for a quick look or a CI job that does not need full history:

```sh
git clone --depth 1 https://github.com/org/myproject.git
```

Clone and initialise all submodules in one step:

```sh
git clone --recurse-submodules https://github.com/org/myproject.git
```

Partial clone — fetch commit and tree objects now, defer blob downloads
until files are actually accessed (great for large monorepos):

```sh
git clone --filter=blob:none https://github.com/org/myproject.git
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--branch <name>` | Check out `<name>` instead of the remote's default branch; also accepts tag names | Start work on a non-default branch or pin to a release tag |
| `--depth <n>` | Shallow clone: fetch only the last `<n>` commits | CI pipelines, quick evaluations, saving bandwidth |
| `--single-branch` | Fetch only the one branch cloned; future fetches stay scoped to it | Paired with `--depth` to keep the clone permanently lean |
| `--no-tags` | Do not download tags | Lean CI clones that don't need release metadata |
| `--filter=<spec>` | Partial clone: omit objects matching the filter until needed (`blob:none`, `blob:limit=<size>`) | Large repos where you only touch a subset of files |
| `--recurse-submodules[=<pathspec>]` | Initialise and clone submodules after cloning the superproject | Repos that embed other repos as submodules |
| `--bare` | Create a bare repository (no working tree; the directory *is* `.git`) | Server-side mirrors, `git bundle` targets, deploy hooks |
| `--mirror` | Like `--bare` but copies all refs and sets up a refspec so `git remote update` overwrites them | Full mirrors: backup or read-only replica of a remote |
| `-o <name>` / `--origin <name>` | Name the remote something other than `origin` | Disambiguate when you will later add a second remote also named `origin` |
| `--no-checkout` / `-n` | Skip the initial checkout | When you want to configure sparse-checkout or inspect the object store before materialising files |
| `--sparse` | Enable sparse-checkout, initially populating only top-level files | Monorepos where you need just one subtree |
| `-c <key>=<value>` | Set a config variable in the new repo immediately after init | Override `core.autocrlf`, add extra fetch refspecs, etc. |
| `--jobs <n>` / `-j <n>` | Number of submodules to fetch in parallel | Speed up `--recurse-submodules` on repos with many submodules |
| `--dissociate` | After borrowing objects from a `--reference` repo, copy them locally so the clone is self-contained | Avoid a long-term dependency on the reference repo being present |
| `--no-local` | When cloning from a local path, use the network transport instead of hardlinks | When you want a fully independent copy, e.g. for backups |

## Best practices

**Prefer HTTPS URLs for new clones unless you have SSH keys configured.**
HTTPS works through corporate proxies, requires no key setup, and prompts
for credentials (or uses a credential helper). Switch to SSH later if you
prefer: `git remote set-url origin git@github.com:org/myproject.git`.

**Use `--recurse-submodules` whenever the project has a `.gitmodules` file.**
Forgetting this leaves the submodule directories empty. You can repair it
after the fact with `git submodule update --init --recursive`, but it is
easier to get it right at clone time.

**Use `--depth 1 --single-branch` in CI.** A full clone on every pipeline run
transfers the entire history. Pair `--depth 1` with `--single-branch` so that
future `git fetch` calls inside the job also stay shallow. For release
pipelines that need tags, add `--no-single-branch` instead.

**Use `--filter=blob:none` for large monorepos.** The partial clone filter
defers downloading file contents until Git actually needs them. Commands like
`git log`, `git diff`, and branch operations work on metadata without fetching
blobs. Files are fetched transparently on first access. This is safer than a
shallow clone because you still have the full history graph.

**Give the directory an explicit name when the URL is ambiguous.** URLs that
end in `.git` give a sensible default name, but bare paths and some hosting
services produce ugly directory names. Be explicit:
`git clone https://example.com/repo.git clean-name`.

**Do not clone into a non-empty directory.** Git refuses unless the directory
is empty. If you need to overlay a clone onto existing files, initialise with
`git init` first, then add the remote and fetch manually.

## Pitfalls & gotchas

**Shallow clones break some Git operations.** `git bisect`, `git merge-base`,
and certain rebase operations need commit ancestry that a shallow clone may
not have. Before running a bisect on a shallow clone, deepen it first:
`git fetch --unshallow`.

**`--depth` implies `--single-branch` by default.** A `git fetch` in a
shallow clone will only update the one branch unless you pass
`--no-single-branch` at clone time or explicitly fetch other branches later.
Surprise: `git fetch origin develop` on a `--depth 1` clone with the default
`--single-branch` will fail with "fatal: couldn't find remote ref develop"
until you add the full refspec to `.git/config`.

**Submodules are not cloned by default.** If you see empty subdirectories
after cloning, the project uses submodules and you forgot
`--recurse-submodules`. Fix it without re-cloning:

```sh
git submodule update --init --recursive
```

**`--bare` and `--mirror` clones have no working tree.** You cannot check
out files, make commits, or run most everyday commands. They are for hosting
and mirroring, not day-to-day development.

**`--shared` is dangerous on local clones.** It sets up an alternates file
so the new clone borrows objects directly from the source. If objects are
later pruned from the source (e.g. after a `git gc` following branch
deletion), the clone can become corrupt. Use `--no-hardlinks` for safe local
backups instead.

**Cloning over SSH fails if the agent is not running.** If `git clone
git@github.com:...` hangs or reports "Permission denied (publickey)", verify
that your SSH key is loaded: `ssh-add -l`. If it is empty, run `ssh-add
~/.ssh/id_ed25519` (or your key path).

**The `--branch` flag accepts tag names but detaches HEAD.** Cloning with
`--branch v1.2.0` puts HEAD in detached state at that tag's commit, which
is correct for a pinned build but unexpected if you intend to start
developing on a release branch.

## Worked examples

### Clone a GitHub project and start working

```sh
git clone https://github.com/cli/cli.git
cd cli
git log --oneline -5
```

```text
a1b2c3d (HEAD -> trunk, origin/trunk, origin/HEAD) Add --json flag to pr list
...
```

Create a local branch from an existing remote branch:

```sh
git switch -c feature/my-change origin/main
```

### Partial clone of a large monorepo

A monorepo with years of history and thousands of files. You only need
recent commits and you will work in one subdirectory.

```sh
git clone --filter=blob:none --sparse https://github.com/org/monorepo.git
cd monorepo
git sparse-checkout set services/auth
```

Git fetches only commit and tree objects during the clone. Blobs under
`services/auth/` are fetched on checkout; blobs elsewhere are never
downloaded unless you explicitly need them. See the *sparse-checkout*
chapter for more on narrowing the working tree.

### Shallow clone for a CI pipeline

A GitHub Actions job that only needs to build from the tip of `main`:

```sh
git clone --depth 1 --single-branch --branch main \
  https://github.com/org/myproject.git
```

This fetches exactly one commit's worth of objects, regardless of how long
the project history is. The pipeline runs faster and uses less disk.

To later fetch tags without fetching all history (e.g. to run
`git describe`):

```sh
git fetch --tags --depth 1
```

### Set up a bare mirror for backup

Create a local bare mirror that you can push to for backup:

```sh
git clone --mirror https://github.com/org/myproject.git \
  /backups/myproject.git
```

Update the mirror later:

```sh
git -C /backups/myproject.git remote update
```

`--mirror` copies all refs (branches, tags, notes, remote-tracking
branches) and writes a fetch refspec that overwrites them all on each
update, making this a true read-only replica. See the *remote* chapter for
managing remotes on an existing repository.

### Clone with a custom remote name

When you plan to track two upstream forks (the original project and your
own fork), name the remotes clearly from the start:

```sh
git clone --origin upstream https://github.com/original/project.git
cd project
git remote add origin https://github.com/yourname/project.git
```

Now `upstream` points at the canonical repo and `origin` points at your
fork — the conventional arrangement for open-source contribution workflows.

## Recovery

If you cloned with `--depth` and later find you need the full history:

```sh
git fetch --unshallow
```

If you forgot `--recurse-submodules`:

```sh
git submodule update --init --recursive
```

If you cloned the wrong URL, update it without re-cloning:

```sh
git remote set-url origin https://github.com/correct/repo.git
```

If a partial clone (`--filter`) left you missing objects that a command
needs, refetch all objects from the remote:

```sh
git fetch --refetch origin
```

See *Getting out of jams* for broader recovery recipes including abandoned
clones and corrupted object stores.

## See also

- *init* — create a new empty repository from scratch instead of cloning.
- *remote* — inspect and modify the remotes configured by `clone`.
- *fetch* — update remote-tracking branches after the initial clone.
- *pull* — fetch and integrate upstream changes into the current branch.
- *sparse-checkout* — limit the working tree after cloning a large repo.
- *submodule* — manage nested repositories initialised with `--recurse-submodules`.
- *Getting out of jams* — fix shallow, partial, or broken clones.
