#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILLS="$(cd "$HERE/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OUT=""

fail() {
  echo "✘ adopt/status.sh — $*" >&2
  echo "$OUT" | sed 's/^/    /' >&2
  exit 1
}
has() { echo "$OUT" | grep -qE "$1" || fail "$2: no line matches '$1'"; }

mkdir -p "$WORK/bare"
OUT="$(HOME="$WORK/home" "$HERE/status.sh" "$WORK/bare")"
has '^1 checks in code +no rule table: /jeanz:correct$' "a repo with nothing"
has '^2 runtime verification +none: /jeanz:create-verification-skill$' "a repo with nothing"
has '^3 property checks +none: /jeanz:create-property-skill' "a repo with nothing"
has '^5 automation +not yet: layers 1 2 3 ' "a repo with nothing"

skills="$WORK/full/.claude/skills"
mkdir -p "$skills/verify-shop/features" "$skills/verify-bare" "$skills/properties-shop" "$skills/properties-old" "$skills/properties-edited" "$skills/properties-rehashed" "$skills/properties-stray" "$WORK/home/.claude/skills/verify-elsewhere"
printf '| Rule | Enforced by |\n|---|---|\n| Money is an integer | the `Money` type |\n' > "$WORK/full/CLAUDE.md"
mkdir -p "$skills/verify-blank" "$skills/verify-unmapped/features" "$skills/verify-unindexed/features"
for f in "$skills/verify-shop/SKILL.md" "$skills/verify-shop/features/README.md" "$skills/verify-shop/features/cart.md" "$skills/verify-shop/features/orders.md" \
  "$skills/verify-bare/SKILL.md" "$skills/properties-shop/SKILL.md" "$skills/properties-old/SKILL.md" "$skills/properties-edited/SKILL.md" \
  "$skills/properties-rehashed/SKILL.md" "$skills/properties-stray/SKILL.md" \
  "$skills/verify-unmapped/SKILL.md" "$skills/verify-unmapped/features/README.md" "$skills/verify-unindexed/SKILL.md" "$skills/verify-unindexed/features/cart.md" "$WORK/home/.claude/skills/verify-elsewhere/SKILL.md"; do
  echo "written" > "$f"
done
touch "$skills/verify-blank/SKILL.md" "$skills/verify-unmapped/features/cart.md" "$skills/verify-unindexed/features/README.md"
cp -R "$SKILLS/create-property-skill/templates/." "$skills/properties-shop/"
cp -R "$SKILLS/create-property-skill/templates/." "$skills/properties-edited/"
echo "export const edited = true;" >> "$skills/properties-edited/spec/guard.ts"
echo "stale" > "$skills/properties-old/SEALED.sha256"
sha() { if command -v shasum > /dev/null; then shasum -a 256 "$@"; else sha256sum "$@"; fi; }
cp -R "$SKILLS/create-property-skill/templates/." "$skills/properties-rehashed/"
echo "export const edited = true;" >> "$skills/properties-rehashed/spec/guard.ts"
(cd "$skills/properties-rehashed" && sha $(awk '{print $2}' SEALED.sha256) > SEALED.new && mv SEALED.new SEALED.sha256)
cp -R "$SKILLS/create-property-skill/templates/." "$skills/properties-stray/"
echo "export const extra = true;" > "$skills/properties-stray/spec/extra.ts"
OUT="$(HOME="$WORK/home" "$HERE/status.sh" "$WORK/full" elsewhere)"
has '^1 checks in code +rule table in CLAUDE\.md$' "a repo with a rule table"
has 'verify-shop \(features mapped: 2\)$' "a verify skill with a feature map"
has 'verify-bare \(no feature map\)$' "a verify skill with no feature map"
has 'home/\.claude/skills/verify-elsewhere \(no feature map\)$' "a verify skill kept outside the repo"
has 'verify-unmapped \(no feature mapped\)$' "a verify skill whose feature files are empty"
has 'verify-unindexed \(no feature map\)$' "a verify skill whose feature map is an empty file"
echo "$OUT" | grep -q 'verify-blank' && fail "a skill folder with an empty SKILL.md counts as a skill"
has 'properties-shop \(sealed files current, no run on record: props\.sh run\)$' "a property skill that never ran"
has 'properties-old \(sealed files behind jeanz: /jeanz:maintain-property-skill\)$' "a property skill behind the templates"
has 'properties-edited \(sealed files edited: /jeanz:maintain-property-skill\)$' "a property skill with an edited sealed file"
has 'properties-rehashed \(sealed files edited: /jeanz:maintain-property-skill\)$' "an edited sealed file whose checksum was written into the seal record"
has 'properties-stray \(sealed files edited: /jeanz:maintain-property-skill\)$' "a file among the sealed files that jeanz never shipped"
mkdir -p "$WORK/jeanz/skills/create-property-skill"
mkdir -p "$WORK/jeanz/skills/adopt"
cp -R "$HERE" "$WORK/jeanz/skills/adopt/scripts"
cp -R "$SKILLS/create-property-skill/templates" "$SKILLS/create-property-skill/sealed-history.txt" "$WORK/jeanz/skills/create-property-skill/"
(cd "$skills/properties-edited" && sha spec/guard.ts) >> "$WORK/jeanz/skills/create-property-skill/sealed-history.txt"
OUT="$(HOME="$WORK/home" "$WORK/jeanz/skills/adopt/scripts/status.sh" "$WORK/full" elsewhere)"
has 'properties-edited \(sealed files behind jeanz: /jeanz:maintain-property-skill\)$' "a sealed file that an older jeanz shipped"
OUT="$(HOME="$WORK/home" "$HERE/status.sh" "$WORK/full" elsewhere)"
has '^5 automation +not yet: layers 2 3 ' "a repo whose layers 2 and 3 are behind"

