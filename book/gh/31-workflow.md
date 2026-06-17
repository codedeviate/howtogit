# workflow

List, view, enable, disable, and manually trigger GitHub Actions workflow
files directly from the command line.

## Mental model

A GitHub Actions workflow is a YAML file stored under `.github/workflows/`
in a repository. GitHub Actions reads those files and turns them into
pipelines that run in response to events — pushes, pull requests, schedules,
or manual dispatches.

`gh workflow` is the command-line interface to that layer. It does not
interact with individual runs (that is the job of `gh run`); it works at the
level of the *workflow definition file itself* — listing all files the
repository knows about, showing their YAML source, toggling them on and off,
and firing a manual `workflow_dispatch` event to start a run.

The key distinction: a workflow is a file, a run is an execution of that
file. `gh workflow list` shows you the files; `gh run list` shows you the
executions. Use both together when diagnosing a CI problem.

Workflows can be in one of two states:

- **active** — eligible to be triggered by events and visible in
  `gh workflow list` by default.
- **disabled** — will not be triggered, and is hidden from the default
  listing unless you pass `--all`.

GitHub identifies each workflow by an integer ID as well as by its filename.
`gh workflow` accepts either form in most subcommands.

## Synopsis

```text
gh workflow list   [flags]
gh workflow view   [<workflow-id> | <workflow-name> | <filename>] [flags]
gh workflow run    [<workflow-id> | <workflow-name>] [flags]
gh workflow enable [<workflow-id> | <workflow-name>] [flags]
gh workflow disable [<workflow-id> | <workflow-name>] [flags]
```

All subcommands accept `-R / --repo [HOST/]OWNER/REPO` to target a
repository other than the one inferred from the current directory.

## Everyday usage

List all active workflows in the current repository:

```sh
gh workflow list
```

```text
NAME               STATE   ID
CI                 active  12345678
Release            active  23456789
Nightly tests      active  34567890
```

Include disabled workflows in the output:

```sh
gh workflow list --all
```

View the YAML source of a workflow interactively (picks from a menu when
called with no argument):

```sh
gh workflow view --yaml
```

View a specific workflow by filename:

```sh
gh workflow view ci.yml --yaml
```

Open a workflow's summary page in the browser:

```sh
gh workflow view ci.yml --web
```

Trigger a workflow that has a `workflow_dispatch` trigger:

```sh
gh workflow run ci.yml
```

Trigger the same workflow on a specific branch:

```sh
gh workflow run ci.yml --ref my-feature-branch
```

Pass named inputs to a parameterised workflow:

```sh
gh workflow run deploy.yml -f environment=staging -f version=1.4.2
```

Disable a workflow so it stops running:

```sh
gh workflow disable stale.yml
```

Re-enable it:

```sh
gh workflow enable stale.yml
```

## Key options

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-a` / `--all` | Include disabled workflows in the output | Auditing all workflow files, not just active ones |
| `-L` / `--limit int` | Cap the number of results returned (default 50) | Repositories with many workflows |
| `--json fields` | Emit JSON with selected fields (`id`, `name`, `path`, `state`) | Scripting and piping to `jq` |
| `-q` / `--jq expression` | Filter the JSON output with a jq expression | Inline extraction without a separate `jq` call |
| `-t` / `--template string` | Format JSON output using a Go template | Custom tabular views |

### view

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-y` / `--yaml` | Print the raw YAML of the workflow file | Auditing what Actions will actually execute |
| `-w` / `--web` | Open the workflow summary in the browser | Seeing recent run history at a glance |
| `-r` / `--ref string` | Show the workflow file from a specific branch or tag | Comparing versions across branches |

### run

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-r` / `--ref string` | Run the workflow file at a specific branch or tag | Testing a workflow change before it merges |
| `-f` / `--raw-field key=value` | Supply a workflow input as a plain string | Passing simple scalar parameters |
| `-F` / `--field key=value` | Supply a workflow input, respecting `@` file-read syntax | Passing file contents as input values |
| `--json` | Read workflow inputs as JSON via stdin | Scripting complex or dynamic input sets |

### enable / disable

These subcommands take no flags beyond `--repo`. Supply the workflow by its
integer ID, display name, or filename.

## Best practices

**Prefer filenames over numeric IDs in scripts.** IDs are repository-stable
but opaque in code review. A filename like `ci.yml` communicates intent;
`12345678` does not. Both are accepted by every subcommand.

**Pair `gh workflow run` with `gh run watch` to close the loop.** Triggering
a dispatch event fires the run asynchronously. Immediately following with
`gh run watch` (from the `gh run` command group) lets you tail the logs
without opening a browser:

```sh
gh workflow run ci.yml --ref main
gh run watch   # interactively pick the just-triggered run
```

**Use `--json` with `gh workflow list` for automation.** The four JSON
fields — `id`, `name`, `path`, `state` — are enough to build inventory
scripts, dashboards, or audit reports without screen-scraping:

```sh
gh workflow list --all --json id,name,state \
  | jq '.[] | select(.state == "disabled") | .name'
