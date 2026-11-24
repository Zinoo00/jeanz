#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd -P)"
CONFIG="$HERE/props.config.sh"
SPEC="$HERE/spec/index.ts"

E_UNREACHED=3
E_TOOL=10
E_SEALED=11
E_INSTANCE=12
E_SPEC=13
E_LOGIN=14
E_SIGNED_OUT=15
E_BUSY=16
E_NO_STATE=17
E_NO_RUN=18
E_CONFIG=19
E_DOWN=20
E_NO_REPLAY=21
E_USAGE=64

LOCK=""
RECORD=""

trap 'pkill -INT -P $$ -f "bombadil browser" 2> /dev/null || true; [ -z "$LOCK" ] || rm -f "$LOCK"' EXIT

end() {
  [ -z "$RECORD" ] || echo "$1" > "$RECORD"
  exit "$1"
}

die() {
  local code="$1"; shift
  echo "props: $*" >&2
  end "$code"
}

[ -f "$CONFIG" ] || die $E_CONFIG "no settings file at $CONFIG"
broken="$( (set -euo pipefail; source "$CONFIG") 2>&1 > /dev/null)" || die $E_CONFIG "$CONFIG does not load: $(echo "$broken" | tail -1)"
source "$CONFIG"
BOMBADIL_VERSION="0.7.10"

usage() {
  cat <<EOF
usage: props.sh <command>
  doctor                      check the settings, bombadil, the sealed files, the instance, the login and a signed-in page
  run [LIMIT]                 explore until the first violation or LIMIT (default 5m), then print the run folder and its summary
  sweep [LIMIT]               explore for LIMIT (default 10m) and keep every violation
  shrink RUN [PROPERTY] [LIMIT]
                              cut RUN to fewer steps that still break PROPERTY (default: the first one broken),
                              trying for at most LIMIT (default 5m); writes RUN-shrunk
  repro RUN                   replay RUN step by step. Exit 2 means it still fails
  confirm RUN [PROPERTY] [LIMIT]
                              after a fix, replay RUN, then explore for LIMIT (default 2m). Exit 0 means PROPERTY held in both
  report RUN                  write RUN/report.html: coverage, each violation, its steps and screenshots
  summary RUN                 coverage, violations, the steps before each, and its evidence
  inspect RUN                 open bombadil's local trace viewer

exit codes
   0  no property broke, and the run reached every listed feature
   1  bombadil failed or was stopped, and no property was violated
   2  a property was violated
   $E_UNREACHED  no property broke, but the run got no new state in its last half, missed a listed feature, or FEATURES is empty
  $E_TOOL  bombadil is missing or is another version
  $E_SEALED  a sealed file changed
  $E_INSTANCE  the instance is not marked disposable, or a setting points off it
  $E_SPEC  an app file exports an action generator outside the guard, or names a property or a cell as a sealed file does
  $E_LOGIN  LOGIN failed
  $E_SIGNED_OUT  not signed in
  $E_BUSY  another run is driving this instance
  $E_NO_STATE  bombadil recorded no state
  $E_NO_RUN  no such run, the run did not break that property, or the spec no longer has it
  $E_CONFIG  a setting is missing or wrong, or SKILL.md lacks the row of a property
  $E_DOWN  the instance does not answer
  $E_NO_REPLAY  the replay did not reach its last step
  $E_USAGE  unknown command
EOF
  exit $E_USAGE
}

host_of() { python3 -I -c 'import sys, urllib.parse; print(urllib.parse.urlsplit(sys.argv[1]).hostname or "")' "$1"; }

instance_of() { python3 -I -c 'import sys, urllib.parse; u = urllib.parse.urlsplit(sys.argv[1]); print(f"{u.scheme}_{u.hostname}_{u.port or 0}")' "$1"; }

sha() { if command -v shasum > /dev/null; then shasum -a 256 "$@"; else sha256sum "$@"; fi; }

exports_of() {
  python3 -I -c '
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
if re.search(r"^\s*export\s*\*", text, re.M):
    sys.exit(1)
names = re.findall(r"^\s*export\s+(?:async\s+)?(?:const|let|var|function|class)\s+([A-Za-z_$][\w$]*)", text, re.M)
for group in re.findall(r"^\s*export\s*\{([^}]*)\}", text, re.M):
    names += [part.split(" as ")[-1].strip() for part in group.split(",") if part.strip() and not part.strip().startswith("type ")]
print("\n".join(names))
' "$1" 2> /dev/null
}

