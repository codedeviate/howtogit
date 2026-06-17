# config

Read and write `gh`'s persistent configuration settings — controlling
everything from your preferred editor and git protocol to pager, browser,
and accessibility options.

## Mental model

`gh` stores its configuration in `~/.config/gh/config.yml` (global) and
`~/.config/gh/hosts.yml` (per-host overrides). Every key-value pair in
those files drives a specific behaviour: which editor opens when `gh pr
create` needs a body, which protocol is used for `git clone`, whether the
interactive prompt appears at all.

The `config` command group is the safe, structured way to read and write
those files. You never have to hand-edit YAML; `gh config get` and
`gh config set` treat the files as a typed key-value store. Changes are
immediate — the next `gh` invocation picks them up.

Most keys are global, but a handful can be scoped to a specific host with
`--host`. A per-host value takes precedence over the global value for that
host; for all other hosts the global value still applies. This lets you
use SSH on `github.com` while staying on HTTPS for a GitHub Enterprise
Server instance.

## Synopsis

```text
gh config list                       [--host <hostname>]
gh config get   <key>                [--host <hostname>]
gh config set   <key> <value>        [--host <hostname>]
gh config clear-cache
```

## Everyday usage

Print every current setting and its value:

```sh
gh config list
```

Read a single key:

```sh
gh config get git_protocol
```

Switch to SSH for all git operations:

```sh
gh config set git_protocol ssh
```

Set your preferred editor:

```sh
gh config set editor "code --wait"
```

Override git protocol for one host only:

```sh
gh config set git_protocol ssh --host github.com
```

Check what protocol is configured for a specific host:

```sh
gh config get git_protocol --host github.com
```

Clear the CLI's local API response cache (useful when stale data is
returned):

```sh
gh config clear-cache
```

## Key options

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-h` / `--host` | Show only settings for the named host | Multi-host setups; see what overrides are in effect |

### get

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-h` / `--host` | Read the per-host value instead of the global value | Verify host-specific overrides |

