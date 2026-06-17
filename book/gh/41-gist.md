# gist

Create, view, edit, and manage GitHub Gists — lightweight, shareable snippets
of code or text hosted at gist.github.com.

## Mental model

A Gist is a minimal GitHub repository with exactly one commit history and one
or more files. Unlike a full repository, it has no issues, pull requests, or
branches — it is designed for sharing a self-contained snippet, a config file,
or a quick script.

Every Gist lives at a stable URL and has a 32-character hex ID. That ID (or the
full URL) is how `gh gist` subcommands address a specific gist:

```text
https://gist.github.com/ada-lovelace/5b0e0062eb8e9654adad7bb1d81cc75f
                         └─ owner ──┘ └──────────── ID ───────────────┘
```

Gists are either **secret** (the default) or **public**. Secret means the URL
is unlisted — anyone with the link can still view it. Public means the gist
appears in your profile and in GitHub search results.

Because a gist is a git repository, you can clone it, push local changes back,
and work with it in any git client. `gh gist clone` handles the URL bookkeeping
for you.

## Synopsis

```text
gh gist list    [flags]
gh gist create  [<filename>... | <pattern>... | -] [flags]
gh gist view    [<id> | <url>] [flags]
gh gist edit    {<id> | <url>} [<filename>] [flags]
gh gist rename  {<id> | <url>} <old-filename> <new-filename> [flags]
gh gist clone   <gist> [<directory>] [-- <gitflags>...]
gh gist delete  {<id> | <url>} [flags]
```

A gist argument is accepted as a bare 32-character hex ID or as a full
`https://gist.github.com/OWNER/ID` URL.

## Everyday usage

### Listing your gists

```sh
gh gist list
```

```text
5b0e0062eb8e9654adad7bb1d81cc75f  deploy.sh          1 file   secret  2024-11-03T09:12:00Z
a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4  notes.md           2 files  public  2024-10-18T14:05:00Z
```

Fetch more than the default ten entries:

```sh
gh gist list --limit 50
```

Filter by a regular expression across descriptions and filenames (add
`--include-content` to also search inside file content):

```sh
gh gist list --filter deploy --include-content
```

### Creating a gist

Share a single file publicly:

```sh
gh gist create --public deploy.sh
```

Create a secret gist with a description from multiple files:

```sh
gh gist create -d "advent of code 2024 solutions" day01.py day02.py
```

Pipe command output directly into a new gist and open it in the browser:

```sh
kubectl get pods -A | gh gist create - --filename k8s-pods.txt -w
```

Use a glob pattern:

```sh
gh gist create *.md *.txt
```

### Viewing a gist

```sh
gh gist view 5b0e0062eb8e9654adad7bb1d81cc75f
```

List which files a gist contains without printing their content:

```sh
gh gist view 5b0e0062eb8e9654adad7bb1d81cc75f --files
```

Show a single file from a multi-file gist in raw form:

```sh
gh gist view 5b0e0062eb8e9654adad7bb1d81cc75f --filename deploy.sh --raw
```

Open a gist in the browser:

```sh
gh gist view 5b0e0062eb8e9654adad7bb1d81cc75f --web
```

### Editing a gist

Open the gist in your `$EDITOR` interactively (prompts when no ID is given):

```sh
gh gist edit
```

Edit a specific file in an existing gist:

```sh
gh gist edit 5b0e0062eb8e9654adad7bb1d81cc75f --filename deploy.sh
```

Replace a gist file with the content of a local file (pass the local file as a
positional argument after the ID):

```sh
gh gist edit 5b0e0062eb8e9654adad7bb1d81cc75f --filename deploy.sh deploy.sh
```

Add a new file to an existing gist:

```sh
gh gist edit 5b0e0062eb8e9654adad7bb1d81cc75f --add README.md
```

Remove a file from a gist:

```sh
gh gist edit 5b0e0062eb8e9654adad7bb1d81cc75f --remove old-file.py
```

Change the gist description:

```sh
gh gist edit 5b0e0062eb8e9654adad7bb1d81cc75f --desc "Updated deploy script"
```

### Renaming a file inside a gist

