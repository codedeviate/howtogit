# alias

Create, manage, and share keyboard-friendly shortcuts for any `gh` command
or shell pipeline.

## Mental model

`gh alias` lets you give a short name to a command you type often. When you
invoke the alias, `gh` expands it — inserting any extra arguments you passed
— before running it. Think of it as an abbreviation table that lives in
`~/.config/gh/config.yml`.

There are two flavours of alias:

- **Plain alias.** The expansion is another `gh` sub-command with optional
  fixed flags. `gh` handles argument passing itself.
- **Shell alias.** The expansion starts with `!` or you pass `--shell`. `gh`
  hands the whole expression to `sh -c`, which lets you pipe, redirect, and
  combine arbitrary commands.

Positional placeholders (`$1`, `$2`, …) let a plain or shell alias accept
dynamic values. Without placeholders, any extra arguments are appended at the
end of the expansion.

Aliases are personal; they are stored in your local config file, not in the
repository. Use `gh alias import` / `gh alias list` to move them between
machines.

## Synopsis

```text
gh alias set    <alias> <expansion> [--clobber] [--shell]
gh alias delete {<alias> | --all}
gh alias list
gh alias import [<filename> | -] [--clobber]
```

## Everyday usage

### Defining a simple alias

Shorten a flag-heavy command you type every day:

```sh
gh alias set bugs 'issue list --label=bug'
gh bugs                    # expands to: gh issue list --label=bug
```

### Using positional placeholders

Accept a dynamic value at invocation time:

```sh
gh alias set epicsBy 'issue list --author="$1" --label=epic'
gh epicsBy alice           # expands to: gh issue list --author="alice" --label=epic
```

### Multi-word (namespace) alias

Use a quoted alias name to create a sub-command under an existing group:

```sh
gh alias set 'issue mine' 'issue list --assignee @me'
gh issue mine              # feels like a built-in subcommand
```

### Shell alias with piping

Prefix the expansion with `!` to pass it through `sh`:

```sh
gh alias set igrep '!gh issue list --label="$1" | grep "$2"'
gh igrep bug "crash"       # lists issues labelled "bug", filtered by "crash"
```

Or use the `--shell` flag with an expansion that does not start with `!`:

```sh
gh alias set --shell openpr 'gh pr view $(gh pr list --json number -q ".[0].number") --web'
```

### Listing all aliases

```sh
gh alias list
```

```text
bugs     issue list --label=bug
epicsBy  issue list --author="$1" --label=epic
igrep    !gh issue list --label="$1" | grep "$2"
```

(`gh alias ls` is an accepted abbreviation.)

### Deleting a single alias

```sh
gh alias delete bugs
```

### Deleting every alias at once

```sh
gh alias delete --all
```

### Exporting and importing aliases

Export from one machine and import on another:

```sh
# On the source machine
gh alias list > aliases.yml

# On the target machine
gh alias import aliases.yml
```

The YAML produced by `gh alias list` is directly consumable by
`gh alias import`. Pass `-` to read from stdin:

```sh
cat aliases.yml | gh alias import -
```

## Key options

### set

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--clobber` | Overwrite an existing alias with the same name | Updating a definition without deleting first |
| `-s` / `--shell` | Treat the expansion as a shell expression via `sh` | Pipelines, redirections, multi-command sequences |

### delete

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--all` | Remove every stored alias in one step | Resetting a machine or wiping a stale dotfile |

