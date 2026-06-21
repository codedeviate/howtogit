# sparse-checkout

Reduce your working tree to a subset of tracked files so you only check out the
directories you actually need.

## Mental model

Every file in a repository lives in the index. Normally the working tree is a
full mirror of that index — every tracked file is present on disk. Sparse
checkout breaks that mirror deliberately: it marks files whose directories you
did not ask for with the **skip-worktree** bit, and Git stops materialising them
on disk. The files are still in the repository history and in the index; they
are simply absent from your working tree.

```text
Repository history
       │
       ▼
     Index  ── skip-worktree bits set for out-of-cone paths
       │
       ▼
 Working tree  ← only in-cone directories appear here
```

The default mode is **cone mode**: you name directories, and Git includes
everything beneath each directory, plus the files at the toplevel and in each
ancestor directory along the path. This constraint lets Git use fast hash-based
lookups rather than O(N×M) pattern matching, and it is the only mode that
supports `--sparse-index`.

A **sparse index** takes the optimisation further: instead of storing one index
entry per file for out-of-cone directories, Git stores a single entry for the
directory itself. This can dramatically shrink the index and speed up
`git status`, `git add`, and related commands in very large repositories.

When Git operations such as merge or rebase need to materialise files outside
the cone to resolve conflicts, they do so temporarily. Use `git sparse-checkout
reapply` afterwards to re-hide those files.

## Synopsis

```text
git sparse-checkout list
git sparse-checkout set [--cone | --no-cone] [--[no-]sparse-index] (--stdin | <dir>...)
git sparse-checkout add [--stdin] <dir>...
git sparse-checkout reapply [--[no-]cone] [--[no-]sparse-index]
git sparse-checkout disable
git sparse-checkout check-rules [--rules-file <file>] [-z]
```

`init` is listed in the help as a deprecated alias for `set` with no paths and
should not be used in new workflows.

## Everyday usage

Set up a sparse checkout that checks out only the `src/` and `docs/` directories
(plus toplevel files):

```sh
# Start from a full clone, or a partial clone for maximum effect
git clone --filter=blob:none --no-checkout https://github.com/example/monorepo
cd monorepo
git sparse-checkout set src docs
git checkout main
```

From inside an existing full clone, narrow the working tree at any time:

```sh
git sparse-checkout set services/api services/auth
```

See which directories are currently included:

```sh
git sparse-checkout list
# services/api
# services/auth
```

Add another directory without replacing what is already there:

```sh
git sparse-checkout add services/payments
```

Restore the full working tree and disable sparse checkout:

```sh
git sparse-checkout disable
```

## Key options

| Option | Applies to | What it does | When to use it |
|--------|-----------|--------------|----------------|
| `--cone` | `set`, `reapply` | Interpret arguments as directory names (default) | Always — cone mode is faster and supports sparse index |
| `--no-cone` | `set`, `reapply` | Interpret arguments as gitignore-style patterns | Avoid; deprecated and incompatible with `--sparse-index` |
| `--sparse-index` | `set`, `reapply` | Collapse out-of-cone directories to single index entries | Large monorepos where `git status` feels slow |
| `--no-sparse-index` | `set`, `reapply` | Expand the index back to per-file entries | Recovering compatibility with older tools |
| `--stdin` | `set`, `add` | Read the directory list from stdin (newline-delimited) | Scripting; piping the output of another command |
| `--rules-file <file>` | `check-rules` | Test paths against rules in `<file>` instead of the live rules | Previewing a rule change before applying it |
| `-z` | `check-rules` | Use NUL-delimited input/output instead of newlines | Paths that contain spaces or special characters |

## Best practices

**Combine sparse checkout with a partial clone.** `git clone
--filter=blob:none` skips downloading file contents at clone time; Git fetches
blobs on demand. Paired with sparse checkout you avoid both downloading and
writing to disk the files you never need. For very large repositories, use
`--filter=tree:0` to also defer tree objects.

```sh
git clone --filter=blob:none --no-checkout https://github.com/example/monorepo
cd monorepo
git sparse-checkout set my/team/dir
git checkout main
```

**Enable the sparse index for speed.** If your sparse cone is a small fraction
of the total repository, add `--sparse-index` when you first call `set`. You
can also add it later via `reapply`:

```sh
git sparse-checkout reapply --sparse-index
```

Check whether it is active with `git config --local index.sparse`.

**Use `set` rather than `init` + `set`.** The old two-step workflow (`init`
then `set`) first stripped the working tree of almost all files and then
re-added them, which was slow and confusing. `set` handles all required config
settings in a single operation.

**Let `set` upgrade worktree config automatically.** When you call `set`,
Git writes the sparsity rules into worktree-specific config so that different
worktrees (see the *worktree* chapter) can have different cone definitions.
This happens automatically; you do not need to configure it.

