#!/usr/bin/env bash
# Enforce: every chapter file in order.txt has exactly one H1 (`# `) line.
# H1s are counted only OUTSIDE fenced code blocks, so shell comments like
# `# do the thing` inside ```sh examples are not mistaken for headings.
# The cover (00-cover.md) is exempt: it is a styled title page with no heading,
# kept out of the table of contents by design.
set -euo pipefail

BOOK="${1:-}"
[ -n "$BOOK" ] || { echo "usage: $0 <git|gh>" >&2; exit 2; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/book/$BOOK"
ORDER="$SRC_DIR/order.txt"
[ -f "$ORDER" ] || { echo "missing $ORDER" >&2; exit 1; }
fail=0

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|\#*) continue ;; esac
  f="$SRC_DIR/$line"
  [ -f "$f" ] || { echo "MISSING: $f"; fail=1; continue; }
  case "$(basename "$line")" in 00-cover.md) continue ;; esac
  n="$(awk '
    /^[[:space:]]*(```|~~~)/ { infence = !infence; next }
    !infence && /^# /        { count++ }
    END                      { print count + 0 }
  ' "$f")"
  if [ "$n" -ne 1 ]; then
    echo "H1 count $n (want 1): $f"; fail=1
  fi
done < "$ORDER"

[ "$fail" -eq 0 ] && echo "lint OK ($BOOK)"
exit "$fail"
