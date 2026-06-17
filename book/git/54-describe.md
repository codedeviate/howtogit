# describe

Produce a human-readable name for any commit by anchoring it to the nearest
reachable tag.

## Mental model

Every commit has a SHA-1 hash, but hashes are opaque. `git describe` gives
you something you can read, say aloud, and embed in a build artifact:

```text
v1.4.2-7-g3a8f91c
  │     │    │
  │     │    └─ abbreviated SHA of the commit being described
  │     └─────── number of commits on top of the tag
  └───────────── most recent reachable annotated tag
```

Git walks backwards through the commit graph from the target commit (HEAD by
default), looking for the nearest tag. If the commit is exactly tagged, the
tag name alone is returned. If not, Git counts how many commits separate the
target from that tag and appends that count plus a `g`-prefixed hash.

The `g` prefix stands for "git" and exists so that version strings stay
unambiguous in environments where other SCMs might produce similar-looking
output.

By default, only annotated tags are considered. Lightweight tags (created
with `git tag` without `-a` or `-s`) are ignored unless you pass `--tags`.

## Synopsis

```text
git describe [--all] [--tags] [--contains] [--abbrev=<n>]
             [--candidates=<n>] [--exact-match] [--long]
             [--match <pattern>] [--exclude <pattern>]
             [--always] [--first-parent] [--debug]
             [<commit-ish>...]
git describe [--all] [--tags] [--contains] [--abbrev=<n>] --dirty[=<mark>]
git describe <blob>
```

## Everyday usage

Describe the current HEAD:

```sh
git describe
# v2.1.0-14-g9f3c20a
```

Describe a specific commit or branch:

```sh
git describe main
git describe a3f9c1b
```

Check whether the working tree is clean relative to the nearest tag (useful
in release scripts):

```sh
git describe --dirty
# v2.1.0          (clean)
# v2.1.0-dirty    (uncommitted changes present)
```

Get just the nearest tag name, with no suffix:

```sh
git describe --abbrev=0
# v2.1.0
```

Always produce output even when no tag exists yet:

```sh
git describe --always
# 9f3c20a   (falls back to abbreviated commit hash)
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--tags` | Match lightweight tags in addition to annotated tags | Repos that use lightweight tags for releases |
| `--all` | Match any ref under `refs/` (branches, remote-tracking refs, tags) | Exploratory use; rarely useful in scripts |
| `--contains` | Find the nearest tag that comes after the commit and contains it | Determine which release first shipped a given commit |
| `--abbrev=<n>` | Use `<n>` hex digits for the hash suffix; `0` suppresses it entirely | Normalize output length; `--abbrev=0` to get just the tag name |
| `--long` | Always emit the long `tag-N-gHASH` format, even on exact tag matches | Scripts that always need to parse all three components |
| `--dirty[=<mark>]` | Append `-dirty` (or a custom mark) if the working tree has local modifications | Build scripts and version-string generators |
| `--broken[=<mark>]` | Like `--dirty` but appends `-broken` if the repo state cannot be determined | CI environments where a corrupt repo is possible |
| `--exact-match` | Only print output if the commit is directly tagged; exit non-zero otherwise | Release gates that must confirm an exact tagged commit |
| `--candidates=<n>` | Consider up to `<n>` recent tags as candidates (default 10) | Deep histories where the nearest tag is more than 10 candidates back |
| `--match <pattern>` | Only consider tags matching the given glob pattern | Repos with multiple tag namespaces (e.g., `v*` vs. `rc*`) |
| `--exclude <pattern>` | Skip tags matching the given glob pattern | Exclude pre-release tags from version strings |
| `--always` | Fall back to an abbreviated commit hash when no tag is reachable | Guarantee output in shallow clones or untagged repos |
| `--first-parent` | Follow only first parents when walking the graph | Avoid picking up tags from merged feature branches |
| `--debug` | Print the search strategy to stderr | Diagnosing why describe chose a particular tag |

## Best practices

**Use annotated tags for releases.** `git describe` prefers annotated tags
over lightweight ones, and annotated tags carry authorship and a message.
Create them with `git tag -a v1.0.0 -m "Release 1.0.0"` rather than plain
`git tag v1.0.0`. Your release tooling will then work with the default
`git describe` invocation and no extra flags.

**Embed the describe output in build artifacts.** A common pattern is to
bake the version string into a compiled binary or a deployed package at
build time:

```sh
VERSION=$(git describe --tags --always --dirty)
echo "Building version: $VERSION"
```

The `--tags` flag catches lightweight tags, `--always` prevents failure in
shallow clones, and `--dirty` makes it obvious when someone shipped
uncommitted work.

**Use `--abbrev=0` to extract the base tag only.** If you only need the tag
name for changelog generation or milestone comparison, `--abbrev=0` strips
the commit-count and hash suffix cleanly:

```sh
LAST_TAG=$(git describe --abbrev=0)
git log "${LAST_TAG}..HEAD" --oneline
```

**Use `--match` to enforce a tag namespace in a monorepo.** In projects
with multiple release tracks, scope describe to the relevant tag prefix:

