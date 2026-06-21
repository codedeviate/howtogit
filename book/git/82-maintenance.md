# maintenance

Run background housekeeping tasks to keep a repository fast and lean over
time.

## Mental model

Every time you run `git add`, `git fetch`, or `git commit`, Git prioritizes
responsiveness over tidiness. Loose objects accumulate. Pack files fragment.
The commit-graph — a precomputed index that makes `git log` and reachability
checks fast — goes stale. Remote-tracking branches fall behind without a full
fetch.

`git maintenance` is the scheduled janitor. It runs a configurable set of
*tasks*, each targeting one aspect of repository health, without interrupting
your normal workflow. Because each run takes a lock on the object database,
tasks cannot race against each other or corrupt in-flight operations.

Think of it in two modes:

- **On-demand**: `git maintenance run` — you trigger it explicitly, choosing
  which tasks to run.
- **Background schedule**: `git maintenance start` — Git registers the
  repository with your OS scheduler (launchctl on macOS, systemd timers on
  Linux, cron as a fallback, schtasks on Windows) and runs `git maintenance
  run --schedule` hourly, daily, and weekly without any further action on
  your part.

```text
git maintenance start
        │
        ▼
OS scheduler (launchctl / systemd / crontab / schtasks)
        │  hourly ──► commit-graph, prefetch
        │  daily  ──► loose-objects, incremental-repack
        └  weekly ──► pack-refs
```

The `register` and `unregister` subcommands manage which repositories appear
in the global `maintenance.repo` list without touching the OS scheduler.

## Synopsis

```text
git maintenance run [--auto] [--schedule=<frequency>] [--quiet] [--task=<task>...]
git maintenance start [--scheduler=auto|crontab|systemd-timer|launchctl|schtasks]
git maintenance stop
git maintenance register [--config-file=<file>]
git maintenance unregister [--force] [--config-file=<file>]
```

## Everyday usage

Register the current repository and start the background schedule:

```sh
git maintenance start
```

Run all currently-enabled tasks immediately, in the foreground:

```sh
git maintenance run
```

Run a specific task without changing what is persistently enabled:

```sh
git maintenance run --task=commit-graph
git maintenance run --task=loose-objects
```

Run multiple tasks in one pass (executed in the order listed):

```sh
git maintenance run --task=loose-objects --task=incremental-repack
```

Stop background maintenance (leaves the repository registered):

```sh
git maintenance stop
```

Remove the current repository from the global maintenance list entirely:

```sh
git maintenance unregister
```

Check which tasks the incremental strategy will run and when — look at the
global config after `git maintenance start`:

```sh
git config --global --list | grep maintenance
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `--task=<task>` | Run only the named task(s), in that order | Target one area without touching the rest |
| `--auto` | Run tasks only when their threshold is exceeded (e.g. loose-object count, pack-file count) | Light-touch check after commands that add data |
| `--schedule=<frequency>` | Run tasks only if their scheduled interval has elapsed since last run; `<frequency>` must be `hourly`, `daily`, or `weekly` | Used internally by the OS scheduler (e.g. `--schedule=hourly`); the value is required — bare `--schedule` is rejected |
| `--quiet` | Suppress progress and informational output on stderr | Cron jobs and scripts where noise pollutes logs |
| `--scheduler=<value>` | Choose the OS scheduler backend: `auto`, `crontab`, `systemd-timer`, `launchctl`, `schtasks` | Force a specific scheduler when `auto` picks the wrong one |

## Best practices

**Use `git maintenance start` on every repository you work in regularly.**
One command enables the full incremental strategy: commit-graph and prefetch
run hourly, loose-objects and incremental-repack run daily, pack-refs runs
weekly. You pay nothing at commit or fetch time; the cost moves to the
background.

**Prefer the incremental strategy over `git gc` for active repositories.**
The `gc` task repacks everything into a single pack file. On a large
repository this can take minutes and holds the object-database lock for the
entire duration, blocking concurrent operations. The `incremental-repack`
task does the same work in small batches using the multi-pack-index, which
finishes quickly and releases the lock sooner. See the *gc* chapter for
cases where a full `git gc` is still appropriate.

**Do not mix `git gc` with `git maintenance run`.** The `git gc` command
does not take the same lock as `git maintenance run`. Running both
concurrently can leave the object database in an inconsistent state. If you
need garbage collection in a maintenance context, use
`git maintenance run --task=gc` instead.

**Set `maintenance.strategy = incremental` explicitly on shared developer
machines.** When `git maintenance register` runs, it sets this value
automatically. On machines where you manage git config centrally, set it in
the global config to ensure every registered repository inherits a sensible
schedule without further per-repo configuration.

```sh
git config --global maintenance.strategy incremental
```

**Tune batch sizes for very large repositories.** The `loose-objects` task
defaults to processing fifty thousand objects per run. If your repository
grows loose objects faster than that, increase the batch size — or set it to
zero to remove the limit and process all of them in one pass:

```sh
git config maintenance.loose-objects.batchSize 0
```

**Verify the scheduler is running after `git maintenance start`.** On macOS,
check that the launch agents are registered:

```sh
ls ~/Library/LaunchAgents/org.git-scm.git*
```

On Linux with systemd:

```sh
systemctl --user list-timers | grep git-maintenance
```

## Pitfalls & gotchas

**`unregister` does not stop the background scheduler.** It removes the
repository from the `maintenance.repo` list, so future scheduled runs skip
it. But if a run is already in progress it will complete. Call
`git maintenance stop` first if you want an immediate halt.

**`stop` does not unregister the repository.** After `git maintenance stop`,
the current repository is still in `maintenance.repo`. A future
`git maintenance start` will pick it up again. This is intentional — stop
means "pause", not "forget".

**The object-database lock causes skipped windows on busy machines.** Each
`git maintenance run` takes the lock for its entire duration. If a previous
run has not finished when the scheduler fires again, the new run exits
without doing any work. On machines with many large registered repositories,
consider moving expensive tasks (especially `gc`) to weekly or disabling
them in favour of `incremental-repack`.

**`maintenance.auto = false` persists after `unregister`.** When you run
`git maintenance register`, it sets `maintenance.auto = false` in the
repository config to prevent double-maintenance (automatic + scheduled). That
setting stays after `git maintenance unregister`. If you want foreground
auto-maintenance back, re-enable it manually:

```sh
git config maintenance.auto true
```

**Prefetch stores refs under `refs/prefetch/`, not under
`refs/remotes/`.** The `prefetch` task deliberately avoids updating your
remote-tracking branches so that a `git fetch` you run interactively
appears to complete instantly. But your remote-tracking branches (`origin/main`,
etc.) do not reflect the prefetched state. Run a regular `git fetch` when
you need those refs updated.

**Credentials must be available for prefetch to work.** The `prefetch` task
calls `git fetch` in a non-interactive context (the OS scheduler). If your
remote requires interactive authentication (e.g. a browser OAuth flow), the
fetch will silently fail. Use SSH keys or a credential helper that stores
tokens persistently.

**On macOS, do not use `crontab` for maintenance.** The cron environment on
macOS does not have a full user context, so credential helpers cannot access
the system keychain. `git maintenance start` uses `launchctl` by default on
macOS for exactly this reason. If you override with `--scheduler=crontab`,
prefetch will fail silently for remotes that require stored credentials.

## Worked examples

### Enabling background maintenance on a new clone

You have just cloned a large monorepo and want ongoing performance
optimisation without any manual intervention.

```sh
cd ~/projects/monorepo
git maintenance start
```

```text
$ git config --global --list | grep maintenance
maintenance.repo=/Users/alice/projects/monorepo
maintenance.strategy=incremental
```

From this point on, the OS scheduler runs `git maintenance run --schedule=hourly`
every hour. At midnight it also runs daily tasks; on Sunday midnight it runs
weekly tasks. Your `git log`, `git fetch`, and `git status` commands will
gradually get faster as the commit-graph and pack structure are kept up to
date.

### Running specific tasks manually before a release

You are about to tag a release and want the repository in peak shape. You
decide to pack loose objects and regenerate the commit-graph, but skip a
full `gc` to avoid the long lock time.

```sh
git maintenance run --task=loose-objects --task=incremental-repack --task=commit-graph
```

Tasks run in the order specified. When the command returns, loose objects
are consolidated into a new pack file, the multi-pack-index is updated, and
the commit-graph reflects all commits on every reachable branch.

Verify the commit-graph was written:

```sh
ls .git/objects/info/commit-graphs/
```

```text
commit-graph-chain  graph-abc123.graph  graph-def456.graph
```

### Migrating from a cron-based `git gc` to managed maintenance

Your team runs `git gc` nightly via a custom cron job. You want to replace
that with `git maintenance` to gain the lock-safety and incremental approach.

1. Remove the old cron entry:

```sh
crontab -e
# delete the line that calls git gc
```

2. Register each repository and enable the incremental strategy:

```sh
cd ~/projects/service-a && git maintenance start
cd ~/projects/service-b && git maintenance start
```

3. Confirm all repositories are registered:

```sh
git config --global --get-all maintenance.repo
```

```text
/Users/ops/projects/service-a
/Users/ops/projects/service-b
```

4. Disable the `gc` task explicitly (it is off by default in the incremental
strategy, but make it explicit for documentation purposes):

```sh
git config --global maintenance.gc.enabled false
```

The incremental-repack and loose-objects tasks now handle what `git gc` used
to do, spread across daily runs with no long lock windows.

### Inspecting and adjusting the schedule

You want the commit-graph rebuilt daily instead of hourly on a repository
that receives only a few commits per day.

```sh
git config maintenance.commit-graph.schedule daily
```

On the next hourly scheduler invocation, `git maintenance run --schedule=hourly`
checks whether `commit-graph` is configured for `hourly` — it is not — and
skips it. The nightly daily run picks it up instead.

To see the full current schedule for the repository:

```sh
git config --list | grep 'maintenance\.'
```

## Recovery

**If `git maintenance run` hangs or leaves a stale lock**, check for a lock
file in the object directory:

```sh
ls .git/objects/pack/*.lock
```

If no `git` process is running against this repository, remove the stale lock
manually:

```sh
rm .git/objects/pack/*.lock
```

**If the commit-graph becomes corrupt**, delete it and let the next maintenance
run rebuild it:

```sh
rm -rf .git/objects/info/commit-graphs/
git maintenance run --task=commit-graph
```

**If background maintenance stops firing on macOS**, re-register the launch
agents:

```sh
git maintenance stop
git maintenance start
```

**If you accidentally unregistered a repository**, add it back without
restarting the full scheduler:

```sh
git maintenance register
```

See *Getting out of jams* for help with object-database corruption and
pack-file recovery.

## See also

- *gc* — full garbage collection; the heavier alternative to incremental
  maintenance.
- *fsck* — verify object integrity; use after suspecting corruption that
  maintenance alone cannot fix.
- *reflog* — understanding what `reflog-expire` removes during maintenance.
- *rerere* — what the `rerere-gc` task cleans up.
- *worktree* — what the `worktree-prune` task removes.
- *fetch* — the underlying command the `prefetch` task drives.
- *Getting out of jams* — recovering from stale locks and object corruption.
