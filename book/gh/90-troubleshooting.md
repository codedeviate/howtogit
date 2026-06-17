# Getting out of jams: gh

Authentication, API, and workflow problems have clear causes and repeatable
fixes. Work through the symptom that matches your error.

## HTTP 403 / "Permission denied" on a repo command

**What it means.** GitHub accepted your token but refused the request. The
authenticated user does not have the access the operation requires.

**Why it happens.** The most common cause on a machine with multiple accounts is
the wrong account being active. `gh` marks one account per host as active and
uses it for every command. If you last worked on a personal repo and forgot to
switch back before opening a work repo, every command runs as the wrong user.
A fine-grained personal access token scoped to specific repositories produces
the same 403 when you target a repo outside its scope.

**How to get out.**

1. Check which account is currently active:

   ```sh
   gh auth status --active
   ```

2. If the wrong account is active, switch to the correct one:

   ```sh
   gh auth switch --user correct-username
   ```

   On a host with exactly two accounts, omit `--user` to toggle between them.

3. Retry the original command.

4. If the token is a fine-grained PAT and the repo is simply outside its scope,
   generate a new token that covers the repo, or use a classic PAT, then
   re-authenticate:

   ```sh
   echo "ghp_newtoken..." | gh auth login --with-token
   ```

**How to avoid it.** After finishing work in one account's repos, run
`gh auth switch` to return to your default account. Confirm the active account
with `gh auth status --active` before any operation on a sensitive repo. Use
`GH_TOKEN` in the environment when you need a one-off override without touching
the stored credentials:

```sh
GH_TOKEN="ghp_work_token..." gh pr list --repo my-company/backend
```

## Not logged in / "authentication required" / expired token

**What it means.** `gh` has no stored credential for the host, or the credential
it holds has been revoked or expired.

**Why it happens.** Tokens expire (especially fine-grained PATs), get revoked in
the GitHub settings UI, or were never created because this is a new machine. In
a CI environment the secret may have been rotated and not updated in the
workflow.

**How to get out.**

1. Confirm the state of stored credentials:

   ```sh
   gh auth status
   ```

   Any account with an authentication failure is flagged here.

2. Log in again (or log in for the first time):

   ```sh
   gh auth login
   ```

   In a headless environment, pass a fresh token on stdin:

   ```sh
   echo "ghp_..." | gh auth login --with-token
   ```

3. If the old broken entry is still listed, log it out first:

   ```sh
   gh auth logout --hostname github.com --user stale-username
   gh auth login
   ```

**How to avoid it.** Prefer classic OAuth tokens (browser flow) for interactive
use — they do not expire on a fixed schedule. In CI, store the token in a secret
and use the `GH_TOKEN` environment variable; rotate the secret whenever you
rotate the underlying PAT.

## Missing token scopes ("requires the X scope")

**What it means.** The OAuth token `gh` holds was granted permissions at login
time, and the operation you are attempting needs a scope that was not included.

**Why it happens.** `gh auth login` requests only the minimum required scopes
(`repo`, `read:org`, `gist`). Commands that go beyond core PR/issue/repo work —
such as managing org SSO, publishing packages, or reading audit logs — need
additional scopes.

**How to get out.**

Add the missing scope without logging out:

```sh
gh auth refresh --scopes <scope-name>
```

For example, adding package write access:

```sh
gh auth refresh --scopes write:packages
```

This opens a browser to re-authorise the existing token with the new scope. When
a command error message names the exact scope needed, paste it directly into
`--scopes`.

To add multiple scopes at once, separate them with commas:

```sh
gh auth refresh --scopes write:org,admin:public_key
```

**How to avoid it.** Grant scopes only as needed — a token with fewer scopes
does less damage if it leaks. Keep note of which projects need which extra
scopes; you can inspect the current set with `gh auth status --show-token` and
decode the token on GitHub's token settings page.

## SSO authorization required for an org's resources

**What it means.** The organization has SAML Single Sign-On enabled. Your token
is valid for github.com in general but has not been authorized for this specific
org, so the API returns a 403 with a `X-GitHub-SSO` response header.

**Why it happens.** After authenticating with `gh auth login` or creating a PAT,
each organization that enforces SAML SSO requires a separate, explicit
authorization step before the token is allowed to access that org's resources.

**How to get out.**

1. Run the refresh command so that the browser flow can handle SSO:

   ```sh
   gh auth refresh
   ```

