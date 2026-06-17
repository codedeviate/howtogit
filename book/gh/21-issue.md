# issue

Create, view, list, and manage GitHub Issues without leaving the terminal.

## Mental model

A GitHub Issue is a unit of tracked work: a bug report, a feature request, a
task, or a question. Every issue lives in a repository, carries a number (e.g.
`#42`), and moves between the `open` and `closed` states. Issues can be
labelled, assigned to people, attached to milestones, added to Projects, pinned
to the repository page, linked to related issues through blocking/blocked-by
relationships, and organised into parent/sub-issue hierarchies.

`gh issue` is the command group that mirrors everything the GitHub web UI lets
you do with issues. Each subcommand targets an issue either by its number or by
its full URL — both forms work identically everywhere. When you run a subcommand
inside a cloned repository `gh` infers the repository from the git remote; pass
`-R OWNER/REPO` to target a different repository without changing directory.

Think of the subcommands in three tiers:

- **Discovery** — `list`, `status`, `view`: find and read issues.
- **Lifecycle** — `create`, `edit`, `close`, `reopen`, `delete`, `transfer`:
  create and move issues through their lifecycle.
- **Housekeeping** — `comment`, `develop`, `lock`, `unlock`, `pin`, `unpin`:
  add context or manage visibility.

## Synopsis

```text
gh issue list    [flags]
gh issue status  [flags]
gh issue view    {<number> | <url>} [flags]

gh issue create  [flags]
gh issue edit    {<numbers> | <urls>} [flags]
gh issue close   {<number> | <url>} [flags]
gh issue reopen  {<number> | <url>} [flags]
gh issue delete  {<number> | <url>} [flags]
gh issue transfer {<number> | <url>} <destination-repo>

gh issue comment  {<number> | <url>} [flags]
gh issue develop  {<number> | <url>} [flags]
gh issue lock     {<number> | <url>} [flags]
gh issue unlock   {<number> | <url>}
gh issue pin      {<number> | <url>}
gh issue unpin    {<number> | <url>}
```

## Everyday usage

### Listing issues

Show open issues in the current repository (default: up to 30):

```sh
gh issue list
```

Filter to issues assigned to you:

```sh
gh issue list --assignee "@me"
```

Filter by label, state, or milestone:

```sh
gh issue list --label bug --label "help wanted"
gh issue list --state all
gh issue list --milestone "v2.0"
```

Use a full-text search query (same syntax as GitHub's search bar):

```sh
gh issue list --search "error no:assignee sort:created-asc"
```

Open the list in a browser instead of the terminal:

```sh
gh issue list --web
```

### Checking your personal dashboard

Show issues in the current repository that are relevant to you — created by
you, assigned to you, or mentioning you:

```sh
gh issue status
```

### Viewing a single issue

Read an issue's title, body, and metadata:

```sh
gh issue view 42
```

Include comments:

```sh
gh issue view 42 --comments
```

Open in the browser:

```sh
gh issue view 42 --web
```

### Creating an issue

Open an interactive prompt for title and body:

```sh
gh issue create
```

Supply everything from the command line (no prompts):

```sh
gh issue create --title "Button overlaps footer on mobile" \
                --body "Steps to reproduce: ..."
```

Apply labels, an assignee, and a milestone in one shot:

```sh
gh issue create --title "Cache miss under load" \
                --label bug --label "help wanted" \
                --assignee "@me" \
                --milestone "v1.5"
```

Use a saved template:

```sh
gh issue create --template "Bug Report"
```

Open the browser form instead (useful for complex Markdown):

```sh
gh issue create --web
```

Create a sub-issue under a parent:

```sh
gh issue create --title "Write unit tests" --parent 100
```

### Editing an issue

Change the title and replace all labels in one call:

```sh
gh issue edit 42 --title "Button overlaps footer (Safari only)" \
                 --add-label bug --remove-label "needs triage"
```

Edit multiple issues at once (same repository):

```sh
gh issue edit 42 43 44 --add-label "help wanted"
```

Set or clear a parent/sub-issue relationship:

```sh
gh issue edit 55 --parent 10
gh issue edit 55 --remove-parent
```

Set blocking/blocked-by dependencies:

```sh
gh issue edit 42 --add-blocked-by 40 --add-blocking 50
```

### Closing and reopening

Close with an optional reason and comment:

```sh
gh issue close 42
gh issue close 42 --reason "not planned" --comment "Out of scope for v1."
gh issue close 42 --duplicate-of 38
```

Reopen a closed issue:

```sh
gh issue reopen 42 --comment "Regression confirmed in v1.4.2."
```

### Commenting

Add a comment non-interactively:

```sh
gh issue comment 42 --body "Reproduced on macOS 14.5."
```

Read from a file (or stdin):

```sh
gh issue comment 42 --body-file notes.md
echo "LGTM" | gh issue comment 42 --body-file -
```

Edit your last comment:

```sh
gh issue comment 42 --edit-last
```

Delete your last comment (with confirmation bypass):

```sh
gh issue comment 42 --delete-last --yes
```

### Creating a linked development branch

Create a branch tied to an issue and check it out immediately:

```sh
gh issue develop 42 --checkout
```

Specify a name and base branch:

```sh
gh issue develop 42 --name fix/button-overlap --base main
```

List branches already linked to an issue:

```sh
gh issue develop --list 42
```

### Housekeeping

Lock a heated conversation:

```sh
gh issue lock 42 --reason too_heated
```

Unlock it later:

```sh
gh issue unlock 42
```

Pin an issue to the repository's issue list (GitHub supports up to three
pinned issues):

