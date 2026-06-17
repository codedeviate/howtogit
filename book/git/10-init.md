# init

Create an empty Git repository in the current directory, or reinitialize an
existing one.

## Mental model

When you run `git init`, Git creates a single hidden directory named `.git`
at the root of your project. That directory is the entire repository: it
holds the object database (every version of every file you will ever commit),
the ref store (branches and tags), configuration, and hooks. The working
tree — the files you actually edit — lives beside `.git` and is separate from
it.

```text
my-project/
├── .git/           ← the repository (object DB, refs, config, hooks)
│   ├── objects/
│   ├── refs/
│   │   ├── heads/
│   │   └── tags/
│   ├── HEAD
│   └── config
├── src/            ← your working tree
└── README.md
```

Nothing is tracked yet after `git init`. Git knows the directory exists but
has made no commits and recorded no files. The repository is a blank slate
waiting for `git add` and `git commit`.

Running `git init` in a directory that already has a `.git` folder is safe:
it does not overwrite existing objects, branches, or config. Its main use
in that case is to apply a new template or relocate the git directory with
`--separate-git-dir`.

## Synopsis

```text
git init [-q | --quiet] [--bare]
         [--template=<template-directory>]
         [--separate-git-dir <git-dir>]
         [--object-format=<format>]
         [--ref-format=<format>]
         [-b <branch-name> | --initial-branch=<branch-name>]
         [--shared[=<permissions>]]
         [<directory>]
```

## Everyday usage

Initialize a repository in the current directory:

```sh
git init
```

```text
Initialized empty Git repository in /home/alice/my-project/.git/
```

Initialize and name the initial branch `main` instead of the system default:

```sh
git init -b main
```

Initialize a new repository in a subdirectory that does not yet exist (Git
creates it):

```sh
git init my-project
cd my-project
```

After any of the above, the typical next steps are:

```sh
git add .
git commit -m "Initial commit"
```

## Key options

| Option | What it does | When to use it |
|--------|--------------|----------------|
| `-b <name>` / `--initial-branch=<name>` | Sets the name of the first branch | Use `main` when team or host convention requires it |
| `--bare` | Creates a repository with no working tree | Central/server repos that only receive pushes |
| `--template=<dir>` | Copies files from `<dir>` into `.git` after creation | Distribute standard hooks or config to new repos |
| `--separate-git-dir=<git-dir>` | Stores the `.git` data at `<git-dir>` and leaves a pointer file in the working tree | Keep repo data on a different filesystem or hide it from tools that scan for `.git` |
| `--shared[=<permissions>]` | Sets group-writable permissions on `.git` contents | Shared bare repos on a multi-user server |
| `--object-format=<format>` | Chooses the hash algorithm: `sha1` (default) or `sha256` | Future-proofing; SHA-256 repos are not yet interoperable with SHA-1 repos |
| `--ref-format=<format>` | Chooses ref storage: `files` (default) or `reftable` | Experimental; `reftable` is faster for repos with millions of refs |
| `-q` / `--quiet` | Suppresses all output except errors and warnings | Scripts and automation |

## Best practices

**Set `init.defaultBranch` once in your global config rather than typing
`-b` every time.** Agree on a name with your team (`main` is the current
convention on GitHub and GitLab) and record it once:

```sh
git config --global init.defaultBranch main
```

Every subsequent `git init` will use that name automatically.

**Add a `.gitignore` before your first commit.** The first commit is the
hardest to rewrite cleanly. A well-considered `.gitignore` prevents build
artifacts, secrets, and editor metadata from entering the object database
at all. Add it as part of the initial commit:

```sh
git init -b main
echo "node_modules/" >> .gitignore
git add .gitignore
git commit -m "Initial commit"
```

**Use `--bare` only for server-side repositories.** A bare repository has no
working tree and cannot be used for day-to-day development. It exists solely
to be the target of `git push` and `git fetch`. If you are setting up a
shared repo on a server or NAS, `--bare` is correct. If you are starting a
project on your laptop, it is not.

**Distribute team hooks via `--template`.** If your project requires a
commit-msg linter or a pre-commit formatter, bake those hook scripts into a
template directory and document that developers should run:

