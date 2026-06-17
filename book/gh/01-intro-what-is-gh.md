# What the GitHub CLI is

`gh` is GitHub's official command-line tool. Where `git` manages a repository
on your machine and speaks the git protocol to remotes, `gh` speaks GitHub's
REST and GraphQL APIs. It lets you open pull requests, file issues, trigger
workflows, manage releases, and inspect repository settings without leaving the
terminal.

## gh vs git: two different tools

The distinction matters because people often confuse them.

| | `git` | `gh` |
|-|-------|------|
| What it talks to | Any git server (GitHub, GitLab, Bitbucket, self-hosted, …) | GitHub's API only |
| What it manages | The content of repositories (commits, branches, history) | GitHub concepts (PRs, issues, Actions, gists, …) |
| Auth required? | Only for private repos or pushes | Always — every call hits the API |
| Works offline? | Yes, for local operations | No |

A typical workflow uses both: `git` to manage the work, `gh` to collaborate
around it on GitHub.

```sh
git switch -c feature/new-search   # git: create a local branch
git commit -m "Implement search"   # git: record a change
git push                           # git: send it to GitHub
gh pr create --fill                # gh: open a pull request on GitHub
```

## Installing gh

**macOS (Homebrew)**

```sh
brew install gh
```

**Linux (Debian / Ubuntu)**

```sh
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
&& sudo mkdir -p -m 755 /etc/apt/keyrings \
&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y
```

**Windows (winget)**

```sh
winget install --id GitHub.cli
```

Verify the installation:

```sh
gh --version
```

```text
gh version 2.68.0 (2026-01-15)
```

## The command shape

Every `gh` invocation follows the same pattern:

```text
gh <command> <subcommand> [flags] [arguments]
```

Examples:

```sh
gh pr list                     # list pull requests in the current repo
gh issue create --title "Bug"  # open a new issue
gh repo clone owner/repo       # clone a repository
gh run watch 12345678          # stream a workflow run's output
```

Run `gh help` for a full list of top-level commands, or `gh <command> --help`
for a specific command's subcommands and flags.

## Auth is the prerequisite for everything

Every `gh` command contacts GitHub's API, which requires authentication. If
you skip `gh auth login`, every command will fail with a `not logged in` error.

Authenticate once, then forget about it — `gh` stores credentials securely in
the system keychain.

```sh
gh auth login
```

See *auth* for the full login workflow, managing multiple accounts, and
using tokens in CI.

## How gh knows which repository you mean

When you run a `gh` command inside a git working directory, `gh` reads the
`origin` remote URL and maps it to a GitHub repository. This means `gh pr
list` with no arguments works when you are inside a cloned repository — it
already knows which one you mean.

Override with `--repo`:

```sh
gh pr list --repo owner/other-repo
```

Or set `GH_REPO` in the environment to target a specific repository for the
duration of a script.

## Getting help

```sh
gh help               # top-level command list
gh <command> --help   # flags and subcommands for a command
gh help environment   # environment variables gh respects
gh help formatting    # --json, --jq, --template output
```

The `gh help formatting` page is particularly useful when you want to pipe `gh`
output into scripts.

## See also

- *auth* — authenticating, switching accounts, and using tokens.
- *pr* — creating and reviewing pull requests.
- *repo* — cloning, forking, and managing repositories.