```sh
git describe --match "api/v*"
git describe --match "frontend/v*"
```

**Pair `--contains` with `--tags` when tracing when a fix shipped.** Given
a commit hash from a bug report, find the earliest release that contains it:

```sh
git describe --contains --tags abc1234
# v3.2.1~5   (the commit is 5 hops before v3.2.1 on the path to HEAD)
```

## Pitfalls & gotchas

**No annotated tags means no output.** On a fresh repo, or in a shallow
clone that did not fetch tags, `git describe` exits with a non-zero status
and prints nothing. Add `--always` to fall back to the commit hash, or
`--tags` if lightweight tags are available.

**Shallow clones truncate the graph.** CI environments often fetch with
`--depth 1` or `--depth 50`. If the nearest annotated tag is outside that
window, `git describe` cannot find it. Either deepen the clone
(`git fetch --unshallow`) or use `--tags --always` to get at least
something useful.

**`--abbrev=0` is not the same as `--exact-match`.** `--abbrev=0` silently
drops the suffix even when the commit is not directly tagged — the tag name
it returns may be many commits behind HEAD. `--exact-match` fails explicitly
when the commit is not directly tagged, which is what release gate scripts
usually want.

**Annotated tags are preferred, but `--tags` does not remove that
preference.** When both an annotated and a lightweight tag point to the
same commit, the annotated one wins. This is usually the right behavior but
can surprise you if you created a lightweight tag intending to override an
earlier annotated one.

**`--contains` walks forward, not backward.** The semantics reverse: it
finds a tag that the commit eventually leads to, not a tag it descended
from. The output format changes too — you may see `v1.2.0~3` rather than
`v1.1.0-4-gabcdef0`.

**Tag patterns use glob(7), not regex.** The `--match` and `--exclude`
patterns are shell-style globs (`v*`, `v[0-9]*`), not regular expressions.
A pattern like `v\d+\.\d+` will not work as expected.

## Worked examples

### Generating a version string for a release build

Your CI pipeline needs a reproducible version string for every build,
whether it is an exact release or a pre-release snapshot.

```sh
# In your build script:
VERSION=$(git describe --tags --long --always --dirty=-dev)
echo "$VERSION"
```

```text
v2.3.0-0-g7a4f1c2        # exact tag, clean tree (long format requested)
v2.3.0-3-g9b1e88a        # 3 commits past the tag
v2.3.0-3-g9b1e88a-dev    # same, with uncommitted changes
7a4f1c2                   # no tags at all (--always fallback)
```

Using `--long` ensures the format is always `tag-N-gHASH`, so a parser
can reliably split on `-` without special-casing exact matches.

### Finding which release first shipped a commit

A customer reports a regression introduced after v4.0.0. You have the
commit hash from `git bisect` (see the *bisect* chapter) and want to know
which release first contained it.

```sh
git describe --contains --tags 8f3c901
```

```text
v4.1.2~12
```

The commit is an ancestor of `v4.1.2`, twelve hops before it on the path
to that tag. The regression first appeared in `v4.1.2`.

If the commit is too recent to have a tag above it, the command exits
non-zero. Check `git log --oneline 8f3c901..HEAD` to see how far it is
from the tip.

### Scoping describe to a tag namespace in a monorepo

A monorepo contains two independently versioned components. Tags look like
`api/v1.2.3` and `ui/v2.0.1`. Describe each component separately:

```sh
# Component versions
API_VERSION=$(git describe --match "api/v*" --tags --abbrev=0)
echo "${API_VERSION#api/}"   # strip the prefix → v1.2.3

UI_VERSION=$(git describe --match "ui/v*" --tags --abbrev=0)
echo "${UI_VERSION#ui/}"     # strip the prefix → v2.0.1
```

The `--match` flag prevents the API describe from accidentally anchoring
to a UI tag that happens to be closer in the graph.

### Guarding a release pipeline with `--exact-match`

A release pipeline should only proceed when HEAD is an exact tagged commit.

```sh
if ! git describe --exact-match --tags HEAD 2>/dev/null; then
    echo "HEAD is not tagged. Tag the release commit before running this pipeline."
    exit 1
fi
```

`--exact-match` exits non-zero and prints nothing if HEAD is not directly
tagged, making it ideal as a guard condition. The `2>/dev/null` redirect
suppresses the error message Git would otherwise emit to stderr.

## Recovery

`git describe` is a read-only command — it never modifies the repository.
There is nothing to undo.

If the command produces unexpected output, use `--debug` to inspect the
search strategy:

```sh
git describe --debug
```

Git prints to stderr which tags it evaluated and how many commits apart
each one was, letting you trace exactly why it chose a particular anchor.

If describe fails because no tags exist in the repo, see the *tag* chapter
for how to create an annotated tag, then re-run describe.

## See also

- *tag* — creating the annotated tags that `git describe` anchors to.
- *log* — `git log <tag>..HEAD` lists commits since the last described tag.
- *bisect* — finding the commit that introduced a bug; pair with
  `git describe --contains` to name the release that shipped it.
- *shortlog* — summarising commits between two described versions.
- *Getting out of jams* — general recovery when the repository state is
  unexpected.
