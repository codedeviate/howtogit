# run

List, view, watch, rerun, cancel, delete, and download artifacts from GitHub
Actions workflow runs.

## Mental model

Every time a GitHub Actions workflow triggers — on a push, a pull-request
event, a schedule, or a manual dispatch — GitHub creates a **workflow run**.
A run belongs to a specific workflow file and a specific commit. It contains
one or more **jobs**, and each job contains **steps**.

`gh run` is a command group that gives you a terminal interface to those runs.
You can:

- **Observe**: list recent runs, watch a run stream its progress live, or view
  a run's full log after the fact.
- **Act**: rerun a failed run (or just its failed jobs), cancel a run that is
  still in progress, or force-cancel one that is stuck.
- **Collect**: download the build artifacts a run produced.
- **Clean up**: delete run records you no longer need.

Runs are identified by a numeric run ID. Most subcommands accept the ID as a
positional argument; omit it and `gh` presents an interactive selector.

`gh run` works within the repository of your current directory by default. Pass
`-R owner/repo` to target any repository on GitHub.

## Synopsis

```text
gh run list     [flags]
gh run view     [<run-id>] [flags]
gh run watch    <run-id>   [flags]
gh run rerun    [<run-id>] [flags]
gh run cancel   [<run-id>] [flags]
gh run delete   [<run-id>] [flags]
gh run download [<run-id>] [flags]
```

## Everyday usage

List the most recent runs for the current repository:

```sh
gh run list
```

Watch a run stream live as it executes (prompts for a run if none is given):

```sh
gh run watch
```

View a summary of a finished run:

```sh
gh run view 12345678
```

View the full log — useful after a failure:

```sh
gh run view 12345678 --log-failed
```

Rerun only the failed jobs in a run:

```sh
gh run rerun 12345678 --failed
```

Cancel a run that is still in progress:

```sh
gh run cancel 12345678
```

Download all artifacts produced by a run:

```sh
gh run download 12345678
```

### list

`gh run list` (alias `gh run ls`) shows the most recent runs, newest first.
Filter by branch, event, status, user, or workflow to narrow the list.

```sh
# Show runs on the main branch
gh run list --branch main

# Show only failed runs
gh run list --status failure

# Show runs triggered by a specific commit
gh run list --commit abc1234

# Show runs for one workflow file
gh run list --workflow ci.yml

# Output JSON for scripting
gh run list --json name,status,conclusion,url
```

### view

`gh run view` shows a run's status, jobs, and optional log output.

```sh
# Interactively select a run to view
gh run view

# View a specific run, expanded to show each job step
gh run view 12345678 --verbose

# View only failed step logs
gh run view 12345678 --log-failed

# View the complete raw log
gh run view 12345678 --log

# View a specific job by its database ID
gh run view --job 987654321

# Open the run in the browser
gh run view 12345678 --web

# Exit non-zero if the run failed (useful in scripts)
gh run view 12345678 --exit-status
```

### watch

`gh run watch` polls a running workflow and prints job and step progress until
the run completes. By default it refreshes every 3 seconds and shows all
steps; `--compact` narrows output to only relevant or failed steps.

```sh
# Watch the most recently triggered run (interactive selector)
gh run watch

# Watch a specific run in compact mode
gh run watch 12345678 --compact

# Notify when done (exit-status propagates failure to the shell)
gh run watch 12345678 --exit-status && terminal-notifier -message "Build passed"
```

Note: `gh run watch` does not support fine-grained personal access tokens
because GitHub's API does not expose a `checks:read` permission for them.

### rerun

`gh run rerun` triggers a new attempt of an existing run. You can rerun the
whole run, only its failed jobs (plus their dependencies), or a single job.

The job ID accepted by `--job` is the **database ID**, not the integer visible
in the browser URL. Retrieve it with:

```sh
gh run view 12345678 --json jobs --jq '.jobs[] | {name, databaseId}'
```

```sh
# Rerun the entire run
gh run rerun 12345678

# Rerun only failed jobs
gh run rerun 12345678 --failed

# Rerun a specific job
gh run rerun 12345678 --job 987654321

# Rerun with debug logging enabled
gh run rerun 12345678 --debug
```

### cancel

`gh run cancel` cancels a run that is queued or in progress. If the run is
stuck and a normal cancel does not take effect, use `--force`.

```sh
# Cancel a run
gh run cancel 12345678

# Force-cancel a run that is not responding
gh run cancel 12345678 --force
```

### delete

`gh run delete` removes a run's record from GitHub. This does not affect
the underlying code or workflow; it only removes the run entry from the
Actions history. Deletion is permanent.

```sh
# Interactively select a run to delete
gh run delete

# Delete a specific run
gh run delete 12345678
```

### download

`gh run download` fetches the artifacts a run produced. Each artifact is
extracted into its own subdirectory named after the artifact, unless you are
downloading exactly one artifact (in which case it is extracted into the
current directory).

