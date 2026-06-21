# search

Search all of GitHub — repositories, issues, pull requests, commits, and
code — directly from the terminal without opening a browser.

## Mental model

GitHub's search is a single global index that covers every public resource on
the platform (plus private resources you have access to). `gh search` exposes
that index through five subcommands — `repos`, `issues`, `prs`, `commits`,
`code` — each returning a specific resource type.

Every subcommand accepts two complementary ways to express a query:

- **Keyword arguments** — positional words (or a quoted phrase) that GitHub
  matches against the resource's primary text fields.
- **Qualifier flags** — typed, structured filters such as `--language=go`,
  `--state=open`, or `--stars=">100"` that map to GitHub search qualifiers
  under the hood.

You can combine both in a single command. Under the hood `gh` assembles the
flags into a GitHub search query string and sends it to the Search API; the
result is the same set of results you would get from `github.com/search`.

One important quirk: GitHub search qualifiers that begin with a hyphen (to
*exclude* results) conflict with the shell's flag parsing. Use `--` before
the qualifier to stop flag interpretation:

```sh
# Find issues that do NOT have the label "wontfix"
gh search issues -- "-label:wontfix"
```

Results default to 30 items. Every subcommand supports `--json` for machine-
readable output and `-w` / `--web` to open the equivalent search on
`github.com` in a browser.

## Synopsis

```text
gh search code     <query> [flags]
gh search commits  [<query>] [flags]
gh search issues   [<query>] [flags]
gh search prs      [<query>] [flags]
gh search repos    [<query>] [flags]
```

## Everyday usage

Find repositories by keyword:

```sh
gh search repos "vim plugin"
```

Find open issues assigned to you across all of GitHub:

```sh
gh search issues --assignee=@me --state=open
```

Find pull requests where you have been asked to review:

```sh
gh search prs --review-requested=@me --state=open
```

Find Go files that contain a specific function call pattern:

```sh
gh search code "http.ListenAndServe" --language=go
```

Find all merged PRs you authored in the last month:

```sh
gh search prs --author=@me --merged --created=">2025-05-17"
```

Open the search results in a browser for further filtering:

```sh
gh search repos "oauth client" --language=python -w
```

### search repos

Find repositories by keyword, language, topic, star count, and more.

```sh
# Public repos in a specific organisation
gh search repos --owner=cli --visibility=public

# Repos with a good-first-issue count suitable for contributors
gh search repos --language=rust --good-first-issues=">=5" --stars=">500"

# Repos tagged with multiple topics
gh search repos --topic=kubernetes,operator

# Exclude archived repos
gh search repos my-tool --archived=false
```

### search issues

Find issues across all of GitHub with fine-grained filters.

```sh
# Issues you were mentioned in
gh search issues --mentions=@me --state=open

# Issues with more than 50 comments, sorted by most comments first
gh search issues performance --comments=">50" --sort=comments

# Issues with no assignee in a specific repo
gh search issues --repo=myorg/myrepo --no-assignee --state=open

# Issues updated in the last week
gh search issues --updated=">2026-06-10" --state=open
```

### search prs

Find pull requests with PR-specific filters such as review status, base
branch, and CI check state.

```sh
# Draft PRs in a repo
gh search prs --repo=myorg/myrepo --draft --state=open

# PRs waiting for review that target the main branch
gh search prs --base=main --review=required --state=open

# Merged PRs approved by a specific reviewer
gh search prs --reviewed-by=alice --merged

# PRs that failed CI
gh search prs --checks=failure --state=open
```

### search commits

Search commit messages and metadata across public repositories or specific
repos.

```sh
# Commits by a specific author containing a keyword
gh search commits "fix memory leak" --author=alice

# Commits committed before a date
gh search commits --committer-date="<2024-01-01" --repo=myorg/myrepo

# Merge commits only
gh search commits --merge --repo=cli/cli
```

### search code

Search within file contents or file paths across public repositories.

```sh
# Find usages of a function across all Go files
gh search code "ctx.Deadline" --language=go

# Find a pattern in a specific repo
gh search code "TODO: remove" --repo=myorg/myrepo

# Search only file paths (not file contents)
gh search code "Makefile" --match=path

# Find config files by extension
gh search code database --extension=yaml --owner=myorg
```

Note: code search uses a legacy GitHub API. Results may differ from
`github.com/search` and regex search is not yet available via this path.

## Key options

