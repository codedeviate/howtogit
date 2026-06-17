# auth

Authenticate `gh` with GitHub accounts, manage stored credentials, and switch
between multiple accounts on the same machine.

## Mental model

`gh` needs an OAuth token (or a personal access token) to call GitHub's API.
The `auth` command group manages those tokens: it stores them in the system
credential store (macOS Keychain, Windows Credential Manager, or a
platform-native secret store), retrieves them transparently on every API call,
and lets you add, remove, refresh, and switch between multiple accounts.

A separate credential is stored for each *(hostname, username)* pair. You can
authenticate against multiple accounts on the same host (e.g., a personal
account and a work account on `github.com`) or against GitHub Enterprise
Server instances alongside github.com.

`gh` marks one account per host as **active**. All commands use the active
account for that host unless you override with `GH_TOKEN` or `--repo` with a
different owner.

## Synopsis

```text
gh auth login    [--web] [--with-token] [-h hostname] [-p git-protocol] [-s scopes]
gh auth logout   [-h hostname] [-u user]
gh auth status   [-h hostname] [-a] [--show-token]
gh auth switch   [-h hostname] [-u user]
gh auth refresh  [-h hostname] [-s scopes] [--remove-scopes scopes] [--reset-scopes]
gh auth setup-git [-h hostname]
gh auth token    [-h hostname] [-u user]
```

## Everyday usage

Log in interactively (opens a browser to authorise):

```sh
gh auth login
```

Log in to a specific GitHub Enterprise host:

```sh
gh auth login --hostname github.mycompany.com
```

Check which accounts are authenticated and which is active:

```sh
gh auth status
```

Switch the active account on github.com:

```sh
gh auth switch
```

Log out of a specific account:

```sh
gh auth logout --hostname github.com --user myusername
```

## Key options

### login

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-w` / `--web` | Open a browser to complete OAuth | The default interactive flow |
| `--with-token` | Read a personal access token from stdin | Headless / CI environments |
| `-p` / `--git-protocol` | Set `https` or `ssh` for git operations | Choose once at login time |
| `-h` / `--hostname` | Target a specific host | GitHub Enterprise Server |
| `-s` / `--scopes` | Request additional OAuth scopes beyond the minimum | When you need extra API access |
| `--skip-ssh-key` | Do not offer to generate/upload an SSH key | When you use HTTPS exclusively |
| `--insecure-storage` | Store the token in plain text | Systems without a keychain |

### status

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-a` / `--active` | Show only the active account | Quick sanity check |
| `-h` / `--hostname` | Check only one host | Multi-host setups |
| `-t` / `--show-token` | Print the stored token | Debugging, piping to other tools |

### switch

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-u` / `--user` | Specify the account to switch to | More than two accounts on one host |
| `-h` / `--hostname` | Target a specific host | Multi-host setups |

### refresh

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-s` / `--scopes` | Add more OAuth scopes | A command needs a scope you did not grant at login |
| `--remove-scopes` | Remove scopes from the token | Reduce permissions after you no longer need them |
| `--reset-scopes` | Reset to the minimum required set | Clean up accumulated scopes |