```sh
# Download all artifacts from a specific run
gh run download 12345678

# Download a specific artifact by name
gh run download 12345678 --name dist

# Download multiple named artifacts
gh run download 12345678 --name dist --name coverage

# Download artifacts matching a glob pattern
gh run download 12345678 --pattern "coverage-*"

# Download to a specific directory
gh run download 12345678 --dir ./artifacts

# Download the latest artifact across all runs (no run-id required)
gh run download --name dist
```

## Key options

### Shared flag

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-R` / `--repo` | Target a different repository | Working outside the current repo |

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-b` / `--branch` | Filter by branch name | Reviewing CI health on a feature branch |
| `-c` / `--commit` | Filter by commit SHA | Auditing a specific commit's CI results |
| `-e` / `--event` | Filter by trigger event | Isolating push vs. PR vs. schedule runs |
| `-s` / `--status` | Filter by run status | Finding all failures or pending runs |
| `-w` / `--workflow` | Filter by workflow name or file | Focusing on one workflow |
| `-u` / `--user` | Filter by triggering user | Auditing a team member's runs |
| `-a` / `--all` | Include disabled workflows | Seeing runs from workflows that have been disabled |
| `-L` / `--limit` | Maximum runs to fetch (default 20) | Getting a longer history |
| `--json fields` | Output JSON fields | Scripting and piping |
| `-q` / `--jq` | Filter JSON with a jq expression | Extracting specific fields inline |

### view

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-v` / `--verbose` | Show each job's steps | Getting a step-by-step breakdown |
| `--log` | Print the full raw log | Investigating a run in detail |
| `--log-failed` | Print only failed step logs | Quickly finding what broke |
| `-j` / `--job` | Focus on a specific job by database ID | Drilling into one job's log |
| `-a` / `--attempt` | View a specific retry attempt | Comparing attempts of a flaky run |
| `--exit-status` | Exit non-zero if run failed | Scripting pass/fail gates |
| `-w` / `--web` | Open the run in a browser | Viewing detailed annotations |
| `--json fields` | Output JSON fields | Scripting |
| `-q` / `--jq` | Filter JSON with a jq expression | Extracting specific fields inline |

### watch

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--compact` | Show only relevant or failed steps | Reducing noise for large workflows |
| `--exit-status` | Exit non-zero if run fails | Chaining with shell commands |
| `-i` / `--interval` | Refresh interval in seconds (default 3) | Reducing API calls on slow connections |

### rerun

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--failed` | Rerun only failed jobs and their dependencies | Saving time after a partial failure |
| `-j` / `--job` | Rerun a specific job by database ID | Retrying one flaky job |
| `-d` / `--debug` | Enable debug logging for the rerun | Diagnosing hard-to-reproduce failures |

### cancel

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--force` | Force-cancel the run | When a normal cancel is not taking effect |

### download

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-n` / `--name` | Download artifacts matching this name (repeatable) | Fetching specific build outputs |
| `-p` / `--pattern` | Download artifacts matching a glob pattern | Fetching groups of related artifacts |
| `-D` / `--dir` | Destination directory (default `.`) | Keeping artifacts out of the project root |

## Best practices

**Use `--exit-status` in scripts and CI gates.** When you call `gh run view`
or `gh run watch` in a script, add `--exit-status` so the script fails if the
run failed. Without it, the command always exits 0, silently hiding failures:

```sh
gh run watch 12345678 --exit-status || { echo "CI failed"; exit 1; }
```

**Rerun with `--failed` before rerunning the whole workflow.** GitHub bills
Actions minutes per job. Rerunning only the failed jobs is cheaper and faster:

```sh
gh run rerun 12345678 --failed
```

**Use `--debug` when a job fails inconsistently.** The flag enables
step-level debug output (`ACTIONS_STEP_DEBUG=true`) for the next attempt. Turn
it off by rerunning again without the flag once you have your diagnosis.

**Download artifacts to a named directory.** By default artifacts land in `.`,
which can clutter your working tree. Use `--dir ./artifacts` (or a path that
is listed in `.gitignore`) to keep things tidy:

```sh
gh run download 12345678 --dir ./artifacts
```

**Filter `run list` before acting.** Combine `--status`, `--branch`, and
`--workflow` flags to narrow to exactly the runs you mean to rerun or cancel.
Accidentally canceling the wrong run in a shared repository is disruptive.

**Use JSON output for scripting.** The `--json` flag with a list of fields and
`--jq` for inline filtering lets you build reliable pipelines without parsing
human-readable output:

```sh
gh run list --status failure --json databaseId,headBranch --jq '.[].databaseId'
```

## Pitfalls & gotchas

**`--job` takes a database ID, not the URL number.** The integer at the end of
a job's browser URL (`/runs/<run-id>/jobs/<number>`) is not the database ID.
Passing the URL number to `gh run rerun --job` or `gh run view --job` results
in a 404. Get the correct ID first:

```sh
gh run view 12345678 --json jobs --jq '.jobs[] | {name, databaseId}'
```

**`gh run watch` does not work with fine-grained PATs.** GitHub does not
expose a `checks:read` scope for fine-grained personal access tokens.
Authenticated with such a token, `gh run watch` will fail. Use a classic PAT
or the `GITHUB_TOKEN` provided by Actions.

**`run list --workflow` skips disabled workflows unless you add `--all`.**
If you filter by workflow name and get no results, the workflow may be
disabled. Add `-a` / `--all` to include it.

**Runs from organization or enterprise ruleset workflows show no workflow
name.** This is an API limitation. The `workflowName` JSON field will be
empty for those runs.

**`gh run download` without a run ID fetches the latest artifact of that
name, which may not be what you expect.** If a later run overwrote or deleted
an artifact, you will get the most recent surviving version. Always supply the
run ID when you need a specific artifact:

```sh
gh run download 12345678 --name dist   # specific run
```

**Deleting a run is permanent.** There is no undo. The underlying code and
workflow file are unaffected, but the run record is gone. Confirm the run ID
with `gh run view` before deleting.

## Worked examples

### Monitoring a deployment pipeline end-to-end

You push a commit and want to tail the deployment workflow until it succeeds
or fails, then know the result immediately.

```sh
# Find the run triggered by your push
gh run list --branch my-feature --workflow deploy.yml --limit 5
```

```text
STATUS      TITLE                        WORKFLOW    BRANCH       EVENT  ID
in_progress Add caching to build step    deploy.yml  my-feature   push   98765432
success     Fix typo in README           deploy.yml  my-feature   push   98765000
```

```sh
# Tail the live run
gh run watch 98765432 --compact --exit-status
```

```text
* deploy.yml #98765432 (my-feature)
  * build (in_progress)
    ✓ Checkout
    ✓ Set up Node
    * Run tests
  ...
