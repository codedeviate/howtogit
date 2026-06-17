# label

Create, edit, delete, list, and clone issue and pull-request labels in a
GitHub repository.

## Mental model

Labels in GitHub are repository-scoped tags attached to issues and pull
requests to signal type, priority, status, or any other dimension your team
cares about. They have three properties: a **name** (the slug that appears in
search filters), a **color** (a six-character hex value that drives the
colored chip in the UI), and an optional **description** (a short tooltip).

`gh label` manipulates those labels directly through the GitHub API without
opening a browser. Because labels are per-repository, every subcommand
operates on a specific repo — the current repository by default, or any other
via `--repo`. The `clone` subcommand is the one exception that reads from a
*source* repository and writes to a destination.

A common team pattern is to designate one "canonical" repository that holds
your full, curated label set and use `gh label clone` to stamp that set onto
every new repo. The `--force` flag on both `create` and `clone` makes
idempotent re-runs safe.

## Synopsis

```text
gh label list   [--search <query>] [--sort <field>] [--order <asc|desc>]
                [--limit <n>] [--json <fields>] [--web] [-R <repo>]

gh label create <name> [--color <hex>] [--description <text>] [--force]
                [-R <repo>]

gh label edit   <name> [--name <new-name>] [--color <hex>]
                [--description <text>] [-R <repo>]

gh label delete <name> [--yes] [-R <repo>]

gh label clone  <source-repository> [--force] [-R <repo>]
```

## Everyday usage

List all labels in the current repository:

```sh
gh label list
```

List labels sorted alphabetically:

```sh
gh label list --sort name
```

Search for labels related to bugs:

```sh
gh label list --search bug
```

Create a new label with a color and description:

```sh
gh label create enhancement \
  --color 84b6eb \
  --description "New feature or request"
```

Edit an existing label's color:

```sh
gh label edit bug --color FF0000
```

Rename a label and update its description at the same time:

```sh
gh label edit wontfix \
  --name "won't fix" \
  --description "Intentionally not addressed"
```

Delete a label (prompts for confirmation):

```sh
gh label delete obsolete-label
```

Delete without a confirmation prompt (useful in scripts):

```sh
gh label delete obsolete-label --yes
```

Copy all labels from a template repository into the current repo:

```sh
gh label clone my-org/label-template
```

Overwrite any conflicting labels in the destination:

```sh
gh label clone my-org/label-template --force
```

## Key options

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-S` / `--search` | Filter by name or description | Find a specific label quickly |
| `--sort` | Sort by `created` or `name` (default: `created`) | Browse labels in alphabetical order |
| `--order` | Sort direction: `asc` or `desc` (default: `asc`) | Show newest labels first with `--order desc` |
| `-L` / `--limit` | Max labels to fetch (default: 30) | Repos with large label sets |
| `--json` | Output JSON with specified fields | Scripting; available fields: `color`, `createdAt`, `description`, `id`, `isDefault`, `name`, `updatedAt`, `url` |
| `-q` / `--jq` | Filter JSON output with a jq expression | Extract just the names or colors |
| `-t` / `--template` | Format JSON with a Go template | Custom tabular output |
| `-w` / `--web` | Open the labels page in the browser | Visual browsing |
| `-R` / `--repo` | Target a different repository | Any `label` subcommand |

### create

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-c` / `--color` | Set the label color as a 6-char hex value | Give the label a specific color; a random color is chosen if omitted |
| `-d` / `--description` | Short description shown as a tooltip | Document the label's intended use |
| `-f` / `--force` | Update color and description if the label already exists | Idempotent provisioning scripts |

### edit

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-n` / `--name` | Rename the label | Standardizing naming across repos |
| `-c` / `--color` | Change the label color | Rebranding or accessibility improvements |
| `-d` / `--description` | Change the description | Clarifying a label's scope |

### delete

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--yes` | Skip the interactive confirmation prompt | Scripted cleanup |

