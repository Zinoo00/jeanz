#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: lane-sessions.sh <run folder> [seconds]" >&2
  echo "  run folder   holds <unit>.kickoff.md for each unit. This script adds <unit>.report.md, the last message of a lane that finished" >&2
  echo "  seconds      wait up to this long for a state to change, then print" >&2
  exit 2
}
[ $# -ge 1 ] && [ $# -le 2 ] && [ -d "$1" ] || usage
run="$(cd "$1" && pwd)"
wait_for="${2:-0}"
[[ $wait_for =~ ^[0-9]+$ ]] || usage
ls "$run"/*.kickoff.md > /dev/null 2>&1 || usage

sessions() {
  claude agents --json --all | python3 -I -c '
import json, os, re, sys
latest = {}
for session in json.load(sys.stdin):
    name, started = session.get("name"), session.get("startedAt", 0)
    if session.get("kind") == "background" and started >= latest.get(name, (0,))[0]:
        slug = re.sub(r"[/.]", "-", session.get("cwd", ""))
        transcript = os.path.join(os.path.expanduser("~"), ".claude", "projects", slug, session.get("sessionId", "") + ".jsonl")
        latest[name] = (started, session.get("state", ""), transcript)
for name, (_, state, transcript) in latest.items():
    print(f"{name}\t{state}\t{transcript}")
'
}

last_message() {
  python3 -I -c '
import json, sys
last = ""
for line in open(sys.argv[1], encoding="utf-8", errors="ignore"):
    try:
        message = json.loads(line).get("message") or {}
    except (ValueError, AttributeError):
        continue
    if message.get("role") == "assistant" and isinstance(message.get("content"), list):
        text = "\n".join(block.get("text", "") for block in message["content"] if isinstance(block, dict) and block.get("type") == "text").strip()
        last = text or last
print(last)
' "$1"
}

states() {
  local listed kickoff unit state transcript report
  listed="$(sessions)"
  for kickoff in "$run"/*.kickoff.md; do
    unit="$(basename "$kickoff" .kickoff.md)"
    state="" transcript=""
    IFS=$'\t' read -r state transcript <<< "$(awk -F'\t' -v name="$(basename "$run")-$unit" '$1 == name { print $2 "\t" $3 }' <<< "$listed")" || true
    if [ ! -s "$run/$unit.report.md" ] && [ "$state" = done ] && [ -r "$transcript" ]; then
      report="$(last_message "$transcript")"
      [ -z "$report" ] || printf '%s\n' "$report" > "$run/$unit.report.md"
    fi
    if [ -s "$run/$unit.report.md" ]; then
      state=done
    else
      case "$state" in
        "") state=waiting ;;
        working | blocked) ;;
        *) state=stopped ;;
      esac
    fi
    printf '%s\t%s\n' "$unit" "$state"
  done
}

first="$(states)"
now="$first"
end=$((SECONDS + wait_for))
while [ "$now" = "$first" ] && [ "$SECONDS" -lt "$end" ]; do
  sleep 15
  now="$(states)"
done
printf '%s\n' "$now"
