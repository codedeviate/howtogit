# project

Create, view, and manage GitHub Projects (v2) boards and their items from the
command line.

## Mental model

GitHub Projects v2 is a spreadsheet-like planning tool that lives at the
organization or user level, not inside a single repository. A project holds
**items** (issues, pull requests, and draft issues) that can come from any
repository. Each item has **fields** — built-in ones like Title, Status, and
Assignees, plus custom fields you define (text, number, date, or single-select).

The `gh project` command group is a full CRUD interface for that data model:

```text
owner (org or user)
  └── project (numbered 1, 2, 3…)
        ├── fields (Title, Status, custom…)
        └── items (issues, PRs, draft issues)
              └── field values (per-item metadata)
```

Because projects exist outside any single repository, most subcommands require
`--owner` (a GitHub login or organization name). Use `@me` to target your own
account without typing your username.

The `project` scope is not granted by default. Before running any `gh project`
command, confirm your token has it — and add it if not:

```sh
gh auth status                  # look for "project" in the listed scopes
gh auth refresh -s project      # add the scope
```

## Synopsis

```text
gh project list          [--owner <login>] [--closed] [-L limit] [--format json] [-w]
gh project view          [<number>] [--owner <login>] [--format json] [-w]
gh project create        --owner <login> --title <title> [--format json]
gh project edit          [<number>] --owner <login> [--title t] [--description d]
                         [--readme r] [--visibility PUBLIC|PRIVATE]
gh project close         [<number>] --owner <login> [--undo]
gh project delete        [<number>] --owner <login>
gh project copy          [<number>] --source-owner <login> --target-owner <login>
                         --title <title> [--drafts]

gh project field-list    [<number>] --owner <login> [-L limit]
gh project field-create  [<number>] --owner <login> --name <name>
                         --data-type TEXT|SINGLE_SELECT|DATE|NUMBER
                         [--single-select-options a,b,c]
gh project field-delete  --id <field-id>

gh project item-list     [<number>] --owner <login> [--query <filter>] [-L limit]
gh project item-add      [<number>] --owner <login> --url <issue-or-pr-url>
gh project item-create   [<number>] --owner <login> --title <title> [--body <body>]
gh project item-edit     --id <item-id> [--field-id <id>] [--project-id <id>]
                         [--text t] [--number n] [--date YYYY-MM-DD]
                         [--single-select-option-id id] [--iteration-id id]
                         [--title t] [--body b] [--clear]
gh project item-archive  [<number>] --owner <login> --id <item-id> [--undo]
gh project item-delete   [<number>] --owner <login> --id <item-id>

gh project link          [<number>] --owner <login> [-R repo] [-T team]
gh project unlink        [<number>] --owner <login> [-R repo] [-T team]
gh project mark-template [<number>] --owner <org> [--undo]
```

## Everyday usage

### Browsing projects

List all projects you own:

```sh
gh project list
```

Include closed projects:

```sh
gh project list --closed
```

List an organization's projects:

```sh
gh project list --owner my-org
```

Open a project in the browser instead of printing it:

```sh
gh project view 3 --owner my-org --web
```

### Creating and editing

Create a new project:

```sh
gh project create --owner "@me" --title "Q3 Roadmap"
```

Rename a project and set it to public:

```sh
gh project edit 3 --owner "@me" --title "Q3 Roadmap (public)" --visibility PUBLIC
```

Add a description and a readme:

```sh
gh project edit 3 --owner "@me" \
  --description "Tracks Q3 deliverables" \
  --readme "## How we work\nUpdate status every Friday."
```

### Closing and deleting

Close a finished project (it stays visible but is marked closed):

```sh
gh project close 3 --owner "@me"
```

Reopen it later:

```sh
gh project close 3 --owner "@me" --undo
```

Delete a project permanently (no confirmation prompt — see Pitfalls):

```sh
gh project delete 3 --owner "@me"
```

### Copying a project

Duplicate a project's structure to a new owner (useful for team templates):

```sh
gh project copy 3 --source-owner monalisa --target-owner my-org --title "Fork of Roadmap"
```

Include draft issues in the copy:

```sh
gh project copy 3 --source-owner monalisa --target-owner my-org \
  --title "Fork of Roadmap" --drafts
```

### Managing fields

List the fields defined in project 1:

```sh
gh project field-list 1 --owner "@me"
```

Add a plain-text field:

```sh
gh project field-create 1 --owner "@me" --name "Notes" --data-type TEXT
```

Add a single-select field (like a status column):

```sh
gh project field-create 1 --owner "@me" --name "Priority" \
  --data-type SINGLE_SELECT \
  --single-select-options "P0,P1,P2,P3"
```

Delete a field by its ID (obtain the ID from `field-list --format json`):

```sh
gh project field-delete --id PVTF_abc123
```

### Managing items

List items in project 1:

```sh
gh project item-list 1 --owner "@me"
```

Filter items using the Projects query syntax (github.com and GHES 3.20+):

```sh
gh project item-list 1 --owner "@me" --query "assignee:@me is:issue is:open"
gh project item-list 1 --owner "@me" --query "label:bug -status:Done"
```

Add an existing issue or pull request to a project:

```sh
gh project item-add 1 --owner "@me" \
  --url https://github.com/myorg/myrepo/issues/42
```

Create a draft issue (a standalone card, not linked to any repository):

```sh
gh project item-create 1 --owner "@me" --title "Research caching layer" \
  --body "Investigate Redis vs Memcached for the API tier."
```

Edit a field value on an item (all three IDs are required for non-draft items):

```sh
# Set a text field
gh project item-edit \
  --id PVTI_abc123 \
  --field-id PVTF_def456 \
  --project-id PVT_ghi789 \
  --text "Blocked on design review"
```

Clear a field value:

```sh
gh project item-edit \
  --id PVTI_abc123 \
  --field-id PVTF_def456 \
  --project-id PVT_ghi789 \
  --clear
```

Archive an item (hides it from the default view but keeps it in the project):

```sh
gh project item-archive 1 --owner "@me" --id PVTI_abc123
```

Unarchive:

```sh
gh project item-archive 1 --owner "@me" --id PVTI_abc123 --undo
```

Delete an item permanently:

```sh
gh project item-delete 1 --owner "@me" --id PVTI_abc123
```

### Linking to repositories and teams

Link project 1 to the current repository (run from inside the repo):

```sh
gh project link 1
```

Link to a specific repository:

```sh
gh project link 1 --owner monalisa --repo my_repo
```

Link to a team (organization projects only):

```sh
gh project link 1 --owner my-org --team frontend-team
```

Unlink:

```sh
gh project unlink 1 --owner monalisa --repo my_repo
```

### Marking a project as a template

Mark an organization project as a template so teams can copy it from the web UI:

```sh
gh project mark-template 1 --owner "my-org"
```

Remove the template mark:

```sh
gh project mark-template 1 --owner "my-org" --undo
```

Note: `mark-template` requires an org login, not a personal account.

## Key options

### Shared across most subcommands

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--owner <login>` | Target a specific user or org | Required for most subcommands |
| `--format json` | Emit JSON instead of a table | Scripting; piping to `jq` |
| `-q` / `--jq <expr>` | Filter JSON output with a jq expression | Extract a single field inline |
| `-t` / `--template <tmpl>` | Format JSON with a Go template | Custom tabular output |

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--closed` | Include closed projects | Auditing historical projects |
| `-L` / `--limit <n>` | Maximum number of projects to fetch (default 30) | Orgs with many projects |
| `-w` / `--web` | Open the projects list in the browser | Quick visual inspection |

### view

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-w` / `--web` | Open the project in the browser | Quick visual inspection |

### edit

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--title <string>` | Rename the project | After a rename decision |
| `-d` / `--description <string>` | Short description shown on the project card | Onboarding new contributors |
| `--readme <string>` | Long-form README for the project | Documenting workflow conventions |
| `--visibility PUBLIC\|PRIVATE` | Control who can see the project | Sharing with external stakeholders |

### copy

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--source-owner` | Owner of the project being copied | Required |
| `--target-owner` | Owner of the new copy | Required |
| `--drafts` | Also copy draft issue items | When drafts carry planning value |

### field-list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-L` / `--limit <n>` | Maximum number of fields to fetch (default 30) | Projects with many custom fields |

