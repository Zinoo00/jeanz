#!/bin/bash
set -euo pipefail

SKILL="$(cd "$(dirname "$0")/.." && pwd)"
UPGRADE="$SKILL/../maintain-property-skill/scripts/upgrade.sh"
WORK="$(mktemp -d)"
EVIDENCE="$WORK/out"
cd "$WORK"
SERVER_PID=""
source "$SKILL/fixture/common.sh"

cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

fail() {
  echo "✘ props.sh against a stand-in bombadil — $*" >&2
  [ ! -f "$EVIDENCE/last.out" ] || tail -5 "$EVIDENCE/last.out" | cut -c1-200 | sed 's/^/    /' >&2
  exit 1
}
expect() {
  local want="$1" what="$2" got
  shift 2
  got="$(exit_of "$@")"
  [ "$got" -eq "$want" ] || fail "$what: exit $got, expected $want"
}
plan() { printf '%s\n' "$@" > "$STAND_IN_PLAN"; }
await_plan() {
  for _ in $(seq 100); do [ "$(wc -l < "$STAND_IN_PLAN" | tr -d ' ')" -le "$1" ] && return 0; sleep 0.1; done
  fail "the stand-in bombadil never started"
}
signal_stand_in() { pkill "-$1" -f "$WORK/standin/bombadil browser" || fail "no stand-in bombadil is running"; }
stopped_by_interrupt() {
  local left="$1" rc=0
  shift
  "$@" > "$EVIDENCE/last.out" 2>&1 &
  await_plan "$left"
  signal_stand_in INT
  wait $! || rc=$?
  echo $rc
}

mkdir -p "$WORK/bin" "$WORK/standin" "$WORK/traces" "$WORK/clock"
cat > "$WORK/standin/bombadil" <<'STAND_IN'
import json
import os
import signal
import sys
import time

args = sys.argv[1:]
if args[:1] == ["--version"]:
    print("bombadil " + (os.environ.get("STAND_IN_VERSION") or os.environ["STAND_IN_PIN"]))
    sys.exit(0)
out = args[args.index("--output-path") + 1] if "--output-path" in args else ""
print("Reproduce this test using:")
print("  bombadil " + " ".join(args), flush=True)
if os.path.isfile(f"{out}/trace.jsonl") and "--output-path-overwrite" not in args:
    sys.exit(f"Error: trace.jsonl already exists at {out}/trace.jsonl")
plan = os.environ["STAND_IN_PLAN"]
lines = open(plan, encoding="utf-8").read().splitlines()
fields = lines[0].split() if lines else []
code = int(fields[0]) if len(fields) > 0 else 0
trace = fields[1] if len(fields) > 1 else "clean"
pause = float(fields[2]) if len(fields) > 2 else 0
if trace != "none":
    os.makedirs(out, exist_ok=True)
    rows = [json.loads(line) for line in open(f"{os.environ['STAND_IN_TRACES']}/{trace}.jsonl", encoding="utf-8")]
    for row in rows:
        row["timestamp"] = int((time.time() + row["timestamp"]) * 1e6)
    open(f"{out}/trace.jsonl", "w", encoding="utf-8").write("".join(json.dumps(row) + "\n" for row in rows))
released = []


def interrupted(*_):
    print("Test was interrupted by SIGINT!", flush=True)
    os._exit(0)


signal.signal(signal.SIGINT, interrupted)
signal.signal(signal.SIGUSR1, lambda *_: released.append(True))
open(plan + ".rest", "w", encoding="utf-8").write("".join(line + "\n" for line in lines[1:]))
os.replace(plan + ".rest", plan)
until = time.monotonic() + pause
while not released and time.monotonic() < until:
    time.sleep(0.05)
found = ", finding 1 violation" if code == 2 else ""
if "--reproduce" in args:
    ending = f"Reproduction finished{found}!"
elif "--exit-on-violation" in args:
    ending = f"Test finished{found or ' after time limit'}!"
else:
    ending = f"Test finished after time limit{found}!"
if code != 1:
    print(ending)
sys.exit(code)
STAND_IN
printf '#!/bin/bash\nexec python3 -I "%s" "$@"\n' "$WORK/standin/bombadil" > "$WORK/bin/bombadil"
printf '#!/bin/bash\necho 20000101-000000\n' > "$WORK/clock/date"
chmod +x "$WORK/bin/bombadil" "$WORK/clock/date"
python3 -I - "$WORK/traces" <<'TRACES'
import json
import sys


SEALED = ["noConsoleErrors", "noHttpErrorCodes", "noUncaughtExceptions", "noUnhandledPromiseRejections", "noDangerousRequestAttempted", "noFailedRequests", "signedIn"]


def row(*broken, listed=("items", "billing"), reached=None, stopped=(), failed=(), action=None, page="app", app=("spinnerClears",), more=(), danger=("delete",), shot=None):
    return {
        "state": {"url": f"http://127.0.0.1/{page}.html", "screenshot": shot},
        "action": action,
        "snapshots": [
            {"name": "jeanzFeatures", "value": {"here": list(listed if reached is None else reached), "all": list(listed)}},
            {"name": "jeanzDanger", "value": {"rects": [{"name": name} for name in danger]}},
            {"name": "network", "value": "an app cell with a sealed cell's old name"},
            {"name": "jeanzNetwork", "value": {"blocked": list(stopped), "blockedCount": 2 * len(stopped), "failed": list(failed), "failedCount": 2 * len(failed)}},
            {"name": "jeanzProperties", "value": SEALED + list(app)},
            *more,
        ],
        "violations": [{"name": name, "violation": broke(name)} for name in broken],
    }


def broke(name):
    seen = [{"name": "seen", "value": name}, {"name": "long", "value": "x" * 400}, {"name": "nested", "value": {"rows": [0, 1, 2, 3, 4, 5, "y" * 400]}}]
    if name != "spinnerClears":
        return {"condition": f"() => {name}", "snapshots": seen}
    waited = {"Eventually": {"subformula": {"Thunk": {"function": "() => !spinner"}}, "reason": {"TimedOut": 1}}}
    return {"Implies": {"left": {"Thunk": {"function": "() => spinner"}}, "right": waited, "antecedent_snapshots": seen}}


