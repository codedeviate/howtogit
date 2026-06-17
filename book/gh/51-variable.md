# variable

Manage plaintext configuration variables for GitHub Actions and Dependabot at
the repository, environment, or organization level.

## Mental model

Variables are named key-value pairs stored on GitHub that Actions workflows
and Dependabot jobs can read at runtime via `${{ vars.MY_VAR }}`. They differ
from secrets in one important way: their values are visible in the GitHub UI
and in API responses. Use variables for configuration that is not sensitive —
build flags, version pins, feature toggle names, deployment region strings —
and keep passwords, tokens, and keys in secrets (see *secret*).

Variables exist at three levels, each with its own scope:

- **Repository** — visible to all Actions runs and Dependabot jobs inside
  that specific repository.
- **Environment** — visible only to runs that target a named deployment
  environment (e.g., `production`, `staging`) in a specific repository.
- **Organization** — visible to runs inside member repositories; an
  organization variable can be restricted to selected repositories or opened
  to all repositories in the org.

When a variable name exists at multiple levels, the most specific level wins:
environment overrides repository, repository overrides organization.

## Synopsis

```text
gh variable list   [-e env] [-o org] [-R repo] [--json fields]
gh variable get    <variable-name> [-e env] [-o org] [-R repo] [--json fields]
gh variable set    <variable-name> [-b body] [-e env] [-f env-file]
                   [-o org] [-r repos] [-v visibility] [-R repo]
gh variable delete <variable-name> [-e env] [-o org] [-R repo]
```

## Everyday usage

List all variables on the current repository:

```sh
gh variable list
```

List variables for a deployment environment:

```sh
gh variable list --env production
```

List variables for an organization:

```sh
gh variable list --org my-org
```

Get the value of a single variable:

```sh
gh variable get DEPLOY_REGION
```

Set a variable interactively (gh prompts for the value):

```sh
gh variable set APP_VERSION
```

Set a variable non-interactively by passing the value directly:

```sh
gh variable set APP_VERSION --body "2.4.1"
```

Read the value from a shell variable to avoid it appearing in shell history:

```sh
gh variable set APP_VERSION --body "$APP_VERSION"
```

Read the value from a file:

```sh
gh variable set SOME_CONFIG < config.txt
```

Bulk-import variables from a dotenv file:

```sh
gh variable set -f .env
```

Set a variable scoped to a deployment environment:

```sh
gh variable set DEPLOY_REGION --env staging
```

Set an organization-level variable visible to all repositories:

```sh
gh variable set NODE_VERSION --org my-org --visibility all
```

Restrict an organization variable to specific repositories:

```sh
gh variable set NODE_VERSION --org my-org --repos repo-a,repo-b,repo-c
```

Delete a variable:

```sh
gh variable delete APP_VERSION
```

## Key options

### list / get

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-e` / `--env` | Target a deployment environment | Inspect per-environment config |
| `-o` / `--org` | Target an organization | Inspect org-level variables |
| `-R` / `--repo` | Target a different repository | When not inside the target repo |
| `--json fields` | Output JSON with named fields | Scripting and automation |
| `-q` / `--jq` | Filter JSON with a jq expression | Extract specific values inline |
| `-t` / `--template` | Format JSON with a Go template | Custom tabular output |

Available JSON fields for both commands: `createdAt`, `name`,
`numSelectedRepos`, `selectedReposURL`, `updatedAt`, `value`, `visibility`.

### set

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-b` / `--body` | Supply the variable value as a string | Non-interactive scripts |
| `-f` / `--env-file` | Load names and values from a dotenv file | Bulk import |
| `-e` / `--env` | Set a deployment environment variable | Per-environment config |
| `-o` / `--org` | Set an organization variable | Shared config across repos |
| `-r` / `--repos` | Repositories that can access an org variable | Scoped org variables |
| `-v` / `--visibility` | Org variable visibility: `all`, `private`, `selected` (default: `private`) | Control org-wide exposure |
| `-R` / `--repo` | Target a different repository | When not inside the target repo |

### delete

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-e` / `--env` | Delete from a deployment environment | Remove env-scoped variable |
| `-o` / `--org` | Delete from an organization | Remove org-level variable |
| `-R` / `--repo` | Target a different repository | When not inside the target repo |

## Best practices

**Keep sensitive values out of variables.** Because variable values are
visible in the UI and in JSON API responses, never store tokens, passwords,
certificates, or private keys as variables. Use *secret* for those instead.

**Use `--body "$SHELL_VAR"` in automation.** Running `gh variable set FOO`
without `--body` opens an interactive prompt, which hangs in CI. Always
supply the value explicitly in scripts. Expanding from a shell variable keeps
the literal value out of the command string that appears in process listings
and build logs:

```sh
gh variable set BUILD_FLAGS --body "$CI_BUILD_FLAGS"
```

**Bulk-import from `.env` with `--env-file`.** For repositories that already
maintain a dotenv file for local development, you can promote the non-secret
values to GitHub in one step:

```sh
gh variable set -f .env.production
```

Lines starting with `#` are treated as comments and skipped. Quoted values
are unquoted automatically.

**Use `--visibility selected` for organization variables.** Granting access
to all repositories in an org (`--visibility all`) can expose build config to
repositories whose maintainers do not expect it. Start with `selected` and
name the repositories explicitly, then broaden only when needed.