```sh
gh issue pin 42
```

Unpin it:

```sh
gh issue unpin 42
```

Transfer to another repository:

```sh
gh issue transfer 42 myorg/other-repo
```

Permanently delete (irreversible — requires admin permission on the repository):

```sh
gh issue delete 42
gh issue delete 42 --yes  # skip confirmation prompt
```

## Key options

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-s` / `--state` | Filter by `open`, `closed`, or `all` | Reviewing resolved issues |
| `-l` / `--label` | Filter by label (repeatable) | Narrowing to a category |
| `-a` / `--assignee` | Filter by assignee login; `@me` for yourself | Your own queue |
| `-A` / `--author` | Filter by the issue's creator | Auditing a contributor |
| `-m` / `--milestone` | Filter by milestone number or title | Sprint planning |
| `-S` / `--search` | Full GitHub search query | Complex ad-hoc queries |
| `--type` | Filter by issue type name | Typed issue workflows |
| `-L` / `--limit` | Maximum issues to fetch (default 30) | Larger result sets |
| `--json` | Output specific fields as JSON | Scripting / piping to `jq` |
| `-q` / `--jq` | Filter JSON output with a jq expression | Inline data extraction |
| `-w` / `--web` | Open results in the browser | Richer filtering UI |

### create

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-t` / `--title` | Issue title | Non-interactive creation |
| `-b` / `--body` | Issue body text | Short bodies on the command line |
| `-F` / `--body-file` | Read body from a file or `-` for stdin | Long Markdown bodies |
| `-l` / `--label` | Apply a label (repeatable) | Categorise at creation time |
| `-a` / `--assignee` | Assign by login; `@me` to self-assign | Immediate ownership |
| `-m` / `--milestone` | Attach to a milestone | Sprint/release tracking |
| `-p` / `--project` | Add to a Project board by title | Project planning |
| `-T` / `--template` | Use a repository issue template | Consistent bug/feature reports |
| `--type` | Set the issue type | Typed issue workflows |
| `--parent` | Make this a sub-issue of another issue | Hierarchical task breakdown |
| `--blocked-by` | Mark as blocked by other issue numbers | Dependency tracking at creation |
| `--blocking` | Mark as blocking other issue numbers | Dependency tracking at creation |
| `-w` / `--web` | Open the browser form | Complex Markdown or file attachments |

