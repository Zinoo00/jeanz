#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/create-property-skill"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/jeanz/typecheck"

command -v npm > /dev/null || { echo "✘ type-check needs npm (Node.js) on PATH"; exit 1; }
mkdir -p "$CACHE"
if ! cmp -s "$ROOT/tools/typecheck/package-lock.json" "$CACHE/package-lock.json" || [ ! -x "$CACHE/node_modules/.bin/tsc" ]; then
  cp "$ROOT/tools/typecheck/package.json" "$ROOT/tools/typecheck/package-lock.json" "$CACHE/"
  if ! installed="$(cd "$CACHE" && npm ci --no-audit --no-fund 2>&1)"; then
    echo "✘ type-check could not install its packages into $CACHE"
    echo "$installed" | tail -15 | sed 's/^/    /'
    exit 1
  fi
fi

cp "$ROOT/tools/typecheck/loose.mjs" "$CACHE/loose.mjs"
if ! loose="$(cd "$ROOT" && node "$CACHE/loose.mjs" skills/create-property-skill/templates/spec/*.ts skills/create-property-skill/fixture/*.ts)"; then
  echo "✘ loose type in a spec file — each line names what switches the type-check off: narrow with a type guard, or annotate the value"
  echo "$loose"
  exit 1
fi

work="$(mktemp -d "$CACHE/work.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/repo/templates" "$work/repo/fixture" "$work/overlay"
cp -R "$SKILL/templates/spec" "$work/repo/templates/spec"
cp "$SKILL"/fixture/*.test.ts "$work/repo/fixture/"
cp -R "$SKILL/templates/spec" "$work/overlay/spec"
cp "$SKILL/fixture/config.ts" "$SKILL/fixture/actions.ts" "$SKILL/fixture/properties.ts" "$work/overlay/spec/"
cp "$ROOT/tools/typecheck/tsconfig.json" "$work/tsconfig.json"

if ! out="$(cd "$work" && "$CACHE/node_modules/.bin/tsc" -p tsconfig.json 2>&1)"; then
  echo "✘ type error in a spec file — fix the type, and do not cast it away"
  echo "$out" | sed -E -e "s#^repo/#skills/create-property-skill/#" -e "s#^overlay/spec/(config|actions|properties)\\.ts#skills/create-property-skill/fixture/\\1.ts#" -e "s#^overlay/spec/#skills/create-property-skill/templates/spec/#" | awk '!seen[$0]++' | sed 's/^/    /'
  exit 1
fi
