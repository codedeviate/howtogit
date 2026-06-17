# status

Show a cross-repository summary of your open work on GitHub: assigned issues,
assigned pull requests, review requests, mentions, and recent repository
activity — all in one view.

## Mental model

Every GitHub user accumulates work scattered across many repositories: issues
assigned to you in one org, PRs waiting for your review in another, comments
where someone mentioned your handle a third place. Normally you would have to
visit each repository or rely on GitHub's notification inbox. `gh status` pulls
all of that together and prints it to the terminal in a single dashboard.

The data comes from GitHub's REST API notifications and activity endpoints. It
reflects the repositories you watch or have been active in, filtered to items
that are directly relevant to you. It is a read-only snapshot — nothing is
modified when you run it.

Think of `gh status` as the terminal equivalent of the GitHub homepage's "Your
activity" feed, but scoped to actionable items rather than general social
activity.

## Synopsis

```text
gh status [-e <owner/repo>,...] [-o <org>]
```

## Everyday usage

Print your full work dashboard:

```sh
gh status
```

The output is divided into five panels:

```text
Assigned Issues                       │ Assigned Pull Requests
Nothing here ^_^                      │ #142 Fix login timeout   owner/repo
                                      │
Review Requests                       │ Mentions
#88 Add dark mode   owner/repo        │ Nothing here ^_^
                                      │
Repository Activity
#201 opened by colleague   owner/repo
```

Limit the dashboard to a single organisation:

```sh
gh status -o my-company
```

Exclude noisy repositories you do not want cluttering the output:

```sh
gh status -e cli/cli -e cli/go-gh
```

Combine both flags — show only one org while excluding a specific repo inside
it:

```sh
gh status -o my-company -e my-company/legacy-monolith
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-e` / `--exclude` | Comma-separated list of `owner/name` repos to hide | Silence high-traffic repos that drown out real work |
| `-o` / `--org` | Restrict results to one GitHub organisation | Focus on a single employer or project group |

## Best practices

**Run `gh status` before starting your day.** It surfaces review requests and
assigned issues that might otherwise sit unnoticed across many repositories.
Making it a morning habit is faster than checking each repository's notification
bell individually.

**Exclude high-traffic repositories with `-e`.** Monorepos and active
open-source repositories generate constant noise. Add them to your exclude list
so that items you actually own do not scroll off screen:

```sh
gh status -e my-company/platform -e my-company/frontend
```

**Scope to an org on large GitHub.com accounts.** If you contribute to both
employer and personal open-source repositories, use `-o <org>` when triaging
work tasks to avoid mixing contexts.

**Pair `gh status` with `gh pr status` for pull-request detail.** `gh status`
gives you the high-level overview; see *pr* for `gh pr status`, which adds CI
check results and merge-conflict indicators for pull requests in the current
repository.

## Pitfalls & gotchas

**Only repositories you watch or have been active in appear.** If you are added
to an issue in a repository you have never interacted with and do not watch, it
may not show up. Go to the repository on GitHub and subscribe to the relevant
notifications to make it appear.

**`--exclude` requires the full `owner/name` format.** Passing just the
repository name without the owner produces no error but also silences nothing.
Always use the slash-separated form:

```sh
# WRONG — silently ignored
gh status -e my-repo

# Correct
gh status -e my-company/my-repo
```

**Multiple repos with `-e` can be comma-separated or repeated.** Both forms
work; use whichever is easier in scripts:

```sh
gh status -e cli/cli,cli/go-gh        # comma-separated
gh status -e cli/cli -e cli/go-gh     # repeated flag
```

**The output is a terminal dashboard, not machine-parseable.** `gh status` has
no `--json` flag. If you need structured data about pull requests or issues,
use `gh pr list --json` or `gh issue list --json` instead (see *pr* and
*issue*).

**Activity reflects your notification subscriptions, not all public activity.**
Removing yourself from a repository's watchers will drop its items from the
Repository Activity panel even if you have open PRs there.

## Worked examples

### Morning triage across all repositories

Run the dashboard with no flags to see everything:

```sh
gh status
```

```text
Assigned Issues                       │ Assigned Pull Requests
#34 Update README   myorg/docs        │ #201 Add rate limiting   myorg/api
#67 Fix nav bar     myorg/frontend    │
                                      │
Review Requests                       │ Mentions
#88 Improve caching myorg/api         │ #12 @you LGTM?   myorg/infra
#91 Bump deps       myorg/frontend    │
                                      │
Repository Activity
#205 opened by alice   myorg/api
#31 closed by bob      myorg/docs
```

From here you can jump directly to any item with `gh pr view 88 --repo myorg/api`
or `gh issue view 34 --repo myorg/docs`.

### Focused org triage with noisy repos excluded

You work mainly in `myorg` but the `myorg/data-pipeline` repository has
continuous-integration bots opening hundreds of issues:

```sh
gh status -o myorg -e myorg/data-pipeline
```

```text
Assigned Issues                       │ Assigned Pull Requests
#34 Update README   myorg/docs        │ #201 Add rate limiting   myorg/api
                                      │
Review Requests                       │ Mentions
#88 Improve caching myorg/api         │ Nothing here ^_^
                                      │
Repository Activity
#205 opened by alice   myorg/api
```

The data-pipeline items are hidden; everything else in `myorg` still appears.

### Checking status in a CI or scripted context

`gh status` does not offer JSON output. For automated pipelines, compose the
purpose-built commands instead:

```sh
# All open PRs assigned to the authenticated user in one repo
gh pr list --assignee @me --state open --json number,title,url

# All open issues assigned to you across an org (via gh api)
gh api graphql -f query='
  query {
    search(query: "assignee:@me is:issue is:open org:myorg", type: ISSUE, first: 20) {
      nodes { ... on Issue { number title url } }
    }
  }
'
```

See *api* for using `gh api` to build custom queries when the dashboard's
fixed format is not enough.

## Recovery

`gh status` is purely read-only — it changes nothing. If the command errors:

- **Authentication error**: your token may have expired. Run `gh auth status`
  and re-authenticate with `gh auth login` if needed (see *auth*).
- **No results when you expect some**: check that the affected repository
  appears in your GitHub notification subscriptions. Visit the repository on
  GitHub and set your watch level to "All Activity" or "Participating".
- **Output truncated**: there is no pagination flag. Switch to `gh issue list`
  or `gh pr list` with `--limit` to retrieve full result sets.

## See also

- *auth* — authenticate `gh` and manage stored credentials used by every
  command including `gh status`.
- *pr* — `gh pr status` shows per-repository pull request detail with CI
  results and conflict indicators.
- *issue* — `gh issue list --assignee @me` lists assigned issues with full
  filtering and JSON output.
- *api* — build custom GraphQL queries when the fixed dashboard format is too
  limited.