check_config() {
  local name unfilled exported
  for name in ORIGIN READY_URL READY_TEXT DISPOSABLE WIDTH HEIGHT LOGIN OUT_ROOT; do
    [ -n "${!name+set}" ] || die $E_CONFIG "$CONFIG does not set $name"
  done
  [ -n "$ORIGIN" ] || die $E_CONFIG "set ORIGIN: the address the run starts from"
  [ -n "$READY_URL" ] && [[ "$READY_TEXT" =~ [^[:space:]] ]] || die $E_CONFIG "set READY_URL and READY_TEXT: a URL, and text in its response, that only a signed-in user gets"
  [[ "$WIDTH" =~ ^[0-9]+$ ]] && [[ "$HEIGHT" =~ ^[0-9]+$ ]] || die $E_CONFIG "set WIDTH and HEIGHT to the viewport in whole pixels"
  [ -f "$HERE/SKILL.md" ] || die $E_CONFIG "no SKILL.md in $HERE: rename SKILL.md.template and put this app's values in it"
  unfilled="$(grep -oE '<(app|run-command|stop-command)>' "$HERE/SKILL.md" | sort -u | tr '\n' ' ' || true)"
  [ -z "$unfilled" ] || die $E_CONFIG "SKILL.md still holds ${unfilled}: put this app's value in its place"
  exported="$(exports_of "$HERE/spec/properties.ts")" || die $E_CONFIG "spec/properties.ts must exist and export each property by name. \`export *\` hides the names that SKILL.md has to list."
  for name in $exported; do
    grep -qF "\`$name\`" "$HERE/SKILL.md" || die $E_CONFIG "SKILL.md does not list the property $name: add a row that says what it checks"
  done
}

check_version() {
  local have
  have="$(bombadil --version 2>/dev/null | awk '{print $2}')" || true
  [ "$have" = "$BOMBADIL_VERSION" ] && return 0
  die $E_TOOL "need bombadil $BOMBADIL_VERSION, found '${have:-none}'. Get it from https://github.com/antithesishq/bombadil/releases/tag/v$BOMBADIL_VERSION"
}

check_sealed() {
  [ -f "$HERE/SEALED.sha256" ] || die $E_SEALED "SEALED.sha256 is missing. Restore the sealed files with /jeanz:maintain-property-skill."
  local bad listed sealed
  listed="$(awk '{print $2}' "$HERE/SEALED.sha256" | sort)"
  sealed="$(cd "$HERE" && { ls props.sh summarize.py GUIDE.md spec/*.ts 2> /dev/null || true; } | grep -vE '^spec/(config|actions|properties)\.ts$' | sort)"
  [ "$listed" = "$sealed" ] || die $E_SEALED "SEALED.sha256 does not list exactly the sealed files. /jeanz:maintain-property-skill restores them. An extra file of this app goes in a folder under spec/."
  bad="$(cd "$HERE" && sha -c SEALED.sha256 2>&1 | grep -v ': OK$' || true)"
  [ -z "$bad" ] || die $E_SEALED "sealed files changed: $(echo "$bad" | tr '\n' ' '). This app's changes go in props.config.sh, spec/config.ts, spec/actions.ts and spec/properties.ts. A flaw any app would hit gets fixed in jeanz, then /jeanz:maintain-property-skill brings it here."
}

check_instance() {
  [ "$DISPOSABLE" = "yes" ] || die $E_INSTANCE "DISPOSABLE is not \"yes\" in $CONFIG. Set it only for an instance on disposable data with every outbound channel off."
  local host h a
  for a in ${BOMBADIL_ARGS[@]+"${BOMBADIL_ARGS[@]}"}; do
    case "$a" in
      --allow-url*) die $E_INSTANCE "BOMBADIL_ARGS holds --allow-url, which lets a run leave ORIGIN's host. Remove it." ;;
    esac
  done
  [ "$(instance_of "$READY_URL")" = "$(instance_of "$ORIGIN")" ] || die $E_INSTANCE "READY_URL is not on ORIGIN's host and port, so the sign-in would go to another instance. Point it at a page of $ORIGIN's instance."
  host="$(host_of "$ORIGIN")"
  case "$host" in
    127.0.0.1 | localhost | ::1) return 0 ;;
  esac
  for h in ${DISPOSABLE_HOSTS[@]+"${DISPOSABLE_HOSTS[@]}"}; do [ "$h" = "$host" ] && return 0; done
  die $E_INSTANCE "ORIGIN host '$host' is not this machine. List it in DISPOSABLE_HOSTS only when that instance is disposable too."
}