### Common flags (most subcommands)

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-L` / `--limit int` | Maximum results to return (default 30) | Increase to fetch more than 30 matches |
| `--owner strings` | Filter by owner login | Scope to one or more orgs / users |
| `-R` / `--repo strings` | Filter on specific repository (not available for `search repos`) | Narrow to known repos |
| `--json fields` | Output JSON with named fields | Scripting and automation |
| `-q` / `--jq expression` | Filter JSON output with a jq expression | Extract specific fields inline |
| `-t` / `--template string` | Format JSON with a Go template | Custom tabular output |
| `-w` / `--web` | Open the query in a browser | Visual exploration / further filtering |
| `--visibility strings` | Filter by visibility: `public`, `private`, `internal` (not available for `search code`) | Limit to private repos you own |

### search repos flags

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--language string` | Filter by primary coding language | Language-specific discovery |
| `--stars number` | Filter by star count (supports `>`, `<`, ranges) | Quality signal |
| `--forks number` | Filter by fork count | Activity signal |
| `--topic strings` | Filter by topic tags | Thematic discovery |
| `--license strings` | Filter by license type | License-compatible forks |
| `--archived` | Include or exclude archived repos (`true`/`false`) | Focus on active projects |
| `--include-forks string` | Include forks: `false`, `true`, `only` | Explore derivative work |
| `--sort string` | Sort by `forks`, `stars`, `updated`, `help-wanted-issues` | Change ranking |
| `--order string` | `asc` or `desc` (with `--sort`) | Reverse the ranking |
| `--good-first-issues number` | Filter by count of "good first issue" labels | Find welcoming projects |
| `--match strings` | Restrict match to `name`, `description`, or `readme` | Target specific fields |
| `--size string` | Filter on repo size in kilobytes | Avoid massive codebases |

### search issues flags

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--state string` | `open` or `closed` | Focus on actionable items |
| `--assignee string` | Filter by assignee; `@me` for yourself | Your workload view |
| `--author string` | Filter by issue author | Track a user's reports |
| `--label strings` | Filter by one or more labels | Triage workflows |
| `--no-label` | Only issues with no labels | Untriaged issues |
| `--milestone title` | Filter by milestone | Release planning |
| `--comments number` | Filter by comment count | Hot topics |
| `--created date` | Filter by creation date | Time-boxed retrospectives |
| `--updated date` | Filter by last-updated date | Recently active threads |
| `--involves user` | Any involvement (author, assignee, commenter, mention) | Full involvement view |
| `--match strings` | Restrict to `title`, `body`, or `comments` | Precision keyword matching |
| `--include-prs` | Include PRs in issue results | Combined view |
| `--sort string` | Sort by `comments`, `created`, `updated`, `reactions`, etc. | Surface high-activity items |

### search prs flags

Shares most flags with `search issues`, with the following additions:

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--draft` | Filter on draft state | Find only draft (work-in-progress) PRs |
| `--merged` | Only merged PRs | Audit merged work |
| `--merged-at date` | Filter by merge date | Release retrospectives |
| `-B` / `--base string` | Filter by base branch name | PRs targeting a specific branch |
| `-H` / `--head string` | Filter by head branch name | Find a specific feature branch |
| `--checks string` | Filter by CI status: `pending`, `success`, `failure` | Find broken builds |
| `--review string` | Filter by review status: `none`, `required`, `approved`, `changes_requested` | Review queue |
| `--review-requested user` | Filter by reviewer or team requested | Your review queue |
| `--reviewed-by user` | Filter by reviewer who already reviewed | Audit reviewed PRs |

### search commits flags

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--author string` | Filter by author login | A contributor's commits |
| `--author-name string` | Filter by author display name | When login is unknown |
| `--author-date date` | Filter by authored date | Time-bounded queries |
| `--committer string` | Filter by committer login | Bot or CI committer |
| `--committer-date date` | Filter by committed date | When merges shift dates |
| `--hash string` | Filter by commit hash | Look up a specific commit |
| `--merge` | Only merge commits | Merge history |
| `--sort string` | Sort by `author-date` or `committer-date` | Chronological ordering |

### search code flags

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--language string` | Filter by language | Precision code search |
| `--extension string` | Filter by file extension | Non-standard language files |
| `--filename string` | Filter by filename | Config or manifest lookup |
| `--match strings` | Restrict to `file` (contents) or `path` | Path-only or content-only |
| `--size string` | Filter by file size in kilobytes | Avoid generated/minified files |

## Best practices

**Prefer qualifier flags over raw query strings where possible.** Flags
produce structured queries that GitHub's API can execute efficiently, and they
are unambiguous. A raw keyword query is fine for initial exploration but a
flag-only query is easier to automate and less prone to tokenisation
surprises.

**Use `--json` and `--jq` for scripting.** The tabular default output is
designed for reading, not parsing. When you need to feed results into another
tool, use `--json fields --jq .` to get structured data:

```sh
# Extract repository full names as plain text
gh search repos "oauth client" --language=go --json fullName --jq '.[].fullName'
```

**Use `@me` as a portable self-reference.** The special token `@me` resolves
to the active authenticated user, so scripts and aliases stay portable across
accounts:

```sh
gh search prs --review-requested=@me --state=open
```

**Set `--limit` intentionally.** The default is 30. GitHub's API caps results
at 1,000 per query. If you expect more than 30 relevant results, raise the
limit or narrow your filters — do not rely on the default to show you
everything.

**Combine keyword arguments with qualifier flags for tighter results.**
GitHub applies both, which narrows the result set more precisely than either
alone:

```sh
# "authentication" in the text, Go language, more than 200 stars
gh search repos authentication --language=go --stars=">200"
```

