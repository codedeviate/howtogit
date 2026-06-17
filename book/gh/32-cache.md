# cache

Inspect and delete GitHub Actions caches stored for a repository.

## Mental model

Every time a GitHub Actions workflow runs, it can save files — dependency
downloads, compiled outputs, tool installations — to a cache keyed by a
string you choose. On the next run the workflow restores that cache, skipping
the expensive re-download or re-build.

GitHub stores those caches server-side, scoped to a *(repository, ref, key)*
triple. The cache is not shared between repositories, and by default a cache
created on a branch cannot be read from a different branch (except that
branches can always read their base branch's caches). GitHub automatically
evicts caches after 7 days of no access, and caps total cache storage at 10 GB
per repository.

`gh cache` gives you two operations on that server-side store:

- **list** — see what is cached, when it was last used, and how large it is.
- **delete** — remove one cache by ID or key, or wipe everything at once.

The `list` and `delete` commands target whichever repository `gh` resolves from
the current directory, or the one you name with `--repo`. Both require a
`repo` scope token, which the normal `gh auth login` flow grants.

## Synopsis

```text
gh cache list   [--key <prefix>] [--ref <ref>] [--sort <field>] [--order asc|desc]
                [--limit <n>] [--json <fields>] [--jq <expr>] [--template <tmpl>]
                [-R [HOST/]OWNER/REPO]

gh cache delete [<cache-id> | <cache-key> | --all] [--ref <ref>]
                [--succeed-on-no-caches]
                [-R [HOST/]OWNER/REPO]
```

## Everyday usage

List all caches for the current repository (sorted by most recently accessed,
newest first):

```sh
gh cache list
```

List caches whose key starts with a known prefix:

```sh
gh cache list --key node-modules-
```

List caches for a specific branch:

```sh
gh cache list --ref refs/heads/main
```

Delete a single cache by its numeric ID:

```sh
gh cache delete 1234
```

Delete a single cache by its exact key:

```sh
gh cache delete "node-modules-linux-abc123"
```

Delete every cache in the repository (useful after a large-scale dependency
change):

```sh
gh cache delete --all
```

Delete all caches for a specific pull request:

```sh
gh cache delete --all --ref refs/pull/42/merge
```

## Key options

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-k` / `--key` | Filter to caches whose key starts with this prefix | Narrow results when you know the key naming convention |
| `-r` / `--ref` | Filter to caches for a specific ref (`refs/heads/<branch>` or `refs/pull/<n>/merge`) | Check a single branch or PR |
| `-S` / `--sort` | Sort by `created_at`, `last_accessed_at`, or `size_in_bytes` (default `last_accessed_at`) | Identify stale or oversized caches |
| `-O` / `--order` | `asc` or `desc` (default `desc`) | Reverse the sort to find the oldest or smallest entries |
| `-L` / `--limit` | Maximum number of caches to return (default 30) | Repos with many caches; increase if you need the full list |
| `--json` | Output raw JSON with the named fields | Scripting; available fields: `createdAt`, `id`, `key`, `lastAccessedAt`, `ref`, `sizeInBytes`, `version` |
| `-q` / `--jq` | Filter JSON output with a jq expression | Extract a single field from machine-readable output |
| `-t` / `--template` | Format JSON with a Go template | Custom human-readable output |
| `-R` / `--repo` | Target a different repository as `[HOST/]OWNER/REPO` | Running outside the repo's directory |

### delete

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-a` / `--all` | Delete every cache in the repo, or every cache for the given `--ref` | Mass cleanup after a cache-key rename or dependency overhaul |
| `-r` / `--ref` | Scope deletion to a specific ref (`refs/heads/<branch>` or `refs/pull/<n>/merge`) | Combined with `--all` to target one branch or PR only |
| `--succeed-on-no-caches` | Exit with code 0 even when no matching caches exist (requires `--all`) | CI pipelines where the cache may or may not be present |
| `-R` / `--repo` | Target a different repository as `[HOST/]OWNER/REPO` | Running outside the repo's directory |

## Best practices

**List before you delete.** Run `gh cache list` first to confirm what you are
about to remove. A typo in a key name passed to `gh cache delete` will silently
do nothing (unless the key matches something unexpected), but `--all` is
immediate and irreversible.

**Use `--ref` to limit blast radius.** When you want to reset caches for a
single PR without touching main's caches, always combine `--all` with
`--ref refs/pull/<n>/merge`. Omitting `--ref` with `--all` wipes every cache in
the repository.

**Use `--succeed-on-no-caches` in CI scripts.** A cleanup step in a workflow
that runs `gh cache delete --all` will fail with exit code 1 if no caches
exist (for example on a first run). Add `--succeed-on-no-caches` to make the
step idempotent:

```sh
gh cache delete --all --succeed-on-no-caches
```

**Sort by size to spot bloat.** Cache entries can grow large if they include
compiled artefacts. Find your heaviest cache:

```sh
gh cache list --sort size_in_bytes --order desc --limit 5
```

**Use JSON output for automation.** Pair `--json` with `--jq` to extract
exactly the field you need without parsing tabular text:

```sh
gh cache list --json id,key,sizeInBytes --jq '.[] | select(.sizeInBytes > 500000000) | .key'
```

This prints keys for caches larger than 500 MB.

## Pitfalls & gotchas

**Cache keys are exact on delete, prefix on list.** `gh cache list --key foo`
matches any key that *begins with* `foo`. `gh cache delete foo` matches only
an entry whose key is exactly `foo`. If you have caches with keys
`foo-linux` and `foo-macos`, listing with `--key foo` shows both; deleting
with `gh cache delete foo` matches neither.

**Numeric IDs and string keys are both valid delete targets, but they look
different.** A numeric argument like `1234` is treated as a cache ID. A
non-numeric string is treated as a cache key. To delete a cache whose key
happens to be a number (unlikely but possible), list first and use the ID.

**`--all` requires no positional argument.** Passing a key or ID alongside
`--all` is an error. Choose one mode.

**`--succeed-on-no-caches` must be combined with `--all`.** Using it without
`--all` is an error. The flag only affects the "no caches found" exit code in
the bulk-delete path.

**Ref format is rigid.** The `--ref` flag requires the fully-qualified ref
string — `refs/heads/main`, not just `main`; `refs/pull/42/merge`, not `42`
or `PR-42`. Passing a short ref returns no results without an error, which can
be confusing.

**The default limit is 30.** A busy repository can have hundreds of caches. If
`gh cache list` seems to be missing entries, raise the limit:

```sh
gh cache list --limit 200
```

**Deletion requires the `repo` scope.** If your token was created with reduced
scopes (e.g. a fine-grained token scoped to read-only), `gh cache delete` will
fail with a permission error. Refresh your token with the full `repo` scope, or
use a classic personal access token. See *auth* for how to add scopes.

## Worked examples

### Auditing cache growth on a long-lived branch

A CI run complains that the repository is nearing its 10 GB cache limit. Find
what is taking up the most space:

```sh
gh cache list --sort size_in_bytes --order desc --limit 10
```

```text
ID    KEY                              REF                    SIZE      LAST ACCESSED
9871  gradle-deps-linux-abc12345       refs/heads/main        1.8 GB    about 1 hour ago
9870  gradle-deps-macos-def67890       refs/heads/main        1.7 GB    about 2 hours ago
9869  gradle-deps-windows-ghi11111     refs/heads/main        1.6 GB    about 3 hours ago
9840  node-modules-linux-jkl22222      refs/heads/main        420 MB    about 1 day ago
...
```

The Gradle dependency caches are 5 GB combined. After updating the dependency
lock file, the old caches will never be hit again. Delete them by key:

```sh
gh cache delete gradle-deps-linux-abc12345
gh cache delete gradle-deps-macos-def67890
gh cache delete gradle-deps-windows-ghi11111
```

Or wipe every cache on main so the next workflow run rebuilds them fresh:

```sh
gh cache delete --all --ref refs/heads/main
```

### Cleaning up caches for a merged pull request

After merging PR 99, its associated caches are stranded. They will be
evicted automatically after 7 days, but if you are tight on quota you can
reclaim the space immediately:

```sh
# Verify what is there
gh cache list --ref refs/pull/99/merge
```

```text
ID    KEY                        REF                      SIZE    LAST ACCESSED
8812  pip-linux-abc123           refs/pull/99/merge       310 MB  3 days ago
8811  pip-linux-abc123           refs/pull/99/merge       308 MB  4 days ago
```

```sh
gh cache delete --all --ref refs/pull/99/merge
```

```text
✓ Deleted 2 caches from myorg/myrepo
```

### Scripting a cache cleanup in a GitHub Actions workflow

Add a final job that clears PR caches when a pull request is closed:

```yaml
on:
  pull_request:
    types: [closed]

jobs:
  cleanup-caches:
    runs-on: ubuntu-latest
    steps:
      - name: Delete PR caches
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh cache delete --all \
            --ref refs/pull/${{ github.event.pull_request.number }}/merge \
            --succeed-on-no-caches \
            --repo ${{ github.repository }}
```

`--succeed-on-no-caches` prevents the step from failing when the PR had no
caches (e.g., if every run was a cache miss).

## Recovery

`gh cache delete` has no undo. A deleted cache is gone; the next workflow run
will rebuild it from scratch. This is usually harmless — the cache was a
performance optimisation, not source data — but it does mean your next CI run
will be slower.

If you accidentally deleted caches across the entire repository with `--all`,
simply trigger a new workflow run on each affected branch. The runners will
repopulate the caches on the first pass. There is nothing to recover.

If `gh cache list` or `gh cache delete` returns a permissions error, your
token lacks the `repo` scope. See *auth* for how to refresh scopes:

```sh
gh auth refresh --scopes repo
```

## See also

- *auth* — manage tokens and scopes; `gh cache delete` requires the `repo` scope.
- *run* — `gh run list` and `gh run view` show the workflow runs that created caches.
- *workflow* — trigger or re-run workflows after clearing caches to rebuild them.
