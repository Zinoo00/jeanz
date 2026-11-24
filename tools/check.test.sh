#!/bin/bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
TPL=skills/create-property-skill/templates
OUT=""
ALL=""
failed=0

RULES="$(cat <<'NAMES'
Cursor tool name
Cursor subagent field
Cursor model slug
Cursor path
Cursor-only feature
Cursor-only skill
Cursor product mention
old namespace
name pattern with no rule, or one that misses its own example
unknown skill name
app fact in a template
non-ASCII text in a template
property that the guide does not list
broken link
skill folder with no SKILL.md
skill that the README does not list
frontmatter that Claude Code cannot read
writing rule broken in jeanz's own text
type-check against another Bombadil than the pin
another Bombadil version in jeanz's own text
test that the check does not run
term that jeanz replaced
allow line that is stale or malformed
decision in the spec that gives a wrong answer
NAMES
)"

fresh() {
  rsync -a --delete --exclude .git "$ROOT/" "$WORK/repo/"
  cd "$WORK/repo" || exit 1
}

miss() {
  echo "✘ $1"
  failed=1
}

planted() {
  local command="$1"
  shift
  if OUT="$($command 2>&1)"; then
    miss "$command passes on a copy with planted violations — make its rules catch them"
    return
  fi
  ALL="$ALL"$'\n'"$OUT"
  while [ $# -gt 0 ]; do
    case "$OUT" in
      *"$1"*) ;;
      *) miss "$command misses a planted violation: its output lacks '$1' — make the rule catch the plant, or fix the plant in tools/check.test.sh" ;;
    esac
    shift
  done
}

under() {
  local rule="$1" hits
  shift
  hits="$(echo "$OUT" | awk -v head="✘ $rule — " 'index($0, "✘ ") == 1 || index($0, "✔ ") == 1 { on = index($0, head) == 1 } on')"
  [ -n "$hits" ] || { miss "tools/check.sh does not report the rule '$rule' on a copy that breaks it — restore the rule, or fix the plant in tools/check.test.sh"; return; }
  while [ $# -gt 0 ]; do
    case "$hits" in
      *"$1"*) ;;
      *) miss "tools/check.sh misses a planted violation of '$rule': the rule's hits lack '$1' — make the rule catch the plant, or fix the plant in tools/check.test.sh" ;;
    esac
    shift
  done
}

needles() {
  grep -ohE '✘ [^—]+ —' "$ROOT/tools/seal.sh" "$ROOT/tools/typecheck.sh"
  {
    sed -nE 's/^    \("([^"]+)", re\.compile.*/\1 '"'"'/p' "$ROOT/tools/prose.py"
    grep -ohE '(yield|return) (number, |1, |None if [^"]*else )?f?"[^{`:]+' "$ROOT/tools/prose.py" "$ROOT/tools/frontmatter.py" | sed -E 's/^(yield|return) (number, |1, |None if [^"]*else )?f?"//'
    sed -nE 's/^  [A-Za-z]+: "(.*)",$/\1/p' "$ROOT/tools/typecheck/loose.mjs"
  } | sed -E 's/^(.*)$/: \1/'
}

entries() { grep -vE '^(#|=|[[:space:]]*$)' "$ROOT/tools/names.txt"; }
terms() { grep -vE '^(#|[[:space:]]*$)' "$ROOT/tools/terms.txt"; }