**Open with `-w` to explore interactively.** When building a complex query,
start with `gh search ... -w` to see the full result count and GitHub's
faceted sidebar before committing to flags.

## Pitfalls & gotchas

**Leading-hyphen qualifiers are eaten by the shell.** Any search qualifier
that starts with `-` (exclusion syntax) will be misinterpreted as a flag
unless you use `--`:

```sh
# WRONG — shell sees -label as an unknown flag
gh search issues -label:bug

# CORRECT — everything after -- is treated as a query argument
gh search issues -- "-label:bug"
```

**`gh search code` uses a legacy API.** The code search endpoint that `gh`
targets is powered by GitHub's older search infrastructure. New features such
as regex search and the exact result counts shown on `github.com` are not
available. If your results look incomplete or differ from the website, use
`-w` to fall back to the browser-based code search.

**Date filter values require quoting when using comparison operators.**
Values that include `>` or `<` must be quoted to prevent the shell from
treating them as redirects:

```sh
# WRONG — shell redirects stdin/stdout
gh search repos --stars=>500

# CORRECT
gh search repos --stars=">500"
```

**The default `--limit` of 30 silently drops results.** There is no warning
when more results exist beyond the limit. If you expect a large result set,
pass `-L 100` (or higher, up to 1,000) explicitly.

**`--sort` and `--order` are linked.** Specifying `--order` without `--sort`
has no effect; the API ignores it. Always pair them:

```sh
gh search repos kubernetes --sort=stars --order=desc
```

**Private repository searches require the right scope.** Searching private
repos requires that your token has the `repo` scope. If results are missing
private content you expect to see, check your auth scopes with `gh auth status
--show-token` (or run `gh auth refresh --scopes repo`; see *auth*).

## Worked examples

### Finding a repository to contribute to

You want to find a well-maintained Go project related to CLI tooling that is
welcoming to new contributors:

```sh
gh search repos cli terminal \
  --language=go \
  --stars=">100" \
  --good-first-issues=">=3" \
  --archived=false \
  --sort=stars \
  --order=desc \
  -L 10
```

```text
NAME                         STARS  FORKS  UPDATED
charmbracelet/bubbletea      27.8k  791    2026-06-16
urfave/cli                   22.2k  1.6k   2026-06-15
spf13/cobra                  38.1k  2.8k   2026-06-14
...
```

Open the top result in a browser to read its contribution guide:

```sh
gh search repos cli terminal --language=go --good-first-issues=">=3" -w
```

### Auditing open review requests

At the start of a work session, surface every open PR waiting for your
review, sorted by most recently updated:

```sh
gh search prs \
  --review-requested=@me \
  --state=open \
  --sort=updated \
  --order=desc \
  --json number,title,repository,url \
  --jq '.[] | "\(.repository.nameWithOwner)#\(.number) \(.title)"'
```

```text
myorg/backend#312 Fix race condition in worker pool
myorg/frontend#98 Add dark mode toggle
myorg/infra#54 Bump Terraform provider to 5.x
```

### Tracking down a regression

A bug was introduced sometime in April 2026 in the `myorg/payments` service.
Search merged PRs in that window to identify candidates:

```sh
gh search prs \
  --repo=myorg/payments \
  --merged \
  --merged-at="2026-04-01..2026-04-30" \
  --sort=updated \
  --json number,title,author,mergedAt,url
```

Then narrow to PRs touching a specific area:

```sh
gh search prs "checkout flow" \
  --repo=myorg/payments \
  --merged \
  --merged-at="2026-04-01..2026-04-30"
```

### Finding internal usage of a deprecated function

Before removing `legacyAuth()` from a shared library, confirm which
repositories in your organisation still call it:

```sh
gh search code "legacyAuth(" \
  --owner=myorg \
  --language=go \
  --json repository,path,url \
  --jq '.[] | "\(.repository.nameWithOwner) \(.path)"'
```

```text
myorg/api-gateway internal/middleware/auth.go
myorg/webhook-worker pkg/handler/verify.go
```

## Recovery

If a `gh search` command returns no results when you expect some:

1. Verify authentication with `gh auth status`. If the token is expired, run
   `gh auth login` to re-authenticate (see *auth*).
2. Check that your token has the `repo` scope if you are searching private
   repositories: `gh auth refresh --scopes repo`.
3. Simplify the query — remove flags one at a time until results appear, then
   add them back to identify the over-restrictive filter.
4. Use `-w` to run the same query on `github.com` and compare; if the website
   returns results the CLI does not, there may be an API lag or a code-search
   legacy-index limitation.

If a qualifier prefixed with `-` causes a "unknown flag" error, wrap the
entire qualifier in quotes and prepend `--`:

```sh
gh search issues -- "-label:wontfix"
```

## See also

- *auth* — manage authentication tokens and scopes required for private
  searches.
- *issue* — `gh issue list` for searching within a single repository without
  the global search API.
- *pr* — `gh pr list` for repository-scoped PR filtering.
- *repo* — `gh repo list` for listing repositories you own or are a member of.
- *browse* — `gh browse` to open a specific repository in the browser after
  finding it with `gh search repos`.