### token

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-h` / `--hostname` | Target a specific host | Multi-host setups |
| `-u` / `--user` | Target a specific account | When multiple accounts are stored |

## Best practices

**Use `--web` for interactive logins.** The browser OAuth flow is the most
secure option because you never handle a token string yourself. The device-code
flow is the fallback for environments without a browser.

**Use `--with-token` in CI.** Automation should not open browsers. Pass a
personal access token or a short-lived `GITHUB_TOKEN` from Actions via stdin:

```sh
echo "$GH_TOKEN" | gh auth login --with-token
```

Or skip `auth login` entirely and set the `GH_TOKEN` environment variable.
`gh` will use it transparently without storing anything:

```sh
export GH_TOKEN="ghp_..."
gh pr list   # uses GH_TOKEN
```

**Set `--git-protocol ssh` at login if you use SSH keys.** This configures
the git credential helper (`gh auth setup-git`) to use SSH URLs when cloning
and pushing, which is consistent with a key-based workflow.

**Grant only the scopes you need.** The minimum required scopes are `repo`,
`read:org`, and `gist`. Add extras with `gh auth refresh --scopes <scope>`
only when a specific command demands them. Fewer scopes means a stolen token
does less damage.

**Run `gh auth setup-git` once per machine.** This command registers `gh` as
git's credential helper so that HTTPS clones and pushes authenticate
automatically — no password prompts:

```sh
gh auth setup-git
```

## Pitfalls & gotchas

**The active account is per-host, per-session context.** If you switch to
account A to run a command and forget to switch back, subsequent commands
targeting account B's repositories will fail or act as account A. Get in the
habit of confirming with `gh auth status --active`.

**`gh auth refresh` works only on the active account.** To refresh credentials
for an inactive account, switch to it first, refresh, then switch back:

```sh
gh auth switch --user work-account
gh auth refresh --scopes admin:org
gh auth switch --user personal-account
```

**`--with-token` expects the token on stdin, not as an argument.** The
following is wrong:

```sh
gh auth login --with-token ghp_...   # WRONG — token is not a positional arg
```

Pass it via a pipe or heredoc:

```sh
echo "ghp_..." | gh auth login --with-token
```

**Fine-grained personal access tokens and `--with-token`.** Fine-grained
tokens are scoped to specific repositories. If you use one with `--with-token`,
`gh` commands targeting other repositories will fail with permission errors.
For fine-grained token usage, set `GH_TOKEN` in the environment rather than
storing the token with `auth login`.

## Worked examples

### Logging in for the first time

```sh
gh auth login
```

```text
? What account do you want to log into?  GitHub.com
? What is your preferred protocol for Git operations?  HTTPS
? Authenticate Git with your GitHub credentials?  Yes
? How would you like to authenticate GitHub CLI?  Login with a web browser
! First copy your one-time code: ABCD-1234
Press Enter to open github.com in your browser...
✓ Authentication complete.
- gh config set -h github.com git_protocol https
✓ Configured git protocol
✓ Logged in as ada-lovelace
```

### Managing two GitHub accounts on one machine

Many developers maintain a personal account and a work account on github.com.
Log in to each in turn:

```sh
gh auth login --hostname github.com   # log in as personal-user; complete browser flow
gh auth login --hostname github.com   # log in as work-user; complete browser flow
```

Check what is stored:

```sh
gh auth status
```

```text
github.com
  ✓ Logged in to github.com account personal-user (keyring)
  - Active account: true
  ✓ Logged in to github.com account work-user (keyring)
  - Active account: false
```

Switch the active account before working on a work repository:

```sh
gh auth switch --user work-user
gh pr list --repo my-company/backend   # now runs as work-user
```

Or switch back to personal:

```sh
gh auth switch --user personal-user
```

If the host has exactly two accounts, `gh auth switch` with no flags alternates
between them.

### Using gh in a GitHub Actions workflow

In Actions, the workflow token is available as `GITHUB_TOKEN`. Pass it through
`GH_TOKEN` rather than using `auth login`:

```yaml
- name: List open PRs
  env:
    GH_TOKEN: ${{ github.token }}
  run: gh pr list --state open
```

No credential storage, no cleanup required.

### Adding a scope after login

You run `gh release create` and get an error about missing `write:packages`
scope. Add it without logging out:

```sh
gh auth refresh --scopes write:packages
```

This opens a browser to re-authorise with the new scope.

## Recovery

If `gh auth status` shows `authentication failed`, the stored token has
expired or been revoked. Log in again:

```sh
gh auth logout
gh auth login
```

To recover from a corrupted credential store, pass `--insecure-storage` to
store the token in plain text as a fallback while you diagnose the keychain
issue.

## See also

- *What the GitHub CLI is* — overview of gh and how it differs from git.
- *config* — gh configuration beyond authentication.
- *repo* — `gh repo clone` uses the active auth credential.
