# hooks

Scripts that Git executes automatically at defined points in its workflow,
letting you enforce policy, automate checks, and integrate with external
systems without changing how contributors invoke Git commands.

## Mental model

A hook is an executable file sitting in `.git/hooks/`. Git calls it by name
at a specific moment — before a commit is written, after a push completes,
when a merge message is prepared — and inspects its exit code. Exit zero means
"proceed"; exit non-zero means "abort" (for hooks that can abort). The hook
receives context through command-line arguments or standard input depending on
which hook it is.

```text
git commit
  │
  ├─► pre-commit          exit ≠ 0 → abort
  ├─► prepare-commit-msg  (fills the editor buffer)
  ├─► commit-msg          exit ≠ 0 → abort
  └─► post-commit         (notification only, cannot abort)
```

Three things determine whether a hook fires:

1. A file with the exact hook name exists in the hooks directory.
2. The file has the executable bit set (`chmod +x`).
3. The file is not bypassed by a flag like `--no-verify`.

The hooks directory defaults to `$GIT_DIR/hooks` (`.git/hooks` in a normal
clone), but you can redirect it for the whole repository with:

```sh
git config core.hooksPath /path/to/shared/hooks
```

This is how teams share hooks without committing them into `.git/`, which is
not version-controlled.

Before invoking any hook, Git changes its working directory to the repository
root (non-bare) or to `$GIT_DIR` (bare). An exception: hooks triggered during
a push (`pre-receive`, `update`, `post-receive`, `post-update`,
`push-to-checkout`) always run in `$GIT_DIR`, even in non-bare repositories.
Git also exports environment variables such as `GIT_DIR` and `GIT_WORK_TREE`
so that commands inside the hook find the right repository.

## Synopsis

Hooks are not a subcommand — there is no `git hooks run` in day-to-day use.
The interface is the filesystem:

```text
# Location (default)
$GIT_DIR/hooks/<hook-name>

# Override location for all hooks in this repo
git config core.hooksPath <dir>

# Bypass hooks that support --no-verify
git commit --no-verify
git push   --no-verify
git am     --no-verify

# Bypass hooks that support --no-verify for merge
git merge  --no-verify
```

A minimal hook skeleton:

```sh
#!/bin/sh
# Hook name: pre-commit
# Exit 0 to allow, non-zero to abort.
exit 0
```

## Everyday usage

### Install a pre-commit hook

```sh
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
# Run the project's lint script before every commit.
npm run lint --silent
EOF
chmod +x .git/hooks/pre-commit
```

From now on, `git commit` runs the linter. A non-zero exit from `npm run lint`
aborts the commit and prints the linter output.

### Enforce a commit-message format

```sh
cat > .git/hooks/commit-msg << 'EOF'
#!/bin/sh
# Require the subject line to reference a ticket: PROJ-1234 or HOTFIX.
msg=$(head -1 "$1")
if ! echo "$msg" | grep -qE '^(PROJ-[0-9]+|HOTFIX)'; then
  echo "commit-msg: subject must start with PROJ-NNNN or HOTFIX" >&2
  exit 1
fi
EOF
chmod +x .git/hooks/commit-msg
```

The hook receives the path to the commit-message file as `$1`; read or edit
that file in place.

### Auto-populate the commit message with a ticket number

```sh
cat > .git/hooks/prepare-commit-msg << 'EOF'
#!/bin/sh
# Prepend the branch ticket number to the commit message.
branch=$(git symbolic-ref --short HEAD 2>/dev/null)
ticket=$(echo "$branch" | grep -oE 'PROJ-[0-9]+')
if [ -n "$ticket" ] && [ "$2" != "merge" ] && [ "$2" != "squash" ]; then
  sed -i.bak "1s/^/$ticket: /" "$1"
fi
EOF
chmod +x .git/hooks/prepare-commit-msg
```

`prepare-commit-msg` receives one to three arguments: the message file path;
an optional source keyword (`message`, `template`, `merge`, `squash`, or
`commit`); and, when the source is `commit`, the commit object name as a third
argument. Guard against the merge and squash sources, which already have
content.

### Run tests before a push

```sh
cat > .git/hooks/pre-push << 'EOF'
#!/bin/sh
# Run the full test suite; abort push on failure.
npm test
EOF
chmod +x .git/hooks/pre-push
```

`pre-push` receives the remote name and URL as arguments and reads
`<local-ref> <local-object-name> <remote-ref> <remote-object-name>` lines from
stdin, one per ref being pushed. A non-zero exit prevents the push.

### Share hooks across the team via a tracked directory

```sh
mkdir -p scripts/hooks
cp .git/hooks/pre-commit scripts/hooks/pre-commit
git add scripts/hooks/pre-commit
git commit -m "Add pre-commit lint hook"
# Configure all contributors' clones to use it:
git config core.hooksPath scripts/hooks
```