fresh
entries | cut -f3 >> docs/design.md
terms | while IFS=$'\t' read -r avoid _; do echo "A line about $avoid here." >> docs/design.md; done
: > docs/fuzz-notes.txt
printf 'old namespace\tzzzplant\tzzzplant docs/claude-code-port.md#no-such-anchor\nold namespace\tqqqplant\tno match here\nghost rule\tpppplant\tpppplant\n' >> tools/names.txt
cat >> docs/design.md <<'NAMED'
Run /jeanz:adpot next.
Run /jeanz:Adopt next.
Run /jeanz:adopt_project next.
Run /jeanz:x next.
NAMED
echo '// waits for Bugbot' >> skills/create-property-skill/fixture/actions.ts
cat >> docs/design.md <<'LINKS'
[gone](gone.md) [angle](<nowhere.md>) [anchor](design.md#no-such-heading) [absolute](/etc/hosts)
[by reference][ref] <a href="no-href.md">a tag</a> [template](../skills/create-property-skill/templates/SKILL.md.template#no-such-part)

[ref]: no-reference.md
LINKS
echo '[gone](missing.md)' >> UPSTREAM.md
cat >> docs/design.md <<'PROSE'
The guard will leverage the list.
This sentence has far too many words in it because it keeps going and going well past the limit that the writing rules set for one single sentence.
Use it for lists etc. when done.
Input -> output.
It runs - then stops.
It runs, it stops; it starts.
Note: this is one.
It is not just fast but also small.
Use read/write access.

#### A deep heading

## A Capitalized heading

# A second top heading
PROSE
printf 'A \xe2\x80\x9cquoted\xe2\x80\x9d word. Done \xe2\x9c\x85\n' >> docs/design.md
grep -v '^| `/jeanz:adopt` |' README.md > README.new && mv README.new README.md
perl -pi -e 's/bombadil\) [0-9.]+ on/bombadil) 0.0.1 on/' README.md
perl -pi -e 's/("\@antithesishq\/bombadil": ")[0-9.]+"/${1}0.0.1"/' tools/typecheck/package.json
perl -0pi -e 's/("node_modules\/\@antithesishq\/bombadil": \{\s*"version": ")[0-9.]+"/${1}0.0.2"/' tools/typecheck/package-lock.json
perl -pi -e 's/("description": ".*)"/$1; and more"/' .claude-plugin/plugin.json
perl -pi -e 's/"$// if /^description: "/' skills/adopt/SKILL.md
perl -ni -e 'print unless /^---$/ && $. > 1' skills/unslop/SKILL.md
perl -pi -e 's/^name: .*/name: wrong/ if $. < 6' skills/maintain-property-skill/SKILL.md
perl -pi -e 's/^description: "(.*)"$/description: Note: $1/' skills/create-property-skill/SKILL.md
perl -pi -e 'print "a stray line\n" if $. == 2' skills/arena/SKILL.md
perl -pi -e 'print "disable-model-invokation: true\n" if $. == 2' skills/bro/SKILL.md
perl -pi -e 's/^(description: .*)$/$1\t/ if $. < 6' skills/how/SKILL.md
perl -pi -e 's/^description: .*/description:/ if $. < 6' skills/ketchup/SKILL.md
perl -pi -e 'print "name: interrogate\n" if $. == 2' skills/interrogate/SKILL.md
perl -ni -e 'print unless $. == 1' skills/architect/SKILL.md
perl -ni -e 'print unless /^description: / && $. < 6' skills/correct/SKILL.md
perl -pi -e 's/^description: .*/description: 2026-11-20/ if $. < 6' skills/tdd/SKILL.md
perl -pi -e 's/^(disable-model-invocation): .*/$1: yes/ if $. < 8' skills/adopt/SKILL.md
mkdir skills/empty
echo 'export const EXTRA = Object.keys({ purge: null });' >> "$TPL/spec/config.ts"
echo 'export const more = customActions;' >> "$TPL/spec/actions.ts"
echo 'export const LIMIT = 3000;' >> "$TPL/spec/properties.ts"
perl -pi -e 's{^ORIGIN=""}{ORIGIN="http://127.0.0.1:3000/"}; s/^WIDTH=1280/WIDTH=390/' "$TPL/props.config.sh"
perl -ni -e 'print unless /^HEADERS=/' "$TPL/props.config.sh"
perl -pi -e 's/<run-command>/make dev/' "$TPL/SKILL.md.template"
echo '| `cartTotal` | The cart total matches its rows |' >> "$TPL/SKILL.md.template"
perl -pi -e 'print "Acme runs on shop.test:3000.\n" if /^## Gotchas/' "$TPL/SKILL.md.template"
perl -ni -e 'print unless /^\| `signedIn` /' "$TPL/GUIDE.md"
printf 'export const label = "\xec\x82\xad\xec\xa0\x9c";\n' >> "$TPL/spec/guard.ts"
perl -pi -e 's/status >= 500/status >= 400/' "$TPL/spec/rules.ts"
echo 'docs/design.md: words that the file does not hold' >> tools/check-allow.txt
echo 'exit 0' > tools/extra.test.sh
echo 'export {};' > skills/adopt/stray.test.ts
planted "tools/check.sh --rules" \
  "✘ stale seal —" \
  "banned word 'leverage'" "words: split it at 25 (technical-writing): This sentence has far too many" \
  ".claude-plugin/plugin.json:1: semicolon" \
  "skills/adopt/SKILL.md: a quoted or bracketed value that does not parse" \
  "skills/adopt/SKILL.md: a value that is not true or false" \
  "skills/unslop/SKILL.md: the frontmatter has no closing" \
  "skills/maintain-property-skill/SKILL.md: the name does not match the folder or the file" \
  "skills/create-property-skill/SKILL.md: a plain value that YAML reads another way" \
  "skills/tdd/SKILL.md: a plain value that YAML reads as a number, a date, or a truth value" \
  "skills/arena/SKILL.md: a frontmatter line that is not" \
  "skills/bro/SKILL.md: an unknown frontmatter key" \
  "skills/how/SKILL.md: a tab in the value of" \
  "skills/ketchup/SKILL.md: an empty value for" \
  "skills/interrogate/SKILL.md: a frontmatter key that appears twice" \
  "skills/architect/SKILL.md: the file does not start with" \
  "skills/correct/SKILL.md: no description"
while IFS=$'\t' read -r rule _ example; do under "$rule" "$example"; done < <(entries)
under "Cursor-only feature" "waits for Bugbot"
under "name pattern with no rule, or one that misses its own example" "tools/names.txt: qqqplant" "tools/names.txt: pppplant"
under "unknown skill name" "jeanz:adpot" "jeanz:Adopt" "jeanz:adopt_project" "jeanz:x"
while IFS=$'\t' read -r avoid use; do under "term that jeanz replaced" "A line about $avoid here.  [write: $use]"; done < <(terms)
under "term that jeanz replaced" "docs/fuzz-notes.txt:0:the name of this file"
under "broken link" "docs/design.md: gone.md" "docs/design.md: nowhere.md" "docs/design.md: design.md#no-such-heading" "docs/design.md: /etc/hosts" "UPSTREAM.md: missing.md" \
  "docs/design.md: no-reference.md" "docs/design.md: no-href.md" "SKILL.md.template#no-such-part" "tools/names.txt: docs/claude-code-port.md#no-such-anchor"
under "skill that the README does not list" "adopt"
under "skill folder with no SKILL.md" "skills/empty"
under "type-check against another Bombadil than the pin" "tools/typecheck/package.json asks for 0.0.1" "tools/typecheck/package-lock.json locks 0.0.2"
under "another Bombadil version in jeanz's own text" "README.md"
under "app fact in a template" \
  "spec/config.ts: a line that the empty file does not have: export const EXTRA = Object.keys" \
  "spec/actions.ts: a line that the empty file does not have: export const more" \
  "spec/properties.ts: a line that the empty file does not have: export const LIMIT = 3000;" \
  'props.config.sh: a line that the empty file does not have: ORIGIN="http://127.0.0.1:3000/"' \
  "props.config.sh: a line that the empty file does not have: WIDTH=390" \
  "props.config.sh: a line of the empty file that is gone: HEADERS=()" \
  'SKILL.md.template: a line of the empty file that is gone: - Start a disposable instance with `<run-command>`.' \
  'SKILL.md.template: a line that the empty file does not have: | `cartTotal` |' \
  "SKILL.md.template: a line that the empty file does not have: Acme runs on shop.test:3000."
under "non-ASCII text in a template" "spec/guard.ts"
under "property that the guide does not list" "signedIn"
under "decision in the spec that gives a wrong answer" "status 404"
under "allow line that is stale or malformed" "words that the file does not hold"
under "test that the check does not run" "tools/extra.test.sh" "skills/adopt/stray.test.ts"
under "frontmatter that Claude Code cannot read" "skills/bro/SKILL.md"
under "writing rule broken in jeanz's own text" "docs/design.md"

fresh
: > skills/create-property-skill/sealed-history.txt
planted "tools/check.sh --rules" "✘ stale seal —"

fresh
{ echo; echo ': '; echo 'README.md: Cursor does this.'; cat tools/check-allow.txt; } > allow.new && mv allow.new tools/check-allow.txt
echo 'Cursor does this.' >> docs/design.md
planted "tools/check.sh --rules"
under "Cursor product mention" "docs/design.md:"
under "allow line that is stale or malformed" ": " "README.md: Cursor does this."

fresh
cat >> "$TPL/spec/rules.ts" <<'TS'
export const kept = ["a"] as const;
export const one: any = 1;
export const two = kept as unknown;
export const three = kept as
  unknown;
export const four = <unknown>kept;
export const five = kept[0]!;
export const six = (): any => 1;
export const seven: Function = () => 1;
export let eight!: number;
declare const nine: number;
export const ten = JSON.parse("1");
export const eleven: unknown = JSON.parse("1");
TS
printf '// @ts-nocheck\n' | cat - "$TPL/spec/rules.ts" > rules.new && mv rules.new "$TPL/spec/rules.ts"
planted tools/typecheck.sh "rules.ts:1: a comment that switches the type-check off"
[ "$(echo "$OUT" | grep -c 'rules\.ts:[0-9]*: ')" -eq 11 ] || {
  miss "tools/typecheck.sh does not report exactly the eleven planted loose types — \`as const\` and a value annotated \`unknown\` pass, and each other plant is reported once"
  echo "$OUT" | sed 's/^/    /'
}

fresh
echo 'export const wrong: number = "a";' >> "$TPL/spec/rules.ts"
planted tools/typecheck.sh "rules.ts"

while IFS= read -r needle; do
  case "$ALL" in
    *"$needle"*) ;;
    *) miss "a rule with no planted violation: no planted run printed '$needle' — plant a violation of it in tools/check.test.sh" ;;
  esac
