#!/usr/bin/env bash
# Assemble a book's chapters (per book/<name>/order.txt) into one markdown
# file and render it to PDF with recon.
set -euo pipefail

BOOK="${1:-}"
case "$BOOK" in
  git)
    TITLE="howtogit — The git Best-Practices Book"
    SUBJECT="A comprehensive, opinionated guide to git porcelain commands"
    KEYWORDS="git, version control, best practices, reference"
    ;;
  gh)
    TITLE="howtogit — The GitHub CLI Best-Practices Book"
    SUBJECT="A comprehensive, opinionated guide to the gh command-line tool"
    KEYWORDS="gh, github cli, best practices, reference"
    ;;
  *) echo "usage: $0 <git|gh>" >&2; exit 2 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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
  --toc --toc-depth 2 --toc-title 'Contents' \
  --gfm --unsafe-html --page-break-on-h1 \
  --doc-title "$TITLE" \
  --doc-author 'Thomas Björk' \
  --doc-subject "$SUBJECT" \
  --doc-keywords "$KEYWORDS" \
  -o "$PDF"

echo "Built $PDF"
