#!/bin/bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILLS="$(cd "$HERE/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failed=0

words() { python3 -I -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8").read().split()))' "$1"; }
turn() { printf '{"message":{"role":"assistant","content":[{"type":"tool_use","name":"%s","input":%s}]}}\n' "$1" "$2"; }
reads() { turn Read "{\"file_path\":\"/plugin/skills/$1\"}"; }

mkdir -p "$WORK/run/subagents"
{
  reads poteto-mode/SKILL.md
  reads poteto-mode/playbooks/bug-fix.md
  reads poteto-mode/playbooks/bug-fix.md
  turn Edit '{"file_path":"/plugin/skills/swarm/SKILL.md"}'
  reads verify-shop/SKILL.md
  echo 'not json'
  echo '{"message":{"role":"user","content":"skills/arena/SKILL.md"}}'
} > "$WORK/run.jsonl"
{
  reads poteto-mode/worker.md
  reads poteto-mode/SKILL.md
} > "$WORK/run/subagents/agent-a.jsonl"
{
  reads poteto-mode/worker.md
  turn Bash '{"command":"sed -n /Principles/,/Autonomy/p /plugin/skills/poteto-mode/SKILL.md"}'
} > "$WORK/run/subagents/agent-b.jsonl"

awk '/^## Principles/ { on = 1 } /^## Autonomy/ { on = 0 } on' "$SKILLS/poteto-mode/SKILL.md" > "$WORK/principles"
mode="$(words "$SKILLS/poteto-mode/SKILL.md")"
worker="$(words "$SKILLS/poteto-mode/worker.md")"
playbook="$(words "$SKILLS/poteto-mode/playbooks/bug-fix.md")"
principles="$(words "$WORK/principles")"
[ "$principles" -gt 0 ] || { echo "✘ SKILL.md has no Principles section between its ## Principles and ## Autonomy headings, which workers read" >&2; failed=1; }

want="$(printf 'turns\t5\nagents\t2\nmode_rereads\t1\ndocuments\t2\nwords\t%d' $((mode + playbook + worker + mode + worker + principles)))"
got="$("$HERE/run-stats.py" "$WORK/run.jsonl" 2>&1)"
[ "$got" = "$want" ] || { printf '✘ run-stats.py on the stand-in run printed:\n%s\nexpected:\n%s\n' "$got" "$want" >&2; failed=1; }

status() { local rc=0; "$HERE/run-stats.py" "$@" > /dev/null 2>&1 || rc=$?; echo "$rc"; }
[ "$(status)" = 2 ] || { echo "✘ run-stats.py with no transcript: expected exit 2" >&2; failed=1; }
[ "$(status "$WORK/run.jsonl" extra)" = 2 ] || { echo "✘ run-stats.py with two arguments: expected exit 2" >&2; failed=1; }
[ "$(status "$WORK/none.jsonl")" = 1 ] || { echo "✘ run-stats.py on a missing transcript: expected exit 1" >&2; failed=1; }

exit $failed
