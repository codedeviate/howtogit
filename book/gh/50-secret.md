# secret

Create, update, list, and delete encrypted secrets for use in GitHub Actions,
Dependabot, Codespaces, and Agents — at the repository, environment,
organization, or user level.

## Mental model

A GitHub secret is a named, encrypted value that GitHub injects into a
workflow run (or Codespaces environment) at execution time. You never see the
raw value again after storing it; GitHub stores only the encrypted form, and
the runner decrypts it in memory just before the step that needs it.

Secrets live at four levels:

- **Repository** — available to Actions runs, Agents sessions, and Dependabot
  inside one repository. This is the default level for `gh secret set`.
- **Environment** — scoped to a named deployment environment inside a
  repository (e.g., `production`, `staging`). Useful for environment-specific
  credentials that should only be visible to jobs targeting that environment.
- **Organization** — shared across repositories in an organization. Visibility
  can be `all` (every repo), `private` (private repos only), or `selected`
  (an explicit allowlist).
- **User** — available to Codespaces running under your personal account.

`gh secret set` encrypts the value locally using the repository's (or org's)
public key before sending it over the wire. GitHub never receives the
plaintext.

## Synopsis

```text
gh secret set    <secret-name> [flags]
gh secret list   [flags]
gh secret delete <secret-name> [flags]
```

`gh secret ls` is an alias for `gh secret list`.
`gh secret remove` is an alias for `gh secret delete`.

## Everyday usage

### Setting a secret interactively

Omit `--body` and `gh` prompts you to paste the value:

```sh
gh secret set DATABASE_URL
```

### Setting a secret from a shell variable

```sh
gh secret set API_KEY --body "$MY_API_KEY"
```

The value never touches your shell history as long as it is already in the
variable.

### Reading the secret value from a file

```sh
gh secret set TLS_CERT < cert.pem
```

### Bulk-loading secrets from a `.env` file

```sh
gh secret set -f .env
```

Each `KEY=value` line in the file becomes a separate secret. Lines starting
with `#` are ignored. Pass `-f -` to read from stdin instead.

### Setting an environment-scoped secret

```sh
gh secret set DB_PASS --env production
```

Only jobs that target the `production` deployment environment can read this
secret.

### Setting an organization secret

```sh
# Visible to all repositories in the org
gh secret set SHARED_TOKEN --org myOrg --visibility all

# Visible only to specific repositories
gh secret set DEPLOY_KEY --org myOrg --repos api,frontend,infra

# Stored but accessible to no repository (useful for reserving a name)
gh secret set PLACEHOLDER --org myOrg --no-repos-selected
```

### Setting a secret for a specific application

```sh
gh secret set NPM_TOKEN --app dependabot
gh secret set CODESPACE_TOKEN --user
```

### Listing secrets in the current repository

```sh
gh secret list
```

```text
NAME          UPDATED
API_KEY       about 2 hours ago
DATABASE_URL  about 1 day ago
TLS_CERT      about 3 days ago
```

Secret values are never shown; only names and timestamps are returned.

### Listing secrets in JSON format

```sh
gh secret list --json name,updatedAt,visibility
```

### Listing secrets for a deployment environment

```sh
gh secret list --env production
```

### Listing organization secrets

```sh
gh secret list --org myOrg
```

### Deleting a secret

```sh
gh secret delete OLD_API_KEY
```

### Deleting an environment or org secret

```sh
gh secret delete STAGING_DB --env staging
gh secret delete LEGACY_TOKEN --org myOrg
```

## Key options