ready="$WORK/ready/.claude/skills"
mkdir -p "$ready/verify-shop/features" "$ready/properties-shop" "$WORK/empty"
runs="$WORK/home/.jeanz/properties/properties-shop-$(printf %s "$(cd "$ready/properties-shop" && pwd -P)" | cksum | cut -d' ' -f1)"
cp "$WORK/full/CLAUDE.md" "$WORK/ready/CLAUDE.md"
for f in "$ready/verify-shop/SKILL.md" "$ready/verify-shop/features/README.md" "$ready/verify-shop/features/cart.md"; do echo "written" > "$f"; done
cp -R "$SKILLS/create-property-skill/templates/." "$ready/properties-shop/"
echo "written" > "$ready/properties-shop/SKILL.md"
record() { rm -rf "$runs"; mkdir -p "$runs"; local name; for name in "$@"; do echo "${name#*=}" > "$runs/${name%%=*}.exit"; done; }
status_of_ready() { OUT="$(HOME="$WORK/home" "$HERE/status.sh" "$WORK/ready")"; }

record 20260101-000000-run=0
status_of_ready
has 'properties-shop \(sealed files current, newest run 20260101-000000-run passed\)$' "a property skill whose newest run passed"
has '^5 automation +ready: layers 1 to 3 hold$' "a repo with every layer"
mkdir -p "$WORK/twin/.claude/skills"
cp "$WORK/full/CLAUDE.md" "$WORK/twin/CLAUDE.md"
cp -R "$ready/verify-shop" "$ready/properties-shop" "$WORK/twin/.claude/skills/"
OUT="$(HOME="$WORK/home" "$HERE/status.sh" "$WORK/twin")"
has 'properties-shop \(sealed files current, no run on record: props\.sh run\)$' "a second checkout whose skill has the same name and no run of its own"
record
status_of_ready
has '^5 automation +not yet: layers 3 ' "a property skill that never ran"
record 20260101-000000-run=0 20260102-000000-sweep=
status_of_ready
has 'newest run 20260102-000000-sweep has no result: it was stopped, or it is still running\)$' "a newest run that recorded no result"
has '^5 automation +not yet: layers 3 ' "a newest run that recorded no result"
record 20260101-000000-run=0 20260102-000000-sweep=1
status_of_ready
has 'newest run 20260102-000000-sweep exited 1\)$' "a newest run that props.sh ended with exit 1"
has '^5 automation +not yet: layers 3 ' "a newest run that props.sh ended with exit 1"
record 20260101-000000-run=2 20260101-000000-run-2=0
status_of_ready
has 'newest run 20260101-000000-run-2 passed\)$' "a passing run after a broken one in the same second"
record 20260101-000000-run=0
touch -t 200001010000 "$runs/20260101-000000-run.exit"
status_of_ready
has "newest run 20260101-000000-run is older than the skill's files\\)\$" "a run older than the spec"
has '^5 automation +not yet: layers 3 ' "a run older than the spec"
for changed in props.sh props.config.sh; do
  record 20260101-000000-run=0
  touch -t 203001010000 "$ready/properties-shop/$changed"
  status_of_ready
  has "newest run 20260101-000000-run is older than the skill's files\\)\$" "a run older than $changed"
  touch -t 200001010000 "$ready/properties-shop/$changed"
done
cp -R "$ready/properties-shop" "$ready/properties-aside"
record 20260101-000000-run=0
status_of_ready
has 'properties-aside \(sealed files current, no run on record: props\.sh run\)$' "a second property skill that never ran"
has '^5 automation +not yet: layers 3 ' "a property skill that never ran beside one that passed"
rm -r "$ready/properties-aside"
record 20260101-000000-run=0
echo 'OUT_ROOT="$HOME/elsewhere"' >> "$ready/properties-shop/props.config.sh"
status_of_ready
has 'properties-shop \(sealed files current, no run on record: props\.sh run\)$' "runs kept where the settings no longer point"
mkdir -p "$WORK/home/elsewhere"
echo 0 > "$WORK/home/elsewhere/20260103-000000-sweep.exit"
status_of_ready
has 'newest run 20260103-000000-sweep passed\)$' "runs kept where OUT_ROOT points"
printf '| Rule | Enforced by |\n|---|---|\n\nNo rows yet.\n' > "$WORK/empty/CLAUDE.md"
OUT="$(HOME="$WORK/home" "$HERE/status.sh" "$WORK/empty")"
has '^1 checks in code +no rule table: /jeanz:correct$' "a rule table with no rows"
mkdir -p "$WORK/noweb/.claude/skills"
cp "$WORK/full/CLAUDE.md" "$WORK/noweb/CLAUDE.md"
cp -R "$ready/verify-shop" "$WORK/noweb/.claude/skills/"
OUT="$(HOME="$WORK/home" "$HERE/status.sh" "$WORK/noweb")"
has '^5 automation +ready only if the project has no web UI: layer 3 is missing$' "a repo with layers 1 and 2 and no property skill"

rc=0
OUT="$("$HERE/status.sh" 2>&1)" || rc=$?
[ "$rc" -eq 64 ] || fail "no repo given: exit $rc, expected 64"