```

**Gate `workflow_dispatch` triggers with inputs for repeatability.** A
workflow that accepts named inputs can be triggered with consistent
parameters from the CLI, from another workflow with `workflow_call`, or by a
human through the GitHub UI. Defining inputs in the YAML and passing them
with `-f` in `gh workflow run` gives you a single, auditable invocation
pattern.

**Use `--ref` to test a modified workflow before merging.** Push your
`.github/workflows/ci.yml` change to a feature branch, then run:

```sh
gh workflow run ci.yml --ref fix/update-node-version
```

This exercises the updated file without touching the default branch.

## Pitfalls & gotchas

**`gh workflow run` only works on workflows with `workflow_dispatch`.**
Attempting to run a workflow that lacks an `on: workflow_dispatch` trigger
returns an error. Check with `gh workflow view <file> --yaml` to confirm the
trigger is present before trying to dispatch.

**Disabled workflows are invisible to `gh workflow list` by default.**
If a workflow seems to have disappeared, run `gh workflow list --all`. A
well-intentioned colleague may have disabled it. Re-enable with
`gh workflow enable <name>`.

**Workflow inputs are strings — no type coercion.** The `-f` / `--raw-field`
flag always passes a plain string. If your workflow YAML declares an input of
type `boolean` or `number`, GitHub Actions performs the coercion on its end,
but pass `"true"` or `"42"` rather than bare values to avoid shell
interpretation issues.

**The `--ref` flag on `run` must contain the workflow file.** If the branch
you name does not yet have the workflow file at `.github/workflows/<name>`,
the run fails with a "workflow file not found" error. Make sure the branch
has been pushed before dispatching.

**`gh workflow view` without `--yaml` shows a summary, not the source.**
The default output is a human-readable table of recent runs and the workflow's
state. Pass `--yaml` explicitly when you want to inspect or copy the actual
YAML definition.

## Worked examples

### Auditing and re-enabling a disabled workflow

A nightly test workflow stopped appearing in run history. Investigate:

```sh
gh workflow list --all
```

```text
NAME               STATE     ID
CI                 active    12345678
Release            active    23456789
Nightly tests      disabled  34567890
```

Inspect the file to confirm it still has the right trigger:

```sh
gh workflow view 34567890 --yaml
```

```text
name: Nightly tests
on:
  schedule:
    - cron: '0 2 * * *'
...
```

Re-enable it:

```sh
gh workflow enable 34567890
```

```text
✓ Enabled nightly.yml
```

Verify the state has changed:

```sh
gh workflow list
```

```text
NAME               STATE   ID
CI                 active  12345678
Release            active  23456789
Nightly tests      active  34567890
```

### Triggering a parameterised deployment workflow

A repository has a `deploy.yml` workflow with two declared inputs:
`environment` (values: `staging`, `production`) and `version`. Trigger a
staging deployment from the command line:

```sh
gh workflow run deploy.yml -f environment=staging -f version=2.3.1
```

```text
✓ Created workflow_dispatch event for deploy.yml at main

To see runs for this workflow, try: gh run list --workflow=deploy.yml
```

Watch the run as it executes (see *run* for full details):

```sh
gh run list --workflow=deploy.yml --limit 1
```

```text
STATUS  TITLE              WORKFLOW  BRANCH  EVENT              ID
*       Manual run         deploy    main    workflow_dispatch  9876543210
```

Pass a complex input set from a JSON file:

```sh
cat inputs.json
```

```text
{"environment": "staging", "version": "2.3.1"}
```

```sh
gh workflow run deploy.yml --json < inputs.json
```

### Inspecting a workflow on a feature branch before merging

You are reviewing a pull request that modifies `.github/workflows/ci.yml`.
Before approving, run the updated workflow against the PR branch:

```sh
gh workflow run ci.yml --ref feature/upgrade-actions
```

Open the resulting run in the browser to review logs:

```sh
gh run list --workflow=ci.yml --limit 1
# note the run ID from the output, then:
gh run view <run-id> --web
```

## Recovery

If a workflow run was triggered accidentally or with wrong inputs, it can
be cancelled via `gh run cancel <run-id>` (see *run*). There is no undo for
`gh workflow disable` or `gh workflow enable`, but re-running the inverse
command restores the previous state immediately.

If a dispatch triggers no run — common when the target branch does not
contain the workflow file — push the branch first, then re-run the command.
If runs continue not to appear, check `gh workflow list --all` to confirm the
workflow is not disabled, and verify the YAML has `on: workflow_dispatch`
with `gh workflow view <file> --yaml`.

For authentication or permission errors when calling `gh workflow run`, see
*auth* — the active credential must have the `workflow` OAuth scope. Add it
without logging out:

```sh
gh auth refresh --scopes workflow
```

## See also

- *run* — list, view, watch, cancel, and rerun individual workflow executions.
- *auth* — managing credentials and OAuth scopes, including the `workflow` scope required to trigger runs.
- *secret* — managing the encrypted secrets that workflows consume at runtime.
- *variable* — managing plaintext configuration variables available to workflow steps.
- *cache* — inspecting and deleting the dependency caches that workflows create.
