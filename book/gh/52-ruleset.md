# ruleset

Inspect and audit the repository protection rules that GitHub enforces on
branches and tags.

## Mental model

A GitHub **ruleset** is a named policy attached to a repository or
organisation that tells GitHub which operations are allowed or forbidden on
matching refs. Unlike the older branch-protection settings, rulesets can
target multiple branches at once (using `fnmatch` patterns), can be layered
— a repository inherits rulesets from its organisation and enterprise — and
are version-controlled inside GitHub itself.

Rules can require pull requests before merging, mandate status checks,
restrict who may push or delete a branch, enforce signed commits, and more.
The `gh ruleset` command group lets you **read** that configuration: list
the rulesets that exist, view the details of any single ruleset, and check
which rules would fire against a specific branch name before you push.

`gh ruleset` is a read-only surface. Creating, editing, or deleting rulesets
is done through the GitHub web UI or the REST API (see *api*).

## Synopsis

```text
gh ruleset list   [flags]
gh ruleset view   [<ruleset-id>] [flags]
gh ruleset check  [<branch>] [flags]
```

`gh rs` is an alias for `gh ruleset`.

## Everyday usage

### List rulesets for the current repository

```sh
gh ruleset list
```

```text
ID    NAME                      SOURCE              STATUS   RULES
12    require-pr-and-ci         my-org/backend      active   6
34    protect-release-branches  my-org/backend      active   3
78    org-wide-signing-policy   my-org              active   1
```

The SOURCE column shows whether a ruleset is defined directly on the
repository or inherited from an organisation (or enterprise).

### List only rulesets defined on the repository itself

Pass `--parents=false` to suppress inherited rulesets:

```sh
gh ruleset list --parents=false
```

### List organisation-wide rulesets

```sh
gh ruleset list --org my-org
```

Your token needs the `admin:org` scope for this. Grant it with
`gh auth refresh -s admin:org` (see *auth*).

### View a single ruleset

```sh
gh ruleset view 34
```

If you omit the ID, `gh` shows an interactive prompt to pick from the
rulesets that apply to the current repository.

Open the ruleset in the browser to read its full configuration:

```sh
gh ruleset view 34 --web
```

### Check which rules apply to a branch

```sh
gh ruleset check my-feature-branch
```

No argument uses the current branch. Pass `--default` to check the
repository's default branch regardless of which branch is checked out:

```sh
gh ruleset check --default
```

Open the equivalent rules page in the browser:

```sh
gh ruleset check --web
```

## Key options

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-L` / `--limit int` | Maximum rulesets to return (default 30) | Large organisations with many rulesets |
| `-o` / `--org string` | List organisation-wide rulesets | Auditing policies at the org level |
| `-p` / `--parents` | Include inherited rulesets (default true) | Pass `false` to see only repo-local rules |
| `-w` / `--web` | Open the rulesets list in the browser | Visual inspection |
| `-R` / `--repo` | Target a different repository | Cross-repo auditing |

### view

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-o` / `--org string` | Indicate the ruleset ID belongs to an org | Viewing organisation-level rulesets by ID |
| `-p` / `--parents` | Include rulesets configured at higher levels that also apply (default true) | Pass `--parents=false` to see only repo-local rules |
| `-w` / `--web` | Open the ruleset in the browser | Reading full rule details |
| `-R` / `--repo` | Target a different repository | Cross-repo inspection |

