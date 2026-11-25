#!/bin/bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export WORK
failed=0

mkdir -p "$WORK/bin" "$WORK/nightly" "$WORK/empty" "$WORK/home/.claude/projects/-work-shop-app"
cat > "$WORK/bin/claude" <<'STAND_IN'
#!/bin/bash
calls="$(cat "$WORK/calls" 2> /dev/null || echo 0)"
echo $((calls + 1)) > "$WORK/calls"
if [ "$calls" -ge "$FLIP_AFTER" ]; then cat "$WORK/after.json"; else cat "$WORK/before.json"; fi
STAND_IN
printf '#!/bin/bash\n' > "$WORK/bin/sleep"
chmod +x "$WORK/bin/claude" "$WORK/bin/sleep"

session() { printf '{"kind":"%s","name":"%s","startedAt":%s,"state":"%s","sessionId":"%s","cwd":"/work/shop.app"}' "$@"; }
sessions() {
  echo "[$(session background nightly-api 1 "$1" s-api),$(session background nightly-web 1 done s-web-old),$(session background nightly-web 2 blocked s-web),$(session interactive nightly-cli 1 working s-cli),$(session background nightly-jobs 1 done s-jobs),$(session background nightly-mail 1 done s-mail),$(session background nightly-auth 1 failed s-auth),$(session background other-docs 1 working s-docs)]"
}
sessions working > "$WORK/before.json"
sessions blocked > "$WORK/after.json"
said() { printf '{"message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$1"; }
{
  said "starting"
  echo 'not json'
  said "PASS on the mail unit"
  echo '{"message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{}}]}}'
} > "$WORK/home/.claude/projects/-work-shop-app/s-mail.jsonl"
echo '{"message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{}}]}}' > "$WORK/home/.claude/projects/-work-shop-app/s-jobs.jsonl"

units() { for unit in api auth cli docs jobs mail ship web; do echo kickoff > "$WORK/nightly/$unit.kickoff.md"; done; rm -f "$WORK/nightly"/*.report.md; echo "PASS on the ship unit" > "$WORK/nightly/ship.report.md"; }
table() { printf '%s\t%s\n' api "$1" auth stopped cli waiting docs waiting jobs stopped mail done ship done web blocked; }
expect() {
  local label="$1" want="$2" flip="$3" got rc=0
  shift 3
  rm -f "$WORK/calls"
  got="$(env PATH="$WORK/bin:$PATH" HOME="$WORK/home" FLIP_AFTER="$flip" "$HERE/lane-sessions.sh" "$@" 2> /dev/null)" || rc=$?
  [ "$rc" -eq 0 ] || got="exit $rc"
  [ "$got" = "$want" ] || { printf '✘ lane-sessions.sh %s printed:\n%s\nexpected:\n%s\n' "$label" "$got" "$want" >&2; failed=1; }
}

units
expect "with no wait" "$(table working)" 99 "$WORK/nightly"
[ "$(cat "$WORK/nightly/mail.report.md" 2> /dev/null)" = "PASS on the mail unit" ] || { echo "✘ lane-sessions.sh did not save the last message of the finished mail lane as its report" >&2; failed=1; }
[ ! -e "$WORK/nightly/jobs.report.md" ] || { echo "✘ lane-sessions.sh saved a report for the jobs lane, which ended with no message" >&2; failed=1; }
units
expect "when a lane changes during the wait" "$(table blocked)" 2 "$WORK/nightly" 60
units
expect "when nothing changes during the wait" "$(table working)" 99 "$WORK/nightly" 1
expect "with no run folder" "exit 2" 99
expect "on a folder that is missing" "exit 2" 99 "$WORK/none"
expect "on a folder with no kickoff file" "exit 2" 99 "$WORK/empty"
expect "with a wait that is not a number" "exit 2" 99 "$WORK/nightly" soon
expect "with three arguments" "exit 2" 99 "$WORK/nightly" 1 2

exit $failed