def click(**fingerprint):
    return {"Click": {"fingerprint": fingerprint, "point": {"x": 1, "y": 1}}}


many = [f"{n:02}" for n in range(61)]
traces = {
    "clean": [row(reached=("items",)), row(reached=("billing",))],
    "unreached": [row(reached=("items",)), row(reached=())],
    "frozen": [row()],
    "stalled": [row(reached=("items",)), row(reached=("billing",))],
    "broken": [row(), row("noFailedRequests", shot="/elsewhere/shot.jpg")],
    "other": [row(), row("spinnerClears")],
    "story": [
        row(),
        row("noFailedRequests", action=click(id="save", tag="button", text_content="Save")),
        row("noFailedRequests", "spinnerClears", action={"TypeText": {"text": "a" * 50}}, page="archive"),
        row("noFailedRequests", action={"PressKey": {"code": 13}}, page="archive"),
        row("noFailedRequests", action={"Custom": {"name": "visit", "arguments": ["/archive.html?" + "q" * 60]}}, page="archive"),
        row("noFailedRequests", action="Reload", page="archive"),
        row("noFailedRequests", action=click(id="menu", tag="button", accessible_name="Open menu"), page="archive"),
        row("noFailedRequests", action=click(id="row-7", tag="td"), page="archive"),
        row("noFailedRequests", action=click(tag="a"), page="archive"),
        row("noFailedRequests", "noConsoleErrors", action=click(tag="button", text_content="Done"), page="archive"),
    ],
    "gone": [row(reached=("items",), app=()), row(reached=("billing",), app=())],
    "clash": [row(more=[{"name": "jeanzNetwork", "value": "an app cell with a sealed cell's name"}])],
    "unlisted": [
        row(listed=(), stopped=["fetch POST /a"], danger=("wipe all",)),
        row(listed=(), stopped=["fetch POST /a", "xhr DELETE /b"], failed=["GET /c -> 500"], danger=("close account",)),
    ],
    "wide": [row(stopped=[f"fetch POST /{n}" for n in many], failed=[f"GET /{n} -> 500" for n in many], danger=[f"delete {n}" for n in many])]
    + [row(page=f"page{n}") for n in range(8)],
}
for name, rows in traces.items():
    for i, r in enumerate(rows):
        r["timestamp"] = 60 * (i + 1 - len(rows)) - 120 * (name == "stalled")
    for later in rows[1:]:
        later["action"] = later["action"] or "Back"
for name, rows in traces.items():
    with open(f"{sys.argv[1]}/{name}.jsonl", "w", encoding="utf-8") as trace:
        trace.write("".join(json.dumps(r) + "\n" for r in rows))
TRACES
export PATH="$WORK/bin:$PATH" STAND_IN_PLAN="$WORK/plan" STAND_IN_TRACES="$WORK/traces"
export STAND_IN_PIN="$(sed -n 's/^BOMBADIL_VERSION="\(.*\)"$/\1/p' "$SKILL/templates/props.sh")"
plan

start_fixture
A="$(copy main "$(login_with right)" yes)"

expect 0 "doctor on a good setup" "$A/props.sh" doctor
STAND_IN_VERSION=0.0.1 expect 10 "doctor with another bombadil version" "$A/props.sh" doctor
B="$(copy wrongpass "$(login_with wrong)" yes)"
expect 14 "doctor with a login that sets no cookie" "$B/props.sh" doctor
B="$(copy bogus "echo session=bogus" yes)"
expect 15 "doctor with a cookie that does not sign in" "$B/props.sh" doctor
B="$(copy noready "$(login_with right)" yes)"
perl -pi -e 's/^READY_TEXT=.*/READY_TEXT="text the page never shows"/' "$B/props.config.sh"
expect 15 "doctor with a page that lacks the ready text" "$B/props.sh" doctor
B="$(copy notdisposable "$(login_with right)" "")"
expect 12 "doctor with an instance not marked disposable" "$B/props.sh" doctor
B="$(copy elsewhere "$(login_with right)" yes)"
perl -pi -e "s{^(ORIGIN|READY_URL)=\"http://127\\.0\\.0\\.1:}{\$1=\"http://fixture.localhost:}" "$B/props.config.sh"
expect 12 "doctor with a host that is neither this machine nor listed" "$B/props.sh" doctor
perl -pi -e 's/^DISPOSABLE_HOSTS=\(\)/DISPOSABLE_HOSTS=(fixture.localhost)/' "$B/props.config.sh"
expect 0 "doctor with a host listed in DISPOSABLE_HOSTS" "$B/props.sh" doctor
B="$(copy localhost "$(login_with right)" yes)"
perl -pi -e 's{^(ORIGIN|READY_URL)="http://127\.0\.0\.1:}{$1="http://localhost:}' "$B/props.config.sh"
expect 0 "doctor with an ORIGIN on localhost" "$B/props.sh" doctor
for lookalike in localhost.fixture 127.0.0.1.fixture; do
  B="$(copy "like-$lookalike" "$(login_with right)" yes)"
  perl -pi -e "s{^(ORIGIN|READY_URL)=\"http://127\\.0\\.0\\.1:}{\$1=\"http://$lookalike:}" "$B/props.config.sh"
  grep -q "^ORIGIN=\"http://$lookalike:" "$B/props.config.sh" || fail "could not point the test copy at $lookalike"
  expect 12 "doctor with the host $lookalike, which only starts like this machine's name" "$B/props.sh" doctor