### field-create

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--data-type` | `TEXT`, `SINGLE_SELECT`, `DATE`, or `NUMBER` | Required; determines value type |
| `--single-select-options` | Comma-separated option names | Required when `--data-type` is `SINGLE_SELECT` |

### item-list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--query <filter>` | Projects filter syntax (assignee, label, status, etc.) | Narrowing large backlogs |
| `-L` / `--limit <n>` | Maximum number of items to fetch (default 30) | Large backlogs |

### item-edit

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--id` | Node ID of the item | Required |
| `--field-id` | Node ID of the field | Required for non-draft items |
| `--project-id` | Node ID of the project | Required for non-draft items |
| `--text` | New text value | TEXT fields |
| `--number` | New numeric value | NUMBER fields |
| `--date` | New date value (`YYYY-MM-DD`) | DATE fields |
| `--single-select-option-id` | Option node ID | SINGLE_SELECT fields |
| `--iteration-id` | Iteration node ID | Iteration fields |
| `--title` / `--body` | Update draft issue metadata | Draft items only |
| `--clear` | Remove the field value | Clearing stale data |

### link / unlink

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-R` / `--repo <name>` | Repository to link/unlink | Repository association |
| `-T` / `--team <name>` | Team to link/unlink (org projects) | Team-level visibility |

## Best practices

**Capture IDs with `--format json` and `jq`.** Most write operations
(`item-edit`, `field-delete`, `item-archive`, `item-delete`) require node IDs
that are never shown in the default table view. Retrieve them once and store
them in shell variables:

```sh
PROJECT_ID=$(gh project list --owner "@me" --format json \
  | jq -r '.projects[] | select(.title=="Q3 Roadmap") | .id')

ITEM_ID=$(gh project item-list 1 --owner "@me" --format json \
  | jq -r '.items[] | select(.title=="Research caching layer") | .id')
```

**Use `--query` to filter before paginating.** `item-list` without a query
fetches up to `--limit` items in project order. For projects with hundreds of
items, a targeted query is faster and avoids hitting the default limit:

```sh
gh project item-list 1 --owner "@me" \
  --query "assignee:@me status:\"In Progress\""
```

**Keep the `project` scope narrow.** The `project` OAuth scope grants
read/write access to all your projects. Do not add it to tokens that only need
repository access.

**Prefer `item-archive` over `item-delete` for completed work.** Archived
items remain searchable and restore with `--undo`. Deleted items are gone
immediately with no undo path from the CLI.

**Use `copy` to seed new projects from a standard template.** For teams that
run the same type of project repeatedly (sprints, quarterly roadmaps), build a
canonical project, mark it as a template with `mark-template`, then copy it at
the start of each cycle.

**Script bulk operations with a JSON pipeline.** The combination of
`--format json`, `jq`, and a shell loop handles bulk updates cleanly — for
example, moving all "Backlog" items to a new single-select value after renaming
a status option.

## Pitfalls & gotchas

**`gh project delete` has no confirmation prompt.** Unlike the web UI, the CLI
deletes immediately upon execution. There is no undo. Double-check the project
number and owner before running it.

**Node IDs vs. project numbers.** The `<number>` argument in most subcommands
is the human-readable project number (1, 2, 3…). However, `--id`, `--field-id`,
and `--project-id` flags all require GraphQL node IDs (strings starting with
`PVT_`, `PVTF_`, `PVTI_`). These are not interchangeable — passing a project
number where an ID is expected silently fails or targets the wrong object.
Retrieve node IDs via `--format json`.

**`item-edit` requires three IDs for non-draft items.** You must supply
`--id` (item), `--field-id` (field), and `--project-id` (project) together.
Omitting any one produces an error. For draft issues, only `--id` is needed
for title and body edits.

**`mark-template` only works on organization-owned projects.** Attempting to
mark a personal project as a template returns an error. The `--owner` value
must be an organization login.

**The `project` scope is not included in the default `gh auth login` scopes.**
Every `gh project` command fails with an authorization error until you add the
scope. Run `gh auth refresh -s project` once per account.