**Stick to cone mode.** Non-cone mode (gitignore-style patterns) has O(N×M)
performance, prevents use of `--sparse-index`, is incompatible with some
merge strategies, and is deprecated. If you think you need a complex pattern,
reconsider whether restructuring the directories would be cleaner.

## Pitfalls & gotchas

**Toplevel files are always included.** Cone mode unconditionally includes
every file at the root of the repository — `README.md`, `Makefile`,
`.gitignore`, and friends. You cannot exclude them without switching to the
deprecated non-cone mode.

**Merge and rebase can leak files into the working tree.** When Git needs to
show a conflict it materialises the conflicting file even if it is outside your
cone. After resolving the conflict and committing or aborting, run
`git sparse-checkout reapply` to hide those files again. Forgetting this step
leaves out-of-cone files present on disk, which can confuse editors and
build tools.

**`git commit -a` ignores files outside the cone.** This is intentional — Git
will not mark out-of-cone paths as deleted just because they are absent from
the working tree. But it means `-a` can give a misleading "nothing to commit"
when you expect it to pick up changes in directories you have not checked out.

**Switching branches does not update out-of-cone paths.** If a branch adds or
changes files outside your current cone, those changes will not appear in the
working tree after `git switch`. The index tracks them correctly, but your
disk does not reflect them until you widen the cone.

**The sparse index can confuse external tools.** Older IDEs, language servers,
and Git GUIs that inspect the index directly may not understand sparse
directory entries. If you encounter strange behaviour, disable the sparse index:

```sh
git sparse-checkout reapply --no-sparse-index
```

**Untracked files block directory removal.** When you narrow the cone with a
new `set` call, Git tries to delete directories that have fallen out of scope.
If any such directory contains untracked files that are not gitignore-d, Git
warns and leaves the directory in place. Stage and commit (or explicitly
remove) those files before narrowing the cone.

**`--sparse-index` is still experimental.** The help text warns that some
commands may be slower until they are fully integrated, and that external tools
may not handle the format correctly. Enable it in workspaces where you control
all tooling.

## Worked examples

### Checking out one service from a monorepo

A monorepo contains hundreds of services under `services/`. You only maintain
`services/billing`.

```sh
# Partial clone — no file contents downloaded yet
git clone --filter=blob:none --no-checkout git@github.com:corp/platform.git
cd platform

# Set the cone and enable sparse index for speed
git sparse-checkout set --sparse-index services/billing

# Now materialise the branch
git checkout main
```

```text
$ git sparse-checkout list
services/billing
```

The working tree contains only `services/billing/` (all depths), every file
immediately under `services/`, and every file at the repository root. The other
190-odd service directories are absent from disk.

To pull in a shared library you discover is needed:

```sh
git sparse-checkout add lib/common
```

### Temporarily widening the cone to resolve a conflict

You are rebasing a branch that touches files in both `services/billing` and
`services/auth`. Git materialises the conflicting `services/auth` files to
present the conflict.

```sh
git rebase origin/main
# ... CONFLICT (content): Merge conflict in services/auth/config.go
```

Resolve the conflict in your editor, then continue:

```sh
git add services/auth/config.go
git rebase --continue
```

After the rebase completes, re-hide the out-of-cone files:

```sh
git sparse-checkout reapply
```

`services/auth/` disappears from the working tree again.

### Previewing rules before applying them

You are writing a script that will configure sparse checkout for a new team
member and want to verify the rule set catches the right paths before touching
anyone's working tree.

```sh
# Write candidate rules to a file
printf 'services/billing\nlib/common\n' > /tmp/billing-rules.txt

# Ask which paths from the index would be included
git ls-tree -r --name-only HEAD | \
  git sparse-checkout check-rules --rules-file /tmp/billing-rules.txt
```

The output is the subset of tracked paths that match those rules, without
modifying the current sparse-checkout configuration.

## Recovery

**Re-enable a full working tree** after accidentally over-narrowing the cone:

```sh
git sparse-checkout disable
```

This sets `core.sparseCheckout` to `false` and repopulates all tracked files.

**Restore a specific out-of-cone file** without changing the cone definition:

```sh
git checkout HEAD -- path/to/file
```

The file reappears on disk; the skip-worktree bit remains cleared for that
path until the next cone-changing operation.

**Recover a sparse index that broke a tool:**

```sh
git sparse-checkout reapply --no-sparse-index
```

This rewrites the index to use per-file entries without changing which
directories are included.

See *Getting out of jams* for broader undo recipes, including recovering from
bad merges and rebases that may have happened while outside your sparse cone.

## See also

- *clone* — `--filter=blob:none` and `--filter=tree:0` for partial clones that
  pair naturally with sparse checkout.
- *worktree* — each worktree maintains its own independent sparse-checkout
  definition.
- *checkout* and *switch* — how branch switches interact with out-of-cone paths.
- *rebase* and *merge* — operations that can temporarily materialise
  out-of-cone files, requiring `reapply` afterwards.
- *Getting out of jams* — restoring a working tree that has ended up in an
  unexpected state.
