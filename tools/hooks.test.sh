#!/bin/bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FIX=skills/create-property-skill/fixture
TPL=skills/create-property-skill/templates
export HOOK_LOG="$WORK/hook.log"
OUT=""

fail() {
  echo "✘ hooks against a stand-in check — $*" >&2
  echo "$OUT" | tail -5 | sed 's/^/    /' >&2
  exit 1
}
git() { command git -c user.name=hooks-test -c user.email=hooks-test@example.invalid -c init.defaultBranch=main "$@"; }
ran() { grep -c "^$1\$" "$HOOK_LOG" 2> /dev/null || true; }
commit() { OUT="$(git commit -q -m "$1" 2>&1)"; }
tip() { git rev-parse HEAD; }

mkdir -p "$WORK/repo" && cd "$WORK/repo" || exit 1
git init -q .
git init -q --bare "$WORK/remote.git"
git remote add origin "$WORK/remote.git"
mkdir -p tools "$FIX" "$TPL" docs
cp -R "$ROOT/tools/hooks" tools/hooks
cat > tools/check.sh <<'CHECK'
#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
echo check >> "$HOOK_LOG"
[ ! -e docs/violation ] || { echo "stand-in check: docs/violation is there"; exit 1; }
CHECK
cat > "$FIX/selftest.sh" <<'SELFTEST'
#!/bin/bash
cd "$(dirname "$0")/../../.." || exit 1
echo selftest >> "$HOOK_LOG"
[ ! -e skills/create-property-skill/fixture/broken ] || { echo "stand-in self-test: fixture/broken is there"; exit 1; }
SELFTEST
cat > "$FIX/mutants.sh" <<'MUTANTS'
#!/bin/bash
cd "$(dirname "$0")/../../.." || exit 1
echo "breaks ${APPLY_ONLY:-}" >> "$HOOK_LOG"
[ ! -e skills/create-property-skill/fixture/stale ] || { echo "NOT-APPLIED stand-in: fixture/stale is there"; exit 1; }
MUTANTS
chmod +x tools/check.sh "$FIX/selftest.sh" "$FIX/mutants.sh"
echo "start" > docs/notes.md
git config core.hooksPath tools/hooks
git add -A
commit "first" || fail "a clean first commit was refused"
[ "$(ran check)" -eq 1 ] || fail "a commit did not run the check"
[ "$(ran selftest)" -eq 1 ] && [ "$(ran "breaks yes")" -eq 1 ] || fail "a commit that adds the fixture ran no self-test, or did not check the break table against the files"

: > "$HOOK_LOG"
echo "more" >> docs/notes.md
git add -A
commit "docs only" || fail "a clean commit of a doc was refused"
[ "$(ran selftest)" -eq 0 ] && [ "$(ran "breaks yes")" -eq 0 ] || fail "a commit of a doc alone ran the self-test"

before="$(tip)"
touch docs/violation
git add -A
commit "violation" && fail "a commit with a staged violation went through"
[ "$(tip)" = "$before" ] || fail "a refused commit moved the branch"
rm docs/violation
commit "violation that only the index holds" && fail "a commit went through because the working tree no longer holds the staged violation"
git reset -q
touch docs/violation
echo "even more" >> docs/notes.md
git add docs/notes.md
commit "a violation that is not staged" || fail "a commit was refused for a violation that is not part of it"
rm docs/violation

for folder in "$TPL" "$FIX"; do
  : > "$HOOK_LOG"
  echo "changed" > "$folder/changed"
  git add -A
  commit "change under $folder" || fail "a clean commit under $folder was refused"
  [ "$(ran selftest)" -eq 1 ] && [ "$(ran "breaks yes")" -eq 1 ] || fail "a commit under $folder ran no self-test, or did not check the break table against the files"
done
before="$(tip)"
touch "$FIX/broken"
git add -A
commit "self-test fails" && fail "a commit went through while the self-test fails"
git rm -q --cached "$FIX/broken" && rm "$FIX/broken"
touch "$FIX/stale"
git add -A
commit "break table is stale" && fail "a commit went through while a break no longer applies to the files"
git rm -q --cached "$FIX/stale" && rm "$FIX/stale"
[ "$(tip)" = "$before" ] || fail "a refused commit moved the branch"

: > "$HOOK_LOG"
OUT="$(git push -q origin main 2>&1)" || fail "a clean first push was refused"
[ "$(ran check)" -eq 1 ] && [ "$(ran selftest)" -eq 1 ] || fail "a first push did not run the check and the self-test"
there="$(command git --git-dir "$WORK/remote.git" rev-parse main)"
touch docs/violation
git add -A
OUT="$(git commit -q --no-verify -m "skipped the hook" 2>&1)" || fail "could not make the commit that skips the hook"
OUT="$(git push -q origin main 2>&1)" && fail "a push of a commit that skipped the hook went through"
[ "$(command git --git-dir "$WORK/remote.git" rev-parse main)" = "$there" ] || fail "a refused push moved the remote branch"
git rm -q docs/violation
commit "fixed" || fail "the commit that removes the violation was refused"
: > "$HOOK_LOG"
OUT="$(git push -q origin main 2>&1)" || fail "a push was refused after the violation was removed"
[ "$(ran selftest)" -eq 0 ] || fail "a push that changes only a doc ran the self-test"
echo "changed again" > "$TPL/changed"
git add -A
commit "templates again" || fail "a clean commit under the templates was refused"
: > "$HOOK_LOG"
OUT="$(git push -q origin main 2>&1)" || fail "a clean push of a template change was refused"
[ "$(ran selftest)" -eq 1 ] || fail "a push that changes a template ran no self-test"

git checkout -q -b side
touch docs/violation
git add -A
OUT="$(git commit -q --no-verify -m "side violation" 2>&1)" || fail "could not make the side commit"
git checkout -q main
echo "main moves" >> docs/notes.md
git add -A
commit "main moves" || fail "a clean commit on main was refused"
before="$(tip)"
OUT="$(git merge -q --no-ff -m "merge side" side 2>&1)" && fail "a merge commit that brings in a violation went through"
[ "$(tip)" = "$before" ] || fail "a refused merge moved the branch"
exit 0