done
B="$(copy ipv6 "$(login_with right)" yes)"
perl -pi -e 's{^(ORIGIN|READY_URL)="http://127\.0\.0\.1:}{$1="http://[::1]:}' "$B/props.config.sh"
expect 20 "doctor with this machine's IPv6 address, where the fixture does not listen" "$B/props.sh" doctor
B="$(copy otherhost "$(login_with right)" yes)"
perl -pi -e 's{^READY_URL="http://127\.0\.0\.1:}{READY_URL="http://localhost:}' "$B/props.config.sh"
expect 12 "doctor with a READY_URL on another host name than ORIGIN" "$B/props.sh" doctor
grep -q 'READY_URL' "$EVIDENCE/last.out" || fail "doctor did not name READY_URL as the setting that leaves the instance"
B="$(copy otherport "$(login_with right)" yes)"
perl -pi -e 's{^READY_URL="http://127\.0\.0\.1:\d+}{READY_URL="http://127.0.0.1:9}' "$B/props.config.sh"
expect 12 "doctor with a READY_URL on another port than ORIGIN" "$B/props.sh" doctor
B="$(copy nologin "" yes)"
printf 'READY_URL="%s/login.html"\nREADY_TEXT="Sign in"\n' "$BASE" >> "$B/props.config.sh"
expect 0 "doctor for an app with no sign-in" "$B/props.sh" doctor
grep -q 'no sign-in' "$EVIDENCE/last.out" || fail "doctor did not say that the settings hold no sign-in"
if grep -q 'signed in' "$EVIDENCE/last.out"; then fail "doctor said signed in with no cookie and no header"; fi
B="$(copy headerlogin "" yes)"
perl -pi -e 's/^HEADERS=\(\)/HEADERS=("X-Session=fixture-ok")/' "$B/props.config.sh"
expect 0 "doctor with a sign-in that only a header carries" "$B/props.sh" doctor
grep -q 'signed in (0 cookie(s), 1 header(s))' "$EVIDENCE/last.out" || fail "doctor did not count the header that signs in"
B="$(copy twocookies "$(login_with right); echo theme=dark" yes)"
expect 0 "doctor with a login that prints two cookies" "$B/props.sh" doctor
grep -q 'signed in (2 cookie(s), 0 header(s))' "$EVIDENCE/last.out" || fail "doctor did not count both cookies"
plan "0 clean"
expect 0 "a run with two cookies" "$B/props.sh" run 1s
[ "$(grep -o -- "--cookie <redacted>" "$(run_dir_of "$(cat "$EVIDENCE/last.out")").log" | wc -l | tr -d ' ')" -eq 2 ] || fail "a run did not pass each cookie to bombadil"
B="$(copy nosetting "$(login_with right)" yes)"
perl -ni -e 'print unless /^READY_TEXT=/' "$B/props.config.sh"
expect 19 "doctor with a missing setting" "$B/props.sh" doctor
B="$(copy tampered "$(login_with right)" yes)"
echo "export const edited = true;" >> "$B/spec/guard.ts"
expect 11 "doctor with an edited sealed file" "$B/props.sh" doctor
expect 2 "an upgrade over an edited sealed file" "$UPGRADE" "$B"
grep -q 'spec/guard.ts was edited here' "$EVIDENCE/last.out" || fail "the upgrade did not say that it replaced an edited file"
grep -q 'export const edited = true;' "$B/replaced/guard.ts" || fail "the upgrade did not keep the edit that it replaced"
expect 0 "doctor after the upgrade" "$B/props.sh" doctor
expect 2 "a second upgrade while the kept edit is still there" "$UPGRADE" "$B"
grep -q 'replaced/ still holds' "$EVIDENCE/last.out" || fail "the upgrade did not say that a kept edit is waiting"
rm -r "$B/replaced"
expect 0 "an upgrade with nothing left to do" "$UPGRADE" "$B"
cmp -s "$B/spec/guard.ts" "$SKILL/templates/spec/guard.ts" || fail "the upgrade did not restore the sealed file"
cmp -s "$B/spec/config.ts" "$SKILL/fixture/config.ts" || fail "the upgrade touched the app's config"
B="$(copy rehashed "$(login_with right)" yes)"
perl -pi -e 's/^export function safe\(action: ActionTemplate\): boolean \{$/$&\n  return true;/' "$B/spec/guard.ts"
grep -q '^  return true;$' "$B/spec/guard.ts" || fail "could not edit the guard in the test copy"
reseal "$B"
expect 0 "doctor after an edit whose checksum was written into the seal record" "$B/props.sh" doctor
expect 2 "an upgrade over an edit whose checksum was written into the seal record" "$UPGRADE" "$B"
grep -q '^  return true;$' "$B/replaced/guard.ts" || fail "the upgrade kept no copy of an edit that the seal record vouched for"
cmp -s "$B/spec/guard.ts" "$SKILL/templates/spec/guard.ts" || fail "the upgrade did not restore the guard"
expect 0 "doctor after an upgrade over a seal record that vouched for an edit" "$B/props.sh" doctor
B="$(copy guide "$(login_with right)" yes)"
echo "Skip the doctor." >> "$B/GUIDE.md"
expect 11 "doctor with an edited guide" "$B/props.sh" doctor
expect 2 "an upgrade over an edited guide" "$UPGRADE" "$B"
cmp -s "$B/GUIDE.md" "$SKILL/templates/GUIDE.md" || fail "the upgrade did not restore the guide"
expect 64 "an unknown command" "$A/props.sh" frobnicate
expect 64 "no command" "$A/props.sh"
for command in $(grep -oE '\./props\.sh [a-z]+' "$SKILL/templates/GUIDE.md" | awk '{print $2}' | sort -u); do
  grep -q "^  $command " "$EVIDENCE/last.out" || fail "the guide names the command $command, and props.sh has none"
done
expect 18 "a summary of a folder that is not a run" "$A/props.sh" summary "$WORK/nowhere"

plan "0 clean"
expect 0 "a run with no violation" "$A/props.sh" run 1s
clean="$(run_dir_of "$(cat "$EVIDENCE/last.out")")"
grep -q -- '--exit-on-violation' "$clean.log" || fail "run did not tell bombadil to stop at the first violation"
grep -q -- ' --headless .* --time-limit 1s ' "$clean.log" || fail "run did not tell bombadil to run headless for LIMIT"
[ "$(cat "$clean.exit")" = 0 ] || fail "a run that passed left no record of exit 0"
grep -qF "log $clean.log)" "$EVIDENCE/last.out" || fail "a run did not name its log"
grep -q '"states": 2' "$EVIDENCE/last.out" || fail "a run printed no summary"
grep -q '"features_listed": 2' "$EVIDENCE/last.out" || fail "the summary does not count the listed features"
for field in $(grep -oE '`[a-z]+(_[a-z]+)+`' "$SKILL/templates/GUIDE.md" | tr -d '`' | sort -u); do
  grep -q "\"$field\"" "$EVIDENCE/last.out" || fail "the guide names the field $field, and the summary has none"
