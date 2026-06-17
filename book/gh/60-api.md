# api

Make authenticated HTTP requests to the GitHub REST and GraphQL APIs directly
from the terminal, without leaving your workflow to open a browser or reach for
`curl`.

## Mental model

`gh api` is a thin, authenticated wrapper around GitHub's HTTP API. When you
run it, `gh` injects the stored OAuth token (or the value of `GH_TOKEN`) as the
`Authorization` header and sends the request to `api.github.com` — or a GitHub
Enterprise Server host if you specify one.

The command exposes both API flavors:

- **REST (v3)** — Pass a path such as `repos/{owner}/{repo}/issues`. The HTTP
  method defaults to `GET`; adding field flags (`-f`, `-F`) switches it to
  `POST`. Override the method explicitly with `-X`.
- **GraphQL (v4)** — Use the special endpoint `graphql` and supply your query
  via `-f query='...'`. Pagination, variable injection, and the `--slurp`
  helper all work with GraphQL too.

The curly-brace placeholders `{owner}`, `{repo}`, and `{branch}` are
substituted automatically from the repository in the current directory or from
the `GH_REPO` environment variable. This lets you write portable scripts that
work in any repo.

Response bodies are printed as-is (usually JSON). Two flags narrow the output
without requiring a separate `jq` installation: `--jq` applies a jq expression
inline, and `--template` renders a Go template.

## Synopsis

```text
gh api <endpoint> [flags]
gh api graphql   [flags]
```

## Everyday usage

Fetch a repository's metadata (uses placeholders):

```sh
gh api repos/{owner}/{repo}
```

List the open issues in the current repo:

```sh
gh api repos/{owner}/{repo}/issues
```

Post a comment on issue #42:

```sh
gh api repos/{owner}/{repo}/issues/42/comments \
  -f body='Looks good to me!'
```

Run a GraphQL query:

```sh
gh api graphql -f query='
  query {
    viewer {
      login
      name
    }
  }
'
```

Print only the login field with `--jq`:

```sh
gh api /user --jq '.login'
```

Fetch all pages of a paginated REST endpoint and collect them into one array:

```sh
gh api repos/{owner}/{repo}/issues --paginate --slurp
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-X` / `--method` | Override the HTTP method (`GET`, `POST`, `PATCH`, `PUT`, `DELETE`) | Any non-default verb |
| `-f` / `--raw-field` | Add a string parameter as `key=value` | Simple string request body fields |
| `-F` / `--field` | Add a typed parameter; converts `true`/`false`/`null`/integers to JSON; `@file` reads from a file | Non-string fields, nested params, file content |
| `-H` / `--header` | Add a custom HTTP request header as `key:value` | Custom `Accept` headers, API versioning |
| `--input` | Read the request body from a file (use `-` for stdin) | Pre-built JSON payloads |
| `-q` / `--jq` | Filter/transform the response with a jq expression | Extracting specific fields |
| `-t` / `--template` | Format the response with a Go template | Tabular or custom output |
| `--paginate` | Fetch all pages of results automatically | Complete data sets |
| `--slurp` | Wrap all paginated pages into a single outer JSON array | Use together with `--paginate` |
| `-p` / `--preview` | Opt into a named GitHub API preview (names must omit the `-preview` suffix, e.g. `baptiste` not `baptiste-preview`; repeat the flag or comma-separate for multiple) | Experimental endpoints |
| `--cache` | Cache the response for a duration (e.g. `60m`, `1h`) | Repeated calls to rate-limited endpoints |
| `-i` / `--include` | Print the HTTP status line and response headers | Debugging |
| `--verbose` | Print the full request and response, including headers | Deep debugging |
| `--silent` | Suppress the response body | Fire-and-forget writes |
| `--hostname` | Override the target host (default: `github.com`) | GitHub Enterprise Server |

### Typed fields with `-F`

The `-F` flag inspects the value and converts it before sending:

| Value form | What `gh` sends |
|------------|-----------------|
| `true` / `false` | JSON boolean |
| `null` | JSON null |
| Integer string | JSON number |
| `@path/to/file` | Contents of that file |
| `@-` | Contents of stdin |
| `{owner}`, `{repo}`, `{branch}` | Substituted from the current repo |