✓ deploy.yml completed with 'success'
```

The shell exits 0, so you can chain a notification:

```sh
gh run watch 98765432 --exit-status && say "Deploy passed"
```

### Diagnosing and rerunning a flaky test job

A run failed in one job. View the failed log, understand what broke, then
rerun with debug logging.

```sh
# View only the failed steps
gh run view 12345678 --log-failed
```

```text
▶ test (ubuntu-latest)
  ✗ Run integration tests
    Error: connection refused on port 5432
```

The log shows a transient database connection error. Rerun with debug to
capture more detail:

```sh
gh run rerun 12345678 --failed --debug
```

The rerun passes. Compare the two attempts to confirm:

```sh
gh run view 12345678 --attempt 2 --verbose
```

### Collecting build artifacts in CI

A workflow builds platform-specific binaries and uploads them as artifacts
named `dist-linux`, `dist-macos`, and `dist-windows`. After the run
succeeds, download all three into a release staging directory:

```sh
RUNID=$(gh run list --workflow build.yml --status success --limit 1 \
  --json databaseId --jq '.[0].databaseId')

gh run download "$RUNID" --pattern "dist-*" --dir ./release/staging
```

```text
✓ Downloaded dist-linux to ./release/staging/dist-linux
✓ Downloaded dist-macos to ./release/staging/dist-macos
✓ Downloaded dist-windows to ./release/staging/dist-windows
```

### Bulk-cancelling queued runs on a stale branch

A branch had a flurry of pushes and left many queued runs you no longer need.
List their IDs in JSON, then cancel each one:

```sh
gh run list --branch old-feature --status queued --json databaseId \
  --jq '.[].databaseId' \
  | xargs -I{} gh run cancel {}
```

## Recovery

**A run is stuck in progress and will not cancel.** Use `--force`:

```sh
gh run cancel 12345678 --force
```

**You deleted the wrong run.** Deletion is permanent. The underlying code and
workflow file are unaffected; only the run record is gone. If the commit still
exists you can trigger a new run by re-pushing or using a manual dispatch
(`gh workflow run`).

**A rerun produced a different failure.** View the specific attempt to
compare logs side by side:

```sh
gh run view 12345678 --attempt 1 --log-failed
gh run view 12345678 --attempt 2 --log-failed
```

**An artifact directory appears empty after download.** Confirm the artifact
name is exact, then re-download:

```sh
gh run view 12345678 --json jobs \
  --jq '.jobs[].steps[].name'
gh run download 12345678 --name exact-artifact-name --dir ./artifacts
```

## See also

- *auth* — authenticate `gh` before running any `gh run` commands.
- *pr* — `gh pr checks` shows CI status associated with a pull request.
- *workflow* — `gh workflow run`, `gh workflow enable`, and
  `gh workflow disable` control the workflow definitions that generate runs.
- *repo* — `gh repo view` links to the Actions tab for a repository.