done
plan "0 unlisted"
expect 3 "a run with no listed feature" "$A/props.sh" run 1s
grep -q 'FEATURES is empty' "$EVIDENCE/last.out" || fail "a run with no listed feature did not say why it exits 3"
grep -q '"features_listed": 0' "$EVIDENCE/last.out" || fail "the summary does not show that no feature is listed"
grep -q '"requests_blocked": 4' "$EVIDENCE/last.out" || fail "the summary does not count the stopped requests"
[ "$(grep -cE '"(fetch POST /a|xhr DELETE /b)"' "$EVIDENCE/last.out")" -eq 2 ] || fail "the summary does not list each stopped request once"
grep -q '"requests_failed": 2' "$EVIDENCE/last.out" && grep -q '"GET /c -> 500"' "$EVIDENCE/last.out" || fail "the summary does not count and list the failed requests"
[ "$(grep -cE '"(wipe all|close account)"' "$EVIDENCE/last.out")" -eq 2 ] || fail "the summary does not list the dangerous controls of every state"
plan "0 unreached"
expect 3 "a run that broke nothing and missed a listed feature" "$A/props.sh" sweep 1s
grep -q 'did not reach: billing' "$EVIDENCE/last.out" || fail "a run that missed a feature did not name it"
[ "$(cat "$(run_dir_of "$(cat "$EVIDENCE/last.out")").exit")" = 3 ] || fail "a run that missed a feature left no record of exit 3"
grep -q '"features_not_reached"' "$EVIDENCE/last.out" || fail "a run that missed a feature printed no summary"
if grep -q -- '--exit-on-violation' "$(run_dir_of "$(cat "$EVIDENCE/last.out")").log"; then fail "sweep told bombadil to stop at the first violation"; fi
plan "0 frozen"
expect 3 "a run whose first page never answered" "$A/props.sh" run 1s
grep -q 'the last of 1 came' "$EVIDENCE/last.out" || fail "a run whose first page never answered did not say why it exits 3"
plan "0 stalled"
expect 3 "a run that got no new state in its last half" "$A/props.sh" run 1s
grep -q 'the last of 2 came 12. s before its end' "$EVIDENCE/last.out" || fail "a run that stopped getting states did not say when the last one came"
plan "0 wide"
expect 0 "a run with more to list than the summary holds" "$A/props.sh" run 1s
python3 -I - "$EVIDENCE/last.out" <<'WIDE' || fail "the summary does not cut its lists to 60 entries and its pages to 8"
import json, sys
text = open(sys.argv[1], encoding="utf-8").read()
coverage = json.loads(text[text.index("{") : text.rindex("}") + 1])["coverage"]
sizes = [len(coverage[key]) for key in ("dangerous_controls_skipped", "requests_blocked_distinct", "requests_failed_distinct", "urls")]
sys.exit(0 if sizes == [60, 60, 60, 8] else f"sizes: {sizes}")
WIDE
plan "0 clean"
expect 0 "a sweep with no LIMIT" "$A/props.sh" sweep
grep -q -- ' --time-limit 10m ' "$(run_dir_of "$(cat "$EVIDENCE/last.out")").log" || fail "a sweep with no LIMIT did not explore for 10 minutes"
plan "2 story"
expect 2 "a sweep that breaks three properties" "$A/props.sh" sweep 1s
python3 -I - "$EVIDENCE/last.out" <<'STORY' || fail "the summary of a run with three broken properties is wrong"
import json, sys
text = open(sys.argv[1], encoding="utf-8").read()
summary = json.loads(text[text.index("{") : text.rindex("}") + 1])
first, second, third = summary["violations"]
want = {
    "order": [first["property"], second["property"], third["property"]] == ["noFailedRequests", "spinnerClears", "noConsoleErrors"],
    "count": [first["count"], second["count"], third["count"]] == [9, 1, 1],
    "first_state": [first["first_state"], second["first_state"], third["first_state"]] == [1, 2, 9],
    "steps_before": third["steps_before"]
    == ["Click 'Save'", 'TypeText "' + "a" * 39, "PressKey key 13", 'visit ["/archive.html?' + "q" * 44, "Reload", "Click 'Open menu'", "Click 'row-7'", "Click 'a'", "Click 'Done'"],
    "condition": first["condition"] == "() => noFailedRequests",
    "evidence": first["evidence"] == {"seen": "noFailedRequests", "long": "x" * 300 + "...", "nested": {"rows": [2, 3, 4, 5, "y" * 300 + "..."]}},
    "waited": second["condition"] == "() => spinner; () => !spinner" and second["evidence"]["seen"] == "spinnerClears",
    "urls": summary["coverage"]["urls"] == {"http://127.0.0.1/archive.html": 8, "http://127.0.0.1/app.html": 2},
    "actions": summary["coverage"]["actions"] == {"Click": 5, "TypeText": 1, "PressKey": 1, "Custom": 1, "Reload": 1},
    "properties": summary["properties"][-2:] == ["signedIn", "spinnerClears"] and len(summary["properties"]) == 8,
}
wrong = [name for name, held in want.items() if not held]
sys.exit(f"wrong fields: {', '.join(wrong)}" if wrong else 0)
STORY
plan "2 broken"
expect 2 "a run with a violation" "$A/props.sh" run 1s
broken="$(run_dir_of "$(cat "$EVIDENCE/last.out")")"
grep -q '"property": "noFailedRequests"' "$EVIDENCE/last.out" || fail "a run did not name the property it broke"
grep -q '"screenshot": "(missing) /elsewhere/shot.jpg"' "$EVIDENCE/last.out" || fail "the summary does not say that a screenshot is missing"
grep -qE '^ +"Back"$' "$EVIDENCE/last.out" || fail "the steps before a violation do not name a step back"
grep -qE '^ +"start",$' "$EVIDENCE/last.out" || fail "the steps before a violation do not begin at the start"
mkdir "$broken/screenshots" && : > "$broken/screenshots/shot.jpg"
expect 0 "a summary of a run" "$A/props.sh" summary "$broken"
grep -qF "\"screenshot\": \"$broken/screenshots/shot.jpg\"" "$EVIDENCE/last.out" || fail "the summary does not point at the screenshot that the run folder holds"
plan "1 none"
expect 17 "a run that recorded no state" "$A/props.sh" run 1s
plan "1 clean"
expect 1 "a run that bombadil failed" "$A/props.sh" run 1s
[ "$(cat "$(run_dir_of "$(cat "$EVIDENCE/last.out")").exit")" = 1 ] || fail "a run that bombadil failed left no record of exit 1"
plan "1 broken"
expect 2 "a run that bombadil failed after a property broke" "$A/props.sh" run 1s

