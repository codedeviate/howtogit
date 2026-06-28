# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Versions map to [Conventional Commits](https://www.conventionalcommits.org): a
`feat` is a minor bump, a `fix`/`docs`/`build` is a patch, and a `!`/`BREAKING
CHANGE` is a major bump.

## [Unreleased]

## [1.1.0] — 2026-06-28

### Added

- **git troubleshooting:** new "Getting out of jams" entry — *A pull request
  pulls in commits from another branch (stacked-branch trap)*. Explains why
  merging a branch that was accidentally based on another unmerged branch pulls
  in that branch's commits (merge by reachability, not "the commits I added"),
  how to diagnose it with `git log <base>..<branch>` and `gh pr view`/`gh pr
  diff`, the `git rebase --onto` fix, and the merge-order alternative.

## [1.0.0] — 2026-06-21

First edition — two in-depth, best-practices reference books for **git** and
**gh**, authored in Markdown and built to PDF with
[recon](https://github.com/codedeviate/recon).

### Added

- **git book** (356 pages) — every porcelain command across eight parts, each
  chapter following a fixed template (mental model, synopsis, everyday usage,
  key options, best practices, pitfalls, worked examples, recovery), closing
  with a symptom-organized "Getting out of jams" troubleshooting part.
- **gh book** (194 pages) — every `gh` command group across eight parts, with
  its own symptom-organized troubleshooting part.
- **Book-quality PDFs** — A4, page-numbered, with a cover page, a linkable
  table of contents, IBM Plex Sans body text, and shaded monospace code blocks,
  rendered via recon's embedded Typst engine.
- **Build pipeline** — `Makefile` targets (`all`, `git`, `gh`, `lint`, `clean`),
  chapter-assembly and fence-aware lint scripts, and a stub generator.
- **Authoring standard** — `STYLE.md` chapter templates, enforced by `make lint`
  (one H1 per chapter).
- **Accuracy** — every flag, option, subcommand, and example verified against
  the real `git` / `gh --help`; 85 confirmed corrections applied across three
  fix waves before release.

[Unreleased]: https://github.com/codedeviate/howtogit/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/codedeviate/howtogit/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/codedeviate/howtogit/releases/tag/v1.0.0
