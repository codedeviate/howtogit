# replace

Transparently substitute any Git object with a different one, without
rewriting history.

## Mental model

Every commit, tree, blob, and tag in a Git repository is identified by its
SHA-1 hash. `git replace` writes a reference into the `refs/replace/`
namespace that says: "whenever any command would resolve SHA-1 X, hand back
SHA-1 Y instead." The original object stays in the object database — nothing
is deleted or rewritten. The swap is purely a lookup table.

```text
  Object database          refs/replace/
  ──────────────           ─────────────
  deadbeef  (original)     deadbeef → cafef00d
  cafef00d  (replacement)

  git log:  sees cafef00d content for the commit named deadbeef
  git --no-replace-objects log:  sees the real deadbeef
```

Because replacements are stored as refs, they can be pushed and fetched like
branches or tags. A team can share a set of "amended" commits without forcing
every contributor to rewrite their local clone.

The mechanism is transparent to almost all porcelain commands. The only
carve-outs are reachability-traversal operations (`prune`, pack transfer, and
`fsck`) which intentionally ignore replacements so the object database stays
self-consistent.

## Synopsis

```text
git replace [-f] <object> <replacement>
git replace [-f] --edit <object>
git replace [-f] --graft <commit> [<parent>...]
git replace [-f] --convert-graft-file
git replace -d <object>...
git replace [--format=<format>] [-l [<pattern>]]
```

## Everyday usage

List all active replacements:

```sh
git replace -l
git replace          # no arguments also lists
```

Show replacements with both SHA-1s and object types:

```sh
git replace --format=long -l
```

Replace a commit with a hand-crafted one (the replacement object already exists):

```sh
git replace deadbeef cafef00d
```

Delete a replacement so the original object is visible again:

```sh
git replace -d deadbeef
```

Edit a commit's metadata (author, message, tree) interactively — Git opens
`$EDITOR`, you save the changes, and a replacement ref is written
automatically:

```sh
git replace --edit deadbeef
```

Graft a commit onto a different set of parents (useful for joining two
separate history lines):

```sh
git replace --graft <tip-of-new-history> <desired-parent>
```

Disable all replacements for one command:

```sh
git --no-replace-objects log
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-f`, `--force` | Overwrite an existing replace ref for the same object | Updating a replacement without deleting it first |
| `-d`, `--delete` | Remove replace refs for the given objects | Undoing a replacement |
| `--edit <object>` | Open the object in `$EDITOR`, write a replacement from the result | Fixing a commit message or metadata without a full rebase |
| `--raw` | With `--edit`, present raw binary content instead of pretty-printed | Repairing a corrupted tree object |
| `--graft <commit> [<parent>...]` | Create a replacement commit with a different parent list | Joining histories or cutting a commit free from its parents |
| `--convert-graft-file` | Migrate `$GIT_DIR/info/grafts` to replace refs and delete the file | Upgrading repos that still use the deprecated grafts mechanism |
| `-l [<pattern>]`, `--list [<pattern>]` | List replace refs, optionally filtered by pattern | Auditing what replacements are active |
| `--format=<format>` | Control listing output: `short`, `medium`, or `long` | Getting a quick overview (`short`) or full type info (`long`) |

## Best practices

**Treat replace refs like branches: push and document them.**
A replacement that lives only in your local clone is a silent trap for
teammates — they will see a different history than you do. Push replace refs
explicitly and note them in the project's contributing guide:

```sh
git push origin 'refs/replace/*'
```

On the receiving end, fetch them with a matching refspec:

```sh
git fetch origin 'refs/replace/*:refs/replace/*'
```

**Prefer `--edit` for one-off metadata fixes over a full rebase.**
When a commit message contains a typo or a broken `Closes:` trailer but the
diff is correct, `git replace --edit` corrects the metadata without touching
any other commit's hash. Use the *rebase* chapter's techniques when you need
to change file content or restructure multiple commits.

**Use `--graft` to join histories, not to rewrite them.**
Grafting is the right tool when you are stitching an import (a repo created
from a tarball) back onto the original upstream history, or when a repository
was split and you want to reconnect the two halves for `git log` purposes. It
leaves both the original root and the synthetic parent intact.

**Convert legacy graft files before they cause confusion.**
The `$GIT_DIR/info/grafts` file has been deprecated since Git 2.18. Run
`git replace --convert-graft-file` once, push the resulting replace refs to
the shared remote, and remove any documentation that references the old
mechanism.

**Scope `--no-replace-objects` in scripts that care about canonical hashes.**
Automation that validates commit hashes, generates release notes from `git
log`, or produces SBOMs should pass `--no-replace-objects` (or set
`GIT_NO_REPLACE_OBJECTS=1`) so it always sees the real object graph.

## Pitfalls & gotchas