### import

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--clobber` | Overwrite any conflicting aliases already defined | Importing a canonical team alias file over personal definitions |

## Best practices

**Read the expansion string from stdin with `-` to avoid quoting headaches.**
Shell quoting of `$1` inside single and double quotes is notoriously tricky.
Pipe the expansion string in instead:

```sh
echo 'issue list --author="$1" --label=epic' | gh alias set epicsBy -
```

The `-` tells `gh alias set` to read the expansion from stdin, so your shell
never sees the inner `$`.

**Namespace aliases that extend a command group.** Using a multi-word alias
like `'pr review-queue'` keeps your personal shortcuts discoverable alongside
the real subcommands and avoids name collisions with top-level commands.

**Commit your `aliases.yml` to a dotfiles repository.** Export with
`gh alias list > aliases.yml`, commit the file, and import on every new
machine with `gh alias import aliases.yml`. A single source of truth is
easier to audit than per-machine config files.

**Prefer plain aliases over shell aliases when no piping is needed.** Plain
aliases are faster (no shell spawn), safer (no injection risk), and easier
for `gh` to complete. Reserve `--shell` for cases that genuinely need a
pipeline or a conditional.

**Use `--clobber` when scripting alias setup.** If a setup script runs
`gh alias set` on a machine that already has the alias, the command fails
without `--clobber`. Add the flag to make your bootstrap script idempotent.

## Pitfalls & gotchas

**Any expansion that starts with `!` is treated as a shell alias — identical
to passing `--shell`.** There is no way to keep a leading `!` literal in a
plain alias; `--shell` is not a workaround, it produces exactly the same
behaviour. If you genuinely need a leading `!` character in your expansion
(e.g., a negated jq filter), restructure the command so the expansion does
not begin with `!` — for example, reorder the jq expression or wrap it in a
helper script.

**`$1` in a plain alias is handled by `gh`, not by `sh`.** Quoting rules
differ from shell: inside a plain alias expansion, `"$1"` works as a
placeholder without a shell process. Do not expect arithmetic (`$((…))`),
command substitution (`` $(...) ``), or variable expansion (`$HOME`) to work
in a plain alias — they require `--shell`.

**Alias names cannot shadow built-in `gh` commands.** Attempting to name an
alias `pr` or `repo` will be rejected. Use a different name or a multi-word
alias such as `'pr draft'`.

**`gh alias list` output is YAML, not shell.** The multiline block syntax
(`|-`) is valid YAML. Do not try to source or eval the output in bash; pass
it through `gh alias import` instead.

**Without `--clobber`, redefining an alias is an error.** If you run
`gh alias set pv 'pr view'` twice, the second invocation fails with a
conflict message. Either delete first or add `--clobber`.

## Worked examples

### Building a personal productivity kit

A developer works primarily on issues and pull requests and wants fast,
finger-friendly shortcuts:

```sh
# List your open issues
gh alias set mine 'issue list --assignee @me --state open'

# List PRs that need your review
gh alias set review-queue 'pr list --search "review-requested:@me"'

# Open the current branch's PR in the browser
gh alias set pv 'pr view --web'

# Quick-create a draft PR from the current branch
gh alias set draft 'pr create --draft --fill'
```

Day-to-day use:

```sh
gh mine            # what am I working on?
gh review-queue    # who is waiting on me?
gh pv              # jump to the PR in the browser
```

### Sharing aliases across a team

The team agrees on a canonical set of shortcuts for a monorepo. A maintainer
creates `aliases.yml` and commits it:

```yaml
# aliases.yml
deploy-check: 'run list --workflow=deploy.yml --limit=5'
flaky:        'issue list --label=flaky-test --state=open'
release-next: '!gh release list --limit=1 | awk "{print \$1}"'
```

Each developer imports it once:

```sh
gh alias import aliases.yml
```

To update an alias without removing it first:

```sh
gh alias import --clobber aliases.yml
```

To inspect what is currently defined after importing:

```sh
gh alias list
```

### Debugging a shell alias

A shell alias is not behaving as expected. Inspect the stored expansion:

```sh
gh alias list | grep igrep
```

```text
igrep  !gh issue list --label="$1" | grep "$2"
```

Run the expanded command manually to isolate the problem:

```sh
gh issue list --label="bug" | grep "crash"
```

If the alias needs updating, overwrite it with `--clobber`:

```sh
gh alias set --shell --clobber igrep 'gh issue list --label="$1" --state=open | grep "$2"'
```

## Recovery

If an alias definition is broken and causes errors on invocation, delete it
and redefine:

```sh
gh alias delete igrep
gh alias set --shell igrep 'gh issue list --label="$1" | grep "$2"'
```

If you have accidentally deleted aliases you need, restore them from your
dotfiles `aliases.yml`:

```sh
gh alias import aliases.yml
```

If you do not have a backup, check your shell history for the original
`gh alias set` invocations:

```sh
history | grep 'alias set'
```

Alias definitions are stored in `~/.config/gh/config.yml` under the
`aliases:` key. In an emergency you can inspect or hand-edit that file, but
prefer the `gh alias` commands so the format stays valid.

## See also

- *auth* — `gh` must be authenticated before any alias expansion that
  calls the API can succeed.
- *config* — the config file that stores aliases (`~/.config/gh/config.yml`);
  use `gh alias list` to inspect current definitions.
- *extension* — for richer, distributable plugins that go beyond what a
  shell alias can express.