**Check the active scope before setting.** A repository variable with the
same name as an org variable silently shadows the org variable for that repo.
Run `gh variable list` at both levels to spot collisions before they cause
subtle workflow failures:

```sh
gh variable list                        # repository level
gh variable list --org my-org           # organization level
```

## Pitfalls & gotchas

**Variables are not secrets.** Values appear in plain text in `gh variable
list` output and in the GitHub web UI. Anyone with read access to the
repository (or to the org's settings) can see them. If you accidentally set a
secret as a variable, delete it immediately with `gh variable delete` and add
it as a secret instead.

**`--body` is required in non-interactive environments.** Without `--body`
(and without stdin being a pipe), `gh variable set` opens an interactive
prompt and the command hangs in CI. Always use `--body` in scripts.

**Visibility flag only applies to organization variables.** Passing
`--visibility` without `--org` is an error. The flag has no meaning at the
repository or environment level.

**The `--repos` flag implicitly sets visibility to `selected`.** When you
supply `--repos`, the GitHub API requires `visibility=selected`; the `gh` CLI
handles this automatically, so you do not need to pass `--visibility selected`
explicitly. You can still pass it explicitly for clarity, but omitting it is
not an error:

```sh
gh variable set NODE_VERSION \
  --org my-org \
  --repos api-service,web-frontend
```

**Environment variables set with `--env` are scoped to one repository.**
There is no org-level concept of environments; `--env` and `--org` are
mutually exclusive.

**`gh variable list` alias is `gh variable ls`.** Both work identically.
Similarly, `gh variable delete` can be invoked as `gh variable remove`.

## Worked examples

### Standardizing the Node.js version across a monorepo

Your organization runs several repositories that all need to stay on the same
Node.js version. Store it as an org variable so workflows can reference
`${{ vars.NODE_VERSION }}` without each repo pinning its own copy.

```sh
# Set it once at the org level, restricted to backend repositories
gh variable set NODE_VERSION \
  --body "20.14.0" \
  --org my-org \
  --visibility selected \
  --repos api-service,worker,jobs
```

Verify:

```sh
gh variable list --org my-org
```

```text
NAME          VALUE    UPDATED
NODE_VERSION  20.14.0  about 1 minute ago
```

When the LTS version bumps, update in one place:

```sh
gh variable set NODE_VERSION --body "22.3.0" --org my-org
```

### Per-environment deployment targets

A repository deploys to different AWS regions depending on the environment.
Store the region as an environment variable so each environment points to the
right place.

```sh
gh variable set AWS_REGION --body "eu-west-1"   --env staging
gh variable set AWS_REGION --body "eu-north-1"  --env production
```

Inspect both:

```sh
gh variable list --env staging
gh variable list --env production
```

```text
# staging
NAME        VALUE       UPDATED
AWS_REGION  eu-west-1   about 1 minute ago

# production
NAME        VALUE       UPDATED
AWS_REGION  eu-north-1  about 1 minute ago
```

In the workflow, the correct region is selected automatically based on which
environment the job targets:

```yaml
jobs:
  deploy:
    environment: production
    steps:
      - run: echo "Deploying to ${{ vars.AWS_REGION }}"
```

### Bulk-importing configuration from a dotenv file

A repository keeps non-secret build configuration in `.env.ci`:

```text
# .env.ci
BUILD_TARGET=linux-amd64
CACHE_BUCKET=my-build-cache
LOG_LEVEL=info
```

Import all three variables at once:

```sh
gh variable set -f .env.ci
```

Then verify:

```sh
gh variable list
```

```text
NAME          VALUE          UPDATED
BUILD_TARGET  linux-amd64    about 1 minute ago
CACHE_BUCKET  my-build-cache about 1 minute ago
LOG_LEVEL     info           about 1 minute ago
```

### Extracting a variable value in a script

Use `--json` and `--jq` to pull a single value into a shell variable without
parsing table output:

```sh
region=$(gh variable get AWS_REGION --env production --json value --jq .value)
echo "Deploying to $region"
```

```text
Deploying to eu-north-1
```

## Recovery

**Accidentally set a sensitive value as a variable** — delete it immediately,
then create it as a secret:

```sh
gh variable delete MY_API_KEY
echo "$MY_API_KEY" | gh secret set MY_API_KEY
```

**Wrong value set** — overwrite it by running `gh variable set` again with
the correct value. There is no separate "update" subcommand; `set` creates or
replaces:

```sh
gh variable set APP_VERSION --body "2.5.0"
```

**Variable not visible to a workflow** — check that the variable exists at
the right level (`--env`, `--org`, or repository) and that no variable at a
more specific level is shadowing it. Use `gh variable list` at each level to
compare.

**Organization variable not accessible to a repository** — if visibility is
`selected`, the repository must be explicitly listed. Add it with:

```sh
gh variable set NODE_VERSION \
  --org my-org \
  --visibility selected \
  --repos existing-repo,new-repo
```

## See also

- *secret* — encrypted secrets for sensitive values; the companion to
  variables.
- *auth* — managing the credentials that allow `gh variable` to call the
  GitHub API.
- *run* — `gh run` and `gh workflow` are where variables surfaced via
  `vars.*` context are consumed.
- *workflow* — managing the Actions workflow files that reference variables.
