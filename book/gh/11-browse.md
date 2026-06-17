# browse

Open the current repository — or any part of it — in your web browser from
the terminal.

## Mental model

`gh browse` constructs a GitHub URL and hands it to your system browser (or
prints it with `--no-browser`). It does not clone anything or change local
state. Think of it as a smart bookmark: it knows which repository the current
directory belongs to, so you never have to copy and paste URLs by hand.

The command accepts three kinds of arguments — a number (issue or pull
request), a file path (optionally with a line anchor), or a commit SHA — and
routes each to the right page. Flags like `--settings` or `--releases` go
directly to well-known repository sections without requiring you to memorise
the URL shape.

Because the destination is just a URL, you can capture it for sharing or
scripting with `--no-browser` rather than letting the browser open.

## Synopsis

```text
gh browse [<number> | <path> | <commit-sha>] [flags]
```

## Everyday usage

Open the home page of the current repository:

```sh
gh browse
```

Open an issue or pull request by number:

```sh
gh browse 217
```

Open a file in the repository browser:

```sh
gh browse cmd/gh/main.go
```

Open a file at a specific line:

```sh
gh browse main.go:312
```

Open a directory:

```sh
gh browse script/
```

Open a specific commit:

```sh
gh browse 77507cd94ccafcf568f8560cfecde965fcfa63
```

Print the URL without opening a browser (useful for copying or scripting):

```sh
gh browse --no-browser
```

Open repository settings directly:

```sh
gh browse --settings
```

Open the Actions tab:

```sh
gh browse --actions
```

Open releases:

```sh
gh browse --releases
```

Open the wiki:

```sh
gh browse --wiki
```

Open projects:

```sh
gh browse --projects
```

### Viewing a file on another branch or commit

```sh
# View a file at the tip of the bug-fix branch
gh browse main.go --branch bug-fix

# View a file as it was at a specific commit
gh browse main.go --commit=77507cd94ccafcf568f8560cfecde965fcfa63
```

### Viewing blame

```sh
gh browse main.go:312 --blame
```

### Targeting a different repository

If you are not inside the repository you want to open, pass `--repo`:

```sh
gh browse --repo cli/cli
gh browse --repo github.mycompany.com/platform/backend
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-n` / `--no-browser` | Print the URL instead of opening a browser | Scripting, headless environments, copying links |
| `-R` / `--repo` | Target a different repository | Working outside the repo directory |
| `-b` / `--branch` | View at the tip of a named branch | Reviewing another branch without checking it out |
| `-c` / `--commit` | View at a specific commit SHA (omit value for last commit) | Linking to a historical snapshot |
| `--blame` | Open the blame view for a file | Investigating who changed a line |
| `-a` / `--actions` | Open the Actions tab | Checking CI status quickly |
| `-p` / `--projects` | Open the Projects board | Checking project status |
| `-r` / `--releases` | Open the Releases page | Checking or sharing release notes |
| `-s` / `--settings` | Open repository settings | Admin tasks |
| `-w` / `--wiki` | Open the repository wiki | Reading or editing docs |

## Best practices

**Use `--no-browser` to generate shareable links.** When you want to point a
colleague to a specific file, line, or commit, generate the URL and paste it
into chat rather than opening the browser yourself:

```sh
gh browse src/auth.ts:42 --no-browser
```

**Use `--commit` without a value to link to the last commit.** Omitting the
SHA defaults to the most recent commit on the current branch, which produces a
permanent URL that will not drift as the branch advances:

```sh
gh browse README.md --commit
```

**Combine `--repo` with `--no-browser` in scripts.** This lets you build
permalink generation helpers that do not depend on a git checkout being
present:

```sh
# Print the Actions tab URL for any repo
gh browse --repo "$OWNER/$REPO" --actions --no-browser
```

**Set `BROWSER` to control which browser opens.** The `BROWSER` environment
variable overrides the system default. Useful when you want to open links in
a work profile while your default browser is personal:

```sh
BROWSER="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" gh browse
```

## Pitfalls & gotchas

**`gh browse` requires a git repository (unless `--repo` is given).** Running
it outside a git working tree produces an error. Pass `--repo OWNER/REPO` to
target a remote repository from any directory.

**Number arguments open issues or pull requests, not commit SHAs.** `gh browse 42`
goes to issue or PR #42. To open a commit by a short SHA that happens to be
all digits, you still need to spell out enough characters for GitHub to
distinguish it from a number — in practice, use the full or a sufficiently
long prefix of the commit hash.

**`--commit` without a value means the last commit, not the current file
state.** `gh browse README.md --commit` links to the last commit that touched
any file on the branch, not specifically the last commit that changed
`README.md`. The result is a permalink to a commit tree view, not a
file-history view.

**Line anchors require a file argument.** `gh browse :42` is not valid; you
must provide the path: `gh browse src/main.go:42`.

**Branch names with slashes need no special quoting.** `--branch feat/my-feature`
works as-is; the slash is treated as part of the branch name, not a path
separator.

## Worked examples

### Sharing a link to a specific line during code review

You spot a tricky function and want to point a reviewer at it without
switching to the browser first:

```sh
gh browse src/payment/processor.go:88 --no-browser
```

```text
https://github.com/acme/checkout/blob/main/src/payment/processor.go#L88
```

Paste that URL into your pull-request comment or Slack message.

### Checking CI for a different repository without cloning it

```sh
gh browse --repo acme/infra --actions --no-browser
```

```text
https://github.com/acme/infra/actions
```

Open it, or pass it to `open` / `xdg-open` manually.

### Jumping to an issue or pull request from the terminal

While reading a `git log` you see a reference to PR #1337. Open it without
leaving the terminal:

```sh
gh browse 1337
```

The browser navigates to the pull-request page directly. If the number
corresponds to both an issue and a pull request (they share the same number
space on GitHub), GitHub will route you to whichever exists.

### Generating a permalink to last night's release commit

```sh
# Find the commit hash
git log --oneline -1 v2.4.0

# Open it as a permanent GitHub link
gh browse a3f9c12 --no-browser
```

```text
https://github.com/acme/checkout/commit/a3f9c12...
```

### Browsing a file on a feature branch without checking it out

```sh
gh browse pkg/api/routes.go --branch feat/new-router
```

GitHub opens the file as it exists on `feat/new-router`, leaving your local
working tree on whatever branch you are currently on.

## Recovery

`gh browse` is read-only and stateless — it opens a URL and exits. Nothing
about your local repository changes, so there is nothing to undo.

If the browser fails to open, use `--no-browser` to retrieve the URL and
open it manually:

```sh
gh browse --no-browser
```

If the command errors with "not a git repository", either `cd` into a
checkout or add `--repo OWNER/REPO`.

If you see "repository not found", confirm that the active `gh` account has
access to the repository (see *auth*).

## See also

- *auth* — configure and switch the GitHub account `gh browse` uses.
- *repo* — `gh repo view --web` is an alias-style alternative for opening the
  repository home page.
- *pr* — `gh pr view --web` opens a specific pull request in the browser.
- *issue* — `gh issue view --web` opens a specific issue in the browser.