plan "0 clean" "0 clean"
first="$(run_dir_of "$(PATH="$WORK/clock:$PATH" "$A/props.sh" run 1s)")"
second="$(run_dir_of "$(PATH="$WORK/clock:$PATH" "$A/props.sh" run 1s)")"
[ -s "$first/trace.jsonl" ] && [ -s "$second/trace.jsonl" ] && [ "$first" != "$second" ] || fail "two runs that started in the same second share a folder ($first, $second)"

plan "0 clean 30"
"$A/props.sh" run 1s > "$EVIDENCE/holder.out" 2>&1 &
holder=$!
await_plan 0
lock="$(find "$WORK" -maxdepth 2 -name '.lock-*')"
[ "$(readlink "$lock")" = "$holder" ] || fail "a run took no lock that names it"
B="$(copy samehost "$(login_with right)" yes)"
perl -pi -e 's{^ORIGIN=.*}{ORIGIN="'"$BASE"'/archive.html"}' "$B/props.config.sh"
expect 16 "a run from another page of the instance that the first run holds" "$B/props.sh" run 1s
B="$(copy lane "$(login_with right)" yes)"
echo "OUT_ROOT=\"$WORK/lane-out\"" >> "$B/props.config.sh"
expect 16 "a run that keeps its evidence in another folder, on the instance that the first run holds" "$B/props.sh" run 1s
expect 16 "a second run while the first holds the instance" "$A/props.sh" run 1s
signal_stand_in USR1
wait "$holder" || fail "the run that held the lock failed"
[ ! -e "$lock" ] && [ ! -L "$lock" ] || fail "a finished run left its lock behind"
ln -s 999999 "$lock"
plan "0 clean"
expect 0 "a run after a lock whose owner is gone" "$A/props.sh" run 1s
[ ! -e "$lock" ] && [ ! -L "$lock" ] || fail "a run that took over a lock left it behind"
plan "0 clean 30"
"$A/props.sh" sweep 1s > "$EVIDENCE/holder.out" 2>&1 &
holder=$!
await_plan 0
[ "$(readlink "$lock")" = "$holder" ] || fail "a sweep took no lock that names it"
expect 16 "a shrink while a sweep holds the instance" "$A/props.sh" shrink "$broken"
expect 16 "a replay while a sweep holds the instance" "$A/props.sh" repro "$broken"
expect 16 "a confirm while a sweep holds the instance" "$A/props.sh" confirm "$broken" noFailedRequests 1s
signal_stand_in USR1
wait "$holder" || fail "the sweep that held the lock failed"

plan "0 clean 30"
"$A/props.sh" run 1s > "$EVIDENCE/holder.out" 2>&1 &
holder=$!
disown "$holder"
await_plan 0
stopped="$(find "$EVIDENCE" -name '*.exit' -empty)"
kill -TERM "$holder"
for _ in $(seq 50); do kill -0 "$holder" 2> /dev/null || pgrep -f "$WORK/standin/bombadil browser" > /dev/null || break; sleep 0.1; done
[ -n "$stopped" ] && [ ! -s "$stopped" ] || fail "a run that was stopped left a record that says how it ended"
[ ! -L "$lock" ] || fail "a run that was stopped left its lock behind"
pgrep -f "$WORK/standin/bombadil browser" > /dev/null && fail "a run that was stopped left bombadil running"
plan "0 clean 30"
[ "$(stopped_by_interrupt 0 "$A/props.sh" run 1s)" -eq 1 ] || fail "a run that an interrupt stopped did not exit 1"
[ "$(cat "$(run_dir_of "$(cat "$EVIDENCE/last.out")").exit")" = 1 ] || fail "a run that an interrupt stopped left no record of exit 1"
plan "0 clean 30"
[ "$(stopped_by_interrupt 0 "$A/props.sh" repro "$broken")" -eq 1 ] || fail "a replay that an interrupt stopped did not exit 1"
plan "0 clean 30" "0 clean"
[ "$(stopped_by_interrupt 1 "$A/props.sh" confirm "$broken" noFailedRequests 1s)" -eq 21 ] || fail "confirm did not exit 21 when an interrupt stopped its replay"
plan "0 clean" "0 clean 30"
[ "$(stopped_by_interrupt 0 "$A/props.sh" confirm "$broken" noFailedRequests 1s)" -eq 1 ] || fail "confirm did not exit 1 when an interrupt stopped its fresh run"
B="$(copy readonly "$(login_with right)" yes)"
mkdir "$WORK/readonly-out" && chmod 555 "$WORK/readonly-out"
echo "OUT_ROOT=\"$WORK/readonly-out\"" >> "$B/props.config.sh"
expect 1 "a run that cannot write its record" "$B/props.sh" run 1s
grep -q 'cannot write a run record' "$EVIDENCE/last.out" || fail "a run that cannot write its record did not say so"
chmod 755 "$WORK/readonly-out"
plan "0 clash"
expect 13 "a run whose app names a cell as a sealed file does" "$A/props.sh" run 1s
grep -q 'jeanzNetwork' "$EVIDENCE/last.out" || fail "the run did not name the cell that an app file took"

plan "0 broken"
expect 0 "a shrink" "$A/props.sh" shrink "$broken/"
[ -s "$broken-shrunk/trace.jsonl" ] || fail "a shrink wrote no trace"
grep -q -- ' --time-limit 5m ' "$broken-shrunk.log" || fail "a shrink with no LIMIT did not try for 5 minutes"
plan "0 broken"
expect 0 "a second shrink of the same run" "$A/props.sh" shrink "$broken" noFailedRequests 9s
grep -q -- ' --time-limit 9s ' "$broken-shrunk.log" || fail "shrink did not try for LIMIT"
plan "1 none"
expect 1 "a shrink that bombadil failed" "$A/props.sh" shrink "$broken"
expect 18 "a shrink of a run with no violation" "$A/props.sh" shrink "$clean"
plan "2 broken"
expect 2 "a replay that still fails" "$A/props.sh" repro "$broken"
plan "0 clean"
expect 0 "a replay that passes" "$A/props.sh" repro "$broken"

