# submodule

Embed one Git repository inside another as a tracked dependency pinned to a
specific commit.

## Mental model

A submodule is a pointer, not a copy. When you add a submodule, Git records
two things:

1. **`.gitmodules`** — a plain-text file at the superproject root that maps
   each submodule path to its remote URL (and optionally a tracking branch).
2. **A gitlink** — a special index entry for the submodule path that stores
   a single SHA-1: the exact commit the superproject expects that submodule
   to be at.

The submodule directory itself is a fully independent Git repository. It has
its own `.git` directory (or a `.git` file pointing into the superproject's
`.git/modules/` store), its own history, and its own remotes. The superproject
does not track the submodule's files — only that one commit SHA-1.

```text
superproject/
  .gitmodules          ← URL + path registry
  .git/modules/ui/     ← submodule's embedded git dir
  ui/                  ← submodule working tree (detached HEAD)
    .git               ← file: pointer to ../.git/modules/ui
    src/
    ...
```

When a teammate clones your superproject they get the `.gitmodules` file and
the gitlink, but not the submodule's files — they must run
`git submodule update --init` to populate the working tree.

The most common confusion: **updating a submodule to a newer commit does not
happen automatically**. You must explicitly pull inside the submodule (or use
`update --remote`), then stage and commit the updated gitlink in the
superproject. Think of it as bumping a version pin.

## Synopsis

```text
git submodule [--quiet] [--cached]
git submodule [--quiet] add [-b <branch>] [-f] [--name <name>]
              [--depth <depth>] [--] <repository> [<path>]
git submodule [--quiet] status [--cached] [--recursive] [--] [<path>...]
git submodule [--quiet] init [--] [<path>...]
git submodule [--quiet] deinit [-f|--force] (--all|[--] <path>...)
git submodule [--quiet] update [--init] [--remote] [-N|--no-fetch]
              [-f|--force] [--checkout|--rebase|--merge]
              [--depth <depth>] [--recursive] [-j <n>] [--] [<path>...]
git submodule [--quiet] set-branch (-b <branch>|-d) [--] <path>
git submodule [--quiet] set-url [--] <path> <newurl>
git submodule [--quiet] summary [--cached|--files] [-n <n>] [--] [<path>...]
git submodule [--quiet] foreach [--recursive] <command>
git submodule [--quiet] sync [--recursive] [--] [<path>...]
git submodule [--quiet] absorbgitdirs [--] [<path>...]
```

## Everyday usage

**Add a submodule** to the superproject:

```sh
git submodule add https://github.com/example/ui-lib.git vendor/ui
git commit -m "Add ui-lib as a submodule at vendor/ui"
```

**Clone a repository that already has submodules** — populate everything in
one step:

```sh
git clone --recurse-submodules https://github.com/example/app.git
```

If you forgot `--recurse-submodules` at clone time, fix it afterwards:

```sh
git submodule update --init --recursive
```

**Check the state** of all submodules. The prefix characters tell you the
story: `-` means not initialized, `+` means the checked-out commit differs
from the superproject's recorded SHA-1, `U` means merge conflict.

```sh
git submodule status
```

```text
 a3f9c1d vendor/ui (v2.1.0)
+7b20e44 vendor/proto (heads/main-3-g7b20e44)
-0000000 vendor/icons (not initialized)
```

**Update submodules** to the commits the superproject records:

```sh
git submodule update --init --recursive
```

**Pull the latest upstream commit** of a submodule and record it in the
superproject:

```sh
cd vendor/ui
git fetch
git checkout main
git pull
cd ../..
git add vendor/ui
git commit -m "Bump ui-lib to latest main"
```

Or use `update --remote` without entering the directory:

```sh
git submodule update --remote vendor/ui
git add vendor/ui
git commit -m "Bump ui-lib to latest upstream HEAD"
```

