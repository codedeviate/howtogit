#!/usr/bin/env bash
# Enforce: every chapter file in order.txt has exactly one H1 (`# `) line.
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
  n="$(grep -c '^# ' "$f" || true)"
  if [ "$n" -ne 1 ]; then
    echo "H1 count $n (want 1): $f"; fail=1
  fi
done < "$ORDER"

[ "$fail" -eq 0 ] && echo "lint OK ($BOOK)"
exit "$fail"