### Nested and array parameters

Use bracket syntax to build nested objects and arrays:

```sh
# Nested object
gh api some/endpoint -F 'parent[child]=value'

# Array — repeat the flag
gh api some/endpoint -F 'tags[]=bug' -F 'tags[]=help-wanted'

# Empty array
gh api some/endpoint -F 'tags[]'
```

### GraphQL-specific behaviour

For `graphql` requests, every field other than `query` and `operationName` is
treated as a GraphQL variable. The `--paginate` flag requires the query to
accept an `$endCursor: String` variable and to fetch
`pageInfo { hasNextPage endCursor }`.

## Best practices

**Use placeholders instead of hard-coding owner and repo.** Scripts written with
`{owner}` and `{repo}` work in any checkout without modification and are safe
to share:

```sh
# Portable — works in any repo
gh api repos/{owner}/{repo}/releases

# Fragile — breaks when copied to another repo
gh api repos/acme/backend/releases
```

**Prefer `-F` over `-f` for non-string values.** Sending the string `"true"`
where the API expects a boolean causes a 422 Unprocessable Entity error. Use
`-F` and let `gh` handle the conversion:

```sh
# Wrong — sends the string "true"
gh api repos/{owner}/{repo} -X PATCH -f has_wiki=true

# Correct — sends JSON boolean true
gh api repos/{owner}/{repo} -X PATCH -F has_wiki=true
```

**Use `--jq` to avoid a `jq` dependency.** The filter runs inside `gh` itself,
so your scripts work even where `jq` is not installed:

```sh
gh api repos/{owner}/{repo}/tags --jq '.[].name'
```

**Cache read-heavy calls.** The REST API allows 5 000 authenticated requests
per hour. Polling in a loop or in CI quickly burns through that budget. Add
`--cache` for any idempotent read:

```sh
gh api repos/{owner}/{repo} --cache 300s
```

**Use `--input` for large or complex payloads.** Building a deeply nested JSON
body with `-F` flags is error-prone. Write the JSON to a file and pass it with
`--input`. Note: when `--input` is used, any `-f`/`-F` flags are appended as
query-string parameters rather than merged into the body:

```sh
gh api repos/{owner}/{repo}/rulesets --input ruleset.json
```

**Set `GH_TOKEN` in CI rather than relying on stored credentials.** In GitHub
Actions the `GITHUB_TOKEN` secret is already available. Map it to `GH_TOKEN`
and `gh api` will use it without any stored credential. See *auth* for details
on environment-variable authentication:

```yaml
- name: Close a stale issue
  env:
    GH_TOKEN: ${{ github.token }}
  run: gh api repos/{owner}/{repo}/issues/99 -X PATCH -F state=closed
```

## Pitfalls & gotchas

**The HTTP method defaults to `POST` when you add any fields.** If you intend
to pass parameters as a `GET` query string, set `-X GET` explicitly:

```sh
# Without -X GET this would incorrectly POST instead of search
gh api -X GET search/issues -f q='repo:cli/cli is:open label:bug'
```

**Shells may expand `{...}` before `gh` sees it.** PowerShell and some zsh
configurations treat curly braces as brace-expansion or glob characters. Quote
the argument:

```sh
gh api "repos/{owner}/{repo}/issues"
```

**`--paginate` returns each page as a separate JSON document, not one merged
result.** Add `--slurp` to wrap all pages into a single array you can process
as a whole:

```sh
# Without --slurp: multiple JSON arrays printed back-to-back
gh api repos/{owner}/{repo}/issues --paginate

# With --slurp: one outer array containing every item
gh api repos/{owner}/{repo}/issues --paginate --slurp
```

**GraphQL pagination requires the query to cooperate.** If your query does not
fetch `pageInfo { hasNextPage endCursor }` and accept `$endCursor: String`,
`--paginate` silently returns only the first page without any warning.

**`--verbose`, `--silent`, `--template`, and `--jq` are mutually exclusive.**
Only one of these output-control flags may be used at a time; combining any two
causes an error. Use `--verbose` for debugging, `--silent` for fire-and-forget
writes, and `--jq`/`--template` for formatted output.

