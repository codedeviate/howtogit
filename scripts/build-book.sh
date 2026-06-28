#!/usr/bin/env bash
# Assemble a book's chapters (per book/<name>/order.txt) into one markdown
# file and render it to PDF with recon (typst engine; A4 + page numbers are
# recon defaults as of 0.101.0). The cover is a typst template, not markdown.
set -euo pipefail

BOOK="${1:-}"
DATE="2026"
case "$BOOK" in
  git)
    TITLE="howtogit — The git Best-Practices Book"
    SUBTITLE="The git Best-Practices Book"
    KEYWORDS="git, version control, best practices, reference"
    ;;
  gh)
    TITLE="howtogit — The GitHub CLI Best-Practices Book"
    SUBTITLE="The GitHub CLI Best-Practices Book"
    KEYWORDS="gh, github cli, best practices, reference"
    ;;
  *) echo "usage: $0 <git|gh>" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Cover edition tracks the latest git tag (semver, e.g. v1.1.0 -> "Edition 1.1.0"),
# so it never goes stale. Falls back to a dev label outside a tagged checkout.
TAG="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
if [ -n "$TAG" ]; then
  VERSION="Edition ${TAG#v}"
else
  VERSION="Edition (dev build)"
fi

SRC_DIR="$ROOT/book/$BOOK"
ORDER="$SRC_DIR/order.txt"
DIST="$ROOT/dist"
MASTER="$DIST/$BOOK-book.md"
PDF="$DIST/$BOOK.pdf"

[ -f "$ORDER" ] || { echo "missing $ORDER" >&2; exit 1; }
mkdir -p "$DIST"
: > "$MASTER"

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|\#*) continue ;; esac
  f="$SRC_DIR/$line"
  [ -f "$f" ] || { echo "missing chapter: $f" >&2; exit 1; }
  cat "$f" >> "$MASTER"
  printf '\n\n' >> "$MASTER"
done < "$ORDER"

recon --md-to-pdf "$MASTER" \
  --cover-template "$ROOT/assets/cover.typ" \
  --toc --toc-depth 2 --toc-title 'Contents' \
  --gfm --page-break-on-h1 \
  --font 'IBM Plex Sans' \
  --doc-title "$TITLE" \
  --doc-subtitle "$SUBTITLE" \
  --doc-version "$VERSION" \
  --doc-date "$DATE" \
  --doc-author 'Thomas Björk' \
  --doc-keywords "$KEYWORDS" \
  -o "$PDF"

echo "Built $PDF"