```sh
git init --template=/path/to/company-template
```

This ensures every fresh init picks up the same hooks without a separate
installation step. You can also set `init.templateDir` in your global config
so the template applies automatically.

## Pitfalls & gotchas

**Forgetting `-b main` when `init.defaultBranch` is not configured.**
Many platforms and teams default to `main`, but Git's own built-in default is
still `master`. If your remote already has a `main` branch, the local
`master` branch will not track it automatically. Set `init.defaultBranch` in
your global config once and avoid this mismatch entirely.

**Nesting a repository inside another repository.** Running `git init` inside
a directory that is already tracked by a parent repository creates a
submodule-like situation — except without the submodule plumbing. The inner
`.git` confuses `git add`, `git status`, and most GUI tools. If you meant to
add a dependency as a submodule, use `git submodule add` instead. If you did
it by accident, delete the inner `.git` directory before staging anything.

**Running `git init` in the home directory.** Running `git init` while `cd`-d
to `~` makes your entire home directory a repository. Every file you own
becomes potentially trackable, and `git add .` could stage credentials,
private keys, or browser profiles. Always confirm your current directory
before running `git init`.

**SHA-256 repositories cannot exchange objects with SHA-1 repositories.**
`--object-format=sha256` is forward-looking. There is currently no
interoperability between SHA-256 and SHA-1 repositories. Do not use SHA-256
for a repo that needs to interact with GitHub, GitLab, or any SHA-1 remote
until interoperability is officially supported.

**`--shared` does not encrypt or authenticate.** It adjusts Unix file
permissions only. Anyone with filesystem access to the bare repository can
read the full history. Use it on trusted servers behind proper access control,
not as a substitute for it.

## Worked examples

### Starting a new project from scratch

```sh
mkdir payment-service
cd payment-service
git init -b main
```

```text
Initialized empty Git repository in /home/alice/payment-service/.git/
```

Create a `.gitignore`, add files, and make the first commit:

```sh
echo "node_modules/" >> .gitignore
echo "*.log"         >> .gitignore
git add .gitignore
git commit -m "Add .gitignore"
```

Add the remote and push:

```sh
git remote add origin git@github.com:alice/payment-service.git
git push -u origin main
```

### Turning an existing directory into a repository

You have a directory full of scripts that you have been editing without
version control. Convert it to a Git repository without losing anything:

```sh
cd /opt/scripts
git init -b main
```

Exclude files you do not want to track before staging anything:

```sh
echo "*.tmp" >> .gitignore
echo ".env"  >> .gitignore
git add .gitignore
git add .
git status     # verify nothing unexpected is staged
git commit -m "Initial commit: import existing scripts"
```

All existing files are now in history. Future edits will be tracked
incrementally.

### Setting up a bare repository as a push target

On a shared server where several developers push code:

```sh
# on the server
mkdir /srv/git/widgets.git
cd /srv/git/widgets.git
git init --bare --shared=group
```

`--shared=group` makes all files under `.git` group-writable so every member
of the Unix group can push. On each developer's machine:

```sh
git remote add origin git@server.example.com:/srv/git/widgets.git
git push -u origin main
```

Because the server-side repository is bare, developers never work in it
directly — they only push to and fetch from it.

## Recovery

If you ran `git init` in the wrong directory and have not yet committed
anything, delete the `.git` directory to undo it entirely:

```sh
rm -rf .git
```

There are no commits to lose, so this is safe. If you have already made
commits and want to abandon the repository, the same command applies — but
any committed history will be gone permanently.

To move the `.git` directory to a different path after initialization, run
`git init --separate-git-dir=<new-path>` in the same working tree; Git will
relocate the repository and leave a filesystem pointer in place.

See *Getting out of jams* for undoing commits made after initialization.

## See also

- *add* — staging files before the first commit.
- *commit* — recording the staged snapshot into history.
- *clone* — an alternative to `git init` when copying an existing repository.
- *remote* — connecting a local repository to a remote after `git init`.
- *Getting out of jams* — recovering from mistakes made early in a
  repository's life.