plan "2 broken"
expect 2 "confirm while the recorded steps still break the property" "$A/props.sh" confirm "$broken" noFailedRequests 1s
plan "0 clean" "2 broken"
expect 2 "confirm while a fresh run breaks the property" "$A/props.sh" confirm "$broken" noFailedRequests 1s
plan "0 clean" "2 other"
expect 0 "confirm when a fresh run breaks only another property" "$A/props.sh" confirm "$broken" noFailedRequests
grep -q -- ' --time-limit 2m ' "$broken-confirm-fresh.log" || fail "confirm with no LIMIT did not explore for 2 minutes"
plan "0 clean" "0 clean"
expect 0 "confirm after a fix" "$A/props.sh" confirm "$broken" noFailedRequests 7s
grep -q 'held in a fresh' "$EVIDENCE/last.out" || fail "confirm did not say that the property held"
grep -q '"states": 2' "$EVIDENCE/last.out" || fail "confirm printed no coverage after it told the reader to read it"
grep -q -- ' --time-limit 7s ' "$broken-confirm-fresh.log" || fail "confirm did not run its fresh run for LIMIT"
plan "0 none"
expect 0 "inspect" "$A/props.sh" inspect "$broken"
grep -qF "bombadil browser inspect $broken" "$EVIDENCE/last.out" || fail "inspect did not open bombadil's trace viewer on the run"

expect 0 "a report" "$A/props.sh" report "$broken"
grep -q 'noFailedRequests' "$broken/report.html" || fail "the report does not name the broken property"

if grep -l "fixture-ok" "$EVIDENCE"/*.log > /dev/null 2>&1; then fail "a log contains the session cookie"; fi

expect 18 "confirm for a property the run did not break" "$A/props.sh" confirm "$broken" noConsoleErrors 1s
grep -q 'did not break noConsoleErrors' "$EVIDENCE/last.out" || fail "confirm did not say that the run never broke the property"
expect 18 "shrink for a property the run did not break" "$A/props.sh" shrink "$broken" noConsoleErrors
B="$(copy readycode "$(login_with right)" yes)"
printf 'READY_URL="%s/known.html"\nREADY_TEXT="Known issues"\n' "$BASE" >> "$B/props.config.sh"
expect 15 "doctor with a READY_URL that shows its text on an error page" "$B/props.sh" doctor
grep -q 'answered 500' "$EVIDENCE/last.out" || fail "doctor did not name the status that READY_URL answered"
plan "0 clean" "1 clean"
expect 1 "confirm when the fresh run failed" "$A/props.sh" confirm "$broken" noFailedRequests 1s
plan "0 clean" "0 stalled"
expect 1 "confirm when the fresh run stopped getting states" "$A/props.sh" confirm "$broken" noFailedRequests 1s
grep -q 'no new state in its last half' "$EVIDENCE/last.out" || fail "confirm did not say that its fresh run stopped getting states"
B="$(copy badsettings "$(login_with right)" yes)"
echo 'WIDTH="unterminated' >> "$B/props.config.sh"
expect 19 "a settings file with a syntax error" "$B/props.sh" doctor
B="$(copy nosettings "$(login_with right)" yes)"
rm "$B/props.config.sh"
expect 19 "no settings file" "$B/props.sh" doctor
B="$(copy down "$(login_with right)" yes)"
perl -pi -e 's{^(ORIGIN|READY_URL)="http://127\.0\.0\.1:\d+}{$1="http://127.0.0.1:9}' "$B/props.config.sh"
expect 20 "an instance that does not answer" "$B/props.sh" doctor

B="$(copy headers "$(login_with right)" yes)"
perl -pi -e 's/^HEADERS=\(\)/HEADERS=("X-Note=alpha beta gamma" "X-Flag=1")/' "$B/props.config.sh"
plan "0 clean"
expect 0 "a run with headers and no LIMIT" "$B/props.sh" run
headers_log="$(run_dir_of "$(cat "$EVIDENCE/last.out")").log"
grep -q -- ' --time-limit 5m ' "$headers_log" || fail "a run with no LIMIT did not explore for 5 minutes"
if grep -q "beta gamma" "$headers_log"; then fail "a log contains a header's value"; fi
grep -q -- "--width 1024" "$headers_log" || fail "redaction removed more than the secrets"
[ "$(grep -o -- "--header <redacted>" "$headers_log" | wc -l | tr -d ' ')" -eq 2 ] || fail "a run did not pass each header to bombadil"
grep -q -- "--height 768" "$headers_log" || fail "a run did not pass HEIGHT to bombadil"
perl -pi -e 's/^BOMBADIL_ARGS=\(\)/BOMBADIL_ARGS=(--seed 7)/' "$B/props.config.sh"
plan "0 clean"
expect 0 "a run with BOMBADIL_ARGS" "$B/props.sh" run 1s
grep -q -- "--seed 7" "$(run_dir_of "$(cat "$EVIDENCE/last.out")").log" || fail "a run did not pass BOMBADIL_ARGS to bombadil"

B="$(copy unlisted "$(login_with right)" yes)"
perl -ni -e 'print unless m{ spec/guard\.ts$}' "$B/SEALED.sha256"
echo "export const edited = true;" >> "$B/spec/guard.ts"
expect 11 "doctor with a sealed file missing from the seal record" "$B/props.sh" doctor
B="$(copy stray "$(login_with right)" yes)"
echo "export const extra = true;" > "$B/spec/stray.ts"
expect 11 "doctor with a file among the sealed files that the seal record does not list" "$B/props.sh" doctor
expect 2 "an upgrade over a file that is not sealed" "$UPGRADE" "$B"
grep -q 'spec/stray.ts' "$EVIDENCE/last.out" || fail "the upgrade did not name the file that is not sealed"
mkdir "$B/spec/app" && mv "$B/spec/stray.ts" "$B/spec/app/stray.ts"
expect 0 "doctor with an app's extra file in a folder under spec" "$B/props.sh" doctor
B="$(copy oldpin "$(login_with right)" yes)"
echo 'BOMBADIL_VERSION="0.0.1"' >> "$B/props.config.sh"
expect 0 "doctor when the settings name another bombadil version" "$B/props.sh" doctor

B="$(copy noorigin "$(login_with right)" yes)"
perl -pi -e 's/^ORIGIN=.*/ORIGIN=""/' "$B/props.config.sh"
expect 19 "doctor with no ORIGIN" "$B/props.sh" doctor
for placeholder in app run-command stop-command; do
  B="$(copy "unfilled-$placeholder" "$(login_with right)" yes)"
  echo "Still to fill: <$placeholder>." >> "$B/SKILL.md"
  expect 19 "doctor with <$placeholder> left in SKILL.md" "$B/props.sh" doctor