2. In the browser, complete the SAML login for the organization when prompted.

3. If the token is a PAT rather than an OAuth app token, go to
   **GitHub → Settings → Personal access tokens**, find the token, and click
   **Authorize** next to the organization.

**How to avoid it.** After first authenticating on a machine used for work at an
SSO-protected org, immediately run `gh auth refresh` and complete the SSO
authorization. Automate CI tokens by creating a service-account PAT that is
pre-authorized for the org and stored as a secret.

## HTTPS git push fails because gh credential helper uses the wrong account

**What it means.** A plain `git push` over HTTPS fails with a 403 or "remote:
Permission to ... denied" message even though `gh auth status` shows you are
logged in.

**Why it happens.** `gh auth setup-git` registers `gh` as git's HTTPS credential
helper. When git asks for credentials, `gh` supplies the token for whichever
account is currently active. If you have two accounts and the active one does not
have write access to the repo you are pushing to, the push is rejected. The
active account is a global setting, so it is easy to push to the wrong identity
after working in another account's repos.

**How to get out.**

1. Check the active account:

   ```sh
   gh auth status --active
   ```

2. Switch to the account that owns (or has write access to) the repo:

   ```sh
   gh auth switch --user correct-username
   ```

3. Push again:

   ```sh
   git push
   ```

4. If the remote URL uses SSH (starts with `git@github.com:` or uses an SSH
   config alias), the credential helper is not involved and the issue is with
   your SSH key, not `gh`. Check `ssh -T git@github.com` to confirm SSH
   identity.

**How to avoid it.** For repos you regularly push to from two different accounts,
consider using SSH remotes with separate host aliases in `~/.ssh/config`. That
way each remote carries its own identity and the active `gh` account is
irrelevant for git pushes.

## Rate limiting (HTTP 429 / X-RateLimit headers)

**What it means.** GitHub's API has returned a 429 Too Many Requests response, or
a 200/403 with `X-RateLimit-Remaining: 0`, indicating you have exhausted your
rate-limit quota for the current window.

**Why it happens.** Unauthenticated requests are limited to 60 per hour. An
authenticated token is limited to 5,000 requests per hour for the REST API.
Scripts that loop over repos, issues, or commits in tight loops can exhaust the
limit quickly. GraphQL has a separate point-based budget.

**How to get out.**

1. Inspect the current limit and when it resets:

   ```sh
   gh api rate_limit
   ```

   The response body shows `resources.core.remaining` and `resources.core.reset`
   (a Unix timestamp).

2. Use `gh api --include` to see the response headers on a live request:

   ```sh
   gh api --include repos/{owner}/{repo} 2>&1 | grep -i ratelimit
   ```

3. Wait until the reset time, then retry. The window resets on a rolling
   one-hour basis.

4. If the rate limit is from an unauthenticated request path, confirm `gh` is
   authenticated and the correct token is in use:

   ```sh
   gh auth status --active
   ```

**How to avoid it.** Add `--cache` to `gh api` calls that fetch stable data:

```sh
gh api --cache 1h repos/{owner}/{repo}
```

Use `--paginate` instead of writing your own loop so that `gh` handles cursor
management efficiently. In scripts, check `X-RateLimit-Remaining` and back off
before the limit hits zero.

## `gh pr create` — "no commits between base and head" / wrong base branch

**What it means.** `gh pr create` refuses to open a PR because the head branch
has no commits that are not already on the base branch.

**Why it happens.** Two common causes: the branch was branched from — or has
already been merged into — the target base, so there is nothing new to include;
or `gh pr create` inferred the wrong base branch (e.g., `main` when you intended
`develop`).

**How to get out.**

1. Confirm what base branch was inferred:

   ```sh
   gh pr create --dry-run --fill
   ```

   The dry-run output shows the base and head without creating the PR.

2. Specify the intended base explicitly:

   ```sh
   gh pr create --base develop --fill
   ```

3. If the branch genuinely has no new commits, check your git log:

   ```sh
   git log origin/main..HEAD --oneline
   ```

   If this is empty, the branch needs commits before a PR makes sense.

**How to avoid it.** Configure a per-branch merge base so that `gh pr create`
always picks it up:

```sh
git config branch.my-feature.gh-merge-base develop
```

From then on, `gh pr create` on that branch defaults to `develop` as the base
without needing the flag.

## Merge blocked by required checks / branch protection