**`--single-select-options` must be supplied at creation time.** You cannot
add options to an existing `SINGLE_SELECT` field via `field-create`. Plan your
option set up front; modifying it later requires deleting and recreating the
field (losing stored values) or editing through the web UI.

**`copy` does not preserve field values on items.** It copies the project
structure (fields, views) and optionally the items themselves, but field
values on those items are not transferred. Use `copy` for structural templates,
not snapshots.

## Worked examples

### Setting up a sprint board from scratch

Create a project and note the project number from the URL it prints:

```sh
gh project create --owner "@me" --title "Sprint 42" --format json \
  | jq -r '.url'
```

```text
https://github.com/users/monalisa/projects/7
```

Add a SINGLE_SELECT Priority field to project 7:

```sh
gh project field-create 7 --owner "@me" \
  --name "Priority" \
  --data-type SINGLE_SELECT \
  --single-select-options "P0,P1,P2,P3"
```

List the fields to capture their node IDs:

```sh
gh project field-list 7 --owner "@me" --format json \
  | jq '.fields[] | {name,id}'
```

```text
{"name": "Title",    "id": "PVTF_aaa"}
{"name": "Status",   "id": "PVTF_bbb"}
{"name": "Priority", "id": "PVTF_ccc"}
```

Add an existing issue from a repository:

```sh
gh project item-add 7 --owner "@me" \
  --url https://github.com/monalisa/api/issues/99
```

Get the new item's node ID and the P1 option ID:

```sh
ITEM_ID=$(gh project item-list 7 --owner "@me" --format json \
  | jq -r '.items[] | select(.content.number==99) | .id')

OPTION_ID=$(gh project field-list 7 --owner "@me" --format json \
  | jq -r '.fields[] | select(.name=="Priority") | .options[] | select(.name=="P1") | .id')

PROJECT_ID=$(gh project list --owner "@me" --format json \
  | jq -r '.projects[] | select(.number==7) | .id')
```

Set the item's Priority to P1:

```sh
gh project item-edit \
  --id "$ITEM_ID" \
  --field-id PVTF_ccc \
  --project-id "$PROJECT_ID" \
  --single-select-option-id "$OPTION_ID"
```

### Archiving all Done items at the end of a sprint

Retrieve the IDs of every item whose Status is "Done" and archive each:

```sh
gh project item-list 7 --owner "@me" \
  --query "status:Done" \
  --limit 100 \
  --format json \
  | jq -r '.items[].id' \
  | while read -r item_id; do
      gh project item-archive 7 --owner "@me" --id "$item_id"
      echo "Archived $item_id"
    done
```

To restore them, swap `item-archive` for `item-archive --undo` in the same
loop, keeping a list of the IDs you archived (archived items no longer appear
in the default `item-list` output).

### Creating a reusable project template for an organization

Build the canonical project structure, add all desired fields and views, then
mark it as a template:

```sh
gh project mark-template 5 --owner "my-org"
```

Team members can copy it from the GitHub web UI, or via the CLI:

```sh
gh project copy 5 --source-owner my-org --target-owner my-org \
  --title "Sprint $(date +%Y-%W)"
```

## Recovery

**Accidentally deleted a project.** There is no CLI recovery path. Before
deleting any project, export its items to JSON as a safety net:

```sh
gh project item-list <number> --owner <owner> --limit 1000 --format json \
  > project-backup.json
```

If the organization has admin access, check with a GitHub organization owner
whether a server-side recovery option is available.

**Accidentally deleted an item.** Item deletion is permanent from the CLI. If
the item was an issue or pull request it still exists in its repository — add
it back with `item-add --url`. Draft issues that were deleted cannot be
recovered.

**Wrong field value set on an item.** Run `item-edit --clear` to remove the
value, then re-run `item-edit` with the correct value.

**Token missing `project` scope.** Run `gh auth refresh -s project` and
complete the browser flow. See *auth* for detailed scope management.

## See also

- *auth* — adding the `project` scope to your token with `gh auth refresh`.
- *issue* — `gh issue` for creating and managing the issues you then add to projects.
- *pr* — `gh pr` for pull requests tracked inside a project board.
- *repo* — `gh project link` connects projects to repositories managed with `gh repo`.
