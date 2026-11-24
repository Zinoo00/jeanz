#!/bin/bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
MODE="${1:-all}"

EXEMPT='^\./(LICENSE|UPSTREAM\.md|docs/claude-code-port\.md|tools/(check\.sh|check\.test\.sh|check-allow\.txt|names\.txt|terms\.txt|prose\.py|antigravity\.sh|antigravity/rules\.md)|skills/poteto-mode/scripts/watch-pr/[^/]*\.ts)$'
TEXT=$(find . -type f -not -path './.git/*' -not -path '*/corpus/*' | sort)
FILES=$(echo "$TEXT" | grep -vE "$EXEMPT")
TPL=skills/create-property-skill/templates
TESTS=(tools/typecheck.sh skills/create-property-skill/fixture/props.test.sh skills/adopt/scripts/status.test.sh tools/hooks.test.sh tools/check.test.sh)
allowed() { python3 -I tools/allow.py filter; }

fail=0
report() {
  [ -z "${CHECK_NAMES:-}" ] || echo "$1" >> "$CHECK_NAMES"
  [ -n "$3" ] || return 0
  echo "✘ $1 — $2"
  echo "$3" | sed 's/^ */    /' | cut -c1-200
  fail=1
}
rule() {
  report "$1" "$3" "$(echo "$FILES" | tr '\n' '\0' | xargs -0 grep -nIE "$2" 2>/dev/null | allowed)"
}

entries() { grep -vE '^(#|=|[[:space:]]*$)' tools/names.txt; }
while IFS=$'\t' read -r name fix; do
  rule "$name" "$(entries | awk -F'\t' -v rule="$name" '$1 == rule { printf "%s%s", sep, $2; sep = "|" }')" "$fix"
done < <(sed -n 's/^= //p' tools/names.txt)
report "name pattern with no rule, or one that misses its own example" "write it as a rule that a = line names, a tab, a pattern, a tab, and an example that the pattern catches" "$(
  entries | while IFS=$'\t' read -r name pattern example; do
    grep -qF "= $name"$'\t' tools/names.txt && [ -n "$example" ] && printf '%s\n' "$example" | grep -qE -- "$pattern" || printf 'tools/names.txt: %s\n' "$pattern"
  done
)"

known="$(ls skills; ls agents | sed 's/\.md$//')"
report "unknown skill name" "jeanz:<name> names a folder in skills/ or a file in agents/" "$(
  echo "$FILES" | tr '\n' '\0' | xargs -0 grep -noIE 'jeanz:[A-Za-z0-9_-]+[<*]?' 2>/dev/null | grep -v -- '[<*]$' | while IFS= read -r hit; do
    grep -qxF -- "${hit##*jeanz:}" <<< "$known" || echo "$hit"
  done
)"

facts=""
ships_as() {
  facts="$facts$(diff - "$TPL/$1" | sed -nE "s#^> (.*)#$TPL/$1: a line that the empty file does not have: \1#p; s#^< (.*)#$TPL/$1: a line of the empty file that is gone: \1#p")"$'\n'
}
ships_as props.config.sh <<'EMPTY'
ORIGIN=""
READY_URL=""
READY_TEXT=""
DISPOSABLE=""
DISPOSABLE_HOSTS=()
WIDTH=1280
HEIGHT=800
LOGIN=""
HEADERS=()
BOMBADIL_ARGS=()
OUT_ROOT="$HOME/.jeanz/properties/$(basename "$HERE")-$(printf %s "$HERE" | cksum | cut -d' ' -f1)"
EMPTY
ships_as spec/config.ts <<'EMPTY'
import { DEFAULTS, type Feature, type KnownIssue } from "./defaults.ts";

export const DANGER_WORDS: string[] = [...DEFAULTS.dangerWords];

export const DANGER_SELECTORS: string[] = [...DEFAULTS.dangerSelectors];

