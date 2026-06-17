# org

List and browse the GitHub organizations your authenticated account belongs to.

## Mental model

GitHub organizations are shared accounts where teams collaborate on repositories
under a common namespace. Your personal account can belong to many organizations
— open-source projects, employers, client accounts — each with its own member
list, repositories, and billing.

`gh org` is a focused command group. It does not administer membership, settings,
or billing through the CLI; those operations belong in the GitHub web UI or the
REST API (see *api*). What `gh org list` gives you is a fast, scriptable answer
to "which orgs can I act as?" — useful when you are switching contexts, writing
automation, or building prompts for other `gh` subcommands that require an org
name.

The results reflect the account that is currently **active** on a given host.
If you are authenticated as multiple GitHub accounts, `gh org list` shows the
organizations for whichever account is active. Use `gh auth switch` to change
the active account before running `gh org list` when you need the org list for
a different identity.

## Synopsis

```text
gh org list [--limit <max>]
gh org ls   [--limit <max>]    # alias
```

## Everyday usage

List the organizations your active account belongs to (up to 30):

```sh
gh org list
```

Raise the cap to see more than 30 organizations:

```sh
gh org list --limit 100
```

Capture the org names for use in a script:

```sh
gh org list --limit 200 | while read -r org; do
  echo "Processing $org"
  # gh repo list "$org" ...
done
```

Check which orgs are available under a specific account without permanently
switching the active account:

```sh
# Switch, inspect, switch back
gh auth switch --user work-user
gh org list
gh auth switch --user personal-user
```

## Key options

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-L` / `--limit` | Maximum number of organizations to list (default: 30) | When you belong to more than 30 orgs, or want to cap output in scripts |

## Best practices

**Always confirm the active account before scripting.** `gh org list` is
only as useful as the account it reflects. Run `gh auth status --active`
first, or embed the switch inside your script, so you never accidentally
operate on the wrong org set.

**Use `--limit` defensively in automation.** The default cap of 30 is
appropriate for interactive inspection. Automation that iterates over all
orgs should pass an explicit `--limit` large enough to cover the real count —
otherwise it silently processes only the first 30 and drops the rest:

```sh
gh org list --limit 500 | sort
```

**Pipe into other `gh` commands to scope operations.** `gh org list` is most
powerful as a source of org names for subsequent commands. Combining it with
`gh repo list <org>` or `gh api` calls lets you write org-wide automation
without hard-coding names:

```sh
for org in $(gh org list --limit 200); do
  echo "=== $org ==="
  gh repo list "$org" --limit 5
done
```

**Prefer the `gh org ls` alias in interactive shells** to save keystrokes.
Use the full `gh org list` spelling in scripts so the intent is self-documenting.

## Pitfalls & gotchas

**The 30-organization default limit silently truncates.** If your account
belongs to 40 organizations and you run `gh org list` without `--limit`, you
see only 30. There is no warning. Scripts that assume the list is complete will
miss organizations without notice.

**Results are tied to the active account, not the current repository.** Unlike
many `gh` commands, `gh org list` does not infer an owner from the current
directory's git remote. It lists orgs for the active account on the target host
regardless of where you run it.

**Organization membership visibility may be restricted.** GitHub allows
organization members to hide their membership publicly. `gh org list` returns
the orgs the authenticated account genuinely belongs to, which may differ from
what an external observer can see on your public profile.

**Enterprise Server hosts need explicit account switching.** If you are
authenticated against a GitHub Enterprise Server instance as well as
`github.com`, `gh org list` only queries the host associated with the active
account. To list orgs on the Enterprise host, switch to that account first:

```sh
gh auth switch --hostname github.mycompany.com
gh org list
```

## Worked examples

### Auditing all organizations you belong to

You want a quick inventory before starting a cross-org search.

```sh
gh auth status --active
```

```text
github.com
  ✓ Logged in to github.com account ada-lovelace (keyring)
  - Active account: true
```

```sh
gh org list --limit 200
```

```text
acme-corp
open-widgets
my-oss-collective
```

You now have a list you can feed into other commands or share with your team.

### Listing recent repositories across every org you belong to

You want to find recently pushed repositories without knowing which org owns
each one.

```sh
gh org list --limit 200 | while read -r org; do
  gh repo list "$org" --limit 5 --json name,pushedAt \
    --jq ".[] | \"$org/\(.name) \(.pushedAt)\""
done | sort -k2 -r | head -20
```

This pipes every org name into `gh repo list`, extracts the five most-recently
pushed repos in each, and sorts by push date to surface the most active
repositories across all your organizations.

### Switching accounts and comparing org memberships

You manage a personal account and a work account on `github.com` and need to
confirm which org is accessible from which account.

```sh
gh auth switch --user personal-user
gh org list
```

```text
my-oss-collective
open-widgets
```

```sh
gh auth switch --user work-user
gh org list
```

```text
acme-corp
acme-internal
```

Now you know exactly which account to use when running commands against each
organization. See *auth* for full details on managing multiple accounts.

## Recovery

`gh org list` is a read-only command — it cannot modify anything, so there is
nothing to undo.

If the command returns an empty list or an authentication error, the most
likely cause is an expired or insufficient token. Refresh credentials with:

```sh
gh auth refresh
```

If you need the `read:org` scope explicitly (required to see private org
membership), add it:

```sh
gh auth refresh --scopes read:org
```

Then retry `gh org list`.

## See also

- *auth* — manage accounts and switch the active identity before listing orgs.
- *repo* — `gh repo list <org>` lists repositories inside an organization.
- *api* — perform org-level administration (members, settings, webhooks) via
  the REST and GraphQL APIs that `gh org list` does not expose.
- *search* — `gh search repos --owner <org>` searches public repositories
  within a specific organization.