**Rate-limit errors return HTTP 403 or 429 with a JSON body.** Check the
remaining quota before a long-running loop:

```sh
gh api rate_limit --jq '.rate | {limit, remaining, reset}'
```

## Worked examples

### Listing and filtering releases

Fetch all release tag names from the current repo and print one per line:

```sh
gh api repos/{owner}/{repo}/releases --jq '.[].tag_name'
```

```text
v2.4.0
v2.3.1
v2.3.0
v2.2.0
```

Limit to the three most recent:

```sh
gh api repos/{owner}/{repo}/releases --jq '.[0:3][].tag_name'
```

### Creating a label via the REST API

```sh
gh api repos/{owner}/{repo}/labels \
  -f name='needs-triage' \
  -f color='e4e669' \
  -f description='Waiting for a maintainer to review'
```

```text
{
  "id": 4028982537,
  "name": "needs-triage",
  "color": "e4e669",
  "description": "Waiting for a maintainer to review",
  ...
}
```

### Bulk-closing issues with `--paginate`

Close every open issue labelled `wontfix` in the current repository. Fetch all
matching issue numbers with one paginated search call, then loop:

```sh
gh api -X GET search/issues \
  -f q='repo:{owner}/{repo} is:open label:wontfix' \
  --paginate \
  --jq '.items[].number' \
| while read -r number; do
    gh api repos/{owner}/{repo}/issues/"$number" \
      -X PATCH -F state=closed --silent
    echo "Closed #$number"
  done
```

### Querying the GraphQL API with pagination

List every repository the authenticated user owns, paginating automatically,
and collect the results into one JSON array:

```sh
gh api graphql --paginate --slurp -f query='
  query($endCursor: String) {
    viewer {
      repositories(first: 100, after: $endCursor) {
        nodes { nameWithOwner isPrivate }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
' | jq '[.[].data.viewer.repositories.nodes[]]'
```

### Tabular output with `--template`

Print the number, title, and state of the last five closed pull requests in a
tidy table:

```sh
gh api repos/{owner}/{repo}/pulls \
  -X GET \
  -f state=closed \
  -f per_page=5 \
  --template '{{range .}}{{tablerow .number .title .state}}{{end}}'
```

```text
47  Fix memory leak in parser    closed
46  Add dark-mode support         closed
45  Bump dependencies             closed
44  Remove deprecated endpoint    closed
43  Initial CI setup              closed
```

### Debugging a failed request

Add `--verbose` to see exactly what `gh` sent and what the server returned:

```sh
gh api repos/{owner}/{repo}/nonexistent --verbose
```

```text
* Request at 2024-11-01 10:32:01.123 +0000 UTC
> GET /repos/acme/backend/nonexistent HTTP/1.1
> Host: api.github.com
> Authorization: token ghp_...
< HTTP/1.1 404 Not Found
{
  "message": "Not Found",
  "documentation_url": "https://docs.github.com/rest"
}
```

## Recovery

If a request fails with **401 Unauthorized**, the stored token has expired or
been revoked. Refresh credentials with `gh auth refresh` or log in again with
`gh auth login`. See *auth* for the full credential-management workflow.

If you hit a **403 or 429 rate-limit** error, check remaining quota and the
reset time:

```sh
gh api rate_limit --jq '.rate | {limit, remaining, reset}'
```

The `reset` value is a Unix timestamp. Wait until that time or switch to a
different token with its own quota.

If a write operation partially succeeded — for example, some labels were
created before the script was interrupted — use `--include` on a subsequent
call to inspect the server state, then issue the corrective `PATCH` or
`DELETE` requests to bring the resource to the intended state.

## See also

- *auth* — managing the OAuth token that `gh api` injects automatically into
  every request.
- *config* — setting a default hostname or adjusting the git credential helper.
- *search* — `gh search` uses the REST search endpoint under the hood;
  `gh api -X GET search/...` gives the same data with full field control.
- *run* and *workflow* — `gh api` can trigger or inspect Actions runs via the
  REST API when the built-in subcommands do not expose the exact endpoint you need.
