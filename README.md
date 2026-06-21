<h1 align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/howtogit-title-dark.svg">
    <img alt="howtogit — $ how to git" src="assets/howtogit-title.svg" width="440">
  </picture>
</h1>

<p align="center">
  Two in-depth, best-practices reference books for <strong>git</strong> and <strong>gh</strong> —
  authored in Markdown, built to polished PDFs with <a href="https://github.com/codedeviate/recon">recon</a>.
</p>

Every porcelain git command and every `gh` command group gets its own deep
chapter: the mental model first, then everyday usage, the options that matter,
best practices, the pitfalls that bite people, worked examples, and how to
recover when things go wrong. Each book closes with a symptom-organized
**"Getting out of jams"** troubleshooting chapter. Written for a mixed
audience — beginner-friendly intros, practitioner-level depth per command.

## Highlights

- 📚 **Two book-length references** — a **356-page** git book (50+ commands) and
  a **194-page** gh book (25+ command groups).
- ✅ **Accuracy-checked** — every flag and option was verified against the real
  `git` / `gh --help`, not written from memory.
- 🎯 **Consistent structure** — every chapter follows the same template
  (see [`STYLE.md`](STYLE.md)), so the books are easy to navigate.
- 🖨️ **Book-quality PDFs** — A4, page-numbered, with a cover page and a linkable
  table of contents; sans-serif body text with monospaced, shaded code blocks.
- 📦 **Prebuilt and ready** — download the rendered PDFs from the latest
  [release](https://github.com/codedeviate/howtogit/releases/latest), or rebuild
  from source with a single `make`.

## Read the books

Download the latest PDFs — no build required (these links always resolve to the
newest [release](https://github.com/codedeviate/howtogit/releases/latest)):

- **[git.pdf](https://github.com/codedeviate/howtogit/releases/latest/download/git.pdf)** — the git book (356 pp)
- **[gh.pdf](https://github.com/codedeviate/howtogit/releases/latest/download/gh.pdf)** — the gh book (194 pp)

## What's inside

### Git book

Distributed version control, end to end, in eight parts:

- **Part I**: Intro & Setup — What git is and how to install it
- **Part II**: Creating & snapshotting — `init`, `clone`, `add`, `status`, `diff`, `commit`, `restore`, `reset`, `rm`, `mv`, `clean`, `stash`
- **Part III**: Branching, merging, history rewriting — `branch`, `checkout`, `switch`, `merge`, `mergetool`, `rebase`, `cherry-pick`, `revert`, `tag`, `bisect`, `rerere`
- **Part IV**: Inspecting & comparing — `log`, `show`, `blame`, `shortlog`, `describe`, `reflog`, `grep`, `range-diff`
- **Part V**: Sharing & remotes — `remote`, `fetch`, `pull`, `push`, `submodule`, `worktree`
- **Part VI**: Patching & email workflow — `apply`, `am`, `format-patch`, `send-email`, `request-pull`
- **Part VII**: Administration — `gc`, `fsck`, `maintenance`, `archive`, `bundle`, `notes`, `sparse-checkout`, `replace`, `filter-branch`, `hooks`
- **Part VIII**: Troubleshooting — Getting out of jams (organized by symptom, not command)

### GitHub CLI (gh) book

GitHub from the command line, in eight parts:

- **Part I**: Intro & Auth — What gh is and how to authenticate
- **Part II**: Repositories & code — `repo`, `browse`, `search`
- **Part III**: Collaboration — `pr`, `issue`, `label`, `project`
- **Part IV**: CI/CD & automation — `run`, `workflow`, `cache`
- **Part V**: Releases & artifacts — `release`, `gist`, `attestation`
- **Part VI**: Configuration & secrets — `secret`, `variable`, `ruleset`, `ssh-key`, `gpg-key`, `org`
- **Part VII**: Extending gh & scripting — `api`, `extension`, `status`, `completion`
- **Part VIII**: Troubleshooting — Getting out of jams (organized by symptom, not command)

## Building from source

Only one tool is needed: **[recon](https://github.com/codedeviate/recon) 0.102.0
or newer**. Its embedded [Typst](https://typst.app/) engine renders the books
(A4, page numbers, cover page, table of contents, the `IBM Plex Sans` body font,
and shaded code blocks). No browser or other dependencies.

```sh
make all       # Build both git.pdf and gh.pdf → dist/
make git       # Build only the git book
make gh        # Build only the gh book
make lint      # Check chapter structure (one H1 per chapter)
make clean     # Remove the dist/ directory
```

## Editing the source

- Chapters live in `book/git/` and `book/gh/`, one Markdown file per command.
- `book/<book>/order.txt` defines the chapter order and the part structure.
- The cover page is a Typst template, [`assets/cover.typ`](assets/cover.typ) — not a chapter.
- Authoring rules are in [`STYLE.md`](STYLE.md) (mandatory for all chapters):
  - One H1 per chapter (the title); sections are `##` / `###`.
  - Command chapters follow a fixed section order: Mental model, Synopsis,
    Everyday usage, Key options, Best practices, Pitfalls & gotchas, Worked
    examples, Recovery, See also.
  - Troubleshooting chapters are organized by symptom, not by command.
  - No invented flags — every option is verified against `--help`.

## Versioning & commits

Releases follow [Semantic Versioning](https://semver.org) — `vMAJOR.MINOR.PATCH`
— and each release attaches the rendered `git.pdf` and `gh.pdf` as assets.

Commits follow [Conventional Commits](https://www.conventionalcommits.org):

| Type | Used for | Bump |
|------|----------|------|
| `feat` | a new chapter or capability | minor |
| `fix` | content corrections, broken commands or examples | patch |
| `docs` | README and other meta documentation | patch |
| `build` | build scripts, Makefile, cover template | patch |
| `style` | presentation/formatting only (no content change) | — |
| `chore` | housekeeping | — |

A `!` after the type or a `BREAKING CHANGE:` footer marks a major bump (e.g. a
restructured book or a breaking change to the build).

## Repository layout

```
howtogit/
├── README.md                 # This file
├── LICENSE                   # MIT License
├── Makefile                  # Build targets (all, git, gh, lint, clean)
├── STYLE.md                  # Writing standards & chapter templates
├── assets/                   # Cover template + reusable brand assets
│   ├── cover.typ             # Typst cover page (recon --cover-template)
│   ├── howtogit-title.svg    # "$ how to git" title lockup (outlined; + -dark, .png, .src)
│   └── README.md             # How to use / regenerate the title assets
├── book/                     # Source chapters
│   ├── git/                  # order.txt + 01-intro-*, NN-<command>, 90-troubleshooting
│   └── gh/                   # order.txt + 01-intro-*, NN-<group>, 90-troubleshooting
├── scripts/
│   ├── build-book.sh         # Assemble a book's chapters and render the PDF via recon
│   ├── lint-chapters.sh      # Enforce one H1 per chapter (fence-aware)
│   └── make-stubs.sh         # Create buildable stubs for any unwritten chapters
└── dist/                     # Build output (gitignored; PDFs published as release assets)
```

## License

MIT — see [`LICENSE`](LICENSE) for details.
