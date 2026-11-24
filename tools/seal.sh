#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../skills/create-property-skill/templates"
HISTORY=../sealed-history.txt
SEALED=(props.sh summarize.py GUIDE.md $(ls spec/*.ts | grep -vE '^spec/(config|actions|properties)\.ts$'))
sha() { if command -v shasum > /dev/null; then shasum -a 256 "$@"; else sha256sum "$@"; fi; }
now="$(sha "${SEALED[@]}")"
if [ "${1:-}" = "--check" ]; then
  if [ "$now" != "$(cat SEALED.sha256 2> /dev/null)" ] || [ -n "$(grep -vxF -f "$HISTORY" SEALED.sha256)" ]; then
    echo "✘ stale seal — the sealed property templates changed. Run tools/seal.sh"
    exit 1
  fi
else
  echo "$now" > SEALED.sha256
  shipped="$(git show "HEAD:skills/create-property-skill/sealed-history.txt" 2> /dev/null || cat "$HISTORY")"
  printf '%s\n%s\n' "$shipped" "$now" | sort -u > "$HISTORY"
  echo "sealed ${#SEALED[@]} files"
fi