**Replacements are invisible unless everyone fetches `refs/replace/`.**
The default `git fetch` refspec does not include `refs/replace/*`. A
developer who has not fetched the replace refs sees the original, unreplaced
history. This asymmetry is the most common source of confusion around the
feature.

**The replaced and replacement objects must be the same type — unless you use `-f`.**
Replacing a commit with a blob fails without `--force`. Using `--force` to
bypass the type check is almost always a mistake; Git commands that dispatch
on object type will behave unpredictably.

**`git reset --hard` to a replaced commit moves to the replacement.**
This is a documented bug. If you run `git reset --hard deadbeef` and
`deadbeef` has a replacement, your working tree will reflect the replacement
commit's tree, not the original. Use `--no-replace-objects` when you
specifically need the original object:

```sh
git --no-replace-objects reset --hard deadbeef
```

**Reachability commands ignore replacements.**
`git fsck`, `git gc --prune`, and pack-transfer operations see the raw object
graph. A replacement object that is not otherwise reachable (not pointed to
by any branch, tag, or other ref) can be pruned away, silently breaking the
replacement. Make sure the replacement commit is reachable by pushing it to
the remote.

**`--edit` on a tree requires `--raw` for binary content.**
Tree objects are stored in a compact binary format. Without `--raw` they are
shown in a human-readable listing; with `--raw` you are editing bytes. Most
editors cannot round-trip binary data cleanly. Avoid `--raw` on trees unless
you have a hex editor configured and a specific reason to work at that level.

**Comparing a replaced object with its replacement does not work properly.**
`git diff deadbeef cafef00d` (where one is a replacement for the other) can
produce misleading output. Use `--no-replace-objects` when you need to see
what actually changed between the two:

```sh
git --no-replace-objects diff deadbeef cafef00d
```

## Worked examples

### Fixing a commit message without rebasing

A release commit landed on `main` with the wrong issue number in the message.
The commit is `a1b2c3d4`. You cannot rebase `main` because other branches
have already diverged from it.

Open the commit in your editor:

```sh
git replace --edit a1b2c3d4
```

Git pretty-prints the commit to a temporary file. The file looks like:

```text
tree 9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e
parent 7654321f
author Jane Dev <jane@example.com> 1700000000 +0100
committer Jane Dev <jane@example.com> 1700000000 +0100

Release v2.4.0 - closes #421
```

Change `#421` to `#412`, save, and quit. Git writes a new commit object and
creates the replace ref automatically.

Verify the replacement is active:

```sh
git replace --format=long -l
```

```console
a1b2c3d4 (commit) → e5f6a7b8 (commit)
```

```sh
git log --oneline -3
```

```console
e5f6a7b8 Release v2.4.0 - closes #412
...
```

Share the fix with the team:

```sh
git push origin 'refs/replace/*'
```

Teammates fetch it:

```sh
git fetch origin 'refs/replace/*:refs/replace/*'
```

### Joining an imported repository to its upstream history

Your organization's copy of a library was created from a tarball in 2019 and
has accumulated two years of local patches. You now have the real upstream
available and want `git log` to show the full lineage, but you cannot rewrite
the patch commits because they are already referenced by release tags.

The goal: make the root commit of the local-patch history (`loc0001`)
appear to descend from the tip of the upstream history (`ups9999`).

```sh
# Add upstream as a remote and fetch it
git remote add upstream https://example.com/library.git
git fetch upstream

# Create the graft: loc0001 gets ups9999 as its parent
git replace --graft loc0001 ups9999
```

Check the result:

```sh
git log --oneline upstream/main..HEAD
```

The log now walks through your local patches and continues back into upstream
history. The original `loc0001` object is untouched; the graft exists only as
a replace ref.

Push so CI and teammates see the same combined history:

```sh
git push origin 'refs/replace/*'
```

### Migrating from the deprecated grafts file

A legacy repository has `$GIT_DIR/info/grafts`. Migrate it to replace refs:

```sh
git replace --convert-graft-file
```

Git reads each line from the grafts file, creates a replacement commit for
it, deletes the file, and prints a summary. Push the new replace refs to a
shared remote and update the team's fetch configuration so everyone gets them
on the next `git fetch`.

## Recovery

Remove a specific replacement and restore the original object's visibility:

```sh
git replace -d <original-sha1>
```

Remove all replace refs in one step:

```sh
git for-each-ref --format='%(refname)' refs/replace/ | \
  xargs -r git update-ref -d
```

Inspect the original version of any object regardless of active replacements:

```sh
git --no-replace-objects cat-file -p <original-sha1>
```

See *Getting out of jams* for broader object-recovery techniques.

## See also

- *rebase* — rewriting history by actually changing commit hashes; reach for
  this when you need to change file content or restructure multiple commits.
- *notes* — attaching metadata to commits without touching the commit object
  or creating replace refs.
- *log* — reading history; pass `--no-replace-objects` to see the unmodified
  object graph.
- *fsck* — inspecting the raw object graph; always bypasses replacements.