done < <(needles)
[ "$(needles | wc -l)" -ge 30 ] || miss "tools/check.test.sh found too few messages to cover in the tools that tools/check.sh runs — fix how it reads them"

fresh
CHECK_NAMES="$WORK/names" tools/check.sh --rules > /dev/null 2>&1
differ="$(diff <(echo "$RULES" | sort) <(sort -u "$WORK/names") | sed -nE 's/^< (.*)/tools\/check.sh no longer runs the rule "\1"/p; s/^> (.*)/tools\/check.sh runs the rule "\1", which RULES in tools\/check.test.sh does not list/p')"
[ -z "$differ" ] || {
  miss "the rules that tools/check.sh runs are not the rules that tools/check.test.sh lists — restore a rule that went missing, or list a new rule and plant a violation of it"
  echo "$differ" | sed 's/^/    /'
}

fresh
tests="$(sed -nE 's/^TESTS=\((.*)\)$/\1/p' tools/check.sh)"
[ "$(echo "$tests" | wc -w)" -ge 5 ] || miss "tools/check.test.sh cannot read TESTS in tools/check.sh — keep the list on one line"
stand_in() { for script in $tests; do printf '#!/bin/bash\necho "%s" >> "%s"\nexit %s\n' "$script" "$WORK/ran" "$1" > "$script"; done; }
stand_in 0
tools/check.sh > /dev/null 2>&1 || miss "tools/check.sh fails on a clean copy whose tests are stand-ins that pass — fix what it reports, so this test can tell a failing test from a failing rule"
stand_in 1
if tools/check.sh > /dev/null 2>&1; then miss "tools/check.sh passes while every test that it runs fails — make a failing test fail the check"; fi
for script in $tests; do
  grep -qxF "$script" "$WORK/ran" 2> /dev/null || miss "tools/check.sh does not run $script — run every script in TESTS"
done

exit $failed