export const DANGER_REQUESTS: { methods: string[]; urls: RegExp[] } = {
  methods: [...DEFAULTS.dangerMethods],
  urls: [...DEFAULTS.dangerUrls],
};

export const SIGNED_OUT: { urls: RegExp[]; selectors: string[] } = {
  urls: [...DEFAULTS.signedOutUrls],
  selectors: [],
};

export const KNOWN_ISSUES: KnownIssue[] = [];

export const FEATURES: Feature[] = [];
EMPTY
ships_as spec/actions.ts <<'EMPTY'
import type { ActionGenerator } from "@antithesishq/bombadil/actions";
import type { ActionTemplate } from "@antithesishq/bombadil/browser";

export const customActions: ActionGenerator<ActionTemplate>[] = [];
EMPTY
ships_as spec/properties.ts <<'EMPTY'
export {};
EMPTY
ships_as SKILL.md.template <<'EMPTY'
---
name: properties-<app>
description: "Check <app>'s web UI against its properties with Bombadil. It explores the app at random, checks properties in every state, and cuts a failing run to a few steps. Use after a UI change and before calling it done, when a UI bug is reported, or when the user corrects how the UI behaves."
---

# Properties of <app>

Read [the guide](GUIDE.md) before the first run. It holds the commands, how to read a run, how to triage a violation, and the protections. The guide is sealed and the same in every app. This file holds what is true of <app> alone.

## Start and stop

- Start a disposable instance with `<run-command>`.
- Stop only what you started, with `<stop-command>`. Never kill by process name.

## Gotchas

Write here what a run of <app> taught you, such as a default entry that you filtered out, and why.

## Properties of this app

The guide lists the properties that every app gets. Each property in `spec/properties.ts` needs a row here.

| Property | Rule in plain words |
|---|---|
EMPTY
report "app fact in a template" "the files that an app fills ship empty, exactly as tools/check.sh lists them. An entry every app needs goes in spec/defaults.ts, and one app's entry goes in that app's generated skill. Change the listed text only when the empty file itself changes" "$(printf '%s' "$facts" | grep -v '^$')"
report "non-ASCII text in a template" "a label in one language belongs in that app's spec/config.ts" "$(find "$TPL" -type f -print0 | xargs -0 perl -ne 'print "$ARGV:$.:$_" if /[^\x00-\x7F]/; close ARGV if eof')"
tools/seal.sh --check || fail=1
report "property that the guide does not list" "add a row for it to the table in $TPL/GUIDE.md" "$(
  for property in $(sed -nE 's/^export \{ (.*) \} from .*/\1/p' "$TPL/spec/index.ts" | tr ',' ' '); do
    grep -qF "\`$property\`" "$TPL/GUIDE.md" || echo "$property"
  done
)"

report "broken link" "point it at a file and a heading that exist, with a relative path" "$(echo "$TEXT" | grep -E '\.(md|template)$|^\./tools/names\.txt$' | python3 -I tools/links.py)"

UPSTREAM=$'\n'"$(cat tools/upstream.txt)"$'\n'
empty=""
unlisted=""
for d in skills/*/; do
  n="${d%/}"; n="${n##*/}"
  [ -f "$d/SKILL.md" ] || { empty="$empty"$'\n'"skills/$n"; continue; }
  case "$UPSTREAM" in *$'\n'"skills/$n/"$'\n'*) continue ;; esac
  grep -qE "^\| \`/jeanz:$n\` \|" README.md || unlisted="$unlisted"$'\n'"$n"
done
report "skill folder with no SKILL.md" "add one, or remove the folder" "${empty#$'\n'}"
report "skill that the README does not list" "add a row for it to the README's table of jeanz's own skills" "${unlisted#$'\n'}"
report "frontmatter that Claude Code cannot read" "each line names the fix" "$(python3 -I tools/frontmatter.py skills/*/SKILL.md agents/*.md)"