```sh
gh gist rename 5b0e0062eb8e9654adad7bb1d81cc75f deploy.sh deploy-prod.sh
```

### Cloning a gist locally

```sh
gh gist clone 5b0e0062eb8e9654adad7bb1d81cc75f
```

Clone into a specific directory:

```sh
gh gist clone 5b0e0062eb8e9654adad7bb1d81cc75f ~/scripts/deploy
```

Pass extra git flags after `--`:

```sh
gh gist clone 5b0e0062eb8e9654adad7bb1d81cc75f -- --depth 1
```

### Deleting a gist

Interactive (prompts for selection and confirmation):

```sh
gh gist delete
```

Non-interactive, skip the confirmation prompt:

```sh
gh gist delete 5b0e0062eb8e9654adad7bb1d81cc75f --yes
```

## Key options

### create

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-d` / `--desc` | Set a description | Always — makes `list` output useful |
| `-p` / `--public` | List the gist publicly (default is secret) | Sharing broadly; note it appears in search |
| `-f` / `--filename` | Override the filename when reading from stdin | stdin input has no natural filename |
| `-w` / `--web` | Open the created gist in a browser | Immediately share or copy the URL |

### list

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-L` / `--limit` | Maximum number of gists to fetch (default 10) | When you have more than ten gists |
| `--public` | Show only public gists | Auditing what you have made discoverable |
| `--secret` | Show only secret gists | Finding unlisted gists |
| `--filter` | Filter by regex on description and filenames (content requires `--include-content`) | Searching across many gists |
| `--include-content` | Include file content in regex filtering | Needed when the search term is inside a file |

### view

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-f` / `--filename` | Show only one file from a multi-file gist | Focused reading |
| `--files` | List filenames only, no content | Seeing what files a gist contains |
| `-r` / `--raw` | Print raw content instead of rendered markdown | Piping output to other tools |
| `-w` / `--web` | Open in browser | Sharing or copying the URL |

### edit

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `-f` / `--filename` | Select which file to edit | Multi-file gists |
| `-d` / `--desc` | Change the gist description | After repurposing a gist |
| `-a` / `--add` | Add a new file to the gist | Growing a multi-file gist |
| `-r` / `--remove` | Remove a file from the gist | Cleaning up old files |

### delete

| Flag | What it does | When to use it |
|------|--------------|----------------|
| `--yes` | Skip the confirmation prompt | Scripting or batch deletion |

## Best practices

**Always supply `--desc`.** The `gh gist list` table shows descriptions
alongside IDs. A gist without a description shows a blank field, making it
nearly impossible to find later among a list of hex IDs.

**Default to secret; promote to public deliberately.** GitHub offers no
unpublish mechanism — once a gist is public, you cannot make it secret again
short of deleting and recreating it. Start secret while drafting and create a
new public gist when the content is ready to share.

**Set a meaningful filename when piping stdin.** GitHub renders syntax
highlighting based on file extension. Without `--filename`, the file is stored
as `gistfile1.txt` and gets no highlighting:

```sh
# Good: syntax highlighting, meaningful name in the list
git log --oneline | gh gist create - --filename recent-commits.txt
```

**Clone for sustained editing.** When you need to make multiple edits over
time, `gh gist clone` gives you a local working copy with full git history.
Edit locally, then `git push` to sync changes back:

```sh
gh gist clone 5b0e0062eb8e9654adad7bb1d81cc75f ~/gists/deploy
# edit files...
git add -A && git commit -m "Fix region variable" && git push
```

**Use `--include-content` sparingly.** Fetching file content for every gist
is significantly slower and consumes more API rate-limit quota than the default
metadata-only listing. Use it when you genuinely need to search inside files,
not as a routine default.

**Script deletions with `--yes` cautiously.** There is no recycle bin.
Deleting a gist is permanent. Review the list output before piping it into
a delete command.

## Pitfalls & gotchas

**Secret gists are not private — they are unlisted.** Anyone who has the URL
can view a secret gist without authentication. Do not store credentials, API
keys, or other sensitive data in any gist, secret or public.

**You cannot make a public gist secret after creation.** GitHub does not
expose an endpoint for this. Your only option is to delete the original and
create a new secret gist with the same content. Forks and embeds of the
original persist on GitHub; you cannot fully retract a public gist once it
has been visible.

**`gh gist edit` without an ID opens `$EDITOR` interactively.** If `$EDITOR`
is not set or the terminal is non-interactive, the command may behave
unexpectedly. Set `EDITOR` (or `VISUAL`) in your shell profile before relying
on this flow.

**Glob patterns expand on the client side.** The shell expands `*.py` before
`gh` sees the arguments. On a system where no `.py` files exist in the current
directory, the command errors with "no matches found". Verify your working
directory before using patterns.

**`gh gist list` shows only your own gists.** There is no flag to list another
user's public gists. To inspect someone else's gists, use
`gh api /users/<username>/gists` (see *api*) or visit their GitHub profile.

**Rate limits with `--include-content`.** Each gist's file content is fetched
individually. Scanning a large collection with `--include-content` can quickly
exhaust your API rate-limit quota. Reduce `--limit` or wait for the quota to
reset (typically one hour) if you hit the limit.

## Worked examples

### Capturing a command's output as a shareable snippet

You ran a verbose build and want to share the log with a colleague without
pasting walls of text into chat:

```sh
npm run build 2>&1 | gh gist create - \
  --filename build-log.txt \
  --desc "npm build output 2024-11-05 — failing on chunk size" \
  -w
