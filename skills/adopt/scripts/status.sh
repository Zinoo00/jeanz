#!/bin/bash
set -euo pipefail

REPO="${1:-}"
APP="${2:-}"
[ -n "$REPO" ] && [ -d "$REPO" ] || { echo "usage: status.sh <repo> [app]" >&2; exit 64; }
REPO="$(cd "$REPO" && pwd)"
TEMPLATES="$(cd "$(dirname "$0")/../../create-property-skill/templates" && pwd)"
SHIPPED="$TEMPLATES/../sealed-history.txt"
behind=""

sha() { if command -v shasum > /dev/null; then shasum -a 256 "$@"; else sha256sum "$@"; fi; }

found() {
  local kind="$1" d
  for d in "$REPO"/.claude/skills/"$kind"-*/ ${APP:+"$HOME/.claude/skills/$kind-$APP/"}; do
    [ -s "$d/SKILL.md" ] && echo "${d%/}"
  done
  return 0
}

line() { printf '%-24s %s\n' "$1" "$2"; }

has_rule_table() {
  awk '
    tolower($0) ~ /^\|.*enforce/ { head = NR; next }
    head && NR == head + 1 && /^\|[-: |]+\|[[:space:]]*$/ { rule = NR; next }
    rule && NR == rule + 1 && /^\|.*[^-|[:space:]]/ { rows = 1 }
    END { exit rows ? 0 : 1 }
  ' "$1"
}

sealed_files() {
  local files held=""
  files="$(cd "$1" && { ls props.sh summarize.py GUIDE.md spec/*.ts 2> /dev/null || true; } | grep -vE '^spec/(config|actions|properties)\.ts$' || true)"
  [ -z "$files" ] || held="$(cd "$1" && sha $files | sort)"
  if [ "$held" = "$(sort "$TEMPLATES/SEALED.sha256")" ]; then
    echo current
  elif [ -z "$(grep -vxF -f "$SHIPPED" <<< "$held")" ]; then
    echo "behind jeanz"
  else
    echo edited
  fi
}

last_run() {
  local skill="$1" root name code
  root="$(set +eu; HERE="$(cd "$skill" && pwd -P)"; source "$skill/props.config.sh" > /dev/null 2>&1; printf '%s' "${OUT_ROOT:-}")" || true
  name="$({ ls "$root" 2> /dev/null || true; } | sed -n 's/\.exit$//p' | LC_ALL=C sort | tail -1)"
  [ -n "$name" ] || { echo "no run on record: props.sh run"; return 0; }
  code="$(cat "$root/$name.exit")"
  if [ -z "$code" ]; then
    echo "newest run $name has no result: it was stopped, or it is still running"
  elif [ "$code" != 0 ]; then
    echo "newest run $name exited $code"
  elif [ -n "$(find "$skill/spec" "$skill/props.sh" "$skill/props.config.sh" -type f -newer "$root/$name.exit" 2> /dev/null)" ]; then
    echo "newest run $name is older than the skill's files"
  else
    echo "newest run $name passed"
  fi
}

table=""
for f in "$REPO/CLAUDE.md" "$REPO/.claude/CLAUDE.md" "$REPO/AGENTS.md"; do
  if [ -z "$table" ] && [ -f "$f" ] && has_rule_table "$f"; then table="${f#"$REPO"/}"; fi
done
if [ -n "$table" ]; then
  line "1 checks in code" "rule table in $table"
else
  line "1 checks in code" "no rule table: /jeanz:correct"
  behind="$behind 1"
fi

verify="$(found verify)"
mapped=""
if [ -z "$verify" ]; then
  line "2 runtime verification" "none: /jeanz:create-verification-skill"
else
  while IFS= read -r d; do
    count="$({ find "$d/features" -name '*.md' ! -name README.md -size +0 2> /dev/null || true; } | wc -l | tr -d ' ')"
    if [ ! -s "$d/features/README.md" ]; then
      line "2 runtime verification" "$d (no feature map)"
      mapped=no
    elif [ "$count" -eq 0 ]; then
      line "2 runtime verification" "$d (no feature mapped)"
      mapped=no
    else
      line "2 runtime verification" "$d (features mapped: $count)"
    fi
  done <<< "$verify"
fi
[ -n "$verify" ] && [ -z "$mapped" ] || behind="$behind 2"

properties="$(found properties)"
proven=yes
if [ -z "$properties" ]; then
  line "3 property checks" "none: /jeanz:create-property-skill (web UIs only)"
else
  while IFS= read -r d; do
    state="$(sealed_files "$d")"
    if [ "$state" = current ]; then
      state="sealed files current, $(last_run "$d")"
    else
      state="sealed files $state: /jeanz:maintain-property-skill"
    fi
    line "3 property checks" "$d ($state)"
    case "$state" in *" passed") ;; *) proven="" ;; esac
  done <<< "$properties"
fi
[ -n "$properties" ] && [ -n "$proven" ] || behind="$behind 3"

if [ -z "$behind" ]; then
  line "5 automation" "ready: layers 1 to 3 hold"
elif [ "$behind" = " 3" ] && [ -z "$properties" ]; then
  line "5 automation" "ready only if the project has no web UI: layer 3 is missing"
else
  line "5 automation" "not yet: layers$behind need work first"
fi