own() { awk 'NR == FNR { if ($0 != "" && $0 !~ /^#/) upstream[$0]; next } { keep = 1; for (p in upstream) if (index($0, p) == 1) keep = 0; if (keep) print }' tools/upstream.txt -; }
OWN=$(find . -type f -not -path './.git/*' | sed 's#^\./##' | sort | own)

report "writing rule broken in jeanz's own text" "each line names the fix, and tools/check-allow.txt takes a line that must stay" "$(echo "$OWN" | grep -E '\.(md|template)$|^\.claude-plugin/[a-z]+\.json$|^tools/typecheck/package\.json$' | xargs python3 -I tools/prose.py)"

pin=$(sed -n 's/^BOMBADIL_VERSION="\(.*\)"$/\1/p' "$TPL/props.sh")
report "type-check against another Bombadil than the pin" "props.sh pins $pin: set the same version in tools/typecheck, then run npm install --package-lock-only there" "$(python3 -I - "$pin" <<'PINS'
import json, sys
asked = json.load(open("tools/typecheck/package.json"))["devDependencies"]["@antithesishq/bombadil"]
locked = json.load(open("tools/typecheck/package-lock.json"))["packages"]["node_modules/@antithesishq/bombadil"]["version"]
if asked != sys.argv[1]:
    print(f"tools/typecheck/package.json asks for {asked}")
if locked != sys.argv[1]:
    print(f"tools/typecheck/package-lock.json locks {locked}")
PINS
)"
report "another Bombadil version in jeanz's own text" "props.sh pins $pin: write that version" "$(echo "$OWN" | grep -E '\.(md|template)$' | xargs grep -noE '[Bb]ombadil[^0-9]{0,80}[0-9]+\.[0-9]+\.[0-9]+' | grep -vE "[^0-9.]${pin//./\\.}\$")"

report "test that the check does not run" "add a script to TESTS in tools/check.sh, and put a table test in skills/create-property-skill/fixture" "$(
  echo "$OWN" | grep -E '\.test\.[a-z]+$' | grep -vE '^skills/create-property-skill/fixture/[^/]+\.test\.ts$' | grep -vxF -f <(printf '%s\n' "${TESTS[@]}")
)"

report "term that jeanz replaced" "tools/terms.txt lists each replaced term and what to write" "$(
  grep -vE '^(#|[[:space:]]*$)' tools/terms.txt | while IFS=$'\t' read -r avoid use; do
    {
      echo "$OWN" | grep -iF -- "$avoid" | sed 's/$/:0:the name of this file/'
      echo "$OWN" | grep -vxE 'tools/(check\.test\.sh|check-allow\.txt|terms\.txt)' | tr '\n' '\0' | xargs -0 grep -niIF -- "$avoid" /dev/null
    } | sed "s/\$/  [write: $use]/"
  done | allowed
)"
report "allow line that is stale or malformed" "write it as <path>: <text that the file still holds>, or delete it" "$(python3 -I tools/allow.py stale)"

tables="$(node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON --test skills/create-property-skill/fixture/*.test.ts 2>&1)" && tables=""
report "decision in the spec that gives a wrong answer" "fix the rule, or fix the case in fixture/rules.test.ts when the rule is right" "$(echo "$tables" | grep -vE '^(✔|ℹ|$)' | head -40)"

if [ "$MODE" != "--rules" ]; then
  for script in "${TESTS[@]}"; do "$script" || fail=1; done
  if git rev-parse --git-dir > /dev/null 2>&1 && [ "$(git config core.hooksPath)" != "tools/hooks" ]; then
    echo "note: this clone does not run the checks on commit — run: git config core.hooksPath tools/hooks"
  fi
fi

[ $fail -eq 0 ] && echo "✔ jeanz check passed ($(echo "$FILES" | wc -l | tr -d ' ') files, $(ls -d skills/*/ | wc -l | tr -d ' ') skills)"
exit $fail
