# What git really is

Git is a distributed version control system that records the complete history
of a project as a graph of snapshots. Every contributor has the entire history
on their own machine. Nothing is lost unless you explicitly throw it away.

That single fact — the whole history, everywhere — changes how you work. You
can experiment freely on a branch, travel back in time, and share selective
pieces of work without ever needing a network connection.

## The problem version control solves

Imagine editing a document and saving copies: `report.docx`, `report-v2.docx`,
`report-FINAL.docx`, `report-FINAL-2.docx`. This breaks down immediately when
a second person edits the same file.

Version control replaces the filename-based approach with a database that
tracks every change: who made it, when, and why. You can inspect any past
state, compare two versions, merge concurrent edits, and revert a mistake.

Git goes further than older centralised systems (CVS, Subversion) by giving
each contributor a full copy of the database. There is no single server you
depend on; collaboration happens by exchanging change sets between peers.

## The object model

Everything git stores is one of four object types, identified by a SHA-1
(or SHA-256 in newer repositories) hash of its content.

**Blob** — the raw contents of a single file at a single point in time.
No filename, no path, just bytes. Two files with identical content share
one blob.

**Tree** — a directory listing. It maps filenames to blobs and to other
trees (subdirectories). A tree snapshot for the project root describes the
entire file system at a moment in time.

**Commit** — a pointer to one root tree plus metadata: author, committer,
timestamp, and a human-readable message. Crucially, every commit also points
to its parent commit(s). That chain of parents is the project history.

**Ref (reference)** — a human-readable name — `main`, `feature/login`,
`v1.4.0` — that points to a specific commit hash. A tag is a ref that never
moves. A branch is a ref that advances automatically when you make a new commit
on it.

```text
      blob "fn main() {…}"  ←  tree "src/"  ←┐
      blob "README.md"      ←  tree "/"    ←──── commit C3  ←  commit C4  ←  HEAD
                                                  (parent: C3)
```

## The three areas

Understanding where your changes live at any moment is the key to not being
surprised by git.

**Working tree** — the files you can see and edit in your project directory.
Making changes here does not tell git anything.

**Index (staging area)** — a lightweight snapshot that accumulates the changes
you have decided to include in the next commit. `git add` copies changes from
the working tree into the index. Nothing is permanent until you commit.

**Repository (`.git/` directory)** — the object database and history. When you
run `git commit`, git writes the index contents as a new tree object, wraps it
in a commit object, and moves the current branch pointer forward.

Files move through these areas as follows:

```text
 Working tree  ──git add──>  Index  ──git commit──>  Repository
               <──git restore──       <──git restore --staged──
```

## A first walkthrough

The following sequence shows how the three areas interact in practice.

```sh
git init my-project        # create a repository from scratch
cd my-project

echo "Hello, git" > README.md    # file exists only in the working tree

git add README.md          # move it into the index

git commit -m "Initial commit"   # snapshot the index into the repository
```

After the commit, `git log` shows one entry:

```text
commit 9fceb02... (HEAD -> main)
Author: Ada Lovelace <ada@example.com>
Date:   Tue Jun 17 09:00:00 2026 +0200

    Initial commit
```

## What a branch really is

A branch is nothing more than a text file in `.git/refs/heads/` containing
a 40-character commit hash. When you commit, git updates that file to point
to the new commit. That is the entire mechanism.

```sh
cat .git/refs/heads/main
```

```text
9fceb02d...
```

**HEAD** is a special ref that tells git which branch (or commit) is currently
checked out. Normally HEAD contains the name of a branch — it is said to be
"attached". When HEAD contains a raw commit hash instead of a branch name, you
are in "detached HEAD" state (useful for inspecting history, but do not commit
work there without creating a branch first).

Creating a branch is instant and cheap because it only creates a new pointer
to an existing commit — no data is copied.

```sh
git branch feature/login   # create pointer at current HEAD
git switch feature/login   # move HEAD to point at the new branch
```

## Local vs remote

A remote is another copy of the same repository — on a server, a colleague's
machine, or elsewhere. The most common remote is named `origin` by convention.

Git tracks remote branches as read-only snapshots in your local repository
under names like `origin/main`. They update only when you explicitly ask:

```sh
git fetch origin        # download new objects and update remote-tracking branches
git pull                # fetch + merge (or fetch + rebase, depending on config)
git push origin main    # upload local main to origin
```

You always work locally. The network is involved only when you explicitly push
or fetch. This makes most operations instant regardless of connectivity.

## See also

- *Installing and configuring git* — set up your identity before your first commit.
- *commit* — how to write good commit messages and use the staging area well.
- *Getting out of jams* — what to do when history gets tangled.