fetch() { curl -s --max-time 10 "$@"; }

check_reachable() {
  fetch -o /dev/null "$ORIGIN" || die $E_DOWN "$ORIGIN does not answer. Start the instance."
}

load_cookies() {
  COOKIES=()
  [ -n "$LOGIN" ] || return 0
  local out rc=0
  out="$(bash -c "$LOGIN")" || rc=$?
  [ $rc -eq 0 ] || die $E_LOGIN "LOGIN failed (exit $rc)"
  while IFS= read -r c; do [ -n "$c" ] && COOKIES+=("$c"); done <<< "$out"
  [ ${#COOKIES[@]} -gt 0 ] || die $E_LOGIN "LOGIN printed no cookies"
}

shows_ready() {
  local body found=1
  body="$(mktemp)"
  code="$(fetch "$@" -o "$body" -w '%{http_code}' "$READY_URL" || true)"
  grep -qF "$READY_TEXT" "$body" && found=0
  rm -f "$body"
  return $found
}

check_ready() {
  local jar="" code shown="" c h
  local sign_in=()
  for c in ${COOKIES[@]+"${COOKIES[@]}"}; do jar="${jar:+$jar; }$c"; done
  [ -z "$jar" ] || sign_in+=(-b "$jar")
  for h in ${HEADERS[@]+"${HEADERS[@]}"}; do sign_in+=(-H "${h%%=*}: ${h#*=}"); done
  shows_ready ${sign_in[@]+"${sign_in[@]}"} && shown=yes
  [ "$code" = 200 ] || die $E_SIGNED_OUT "READY_URL answered $code, not 200. A redirect usually means the login did not take, and 000 means no answer."
  [ -n "$shown" ] || die $E_SIGNED_OUT "READY_URL answered 200 but does not show READY_TEXT"
  [ ${#sign_in[@]} -gt 0 ] || return 0
  ! shows_ready || die $E_CONFIG "READY_URL shows READY_TEXT without the sign-in, so it proves nothing. Pick a URL that only a signed-in user gets."
}

preflight() { check_config; check_version; check_sealed; check_instance; check_reachable; load_cookies; check_ready; }

take_lock() {
  local lock owner
  lock="$(dirname "$OUT_ROOT")/.lock-$(instance_of "$ORIGIN")"
  mkdir -p "$OUT_ROOT"
  if ! ln -s "$$" "$lock" 2> /dev/null; then
    owner="$(readlink "$lock" 2> /dev/null || true)"
    if [ -n "$owner" ] && kill -0 "$owner" 2> /dev/null; then die $E_BUSY "another props.sh (pid $owner) is driving the instance at $ORIGIN"; fi
    rm -rf "$lock"
    ln -s "$$" "$lock" 2> /dev/null || die $E_BUSY "another props.sh took the instance at $ORIGIN first"
  fi
  LOCK="$lock"
}

new_run() {
  local base n out
  base="$OUT_ROOT/$(date +%Y%m%d-%H%M%S)-$1"
  for n in "" -2 -3 -4 -5 -6 -7 -8 -9; do
    out="$base$n"
    (set -o noclobber; : > "$out.exit") 2> /dev/null || continue
    echo "$out"
    return
  done
  die 1 "cannot write a run record in $OUT_ROOT"
}

bombadil_args() {
  ARGS=(--headless --width "$WIDTH" --height "$HEIGHT")
  local h c a
  for h in ${HEADERS[@]+"${HEADERS[@]}"}; do ARGS+=(--header "$h"); done
  for c in ${COOKIES[@]+"${COOKIES[@]}"}; do ARGS+=(--cookie "$c"); done
  for a in ${BOMBADIL_ARGS[@]+"${BOMBADIL_ARGS[@]}"}; do ARGS+=("$a"); done
}

redact() {
  SECRETS="$(printf '%s\n' ${COOKIES[@]+"${COOKIES[@]}"} ${HEADERS[@]+"${HEADERS[@]}"})" python3 -I -c '
import os, sys
secrets = os.environ["SECRETS"].splitlines()
for line in sys.stdin:
    for secret in secrets:
        line = line.replace(secret, "<redacted>")
    sys.stdout.write(line)
'
}

run_bombadil() {
  local log="$1"; shift
  local rc
  set +e
  bombadil browser "$@" 2>&1 | redact > "$log"
  rc=${PIPESTATUS[0]}
  set -e
  return $rc
}

explored() { grep -q '^Test finished after time limit' "$1.log"; }

replay_ended() { grep -q '^Reproduction finished' "$1.log"; }

summarize() { python3 -I "$HERE/summarize.py" "$@" || die 1 "could not read the trace in $1. It may be cut short."; }

asks() {
  local rc=0
  python3 -I "$HERE/summarize.py" "$@" || rc=$?
  [ $rc -eq 0 ] || [ $rc -eq 3 ] || die 1 "could not read the trace in $1"
  return $rc
}

violates() { asks "$1" --violates "$2"; }

verdict() {
  local gap rc=0
  gap="$(python3 -I "$HERE/summarize.py" "$1" --verdict)" || rc=$?
  case $rc in
    0 | 2) return $rc ;;
    3) echo "props: no property broke, but $gap. This run cannot vouch for the whole app." >&2; return $E_UNREACHED ;;
    *) die 1 "could not read the trace in $1" ;;
  esac
}

checks() { asks "$1" --checks "$2" || die $E_NO_RUN "the spec that this run loaded has no property named $2, so no run can check it"; }

listed() {
  local name names clash
  clash="$(python3 -I "$HERE/summarize.py" "$1" --clash)" || die 1 "could not read the trace in $1. It may be cut short."
  [ -z "$clash" ] || die $E_SPEC "an app file names a cell $clash, and a sealed file owns that name. Rename the app's cell."
  names="$(python3 -I "$HERE/summarize.py" "$1" --properties)" || die 1 "could not read the trace in $1. It may be cut short."
  for name in $names; do
    grep -qF "\`$name\`" "$HERE/SKILL.md" "$HERE/GUIDE.md" || die $E_CONFIG "SKILL.md does not list the property $name, which this run checked. Add a row that says what it checks."
  done
}

recorded() {
  if [ -s "$1/trace.jsonl" ]; then listed "$1"; return 0; fi
  local refused
  refused="$(grep -oE 'spec/properties\.ts exports .*(wraps|Rename) it\.' "$1.log" 2>/dev/null | head -1 || true)"
  [ -z "$refused" ] || die $E_SPEC "$refused"
  die $E_NO_STATE "bombadil recorded no state: the spec did not load, the browser did not start, or the first page never finished loading. See $1.log"
}

run_dir_arg() {
  RUN="${1%/}"
  [ -n "$RUN" ] && [ -f "$RUN/trace.jsonl" ] || die $E_NO_RUN "not a run folder (no trace.jsonl): ${1:-<missing>}"
}

property_arg() {
  PROPERTY="${1:-$(python3 -I "$HERE/summarize.py" "$RUN" --first-property)}"
  [ -n "$PROPERTY" ] || die $E_NO_RUN "$RUN has no violation"
  violates "$RUN" "$PROPERTY" || die $E_NO_RUN "$RUN did not break $PROPERTY"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  doctor)
    preflight
    signed="signed in (${#COOKIES[@]} cookie(s), ${#HEADERS[@]} header(s))"
    [ $((${#COOKIES[@]} + ${#HEADERS[@]})) -gt 0 ] || signed="no sign-in, since LOGIN and HEADERS are empty"
    echo "ok: bombadil $BOMBADIL_VERSION, sealed files intact, disposable $ORIGIN, $signed, evidence in $OUT_ROOT"
    ;;
  run|sweep)
    preflight; take_lock; bombadil_args
    if [ "$cmd" = run ]; then limit="${1:-5m}"; ARGS+=(--exit-on-violation); else limit="${1:-10m}"; fi
    out="$(new_run "$cmd")"
    RECORD="$out.exit"
    rc=0
    run_bombadil "$out.log" test "${ARGS[@]}" --time-limit "$limit" --output-path "$out" "$ORIGIN" "$SPEC" || rc=$?
    echo "run: $out (bombadil exit $rc, log $out.log)"
    recorded "$out"
    summarize "$out"
    code=0
    verdict "$out" || code=$?
    [ $code -eq 2 ] || explored "$out" || die 1 "bombadil ended early (exit $rc), before any property broke. See $out.log"
    end $code
    ;;
  shrink)
    run_dir_arg "${1:-}"; preflight; take_lock; bombadil_args
    property_arg "${2:-}"
    limit="${3:-5m}"
    rc=0
    run_bombadil "$RUN-shrunk.log" shrink "${ARGS[@]}" --trace "$RUN/trace.jsonl" --property "$PROPERTY" --time-limit "$limit" \
      --output-path "$RUN-shrunk" --output-path-overwrite "$ORIGIN" "$SPEC" || rc=$?
    [ $rc -eq 0 ] && [ -f "$RUN-shrunk/trace.jsonl" ] || die 1 "shrink of $PROPERTY failed (exit $rc). See $RUN-shrunk.log"
    echo "shrunk $PROPERTY: $RUN-shrunk"
    summarize "$RUN-shrunk"
    ;;
  repro)
    run_dir_arg "${1:-}"; preflight; take_lock; bombadil_args
    out="$RUN-repro"; rm -rf "$out"
    rc=0
    run_bombadil "$out.log" test "${ARGS[@]}" --reproduce "$RUN/trace.jsonl" --output-path "$out" "$ORIGIN" "$SPEC" || rc=$?
    recorded "$out"
    case $rc in
      0) replay_ended "$out" || die 1 "the replay was stopped before its last step. See $out.log"
         echo "repro: no violation (the steps ran and every property held)" ;;
      2) echo "repro: still fails"; summarize "$out" ;;
      *) echo "repro: diverged or errored (exit $rc). The UI no longer matches the recorded steps. See $out.log" ;;
    esac
    exit $rc
    ;;
  confirm)
    run_dir_arg "${1:-}"; preflight; take_lock; bombadil_args
    property_arg "${2:-}"
    limit="${3:-2m}"
    replay="$RUN-confirm-replay"; fresh="$RUN-confirm-fresh"; rm -rf "$replay" "$fresh"
    rc=0
    run_bombadil "$replay.log" test "${ARGS[@]}" --reproduce "$RUN/trace.jsonl" --output-path "$replay" "$ORIGIN" "$SPEC" || rc=$?
    if [ -s "$replay/trace.jsonl" ] && violates "$replay" "$PROPERTY"; then
      echo "confirm: $PROPERTY still breaks on the recorded steps"
      summarize "$replay"
      exit 2
    fi
    replayed=yes
    if replay_ended "$replay"; then
      echo "confirm: the recorded steps no longer break $PROPERTY"
    else
      replayed=""
      echo "confirm: the replay did not reach its last step (exit $rc). A fresh run follows, and it cannot confirm the fix alone."
    fi
    rc=0
    run_bombadil "$fresh.log" test "${ARGS[@]}" --time-limit "$limit" --output-path "$fresh" "$ORIGIN" "$SPEC" || rc=$?
    recorded "$fresh"
    checks "$fresh" "$PROPERTY"
    if violates "$fresh" "$PROPERTY"; then
      echo "confirm: $PROPERTY broke again in a fresh $limit run"
      summarize "$fresh"
      exit 2
    fi
    explored "$fresh" || die 1 "the fresh run ended early (exit $rc), so it confirmed nothing. See $fresh.log"
    asks "$fresh" --stepped || die 1 "the fresh run got no new state in its last half, so it confirmed nothing. See $fresh.log"
    echo "confirm: $PROPERTY held in a fresh $limit run. Read the coverage below before trusting it."
    summarize "$fresh"
    [ -n "$replayed" ] || exit $E_NO_REPLAY
    ;;
  report)
    run_dir_arg "${1:-}"
    summarize "$RUN" --html "$RUN/report.html"
    echo "report: $RUN/report.html"
    ;;
  summary) run_dir_arg "${1:-}"; summarize "$RUN" ;;
  inspect) run_dir_arg "${1:-}"; bombadil browser inspect "$RUN" ;;
  *) usage ;;
esac
