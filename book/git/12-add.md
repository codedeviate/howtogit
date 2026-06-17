# add

Copy file contents from the working tree into the index so they are
included in the next commit.

## Mental model

Git tracks three distinct copies of every file: the committed version in
the repository, the staged version in the index, and the version on disk
in your working tree. The index is the crucial middle layer — it is the
exact snapshot that `git commit` will turn into a commit object.

`git add` moves content from the working tree into the index. Until you
run it, your edits exist only on disk and are invisible to the next
commit. You can run `git add` as many times as you like before committing;
each call updates the index to match the current disk state of the
specified paths.

```text
Working tree ──git add──> Index ──git commit──> Repository
     (your edits)          (staged snapshot)      (permanent history)
```

A common mental slip is to think of `git add` as "tell Git to track this
file forever." That is only true for new files. For already-tracked files,
each invocation of `git add` means "record the current content of this
file in the staging area right now." If you edit the file again after
staging it, the new edits are not staged; you must run `git add` again.

## Synopsis

```text
git add [--verbose | -v] [--dry-run | -n] [--force | -f]
        [--interactive | -i] [--patch | -p] [--edit | -e]
        [--all | -A | --update | -u | --no-all]
        [--intent-to-add | -N] [--refresh] [--ignore-errors]
        [--ignore-missing] [--renormalize] [--sparse]
        [--chmod=(+|-)x]
        [--pathspec-from-file=<file> [--pathspec-file-nul]]
        [--] [<pathspec>...]
```

## Everyday usage

Stage a single file:

```sh
git add src/login.js
```

Stage several files at once:

```sh
git add src/login.js tests/login.test.js
```

Stage an entire directory (adds new, modified, and records deletions):

```sh
git add src/
```

Stage every change in the repository — new files, modifications, and
deletions:

```sh
git add -A
```

Stage only modifications and deletions of already-tracked files (skips
new untracked files):

```sh
git add -u
```

Interactively choose which hunks within a file to stage:

```sh
git add -p src/api.js
```

Git presents each changed block and asks: stage this hunk? The most
useful responses are `y` (yes), `n` (no), `s` (split into smaller
hunks), and `q` (quit). See the hunk keys table in the Worked
examples section for the complete list.

Preview what would be staged without actually staging anything:

```sh
git add --dry-run .
git add -n .
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `<pathspec>` | Stage the named files or directories | The everyday case — name what you want staged |
| `-A` / `--all` | Stage all changes: additions, modifications, deletions | Commit everything at once; be deliberate |
| `-u` / `--update` | Stage modifications and deletions of tracked files only | Exclude new untracked files from the stage |
| `--no-all` / `--ignore-removal` | Stage new and modified files, ignore deletions | Legacy-compatibility; rarely needed |
| `-p` / `--patch` | Interactively choose hunks to stage | Commit only part of a file's changes |
| `-i` / `--interactive` | Full interactive mode with a command menu | Explore staged/unstaged state interactively |
| `-e` / `--edit` | Open the diff in an editor; apply what you save | Fine-grained control when `-p` hunks are too coarse |
| `-n` / `--dry-run` | Show what would be added without staging it | Verify glob patterns or check ignore status |
| `-f` / `--force` | Stage files that would normally be ignored | Deliberately commit a file in `.gitignore` |
| `-N` / `--intent-to-add` | Register a path as "will be added" without staging content | Make a new file visible to `git diff` before staging |
| `--chmod=(+\|-)x` | Set or clear the executable bit in the index only | Fix execute permissions without touching the filesystem |
| `--renormalize` | Re-apply line-ending normalization to all tracked files | Fix mixed CRLF/LF after changing `core.autocrlf` |
| `--refresh` | Update cached stat info without changing staged content | Silence false-positive dirty markers without restaging |
| `--ignore-errors` | Continue staging remaining files if some fail | Partially stage a large batch where a few files error |
| `--ignore-missing` | With `--dry-run`, check ignore status for absent files | Test whether a path would be ignored before it exists |
| `--sparse` | Allow staging paths outside the sparse-checkout cone | Advanced sparse-checkout workflows |
| `--pathspec-from-file=<file>` | Read paths from a file instead of the command line | Script-generated file lists; very long path sets |
| `--pathspec-file-nul` | With `--pathspec-from-file`, use NUL as the separator | Safe handling of filenames that contain newlines |

## Best practices

**Stage deliberately, not wholesale.** `git add -A` is convenient but
often stages more than you intended — debug output left in a test file,
a half-finished change to an unrelated module, a build artifact that
slipped past `.gitignore`. Stage specific files or directories by name,
or use `-p` to review hunks. Each commit should represent one logical
unit of work; that discipline starts at `git add`.

**Use `-p` to split mixed edits.** When a file contains two unrelated
changes, `-p` lets you stage only the relevant hunks and leave the rest
for a later commit. Reviewers and future `git bisect` users will thank
you. See the *commit* chapter for how this pairs with `git commit`.

**Re-run `git add` after editing a staged file.** The index holds the
content at the moment you staged, not a live reference. If you edit a
file after staging it, `git status` will show it listed under both
"Changes to be committed" and "Changes not staged for commit." Run
`git add` again to bring the staged version up to date — or stage only
the first set of changes intentionally.

**Confirm what you are about to stage with `--dry-run`.** Before staging
a broad glob like `git add '*.json'`, run `git add -n '*.json'` to see
exactly which files match. This is especially valuable when your shell
might expand the glob differently from Git.

**Understand what `-A` and `-u` do differently.** `-A` updates the entire
index to match the working tree: new files, modifications, and deletions.
`-u` updates only already-tracked paths: modifications and deletions, but
not new untracked files. Neither option is "safer" in the abstract — the
right one depends on your intent.

**Use `-N` to make new files visible before staging them.** `git diff`
only shows tracked content by default, so a brand-new file is invisible
until you stage it. `git add -N path/to/newfile.js` registers the path
without staging any content; now `git diff` shows the full pending
addition so you can review it before committing.

## Pitfalls & gotchas

**`.gitignore` only affects untracked files.** If a file is already
tracked in the repository, adding its pattern to `.gitignore` has no
effect. Git continues to stage and commit changes to it. To stop
tracking a file, use `git rm --cached` first; then add it to
`.gitignore`.

**`git add -A` without a pathspec operates on the entire repository.**
Running `git add -A` from a subdirectory stages changes across the whole
working tree, not just the current directory. This changed from older
versions of Git that scoped it to the current directory. If you want to
limit scope, pass an explicit path: `git add -A src/`.

**Shell glob expansion vs. Git glob expansion differ.** When you write
`git add *.js`, your shell expands the glob before Git sees it — so only
files in the current directory are matched. To let Git expand the glob
recursively, quote it: `git add '*.js'`. The `--dry-run` flag is the
fastest way to verify which form you need.

**Staging a file twice is harmless but the second stage silently wins.**
If you stage a file, edit it, then stage it again, the index holds only
the most recent staged content. There is no warning. If you want to
preserve the first staged version, commit before editing further.

**`--edit` patches the index, not the working tree.** When you modify the
diff in your editor with `git add -e`, the index diverges from both HEAD
and your working tree. `git diff --cached` shows what is staged; `git
diff` shows what is unstaged. The divergence is intentional and powerful
but confusing until you understand it.

**Embedded repositories trigger a warning.** If you run `git add` on a
directory that contains its own `.git` folder (a nested repository not
managed as a submodule), Git warns you and registers only an empty tree.
To add a nested repo properly, use `git submodule add`.

## Worked examples

### Staging only the bug fix from a file with mixed changes

You edited `api.js` in two places: a one-line bug fix and a larger
refactor. You want separate, focused commits.

```sh
git add -p api.js
```

Git presents each hunk:

```text
@@ -42,7 +42,7 @@ function parseToken(token) {
-  if (token == null) return false;
+  if (token == null) throw new Error('token required');
...
Stage this hunk [y,n,q,a,d,g,/,j,J,k,K,s,e,p,?]?
```

Hunk keys:

| Key | Action |
|-----|--------|
| `y` | Stage this hunk |
| `n` | Do not stage this hunk |
| `q` | Quit; do not stage this hunk or any of the remaining ones |
| `a` | Stage this hunk and all later hunks in the file |
| `d` | Do not stage this hunk or any of the later hunks in the file |
| `g` | Select a hunk to go to |
| `/` | Search for a hunk matching the given regex |
| `j` | Leave this hunk undecided, see next undecided hunk |
| `J` | Leave this hunk undecided, see next hunk |
| `k` | Leave this hunk undecided, see previous undecided hunk |
| `K` | Leave this hunk undecided, see previous hunk |
| `s` | Split the current hunk into smaller hunks |
| `e` | Manually edit the current hunk |
| `p` | Print the current hunk |
| `?` | Print help |

Stage the bug-fix hunk (`y`) and skip the refactor hunk (`n`). Then
commit just the fix:

```sh
git commit -m "Throw on null token instead of silently returning false"
```

Go back and stage the refactor:

```sh
git add api.js
git commit -m "Extract token validation into parseToken helper"
```

### Staging all changes then reviewing before committing

You have been working across several files and want to commit everything,
but you want to double-check what is staged first.

```sh
git add -A
git diff --cached       # review the full staged diff
git status              # confirm staged vs. unstaged summary
git commit -m "Implement user profile page"
```

If you spot something you do not want in this commit, unstage it:

```sh
git restore --staged src/debug-helpers.js
```

Then commit the rest and stage the debug file separately when it is
ready.

### Fixing execute permissions in the index

A deployment script `deploy.sh` needs to be executable, but the
filesystem bit was not set when it was committed. Fix it in the index
without touching the file on disk:

```sh
git add --chmod=+x deploy.sh
git commit -m "Mark deploy.sh as executable"
```

Verify the change took effect:

```sh
git ls-files --stage deploy.sh
```

The mode field in the output should read `100755` (executable) instead
of `100644`.

### Staging files listed by a script

A code-generation step produces a list of changed files. Pass them to
`git add` without hitting shell argument-length limits:

```sh
./generate.sh | git add --pathspec-from-file=- --pathspec-file-nul
```

The `--pathspec-file-nul` flag tells Git to split on NUL bytes, which is
safe for filenames containing spaces or special characters.

## Recovery

To unstage a file that you added by mistake (put it back to "not staged
for commit" while keeping your working-tree edits):

```sh
git restore --staged path/to/file.js
```

To unstage everything at once:

```sh
git restore --staged .
```

If you want to discard both the staged version and the working-tree
edits entirely, see the *restore* chapter and the *reset* chapter.

See *Getting out of jams* for recipes covering accidentally staged
secrets, staged deletions you did not intend, and recovering from a
`git add -A` that swept up files you wanted to keep unstaged.

## See also

- *commit* — freezes the staged index into a permanent commit object.
- *status* — shows which files are staged, unstaged, or untracked.
- *diff* — use `git diff --cached` to review exactly what is staged.
- *restore* — unstage files with `git restore --staged`.
- *reset* — `git reset HEAD <file>` is an older equivalent of `git restore --staged`.
- *Getting out of jams* — recovering from accidental stages and other index mishaps.