### set

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-b` / `--body string` | Supply the value directly | Scripting; avoids the interactive prompt |
| `-f` / `--env-file file` | Load from a dotenv file | Bulk-importing secrets |
| `-e` / `--env environment` | Target a deployment environment | Environment-specific credentials |
| `-o` / `--org organization` | Target an organization | Shared secrets across repos |
| `-u` / `--user` | Target your user account | Personal Codespaces secrets |
| `-a` / `--app string` | Target a specific app (`actions`, `agents`, `codespaces`, `dependabot`) | App-scoped secrets |
| `-r` / `--repos repositories` | List of repositories that can access an organization or user secret | Explicit allowlist for org or user secrets |
| `-v` / `--visibility string` | `all`, `private`, or `selected` (default `private`) | Org-level visibility control |
| `--no-repos-selected` | Block all repos from accessing the org secret | Parking a name without exposure |
| `--no-store` | Print the encrypted base64 value instead of storing | Debugging the encryption path |
| `-R` / `--repo` | Target a different repository | Cross-repo secret management |

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-e` / `--env string` | List secrets for an environment | Environment-scoped audit |
| `-o` / `--org string` | List org secrets | Organization-level audit |
| `-u` / `--user` | List user secrets | Personal Codespaces audit |
| `-a` / `--app string` | Filter by application | App-specific listing |
| `--json fields` | Output JSON with chosen fields | Scripting and automation |
| `-q` / `--jq expression` | Filter JSON with a jq expression | Inline JSON processing |
| `-t` / `--template string` | Format JSON with a Go template | Custom output |

### delete

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-e` / `--env string` | Delete from a deployment environment | Environment cleanup |
| `-o` / `--org string` | Delete from an organization | Org-level secret removal |
| `-u` / `--user` | Delete from your user account | Personal Codespaces cleanup |
| `-a` / `--app string` | Target a specific application | App-scoped delete |

## Best practices

**Never pass secret values as positional arguments or in command history.**
Use `--body "$VAR"` (from a variable already in memory), a redirected file
(`< secret.txt`), or the interactive prompt. Commands written directly into
shell history can be recovered by teammates or attackers with access to that
machine.

**Use environment-scoped secrets for deployment credentials.** Putting
production database passwords in repository secrets means any Actions job in
the repo can read them, even on feature branches. Environment secrets require
a job to explicitly target `environment: production`, and you can add required
reviewers or branch filters to the environment.

**Prefer organization secrets for credentials shared across many repos.**
Updating one org secret propagates to every authorized repository
automatically. Maintaining the same secret name in thirty individual
repositories guarantees they will drift out of sync.

**Rotate secrets through `gh secret set` without downtime.** `set` is an
upsert — it overwrites the existing value in place. Queue a new value with
`gh secret set` before the old credential expires; workflows already in
progress use the version that was loaded when the run started.

**Audit secrets regularly with `gh secret list --json name,updatedAt`.** A
secret that has not been rotated in months is a liability. Pipe the output
through `jq` to find stale entries:

```sh
gh secret list --json name,updatedAt \
  | jq '.[] | select(.updatedAt < "2024-01-01") | .name'
```

**Use `--app dependabot` for Dependabot-specific secrets.** Actions secrets
and Dependabot secrets are separate namespaces because Dependabot runs in a
different execution context. A secret set without `--app` is not automatically
available to Dependabot.

## Pitfalls & gotchas

**Values are write-only — you can never read them back.** `gh secret list`
returns only names and timestamps. There is no `gh secret get`. Store the
plaintext value in a password manager before setting it; if you lose it, you
must generate a new credential and overwrite the secret.

**`--body` in your shell history.** If you type `gh secret set FOO --body
supersecret` directly into a terminal, the value lands in `.bash_history` or
`.zsh_history`. Use a variable or the interactive prompt instead:

```sh
# Risky — value ends up in shell history
gh secret set FOO --body "supersecret"