Each contributor who clones and runs this config command gets the same hooks.
Automate the config step in a setup script or `Makefile`.

## Key options

Hooks themselves have no flags; the relevant options belong to the commands
that invoke them.

| Context | Option / variable | What it does |
|---------|-------------------|--------------|
| `git commit` | `--no-verify` | Skips `pre-commit` and `commit-msg` hooks |
| `git merge` | `--no-verify` | Skips `pre-merge-commit` and `commit-msg` hooks |
| `git push` | `--no-verify` | Skips `pre-push` hook |
| `git am` | `--no-verify` | Skips `applypatch-msg` and `pre-applypatch` hooks |
| `git config` | `core.hooksPath` | Redirects all hook lookups to the given directory |
| Hook file | executable bit | Must be set (`chmod +x`); hooks without it are silently ignored |
| Hook file | shebang line | Determines the interpreter; use `#!/bin/sh` for portability |
| `pre-receive` | `GIT_PUSH_OPTION_COUNT` / `GIT_PUSH_OPTION_N` | Environment variables carrying push options passed with `git push --push-option=...` |

## Best practices

**Keep hooks fast.** Every `git commit` goes through `pre-commit`. A hook that
takes five seconds trains contributors to reach for `--no-verify`. Run only
the subset of checks that is fast locally; save expensive steps (full test
suite, integration tests) for `pre-push` or CI.

**Use `core.hooksPath` to version-control your hooks.** The `.git/` directory
is not committed, so a hook installed directly in `.git/hooks/` vanishes after
a fresh clone. Put hooks in a tracked directory (e.g. `scripts/hooks/`) and
document the one-time setup command. Consider automating it in a `Makefile`
target or a `postinstall` script.

**Write hooks in portable shell.** Use `#!/bin/sh`, not `#!/bin/bash`, unless
you need Bash-specific features. Many CI environments and developer machines
use different shells. POSIX sh is available everywhere Git runs.

**Exit with a meaningful message to stderr.** When a hook rejects an
operation, the developer needs to know why and how to fix it:

```sh
echo "pre-commit: trailing whitespace found in src/api.js:42" >&2
exit 1
```

Write to stderr (`>&2`), not stdout. Git forwards stderr to the terminal.

**Distinguish notification hooks from gating hooks.** Hooks like `post-commit`
and `post-receive` run after the fact and their exit code is ignored (for
outcome purposes). Use them for notifications, cache invalidation, or
deployments. Do not write critical logic in them expecting they can block
anything.

**On the server side, prefer `pre-receive` over `update`.** The `update` hook
fires once per ref, which can produce a flood of emails or Slack messages.
`pre-receive` fires once per push operation and sees all refs being updated in
a single stdin read.

**Do not call `git commit` or `git push` from inside a hook that git itself
invoked.** Re-entrant Git operations inside a hook inherit the lock on the
repository and will deadlock or corrupt state. Use object database plumbing, or
stage changes to a file and let the caller commit them.

## Pitfalls & gotchas

**Missing executable bit silently skips the hook.** Git does not warn you when
a hook file exists but is not executable. If your hook appears to do nothing,
the first thing to check is `ls -l .git/hooks/pre-commit` — the permissions
must include `x`.

```sh
chmod +x .git/hooks/pre-commit   # fix it
```

**`prepare-commit-msg` is not bypassed by `--no-verify`.** Developers who
reach for `--no-verify` to skip `pre-commit` are sometimes surprised that the
message template hook still runs. The Git manual is explicit: `--no-verify`
skips `pre-commit` and `commit-msg`, but not `prepare-commit-msg`.

**Windows line endings break shell hooks.** A hook file with `\r\n` line
endings will fail on Linux/macOS with a cryptic `bad interpreter` error
because the shebang line becomes `#!/bin/sh\r`. Ensure your editor and
`.gitattributes` do not convert the hook files to CRLF:

```text
# .gitattributes
scripts/hooks/*  text eol=lf
```

**Hooks in `core.hooksPath` must still have the executable bit.** The
directory override does not change this requirement. After copying hooks to a
tracked directory, remember `chmod +x scripts/hooks/*`.

**`post-rewrite` is not called by `git filter-repo` or `git fast-import`.**
The documentation is explicit: full history-rewriting tools typically skip this
hook. If you rely on `post-rewrite` to update notes or external references
after a rebase, test whether your specific rewriting tool calls it.

**Environment variables inherited from Git can interfere with subshells.**
If a hook needs to run Git commands against a different repository, unset the
Git environment variables first, otherwise they point the subprocess at the
wrong repo:

```sh
foreign_desc=$(unset $(git rev-parse --local-env-vars); git -C ../other-repo describe)
```