### check

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--default` | Check rules on the default branch | CI scripts that should not depend on the checked-out branch |
| `-w` / `--web` | Open the branch rules page in the browser | Visual walkthrough of what applies |
| `-R` / `--repo` | Target a different repository | Checking rules before opening a PR into another repo |

## Best practices

**Run `gh ruleset check` before pushing to an unfamiliar branch.** Rules
are evaluated server-side when you push, so a failed push is the first sign
something is blocked. Running the check locally first tells you exactly which
requirements must be satisfied — required status checks, signed commits, a
pull request — before the push can succeed.

```sh
gh ruleset check   # check the branch you are about to push to
```

**Use `--parents=false` when auditing repository-local policy.** The
default includes inherited organisation and enterprise rulesets, which can
make the list noisy. When you are reviewing only what your team owns,
suppress the parents:

```sh
gh ruleset list --parents=false
```

**Audit org-wide rulesets periodically.** Policies defined at the
organisation level apply silently to every repository in the org. Running
`gh ruleset list --org <org>` across your organisation gives you a single
view of what every repository is subject to, independent of per-repository
settings.

**Open in `--web` when you need the full rule payload.** The terminal output
of `gh ruleset view` shows the ruleset summary. The browser view exposes the
complete rule list, enforcement level, bypass actors, and the target branch
or tag patterns — information not fully surfaced in the CLI output.

## Pitfalls & gotchas

**The branch name passed to `check` does not have to exist.** The command
evaluates pattern matching against whatever string you supply, which is useful
for planning: you can verify that a branch named `release/2.0` would be
protected before you create it. Conversely, if you spell the branch name
wrong you will get back the rules for the typo'd name, not for your real
branch — no warning is issued.

**`--org` on `list` requires elevated token scope.** Without `admin:org`
your request is rejected. The error message references permission denied but
does not always name the missing scope. Fix it with:

```sh
gh auth refresh -s admin:org
```

**Inherited rulesets have IDs that are org-scoped, not repo-scoped.**
When you see a ruleset in `gh ruleset list` that comes from an organisation,
its ID belongs to the organisation. Passing that ID to `gh ruleset view`
without `--org <org>` may return "not found" because `gh` searches the
repository's own ruleset namespace. Use `--org` to resolve it:

```sh
gh ruleset view 78 --org my-org
```

**`ruleset` is read-only.** There is no `gh ruleset create` or
`gh ruleset edit`. Attempting to manage ruleset configuration with `gh
ruleset` alone is not possible; use the web UI or `gh api` with the rulesets
REST endpoints.

**`gh ruleset check` returns all matching rules, not just blocking ones.**
A ruleset can be in `evaluate` mode (logging only, not enforcing). The check
output does not distinguish enforced rules from evaluate-mode rules, so a
rule appearing in the output does not guarantee it will block a push.

## Worked examples

### Pre-push rules audit

You are about to push commits to `main` on a repository you have not
contributed to before. Check what rules apply before touching the remote:

```sh
gh ruleset check main --repo owner/backend
```

```text
Total rules: 4
  - Branch is not deletable.
  - Cannot force push.
  - Requires linear history.
  - Must pass status checks: ci/build, ci/test
```

The output tells you that a linear history is required. You squash or rebase
your commits before pushing:

```sh
git rebase origin/main
git push origin main
```

### Auditing organisation policy inheritance

You are the platform engineer responsible for a GitHub organisation with
dozens of repositories. You want to confirm that the org-wide signing
requirement is in place:

```sh
gh ruleset list --org my-org
```

```text
ID    NAME                     SOURCE   STATUS   RULES
78    org-wide-signing-policy  my-org   active   1
91    require-pr-all-repos     my-org   active   3
```

View the signing ruleset in detail:

```sh
gh ruleset view 78 --org my-org
```

```text
Name: org-wide-signing-policy
ID: 78
Source: my-org (Organization)
Enforcement: active
Target: ~DEFAULT_BRANCH

Rules
  - Require signed commits
```

Now verify that a specific repository inherits it:

```sh
gh ruleset list --repo my-org/payments-service
```

The `78` entry appears in the list with `SOURCE` set to `my-org`, confirming
the repository is covered.

### Checking rules before opening a PR into a protected branch

Your team uses a `release/*` glob to protect release branches. Before
creating `release/3.1`, confirm what rules that name would trigger:

```sh
gh ruleset check release/3.1 --repo my-org/backend
```

If required status checks appear in the output, you know any PR targeting
this branch must have those checks green before it can merge.

## Recovery

If a push is rejected by a ruleset with a message like
`GH013: Repository rule violations found`, run `gh ruleset check` on the
target branch to see exactly which rules fired:

```sh
gh ruleset check <branch>
```

Address each requirement — add a PR, get required checks to pass, rewrite
history to be linear, sign commits — then retry the push.

If you believe a ruleset is misconfigured (wrong target pattern, wrong
enforcement level), open it in the browser for editing:

```sh
gh ruleset view <id> --web
```

Changes to rulesets take effect immediately with no cache delay; the next
push attempt will reflect the updated policy.

## See also

- *auth* — grant the `admin:org` scope needed by `gh ruleset list --org`.
- *api* — create, update, or delete rulesets via the REST API when the read-only CLI is insufficient.
- *pr* — pull requests are one of the most common requirements enforced by rulesets.
- *run* — required status checks referenced by rulesets correspond to workflow runs managed with `gh run`.