### edit

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-t` / `--title` | Replace the title | Correcting an unclear title |
| `-b` / `--body` / `-F` / `--body-file` | Replace the body | Updating the description |
| `--add-label` / `--remove-label` | Add or remove labels | Triaging in bulk |
| `--add-assignee` / `--remove-assignee` | Assign or unassign (supports `@me`) | Reassigning work |
| `--add-project` / `--remove-project` | Attach or detach from a Project | Moving between boards |
| `-m` / `--milestone` | Change milestone | Rescheduling |
| `--remove-milestone` | Remove the milestone association | Deferring indefinitely |
| `--parent` / `--remove-parent` | Set or clear the parent issue | Reorganising hierarchy |
| `--add-sub-issue` / `--remove-sub-issue` | Attach or detach sub-issues | Reorganising hierarchy |
| `--add-blocked-by` / `--remove-blocked-by` | Manage blocked-by relationships | Dependency graph updates |
| `--add-blocking` / `--remove-blocking` | Manage blocking relationships | Dependency graph updates |
| `--type` / `--remove-type` | Set or clear the issue type | Reclassification |

### close

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-r` / `--reason` | `completed`, `not planned`, or `duplicate` | Accurate state reason |
| `--duplicate-of` | Reference the original issue number or URL | Deduplication |
| `-c` / `--comment` | Attach a closing comment | Leaving context for others |

### comment

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-b` / `--body` | Comment text | Quick inline comments |
| `-F` / `--body-file` | Read comment from file or stdin | Longer or templated text |
| `--edit-last` | Edit your most recent comment | Correcting a typo |
| `--delete-last` | Delete your most recent comment | Retracting a comment |
| `--create-if-none` | Create a new comment when used with `--edit-last` | Idempotent scripting |
| `--yes` | Skip the delete confirmation | Scripting `--delete-last` |
| `-w` / `--web` | Open the browser comment form | Rich editing |

### develop

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-n` / `--name` | Branch name to create | Custom branch naming |
| `-b` / `--base` | Remote branch to base the new branch on | Feature branches off non-default base |
| `-c` / `--checkout` | Check out the branch after creating it | Immediately start coding |
| `-l` / `--list` | List branches already linked to the issue | Auditing |
| `--branch-repo` | Repository where the branch should be created | Cross-repo development |

## Best practices

**Write the title first, then the body.** Use `--title` and `--body` (or
`--body-file`) for every scripted or automated creation. Relying on the
interactive prompt works fine ad hoc, but automation needs deterministic input.

**Use `--body-file -` to pipe Markdown from a template generator.** A script
that assembles a report from JSON data can write the Markdown to stdout and pipe
it straight into the issue body:

```sh
./generate-report.sh | gh issue create \
    --title "Nightly report $(date +%Y-%m-%d)" \
    --body-file -
```

**Prefer `--add-label` / `--remove-label` over replacing all labels.** The
`edit` subcommand adds and removes labels individually, so you cannot
accidentally wipe labels that were set by automation or other team members.

**Close with a reason.** GitHub records whether an issue was `completed`,
`not planned`, or `duplicate`. This context is permanently visible in the issue
timeline and in `list` output, helping future contributors understand why
something was closed. Make it a habit:

```sh
gh issue close 42 --reason completed
gh issue close 99 --reason "not planned" --comment "Deprioritised; reopen if needed."
```

**Use `develop --checkout` to start feature work.** Creating a linked branch
through `gh issue develop` registers the branch–issue relationship in GitHub's
UI. This makes it easy for reviewers to navigate from a pull request back to the
issue and understand the context.

**Add `--json` and `--jq` to scripts instead of grepping terminal output.**
The JSON field list for `list` and `view` is stable across `gh` versions;
terminal formatting is not:

```sh
# Get the number of every open bug
gh issue list --label bug --state open --json number --jq '.[].number'
```

**Batch edits save API round-trips.** When you need to apply the same label or
assignee to several issues, pass multiple numbers in one call:

```sh
gh issue edit 10 11 12 13 --add-label "sprint-3"
```

## Pitfalls & gotchas

**`gh issue list` only returns open issues by default.** This surprises
everyone at least once. Pass `--state all` or `--state closed` when you know
the issue was closed:

```sh
gh issue list --state closed --search "cache bug"
```

**`delete` is permanent and unrecoverable.** GitHub does not soft-delete issues:
once gone, the issue number is retired and the content is gone. Prefer `close
--reason "not planned"` unless you genuinely need to erase the issue. The `--yes`
flag skips the confirmation prompt entirely — do not use it in ad-hoc
interactive sessions.

**`develop` creates the branch on the remote, not locally (unless you pass
`--checkout`).** Running `gh issue develop 42` without `--checkout` creates the
branch on GitHub but leaves your local repository unchanged. You still need to
`git fetch` and check out the branch manually if you omit `--checkout`.

**Adding an issue to a Project requires the `project` scope.** If `create` or
`edit` fails with a scope error when you pass `--project`, grant the scope and
retry:

```sh
gh auth refresh --scopes project
gh issue create --project "Roadmap" --title "..."
```

**`--search` uses GitHub's issue search syntax, not shell glob syntax.** Quotes
inside the query refer to GitHub search qualifiers, not shell quoting. Always
wrap the whole query in double quotes and escape inner quotes if needed:

```sh
gh issue list --search "label:bug label:\"help wanted\""
```

**`status` shows issues relevant to you in the current repository (or the one
specified with `-R`), not across all repositories.** If you want to filter
further, use `list` with `--assignee "@me"` or `--author "@me"`.

**`lock` accepts only four reason values.** Anything outside
`off_topic`, `resolved`, `spam`, `too_heated` causes an error.

## Worked examples

### Triaging a bug report end-to-end

A user files a vague issue. You take ownership, label it, ask for
reproduction steps, and eventually resolve it.

```sh
# Assign yourself and apply triage labels
gh issue edit 88 --add-assignee "@me" \
                 --add-label bug \
                 --add-label "needs info"

# Ask the reporter for more detail
gh issue comment 88 --body \
  "Thanks for the report! Could you share the exact error message and OS version?"

# Once the reporter replies, remove needs-info and add reproduced
gh issue edit 88 --remove-label "needs info" --add-label "reproduced"

# Create a linked development branch and start working
gh issue develop 88 --checkout

# After the fix is merged, close as completed with a note
gh issue close 88 --reason completed \
  --comment "Fixed in #91. Will be available in the next release."
```

### Bulk labelling issues for a sprint

At sprint planning, the team decides which open issues belong to sprint 4.

```sh
# List candidates interactively in the browser first
gh issue list --state open --label "backlog" --web

# Apply the sprint label to the chosen issues
gh issue edit 20 21 25 30 33 --add-label "sprint-4" --remove-label "backlog"

# Confirm
gh issue list --label "sprint-4" --json number,title \
  --jq '.[] | "#\(.number) \(.title)"'
```

```text
#20 Improve cache eviction algorithm
#21 Add dark mode toggle
#25 Fix mobile layout on issue list page
#30 Write migration guide for v2 API
#33 Reduce cold-start time below 200 ms
```

### Scripting a nightly issue report

A CI job collects overnight error counts and files a dated issue with the
results.

```sh
#!/usr/bin/env bash
# nightly-report.sh
REPORT=$(./collect-errors.sh)   # produces Markdown

gh issue create \
  --repo myorg/myapp \
  --title "Nightly error report $(date +%Y-%m-%d)" \
  --body "$REPORT" \
  --label "automated" \
  --assignee ops-oncall
```

Because the body comes from a variable rather than an interactive prompt, the
script runs unattended in CI.

### Closing duplicates in bulk

After a popular library releases a breaking change, dozens of duplicate issues
appear. Close them all as duplicates of the canonical issue (`#200`):

```sh
# Find all the duplicates by searching for a shared error string
gh issue list --search "\"cannot read property of undefined\"" \
  --state open --json number --jq '.[].number' \
  | xargs -I{} gh issue close {} \
      --duplicate-of 200 \
      --comment "Duplicate of #200. Please subscribe there for updates."
```

## Recovery

**Accidentally closed an issue?** Reopen it and leave a note:

```sh
gh issue reopen 42 --comment "Closed by mistake."
```

**Accidentally deleted an issue?** Deletion is permanent. There is no recovery
path. Contact GitHub Support only if the deletion was very recent — they may be
able to restore it in exceptional circumstances, but this is not guaranteed.

**Wrong labels applied in bulk?** Reverse the edit with the inverse flags:

```sh
gh issue edit 20 21 25 --remove-label "sprint-4" --add-label "backlog"
```

**Branch created in the wrong repo?** Delete the branch on GitHub and re-run
`gh issue develop` with `--branch-repo` pointing at the correct repository.

See *Getting out of jams* for broader guidance on recovering from accidental
operations.

## See also

- *auth* — grant the `project` scope when `--project` flags fail.
- *pr* — `gh pr create` links a pull request to an issue; use `develop` to
  create the branch first.
- *label* — manage the label definitions referenced by `--label` flags.
- *project* — manage Project boards that issues are added to via `--project`.
- *repo* — `gh repo view` shows pinned issues and overall repository context.