**Client-side hooks are not enforced.** Anyone can delete `.git/hooks/` or
pass `--no-verify`. Use server-side hooks (`pre-receive`, `update`) for
hard policy enforcement. Client-side hooks are developer-experience tools,
not security controls.

## Worked examples

### Example 1: Linting and formatting on every commit

The goal: run ESLint and Prettier on staged JavaScript files only (not the
whole repo), and abort if either tool reports an error.

```sh
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/sh
# Collect staged .js and .ts files.
staged=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(js|ts)$')
[ -z "$staged" ] && exit 0   # nothing to check

# Run Prettier check.
echo "$staged" | xargs npx prettier --check
prettier_exit=$?

# Run ESLint.
echo "$staged" | xargs npx eslint
eslint_exit=$?

# Fail if either tool found issues.
[ $prettier_exit -ne 0 ] || [ $eslint_exit -ne 0 ] && exit 1
exit 0
EOF
chmod +x .git/hooks/pre-commit
```

Running `git commit` now produces output like:

```console
Checking formatting...
[warn] src/api.js
[warn] Code style issues found in the above file. Run Prettier with
       --write to fix.
```

Fix the formatting, re-stage, and commit again.

### Example 2: Server-side branch protection with pre-receive

The goal: reject any push that attempts to force-update `main` or `release/*`
on the central bare repository.

```sh
cat > /srv/repos/myproject.git/hooks/pre-receive << 'EOF'
#!/bin/sh
# Read each ref being updated from stdin.
while IFS=' ' read -r old new ref; do
  case "$ref" in
    refs/heads/main|refs/heads/release/*)
      # Detect a force push: new commit is not a descendant of old.
      if [ "$old" != "0000000000000000000000000000000000000000" ]; then
        if ! git merge-base --is-ancestor "$old" "$new" 2>/dev/null; then
          echo "pre-receive: force push to $ref is not allowed." >&2
          exit 1
        fi
      fi
      ;;
  esac
done
exit 0
EOF
chmod +x /srv/repos/myproject.git/hooks/pre-receive
```

The hook reads `<old-oid> <new-oid> <ref-name>` triplets from stdin. When
`old` is the all-zeroes object name, this is a new branch being created, not
a force push — the check is skipped. For existing branches, `git merge-base
--is-ancestor` returns zero only if the old commit is an ancestor of the new
one (a fast-forward); otherwise it exits non-zero, triggering the rejection.

### Example 3: Triggering a deployment from post-receive

The goal: after a successful push to the `production` branch on the server,
update the working tree of a checked-out deployment directory.

```sh
cat > /srv/repos/myproject.git/hooks/post-receive << 'EOF'
#!/bin/sh
# Deploy when the production branch is updated.
while IFS=' ' read -r old new ref; do
  if [ "$ref" = "refs/heads/production" ]; then
    echo "post-receive: deploying production..."
    GIT_WORK_TREE=/var/www/myapp git checkout -f production
    echo "post-receive: done."
  fi
done
EOF
chmod +x /srv/repos/myproject.git/hooks/post-receive
```

`post-receive` cannot abort the push — the data is already stored. It is safe
to use for side effects such as deployments, cache purges, or webhook calls.
Both stdout and stderr are forwarded to the pushing client, so `echo` messages
appear in the developer's terminal.

## Recovery

Hooks occasionally go wrong — a broken script blocks all commits, or a
half-finished hook was left behind. Quick escapes:

**Skip a hook for one invocation** using `--no-verify` on supported commands:

```sh
git commit --no-verify -m "Emergency fix — re-enable hook after"
git push   --no-verify
```

Use this sparingly. Fix the hook as soon as possible; leaving `--no-verify`
in a team's muscle memory defeats the purpose of the hook.

**Disable a hook permanently** by removing the executable bit or renaming it:

```sh
chmod -x .git/hooks/pre-commit       # disable without deleting
mv .git/hooks/pre-commit .git/hooks/pre-commit.disabled
```

**Restore a deleted or corrupted hook** from your tracked hooks directory:

```sh
cp scripts/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Debug a misbehaving hook** by running it directly:

```sh
sh -x .git/hooks/pre-commit     # print each command as it executes
```

See *Getting out of jams* for broader undo recipes when a hook-related abort
has left the repository in a partial state (e.g. a failed `am` or
interrupted rebase).

## See also

- *commit* — the `--no-verify` flag that bypasses `pre-commit` and `commit-msg`.
- *push* — the `--no-verify` flag that bypasses `pre-push`.
- *am* — `applypatch-msg` and `pre-applypatch` hooks called during patch
  application.
- *rebase* — triggers `post-rewrite` after squash and fixup operations.
- *gc* — `pre-auto-gc` hook called before automatic garbage collection.
- *Getting out of jams* — recovering from interrupted operations caused by
  hook failures.