**Run a command in every submodule** (the `$sm_path` variable holds each
submodule's path relative to the superproject):

```sh
git submodule foreach 'git fetch && echo "fetched $sm_path"'
```

## Key options

| Option | Applies to | What it does | When to use it |
|--------|-----------|--------------|----------------|
| `add <repo> [<path>]` | — | Register a remote repo as a submodule at `<path>` | Adding a new dependency |
| `update --init` | `update` | Initialize uninitialized submodules before updating | After a fresh clone or pull |
| `update --recursive` | `update`, `status`, `foreach`, `sync` | Descend into nested submodules | Repos with multi-level nesting |
| `update --remote` | `update` | Fetch and check out the submodule's upstream tracking branch instead of the pinned SHA-1 | Pulling latest upstream into a submodule |
| `update --merge` | `update` | Merge the superproject's recorded commit into the submodule's current branch | Keep submodule on a real branch |
| `update --rebase` | `update` | Rebase the submodule's current branch onto the recorded commit | Keep submodule on a real branch |
| `-j <n>` / `--jobs <n>` | `update` | Clone or fetch submodules in parallel | Many submodules or slow network |
| `--depth <n>` | `add`, `update` | Shallow-clone with history truncated to `n` commits | Large submodule repos, CI |
| `deinit <path>` | — | Remove a submodule's working tree and local config entry (does not remove the gitlink) | Stopping work on a submodule temporarily |
| `deinit --all` | `deinit` | Deinit every registered submodule | Cleaning up the entire workspace |
| `-f` / `--force` | `add`, `deinit`, `update` | `add`: allow adding an otherwise-ignored path; `deinit`/`update`: proceed even when local modifications exist | Recovery; use with care |
| `foreach <cmd>` | — | Run a shell command in each checked-out submodule | Bulk operations: fetch, status, branch |
| `foreach --recursive` | `foreach` | Also descend into nested submodules | Deep nesting |
| `sync` | — | Update `.git/config` remote URLs from `.gitmodules` | After an upstream URL change |
| `set-url <path> <url>` | — | Change the URL of a submodule and sync local config | Migrating a submodule to a new host |
| `set-branch -b <branch>` | — | Set the remote tracking branch stored in `.gitmodules` | Control which branch `update --remote` follows |
| `set-branch -d` | — | Remove the tracking-branch setting, reverting to remote HEAD | Reset to default upstream branch |
| `status --cached` | `status` | Show the SHA-1 stored in the index rather than in HEAD | See what is staged for commit |
| `summary` | — | Show commits in submodules between superproject HEAD and the index | Quick diff of what changed |
| `absorbgitdirs` | — | Move submodule `.git` dirs into the superproject's `.git/modules/` store | Housekeeping after a manual clone-and-add |
| `--quiet` | all | Only print error messages | Scripts and CI pipelines |

## Best practices

**Always commit `.gitmodules` and the gitlink together.** When you add or bump
a submodule, stage both the `.gitmodules` file and the submodule path in the
same commit. Leaving one staged without the other produces an inconsistent
state for every collaborator who pulls.

**Pin submodules to stable refs, not moving branches.** The superproject
stores a commit SHA-1, not a branch name. Pointing a submodule at a branch
with `--branch` only affects `update --remote`; collaborators who run a plain
`update` still get the recorded SHA-1. Make deliberate bump commits rather
than silently drifting with `--remote` in CI.

**Use `--recurse-submodules` everywhere.** Add it to your `clone` invocations,
and set it globally so `pull`, `checkout`, and `switch` automatically keep
submodules in sync:

```sh
git config --global submodule.recurse true
```

Without this you constantly run `git submodule update` after every pull, and
occasionally forget.

**Parallelize on large trees.** When a project has many submodules, use `-j`
to clone or fetch them in parallel. Set the default once:

```sh
git config --global submodule.fetchJobs 8
```

Then any `git submodule update` will use eight parallel jobs automatically.

**Shallow-clone large submodule histories in CI.** If a submodule has a long
history you do not need, `--depth 1` cuts clone time dramatically:

```sh
git submodule update --init --depth 1
```

**Keep submodule development on a branch.** By default `update --checkout`
leaves the submodule in detached HEAD state. Any commits you make there are
easily lost. Before hacking on a submodule, check out a branch:

```sh
cd vendor/ui
git checkout -b feature/my-change origin/main
```

Now your commits belong to a branch and cannot be silently overwritten by a
future `submodule update`.

## Pitfalls & gotchas

**Empty directory after clone.** Pulling a commit that adds a new submodule
leaves an empty directory in your working tree. The fix is always
`git submodule update --init --recursive`. Without it the directory exists but
contains nothing, and any build referencing it will fail silently.

**Detached HEAD inside the submodule.** A plain `git submodule update` checks
out the pinned commit on a detached HEAD. Any commits you make in that state
are dangling — no branch points at them. After switching the superproject
away and back, `update` will silently replace your work. Always
`git checkout -b <branch>` inside the submodule before making changes.

**`deinit` does not remove the gitlink.** Running `git submodule deinit
vendor/ui` removes the working tree and the `.git/config` entry, but the path
still exists as a gitlink in the index and in `.gitmodules`. To fully remove a
submodule from the project, you must also run `git rm vendor/ui`. See the
Worked examples section for the complete sequence.

**URL changes are not automatic.** If an upstream repository moves to a new
URL, collaborators must run `git submodule sync` after you commit the updated
`.gitmodules`; otherwise their local `.git/config` still points at the old
address and fetches fail.

**`update --remote` without staging creates drift.** Running
`git submodule update --remote` updates the submodule's checked-out commit but
does not stage the gitlink in the superproject. If you stop there, the
superproject still records the old SHA-1. Always follow with
`git add <path>` and a commit.

**Shallow history breaks older commit checkouts.** If a submodule was cloned
with `--depth 1`, attempting to check out an older commit recorded in the
superproject fails with "object not found". Deepen the clone first:

```sh
cd vendor/ui
git fetch --unshallow
```

**Nested submodules multiply complexity.** Every submodule can have its own
submodules. Without `--recursive` you only process one level. Use
`--recursive` consistently or nested submodules silently fall out of sync.

## Worked examples

### Setting up a project that uses libraries as submodules

You are building an application that depends on two libraries in separate
repositories.

```sh
git init app && cd app

# Add the first library
git submodule add https://github.com/example/core.git vendor/core

# Add a second library, tracking the stable-2 branch for update --remote
git submodule add -b stable-2 https://github.com/example/utils.git vendor/utils

git status
```

```text
On branch main

Changes to be committed:
  new file:   .gitmodules
  new file:   vendor/core
  new file:   vendor/utils
```

```sh
git commit -m "Add core and utils as submodules"
```

A collaborator who clones the project populates the submodules with:

```sh
git clone --recurse-submodules https://github.com/example/app.git
```

Or, after a plain clone:

```sh
git submodule update --init --recursive
```

### Bumping a submodule to a newer release

The `vendor/core` library has published `v3.0.0` and you want the superproject
to track it.

```sh
cd vendor/core
git fetch --tags
git checkout v3.0.0
cd ../..

# The superproject sees vendor/core as modified (+ prefix means the
# checked-out commit no longer matches the recorded SHA-1)
git submodule status
```

```text
+e8a712f vendor/core (v3.0.0)
 c901234 vendor/utils (stable-2)
```

```sh
git add vendor/core
git commit -m "Bump core to v3.0.0"
```

Teammates get the updated pin by running:

```sh
git pull
git submodule update --recursive
```

### Fully removing a submodule

You have decided to vendor the `vendor/utils` source directly and no longer
need it as a submodule.

```sh
# 1. Remove the working tree and the .git/config entry
git submodule deinit vendor/utils

# 2. Remove the gitlink from the index and delete the directory;
#    also removes the [submodule "vendor/utils"] block from .gitmodules
git rm vendor/utils

# 3. Remove the leftover modules store entry
rm -rf .git/modules/vendor/utils

git commit -m "Remove utils submodule; vendor source directly"
```

Skip any of those three steps and you leave behind orphaned data that
confuses future `submodule update` runs.

### Running bulk operations with foreach

Print the current branch of every submodule:

```sh
git submodule foreach 'echo "$sm_path: $(git branch --show-current)"'
```

Pull the latest changes in every submodule, continuing even if one fails:

```sh
git submodule foreach 'git pull --ff-only || :'
```

Run the same command recursively through all nested submodules:

```sh
git submodule foreach --recursive 'git fetch origin'
```

### Fixing a URL change after a repository migration

The `vendor/core` library moved from GitHub to an internal GitLab instance.

```sh
git submodule set-url vendor/core https://gitlab.internal/core.git

# Propagate the new URL to .git/config (local clone config)
git submodule sync vendor/core

git add .gitmodules
git commit -m "Migrate core submodule URL to internal GitLab"
```

Every teammate pulls and runs:

```sh
git submodule sync          # update their .git/config from .gitmodules
git submodule update        # re-fetch if needed
```

## Recovery

**Submodule directory is empty after clone or pull:**

```sh
git submodule update --init --recursive
```

**Accidentally made commits on detached HEAD inside a submodule.** You ran
`git submodule update` and your commits disappeared:

```sh
cd vendor/ui
git reflog                      # find the last commit you made
git branch rescue-work abc1234  # create a branch at that commit
git checkout rescue-work
```

Then cherry-pick or merge `rescue-work` into your intended branch, and
record the updated gitlink in the superproject.

**`update` fails with "reference is not a tree".** The superproject records a
commit the submodule does not have locally, which is common with shallow clones
or after the submodule's remote changed:

```sh
cd vendor/ui
git fetch --unshallow   # if shallow; otherwise a plain fetch is enough
git fetch origin
cd ../..
git submodule update
```

**Wrong commit after a merge conflict on the gitlink.** A merge brought in a
gitlink pointing at a different commit. See what each side wanted:

```sh
git diff HEAD MERGE_HEAD -- vendor/ui
```

Check out the commit you want, stage the path, and complete the merge commit.

See *Getting out of jams* for broader undo recipes.

## See also

- *clone* — `--recurse-submodules` for initial population; `--depth` and
  `--shallow-submodules` for partial histories.
- *add* — staging the gitlink after updating a submodule's checked-out commit.
- *commit* — recording the bumped submodule pointer in the superproject.
- *diff* — `--submodule=log` shows which commits changed inside a submodule
  between two superproject revisions.
- *Getting out of jams* — recovering detached-HEAD commits and other
  submodule mishaps.