done
B="$(copy noskill "$(login_with right)" yes)"
rm "$B/SKILL.md"
expect 19 "doctor with no SKILL.md" "$B/props.sh" doctor
B="$(copy defaultroot "$(login_with right)" yes)"
grep '^OUT_ROOT=' "$SKILL/templates/props.config.sh" > "$WORK/out-root"
perl -ni -e 'print unless /^OUT_ROOT=/' "$B/props.config.sh"
cat "$WORK/out-root" >> "$B/props.config.sh"
plan "0 clean"
HOME="$WORK/home" expect 0 "a run with the default OUT_ROOT" "$B/props.sh" run 1s
[ -d "$WORK/home/.jeanz/properties/defaultroot-$(printf %s "$(cd "$B" && pwd -P)" | cksum | cut -d' ' -f1)" ] || fail "the default OUT_ROOT is not named for the skill's folder and its path"

B="$(copy older "$(login_with right)" yes)"
rm "$B/spec/rules.ts"
perl -ni -e 'print unless /^WIDTH=/' "$B/props.config.sh"
perl -ni -e 'print unless /^export const SIGNED_OUT/' "$B/spec/config.ts"
expect 2 "an upgrade of a skill whose app files lack a setting" "$UPGRADE" "$B"
grep -q 'updated spec/rules.ts' "$EVIDENCE/last.out" || fail "the upgrade did not add a sealed file that the skill lacked"
grep -q 'props.config.sh lacks WIDTH' "$EVIDENCE/last.out" || fail "the upgrade did not name the setting that props.config.sh lacks"
grep -q 'spec/config.ts lacks SIGNED_OUT' "$EVIDENCE/last.out" || fail "the upgrade did not name the list that spec/config.ts lacks"
expect 64 "an upgrade of a folder that is not a property skill" "$UPGRADE" "$WORK"
B="$(copy renamed "$(login_with right)" yes)"
sed 's/DEFAULTS/STARTERS/' "$B/spec/defaults.ts" > "$B/spec/starters.ts"
rm "$B/spec/defaults.ts"
perl -pi -e 's/DEFAULTS/STARTERS/g; s{\./defaults\.ts}{./starters.ts}' "$B/spec/config.ts"
(cd "$B" && sha props.sh summarize.py GUIDE.md $(ls spec/*.ts | grep -vE '/(config|actions|properties)\.ts$') > SEALED.sha256)
echo "../escape.txt" > "$WORK/escape.txt"
echo "0000  ../escape.txt" >> "$B/SEALED.sha256"
expect 2 "an upgrade over a file that jeanz never shipped, though the seal record lists it" "$UPGRADE" "$B"
grep -q 'spec/starters.ts is not a sealed file' "$EVIDENCE/last.out" && [ -f "$B/spec/starters.ts" ] || fail "the upgrade removed a file that jeanz never shipped, or did not name it"
mkdir -p "$WORK/jeanz/skills"
cp -R "$SKILL" "$WORK/jeanz/skills/create-property-skill"
cp -R "$SKILL/../maintain-property-skill" "$WORK/jeanz/skills/maintain-property-skill"
(cd "$B" && sha spec/starters.ts) >> "$WORK/jeanz/skills/create-property-skill/sealed-history.txt"
expect 2 "an upgrade of a skill that holds a sealed file jeanz no longer ships" "$WORK/jeanz/skills/maintain-property-skill/scripts/upgrade.sh" "$B"
grep -q 'removed spec/starters.ts' "$EVIDENCE/last.out" && [ ! -e "$B/spec/starters.ts" ] || fail "the upgrade did not remove the sealed file that jeanz no longer ships"
grep -q 'spec/config.ts imports ./starters.ts' "$EVIDENCE/last.out" || fail "the upgrade did not name the import that no longer resolves"
[ -f "$WORK/escape.txt" ] || fail "the upgrade removed a file outside the skill's folder"
[ ! -d "$B/replaced" ] || fail "the upgrade kept a copy of a sealed file that nobody had edited"
B="$(copy olderfile "$(login_with right)" yes)"
echo "export const older = true;" >> "$B/spec/guard.ts"
(cd "$B" && sha spec/guard.ts) >> "$WORK/jeanz/skills/create-property-skill/sealed-history.txt"
expect 0 "an upgrade over a sealed file that an older jeanz shipped" "$WORK/jeanz/skills/maintain-property-skill/scripts/upgrade.sh" "$B"
grep -q 'updated spec/guard.ts' "$EVIDENCE/last.out" && cmp -s "$B/spec/guard.ts" "$SKILL/templates/spec/guard.ts" || fail "the upgrade did not replace a sealed file that an older jeanz shipped"
[ ! -d "$B/replaced" ] || fail "the upgrade kept a copy of a file that an older jeanz shipped"
B="$(copy copied "$(login_with right)" yes)"
cp "$B/spec/rules.ts" "$B/spec/copied.ts"
expect 2 "an upgrade over a file that copies a sealed file under another name" "$UPGRADE" "$B"
grep -q 'spec/copied.ts is not a sealed file' "$EVIDENCE/last.out" && [ -f "$B/spec/copied.ts" ] || fail "the upgrade removed a file because another sealed file has the same text"

setting() {
  local name="$1" line="$2" dest
  dest="$(copy "$name" "$(login_with right)" yes)"
  echo "$line" >> "$dest/props.config.sh"
  echo "$dest"
}
expect 19 "a setting that reads a variable nobody set" "$(setting unsetvar 'WIDTH="$NO_SUCH_SETTING"')/props.sh" doctor
expect 19 "a setting whose command fails" "$(setting failing 'HEIGHT="$(exit 3)"')/props.sh" doctor
expect 19 "a width that is not a number" "$(setting wide 'WIDTH=wide')/props.sh" doctor
expect 19 "a blank READY_TEXT" "$(setting blanktext 'READY_TEXT=" "')/props.sh" doctor
expect 19 "no READY_URL" "$(setting noreadyurl 'READY_URL=""')/props.sh" doctor
expect 12 "BOMBADIL_ARGS that widen where the run goes" "$(setting leaves 'BOMBADIL_ARGS=(--allow-url "https://*/*")')/props.sh" doctor
B="$(copy publicready "echo session=bogus" yes)"
printf 'READY_URL="%s/login.html"\nREADY_TEXT="Sign in"\n' "$BASE" >> "$B/props.config.sh"
expect 19 "a READY_URL that shows READY_TEXT to anyone" "$B/props.sh" doctor
B="$(copy bigpublic "echo session=bogus" yes)"
printf 'READY_URL="%s/big.html"\nREADY_TEXT="Sign in"\n' "$BASE" >> "$B/props.config.sh"
expect 19 "a long READY_URL page that shows READY_TEXT to anyone" "$B/props.sh" doctor
B="$(copy loginexit "echo session=fixture-ok; exit 3" yes)"
expect 14 "a LOGIN that prints a cookie and fails" "$B/props.sh" doctor
mkdir "$WORK/unedited"
cp -R "$SKILL/templates/." "$WORK/unedited/"
mv "$WORK/unedited/SKILL.md.template" "$WORK/unedited/SKILL.md"
chmod +x "$WORK/unedited/props.sh"
expect 19 "doctor in a copy of the templates that nobody filled" "$WORK/unedited/props.sh" doctor
B="$(copy nosummary "$(login_with right)" yes)"
rm "$B/summarize.py"
expect 11 "doctor with a sealed file gone" "$B/props.sh" doctor
B="$(copy norecord "$(login_with right)" yes)"
rm "$B/SEALED.sha256"
expect 11 "doctor with no seal record" "$B/props.sh" doctor
B="$(copy norow "$(login_with right)" yes)"
echo 'export const extraRule = spinnerClears;' >> "$B/spec/properties.ts"
expect 19 "doctor with a property that SKILL.md does not list" "$B/props.sh" doctor
grep -q 'extraRule' "$EVIDENCE/last.out" || fail "doctor did not name the property that SKILL.md lacks"
B="$(copy indentedrow "$(login_with right)" yes)"
echo '  export const indentedRule = spinnerClears;' >> "$B/spec/properties.ts"
expect 19 "doctor with an indented export that SKILL.md does not list" "$B/props.sh" doctor
grep -q 'indentedRule' "$EVIDENCE/last.out" || fail "doctor did not name the indented property that SKILL.md lacks"
B="$(copy renamedrow "$(login_with right)" yes)"
echo 'export { spinnerClears as renamedRule };' >> "$B/spec/properties.ts"
expect 19 "doctor with a property exported under another name that SKILL.md does not list" "$B/props.sh" doctor
grep -q 'renamedRule' "$EVIDENCE/last.out" || fail "doctor did not name the renamed property that SKILL.md lacks"
B="$(copy braces "$(login_with right)" yes)"
perl -pi -e 's/^export const spinnerClears/const spinnerClears/' "$B/spec/properties.ts"
echo 'export { spinnerClears };' >> "$B/spec/properties.ts"
plan "2 other"
expect 2 "a run that breaks a property exported in braces" "$B/props.sh" run 1s
braces="$(run_dir_of "$(cat "$EVIDENCE/last.out")")"
plan "0 clean" "0 clean"
expect 0 "confirm for a property exported in braces" "$B/props.sh" confirm "$braces" spinnerClears 1s
B="$(copy starexport "$(login_with right)" yes)"
echo 'export * from "./config.ts";' >> "$B/spec/properties.ts"
expect 19 "doctor with properties that hide behind export *" "$B/props.sh" doctor

mkdir "$WORK/cut"
printf '{"state": {"url"' > "$WORK/cut/trace.jsonl"
expect 1 "a summary of a trace that was cut short" "$A/props.sh" summary "$WORK/cut"
expect 1 "a report of a trace that was cut short" "$A/props.sh" report "$WORK/cut"
grep -q '^props: could not read the trace' "$EVIDENCE/last.out" || fail "a report of a cut trace did not say so in one line"
plan "2 none"
expect 17 "a replay that recorded nothing" "$A/props.sh" repro "$broken"
for replay in none clean; do
  plan "1 $replay" "0 clean"
  expect 21 "confirm when the replay failed and left a trace of kind $replay" "$A/props.sh" confirm "$broken" noFailedRequests 1s
done
B="$(copy gone "$(login_with right)" yes)"
plan "2 other"
expect 2 "a run that breaks an app property" "$B/props.sh" run 1s
other="$(run_dir_of "$(cat "$EVIDENCE/last.out")")"
perl -ni -e 'print unless /spinnerClears/ .. /;$/' "$B/spec/properties.ts"
grep -q spinnerClears "$B/spec/properties.ts" && fail "could not remove the property from the test copy"
perl -ni -e 'print unless /spinnerClears/' "$B/SKILL.md"
plan "0 gone" "0 gone"
expect 18 "confirm for a property that the spec no longer has" "$B/props.sh" confirm "$other" spinnerClears 1s
grep -q 'no property named spinnerClears' "$EVIDENCE/last.out" || fail "confirm did not say that the spec lost the property"
plan "0 clean" "0 gone"
expect 18 "confirm when only the fresh run's spec lacks the property" "$B/props.sh" confirm "$other" spinnerClears 1s
B="$(copy unrowed "$(login_with right)" yes)"
perl -pi -e 's/^export const spinnerClears/const spinnerClears/' "$B/spec/properties.ts"
echo 'const listed = true; export { spinnerClears, listed };' >> "$B/spec/properties.ts"
perl -ni -e 'print unless /spinnerClears/' "$B/SKILL.md"
expect 0 "doctor when an export hides from the row check" "$B/props.sh" doctor
plan "0 clean"
expect 19 "a run that checked a property with no row in SKILL.md" "$B/props.sh" run 1s
grep -q 'does not list the property spinnerClears' "$EVIDENCE/last.out" || fail "the run did not name the property that SKILL.md lacks"
