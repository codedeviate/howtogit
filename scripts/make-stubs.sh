#!/usr/bin/env bash
# Create a buildable stub for every chapter listed in order.txt that does
# not yet exist. A stub is valid single-H1 markdown so the book always builds.
set -euo pipefail

BOOK="${1:-}"
[ -n "$BOOK" ] || { echo "usage: $0 <git|gh>" >&2; exit 2; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/book/$BOOK"
ORDER="$SRC_DIR/order.txt"
[ -f "$ORDER" ] || { echo "missing $ORDER" >&2; exit 1; }

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|\#*) continue ;; esac
  f="$SRC_DIR/$line"
  [ -e "$f" ] && continue
  # Derive a human title from the filename: 35-rebase.md -> "rebase"
  base="$(basename "$line" .md)"
  title="${base#*-}"
  printf '# %s\n\n_Chapter pending._\n' "$title" > "$f"
  echo "stub: $f"
done < "$ORDER"