# Safe — value comes from a variable already set outside of history
gh secret set FOO --body "$SECRET_VALUE"
```

**`.env` file syntax is strict.** `gh secret set -f .env` expects lines in
the form `KEY=value`. Quoted values, `export KEY=value` prefixes, and
multi-line values may not parse as expected. Test with a small file and verify
immediately with `gh secret list`.

**Environment secrets require the environment to exist first.** If the
deployment environment `staging` does not exist in the repository settings,
`gh secret set --env staging` will fail. Create the environment in the GitHub
UI or via `gh api` before setting secrets against it.

**Organization secret visibility defaults to `private`.** Running `gh secret
set --org myOrg` without `--visibility` restricts the secret to private
repositories. If your target repo is public, add `--visibility all`
explicitly.

**`--repos` implies `selected` visibility for org secrets.** Passing `--repos`
automatically targets only those repositories. If you later want to widen
access, re-run `gh secret set` with a new `--repos` list or a different
`--visibility` value.

**Deleting a secret that is in active use silently breaks workflows.** There
is no confirmation prompt before delete. Confirm with `gh secret list` and
search the repository's workflow files before removing a secret that workflows
depend on.

## Worked examples

### Rotating a production database password

The old password is expiring. Generate a new one, store it, then verify:

```sh
# Generate a new password
NEW_PASS=$(openssl rand -base64 32)

# Overwrite the existing secret in place
gh secret set DB_PASSWORD --env production --body "$NEW_PASS"

# Confirm the timestamp updated
gh secret list --env production
```

```text
NAME         UPDATED
DB_PASSWORD  less than a minute ago
```

Store `$NEW_PASS` in your team password manager, then update the database to
accept the new credential before the old one expires.

### Importing a full set of secrets from a file into a new repository

You have a `.env.ci` file with all the secrets a workflow needs. Import them
in one step:

```sh
gh secret set -f .env.ci --repo myOrg/new-repo
```

Then confirm everything arrived:

```sh
gh secret list --repo myOrg/new-repo
```

### Sharing a deployment key across several repositories in an org

```sh
# Allow exactly three repos to read DEPLOY_KEY
gh secret set DEPLOY_KEY \
  --org myOrg \
  --repos api,frontend,infra \
  --body "$DEPLOY_KEY_VALUE"

# Later, extend the allowlist by re-running set with the full updated list
gh secret set DEPLOY_KEY \
  --org myOrg \
  --repos api,frontend,infra,docs \
  --body "$DEPLOY_KEY_VALUE"
```

### Auditing and cleaning up stale secrets

List all repo secrets with timestamps and find ones that have not been rotated
recently:

```sh
gh secret list --json name,updatedAt \
  | jq -r '.[] | [.name, .updatedAt] | @tsv'
```

Remove a secret that is no longer referenced in any workflow:

```sh
gh secret delete LEGACY_DEPLOY_TOKEN
```

### Dry-run: inspect the encrypted payload without storing

```sh
gh secret set TEST_SECRET --body "hello" --no-store
```

```text
QIAJAFq8...base64-encoded-ciphertext...==
```

This is useful when debugging a custom tool that handles secret encryption
before submitting via the API.

## Recovery

Secrets cannot be retrieved after they are set. If a secret value is lost:

1. Generate a new credential from the upstream service (API provider, cloud
   console, etc.).
2. Overwrite the old secret: `gh secret set <NAME> --body "$NEW_VALUE"`.
3. Update any dependent systems (databases, external services) to accept the
   new credential.

If a secret was deleted by mistake and workflows are failing, re-create it
immediately:

```sh
gh secret set DELETED_SECRET --body "$RECOVERED_VALUE"
```

Workflows that failed due to the missing secret can be re-run from the GitHub
Actions UI once the secret is restored.

If credentials may have been exposed (for example, accidentally echoed in a
workflow log or committed to a branch), treat it as a leak: revoke the
credential at the source immediately, generate a replacement, and rotate via
`gh secret set` before any further workflow runs.

## See also

- *auth* — authenticate `gh` before managing secrets.
- *variable* — `gh variable` manages non-secret, plaintext configuration
  values in Actions; use secrets for anything sensitive.
- *run* — `gh run` triggers and inspects the workflows that consume secrets.
- *workflow* — `gh workflow` lists and enables the workflows that reference
  secrets.