### set

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-h` / `--host` | Write a per-host value | Different protocols or editors per host |

### Recognised keys

| Key | Allowed values | Default | What it controls |
|-----|----------------|---------|-----------------|
| `git_protocol` | `https`, `ssh` | `https` | Protocol for `git clone` and `push` |
| `editor` | any executable (quoted if it has arguments) | system `$EDITOR` | Editor for multi-line input |
| `prompt` | `enabled`, `disabled` | `enabled` | Interactive prompts in the terminal |
| `prefer_editor_prompt` | `enabled`, `disabled` | `disabled` | Open the editor for prompts instead of inline questions |
| `pager` | any executable | system `$PAGER` | Pager for long output |
| `http_unix_socket` | filesystem path | — | Route HTTP calls through a Unix socket (proxy / VM use) |
| `browser` | any executable | system `$BROWSER` | Browser opened by `gh browse` and similar |
| `color_labels` | `enabled`, `disabled` | `disabled` | Render label colours using RGB hex in truecolor terminals |
| `accessible_colors` | `enabled`, `disabled` | `disabled` | Use 4-bit accessible colour palette instead of defaults |
| `accessible_prompter` | `enabled`, `disabled` | `disabled` | Use an accessible prompt mode (screen-reader friendly) |
| `spinner` | `enabled`, `disabled` | `enabled` | Show animated progress spinner |
| `telemetry` | `enabled`, `disabled`, `log` | `enabled` | CLI usage telemetry reporting |

## Best practices

**Set `editor` to a command that blocks until closed.** `gh` waits for
the editor to exit before continuing. Graphical editors typically return
immediately unless you pass the right flag:

```sh
gh config set editor "code --wait"       # VS Code
gh config set editor "subl --wait"       # Sublime Text
gh config set editor "idea --wait"       # JetBrains (via toolbox CLI)
```

Terminal editors (vim, nvim, nano, emacs) block naturally and need no
extra flag.

**Use `--host` for per-host overrides, not separate config files.** If
you work with both `github.com` and a GitHub Enterprise Server instance,
set `git_protocol` separately for each:

```sh
gh config set git_protocol ssh   --host github.com
gh config set git_protocol https --host github.mycompany.com
```

This keeps a single config file with clear, auditable overrides.

**Disable the prompt in automation scripts.** Interactive prompts hang
in CI pipelines. If you invoke `gh` in scripts outside of Actions (where
`GH_TOKEN` implicitly disables them), turn prompts off globally:

```sh
gh config set prompt disabled
```

**Keep telemetry choices deliberate.** The `telemetry` key has three
values: `enabled` sends usage data, `disabled` sends nothing, and `log`
writes locally to `~/.config/gh/telemetry.jsonl` without sending. If
you want to review what would be sent before opting in, start with `log`.

**Run `gh config list` after any machine setup.** The output is concise
and shows every active setting, making it easy to confirm that a
freshly-cloned dotfiles installation applied correctly.

## Pitfalls & gotchas

**`gh config set` does not validate values beyond basic types.** Setting
`git_protocol` to `ftp` or `prompt` to `yes` will be silently accepted
and written — but the next `gh` command will either error or fall back to
the default. Always use the exact values listed in `gh config --help`.

**Global vs. per-host resolution can surprise you.** Running `gh config
get git_protocol` returns the *global* value, even if a per-host override
exists. To see the effective value for a particular host, always pass
`--host`:

```sh
gh config get git_protocol --host github.com
```

**The editor must be on `$PATH` at the time `gh` is invoked.** Setting
`editor` to an absolute path works, but a relative name like `code` only
works if the binary is in `$PATH` in the shell that runs `gh`. When this
goes wrong, `gh pr create` (and similar) will fail with `exec: "code":
executable file not found`.

**`config clear-cache` is not the same as revoking credentials.** The
cache stores API responses (repository metadata, etc.) for speed. Clearing
it does not touch tokens or auth state — use `gh auth logout` for that.

**`prefer_editor_prompt` has no effect when `prompt` is `disabled`.**
Both keys affect the prompt experience, but `prompt disabled` takes
priority. Enable `prompt` first before toggling `prefer_editor_prompt`.

## Worked examples

### First-time setup on a new machine

After running `gh auth login` (see *auth*), configure your preferred tools
before you start working:

```sh
gh config set git_protocol ssh
gh config set editor "nvim"
gh config set pager "less -FRX"
```

Verify everything at once:

```sh
gh config list
```

```text
git_protocol=ssh
editor=nvim
prompt=enabled
prefer_editor_prompt=disabled
pager=less -FRX
http_unix_socket=
browser=
color_labels=disabled
accessible_colors=disabled
accessible_prompter=disabled
spinner=enabled
telemetry=enabled
```

### Working with two hosts that need different git protocols

Your personal account on `github.com` uses SSH keys; your company's
GitHub Enterprise Server only allows HTTPS.

```sh
gh config set git_protocol ssh   --host github.com
gh config set git_protocol https --host github.mycompany.com
```

Confirm the overrides:

```sh
gh config list --host github.com
```

```text
git_protocol=ssh
```

```sh
gh config list --host github.mycompany.com
```

```text
git_protocol=https
```

Now `gh repo clone personal/project` uses SSH, and operations against
`github.mycompany.com` use HTTPS, without any extra flags on every command.

### Recovering from a stale cache

`gh pr list` shows a PR as open even though you merged it moments ago.
Clear the cache and re-run:

```sh
gh config clear-cache
gh pr list
```

The fresh API call returns current state.

## Recovery

`gh config set` overwrites the current value. If you set a key
incorrectly, set it again with the correct value:

```sh
gh config set editor vim   # restore a known-good editor
```

To remove a per-host override entirely, there is no `gh config unset`
command — open `~/.config/gh/hosts.yml` and delete the relevant key
manually, or set the per-host value to match the global default.

If `~/.config/gh/config.yml` becomes corrupted, delete it and re-run
`gh config set` for each key you need. `gh` recreates the file with
defaults on its next invocation.

## See also

- *auth* — store and manage the credentials that `gh config` never
  touches directly.
- *alias* — define shorthand commands that can embed config-driven
  behaviour.
- *completion* — shell completion setup, which depends on the active
  shell detected via config.