```

```text
- Creating gist build-log.txt...
✓ Created secret gist build-log.txt
Opening github.com/gist/ada-lovelace/a1b2c3d4... in your browser.
```

The `-w` flag opens the gist immediately so you can copy the URL from the
address bar and paste it into chat.

### Maintaining a living dotfile snippet

You keep a snippet of your `.zshrc` aliases as a public gist so you can
quickly bootstrap new machines.

Initial creation:

```sh
gh gist create --public ~/.zshrc \
  --desc "Personal zsh aliases and functions"
```

Later, after updating your aliases locally, replace the gist file in one
command:

```sh
gh gist edit <ID> --filename .zshrc ~/.zshrc
```

Or clone the gist once and use `git push` from then on:

```sh
gh gist clone <ID> ~/gists/zshrc
cd ~/gists/zshrc
# edit .zshrc here
git add .zshrc && git commit -m "Add git aliases" && git push
```

### Finding a forgotten gist by content

You remember writing a bash retry function but cannot recall which gist it
was in:

```sh
gh gist list --limit 100 --filter retry --include-content
```

```text
5b0e0062eb8e9654adad7bb1d81cc75f  utils.sh
  shell utilities for CI pipelines
      function retry() {
```

Copy the ID from the first column, then view or clone the gist.

### Batch-deleting gists in a script

Delete every secret gist whose description matches a pattern:

```sh
# Review first
gh gist list --secret --limit 200 --filter "temp"

# Then delete after confirming the list looks right
gh gist list --secret --limit 200 --filter "temp" \
  | awk '{print $1}' \
  | xargs -I{} gh gist delete {} --yes
```

Always run the listing step first and read its output before proceeding.

## Recovery

Deleted gists cannot be restored through `gh` or the GitHub web interface.
If the gist was cloned locally, the content is still in that clone's git
history. Retrieve a previous version with:

```sh
cd ~/gists/mygist
git log --oneline
git checkout <hash> -- <filename>
git add <filename> && git commit -m "Restore previous version" && git push
```

If you need the URL to remain stable and want branching or access control,
consider migrating the content to a full repository (see *repo*).

If gist commands fail with permission errors, the `gist` scope may not be
granted on your token. Add it without logging out:

```sh
gh auth refresh --scopes gist
```

See *auth* for the full scope management workflow.

## See also

- *auth* — the `gist` OAuth scope is required; use `gh auth refresh --scopes gist` if gist commands fail with permission errors.
- *repo* — use a full repository instead of a gist when you need branches, issues, pull requests, or fine-grained access control.
- *api* — use `gh api /users/<username>/gists` to list another user's public gists, or `/gists/public` for the global public feed.