### clone

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-f` / `--force` | Overwrite labels that already exist in the destination | Re-syncing a repo to the canonical template |

## Best practices

**Maintain a canonical label repository.** Keep one repository (e.g.
`my-org/labels`) whose sole purpose is to hold the agreed label set. Seed new
repositories from it with `gh label clone`. This guarantees consistent names
and colors across every repo, which matters for cross-repo issue searches and
automation that filters by label.

**Use `--force` when re-syncing, not just when first cloning.** On a first
clone the destination is empty, so `--force` is harmless but unnecessary.
Reserve it for explicit re-sync runs where you want the canonical set to win
over any local drift.

**Always supply a color.** GitHub assigns a random color when you omit
`--color`, producing an inconsistent palette. Choose a palette upfront and
encode it in your `create` commands or canonical repository.

**Use `--json` and `--jq` for scripting.** The text output of `gh label list`
is for humans. When a script needs label names, pipe JSON instead:

```sh
gh label list --json name --jq '.[].name'
```

**Use `--force` on `create` for idempotent provisioning.** Automation scripts
that run on every deploy can call `gh label create --force` and never need to
check whether the label already exists first.

**Prefer `edit` over delete-and-recreate when renaming.** GitHub preserves the
association between a label and its issues when you rename via the API. Deleting
and recreating the label severs that link; `gh label edit --name` keeps it.

## Pitfalls & gotchas

**`--search` disables `--sort` and `--order`.** When you pass `--search`,
results are ranked by best match. The `--sort` and `--order` flags are silently
ignored in that mode.

**Color must be exactly 6 hex characters with no leading `#`.** Both of these
will fail:

```sh
gh label create triage --color "#FF6600"   # WRONG — do not include the hash
gh label create triage --color F60         # WRONG — must be 6 characters
```

Correct form:

```sh
gh label create triage --color FF6600
```

**`clone` does not delete labels absent from the source.** Labels present in
the destination but missing from the source are left untouched. If you want
the destination to be an exact mirror you must delete the extra labels manually
with `gh label delete`.

**`clone` skips existing labels unless you pass `--force`.** If the destination
already has a label with the same name but a different color or description, it
is silently skipped. Add `--force` to overwrite.

**`--limit` defaults to 30.** A repository with more than 30 labels will appear
incomplete in the default `list` output. Pass a higher value when you need the
full set:

```sh
gh label list --limit 200
```

**Deleting a label does not remove it from closed issues' history.** The label
is stripped from the issue's current state but the deletion event is recorded
in the issue timeline.

## Worked examples

### Bootstrapping a new repository from a shared label set

A team keeps their canonical labels in `my-org/standards`. When they create a
new repository they run:

```sh
# Create the new repo
gh repo create my-org/new-service --private

# Copy all labels from the canonical repo into the new one
gh label clone my-org/standards --repo my-org/new-service
```

```text
✓ Cloned 18 labels to my-org/new-service
```

Six months later the canonical set is updated. Re-sync and overwrite any
drifted labels:

```sh
gh label clone my-org/standards --repo my-org/new-service --force
```

### Auditing a label set with JSON output

List every label as JSON and print name, color, and description side by side:

```sh
gh label list --limit 100 --json name,color,description \
  --jq '.[] | "\(.color)  \(.name)  — \(.description)"'
```

```text
e4e669  duplicate  — This issue or pull request already exists
d73a4a  bug        — Something isn't working
0075ca  feature    — New feature or request
```

Find labels that have no description (empty string):

```sh
gh label list --limit 100 --json name,description \
  --jq '.[] | select(.description == "") | .name'
```

Delete each undescribed label after reviewing the list:

```sh
gh label delete "undescribed-label" --yes
```

### Renaming a label without losing issue associations

Use `edit` rather than delete-and-recreate to preserve the link between a
label and its issues:

```sh
# Old name: "in-progress" — team wants "status: in progress"
gh label edit "in-progress" \
  --name "status: in progress" \
  --color 0E8A16 \
  --description "Work is actively underway"
```

All issues that carried `in-progress` now show `status: in progress` with no
manual re-tagging required.

## Recovery

If you delete a label by mistake, recreate it with the original name, color,
and description, then re-apply it to affected issues:

```sh
# Recreate the deleted label
gh label create accidentally-deleted \
  --color CC0000 \
  --description "Original description here"

# Re-apply to a specific issue
gh issue edit 42 --add-label "accidentally-deleted"
```

If a `clone --force` run overwrote labels you wanted to keep, the only path
back is to `edit` each label to its previous color and description. Check your
team's canonical source or the GitHub UI's label history for the original
values.

For broader repository mistakes, see *Getting out of jams*.

## See also

- *issue* — attach and remove labels on issues with `gh issue edit --add-label`
  and `gh issue edit --remove-label`.
- *pr* — the same `--add-label` / `--remove-label` flags apply to pull requests
  via `gh pr edit`.
- *repo* — `gh repo create` creates the repository that labels live in.