**What it means.** GitHub refused a `gh pr merge` because required status checks
have not passed, or a branch protection rule demands reviews that have not been
completed.

**Why it happens.** The repository's branch protection rules require one or more
of: all CI checks to pass, a minimum number of approving reviews, no unresolved
conversations, or a signed-off commit policy. Attempting to merge before these
conditions are satisfied fails even via the CLI.

**How to get out.**

1. See which checks are pending or failing:

   ```sh
   gh pr checks
   ```

2. If checks are still running, wait for them or watch live:

   ```sh
   gh pr checks --watch
   ```

3. If a required check failed, fix the code, push, and wait for re-runs.

4. If you are waiting for a review, request one explicitly:

   ```sh
   gh pr edit --add-reviewer teammate-username
   ```

5. Enable auto-merge so that `gh` merges automatically once all requirements are
   met:

   ```sh
   gh pr merge --auto --squash
   ```

6. As a last resort, administrators can bypass protections with `--admin`:

   ```sh
   gh pr merge --admin --squash   # requires admin rights on the repo
   ```

**How to avoid it.** Use `gh pr merge --auto` as a habit. It queues the merge
immediately but waits for checks and reviews, so you do not have to poll
manually.

## `gh api` — distinguishing 404 vs 403 vs 422

**What it means.** `gh api` exits non-zero when the server returns an error
status. Each code means something different and demands a different fix.

**Why it happens.**

| Status | Meaning | Typical cause |
|--------|---------|---------------|
| `404 Not Found` | The resource does not exist, or the authenticated user cannot see it | Wrong endpoint path, resource deleted, or insufficient read access |
| `403 Forbidden` | The resource exists but the operation is not allowed | Token lacks a required scope, org SSO not authorized, or write-protected resource |
| `422 Unprocessable Entity` | The request was well-formed but semantically invalid | Required fields missing, conflicting state (e.g., trying to merge an already-merged PR), or validation failure |

**How to get out.**

Use `--include` to see the full HTTP response including status code and headers:

```sh
gh api --include repos/{owner}/{repo}/pulls/999
```

```text
HTTP/2.0 404 Not Found
...
{"message":"Not Found","documentation_url":"..."}
```

- **404**: Verify the endpoint path and that the resource exists. A private repo
  you cannot see returns 404, not 403, to avoid leaking its existence. Check
  that the active account has at least read access.

- **403**: Run `gh auth status --show-token` and check the token's scopes. See
  the *HTTP 403 / "Permission denied"* and *Missing token scopes* entries above.

- **422**: Read the response body carefully — it contains a `message` and often
  an `errors` array describing which field or constraint failed. Fix the request
  parameters accordingly.

**How to avoid it.** In scripts, capture the HTTP status with `--include` and
branch on it rather than letting a non-zero exit silently abort your script.
Use `--silent` combined with exit-code checking when you only care about success
vs failure:

```sh
if gh api repos/{owner}/{repo} --silent 2>/dev/null; then
  echo "repo accessible"
else
  echo "repo not accessible (check auth and path)"
fi
```

## Targeting a GitHub Enterprise Server host

**What it means.** Commands that work fine against github.com fail or hit the
wrong host when the target repository is on a GitHub Enterprise Server (GHES)
instance.

**Why it happens.** `gh` defaults every request to `github.com`. If your GHES
host is not specified, API calls go to the wrong server and return 404 or refuse
to authenticate.

**How to get out.**

1. Log in to the Enterprise host if you have not already:

   ```sh
   gh auth login --hostname github.mycompany.com
   ```

2. For `gh api` calls, pass `--hostname` to target the GHES instance:

   ```sh
   gh api --hostname github.mycompany.com repos/{owner}/{repo}
   ```

   For other commands that do not accept `--hostname`, set `GH_HOST` for the
   invocation, or use the `[HOST/]OWNER/REPO` syntax with the `-R` flag:

   ```sh
   GH_HOST=github.mycompany.com gh repo list my-org
   gh pr list -R github.mycompany.com/my-org/backend
   ```

3. To check which hosts are authenticated:

   ```sh
   gh auth status
   ```

**How to avoid it.** When a project always targets a GHES host, add
`GH_HOST=github.mycompany.com` to a project-level `.env` or your shell profile
for that work context. This avoids having to pass `--hostname` on every
invocation. See *auth* for details on managing credentials across multiple hosts.
