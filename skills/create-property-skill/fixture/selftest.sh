#!/bin/bash
set -euo pipefail

SKILL="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE="${1:-$HOME/.jeanz/properties/selftest}/$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
SERVER_PID=""
source "$SKILL/fixture/common.sh"

cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

fail() {
  echo "SELFTEST FAIL: $*" >&2
  [ ! -s "$EVIDENCE/stderr.log" ] || echo "what the runs wrote to stderr is in $EVIDENCE/stderr.log" >&2
  exit 1
}
quietly() { "$@" 2>> "$EVIDENCE/stderr.log" || true; }
pass() { echo "pass: $*"; }
mark() { wc -l < "$SERVER_LOG" | tr -d ' '; }
since() { tail -n +"$(($1 + 1))" "$SERVER_LOG"; }
logged() { since "$1" > "$WORK/since"; grep -qE -- "$2" "$WORK/since"; }
violated() { echo "$1" | grep -q "\"property\": \"$2\""; }
trace() { python3 -I "$SKILL/fixture/trace.py" "$@"; }
coverage() { "$A/props.sh" summary "$1" | python3 -I -c 'import json, sys; print("\n".join(json.load(sys.stdin)["coverage"][sys.argv[1]]))' "$2"; }
on_page() {
  perl -pi -e "s{/app\\.html\"\$}{/$2\"} if /^ORIGIN=/" "$1/props.config.sh"
  perl -0pi -e 's/(export const FEATURES: Feature\[\] = )\[.*?\n\];/$1\[\];/s' "$1/spec/config.ts"
  grep -q "^ORIGIN=.*/$2\"\$" "$1/props.config.sh" && grep -q '^export const FEATURES: Feature\[\] = \[\];$' "$1/spec/config.ts" || fail "could not keep the test copy on $2"
}
properties_of() { "$1/props.sh" summary "$2" | python3 -I -c 'import json, sys; print(" ".join(sorted(json.load(sys.stdin)["properties"])))'; }

start_fixture
A="$(copy main "$(login_with right)" yes)"

"$A/props.sh" doctor > /dev/null || fail "doctor failed on a good setup"
pass "doctor accepts a disposable, signed-in instance"

B="$(copy badspec "$(login_with right)" yes)"
printf '\nexport { clicks as extraClicks } from "@antithesishq/bombadil/browser/defaults/actions";\n' >> "$B/spec/properties.ts"
echo '| `extraClicks` | An action generator that sits outside the guard |' >> "$B/SKILL.md"
[ "$(exit_of "$B/props.sh" run 10s)" -eq 13 ] || fail "a run did not exit 13 when an app file exports an action generator outside the guard"
pass "a run refuses to start when an app file exports an action generator outside the guard"

B="$(copy clash "$(login_with right)" yes)"
printf '\nexport const signedIn = spinnerClears;\n' >> "$B/spec/properties.ts"
echo '| `signedIn` | An app property under the name of a sealed one |' >> "$B/SKILL.md"
[ "$(exit_of "$B/props.sh" run 10s)" -eq 13 ] && grep -q 'exports signedIn' "$EVIDENCE/last.out" || fail "a run did not exit 13 when an app property takes the name of a sealed one"
pass "a run refuses to start when an app property takes the name of a sealed one"

B="$(copy parked "$(login_with right)" yes)"
perl -0pi -e 's{(export const spinnerClears.*?\);\n)}{/*\n$1*/\n}s' "$B/spec/properties.ts"
grep -q '^/\*$' "$B/spec/properties.ts" || fail "could not comment the property out in the test copy"
parked="$(run_dir_of "$(quietly "$B/props.sh" sweep 3s)")"
[ "$(properties_of "$B" "$parked")" = "noConsoleErrors noDangerousRequestAttempted noFailedRequests noHttpErrorCodes noNewTab noUncaughtExceptions noUnhandledPromiseRejections signedIn" ] ||
  fail "a property inside a comment is still listed as checked: $(properties_of "$B" "$parked")"
pass "a property that is commented out leaves the list of checked properties"

m="$(mark)"
sweep_out="$(quietly "$A/props.sh" sweep 45s)"
sweep_dir="$(run_dir_of "$sweep_out")"
[ -f "$sweep_dir/trace.jsonl" ] || fail "sweep wrote no trace"
violated "$sweep_out" noDangerousRequestAttempted && fail "a dangerous request was attempted: a control got past the guard, or a safe request was blocked"
violated "$sweep_out" signedIn && fail "the run signed itself out"
violated "$sweep_out" noNewTab && fail "the page went out of view, though the run opened no tab"
for p in noUncaughtExceptions spinnerClears noFailedRequests; do
  violated "$sweep_out" "$p" || fail "sweep missed planted bug $p"
  pass "sweep caught $p"
done
violated "$sweep_out" noConsoleErrors && fail "the console error listed in KNOWN_ISSUES was reported anyway"
[ "$(properties_of "$A" "$sweep_dir")" = "noConsoleErrors noDangerousRequestAttempted noFailedRequests noHttpErrorCodes noNewTab noUncaughtExceptions noUnhandledPromiseRejections signedIn spinnerClears" ] ||
  fail "the summary does not list exactly the properties that the spec holds: $(properties_of "$A" "$sweep_dir")"
pass "a run lists the properties that it checked"
logged "$m" '/__destructive/|/logout' && fail "a dangerous request reached the server"
logged "$m" 'GET /api/ok 200' || fail "safe controls were never used: the guard blocks too much"
logged "$m" '/api/ok\?deleted' || fail "the safe control 'Deleted items' was never used, or its request was blocked"
logged "$m" '/api/ok\?frame' || fail "the safe control inside the frame was never reached: clicks in frames miss"
logged "$m" '/api/ok\?xframe' && fail "the run clicked inside a frame from another origin"
[ "$(trace acted "$sweep_dir" TypeText)" -gt 0 ] || fail "the run never typed into a field"
[ "$(trace clicked "$sweep_dir" frame-safe)" -gt 0 ] || fail "the trace shows no click on the safe control inside the frame"
[ "$(trace clicked "$sweep_dir" frame-side)" -eq 0 ] || fail "the run clicked a frame control that its frame does not show"
grep -q 'content: "Rename"' "$sweep_dir.log" || fail "the safe menu item next to Delete was never clicked: the guard blocks too much"
skipped="$(coverage "$sweep_dir" dangerous_controls_skipped)"
planted=0
while IFS= read -r want; do
  echo "$skipped" | grep -qF -- "$want" || fail "the guard did not recognize the planted control '$want'"
  planted=$((planted + 1))
done <<'EOF'
delete everything
delete row
delete account
permanently delete
삭제
remove (double-click)
remove link
log out
remove attachment
delete draft
remove entry
delete in shadow
delete slotted
delete workspace
purge through every channel
delete through another address
delete in frame
frame http://localhost
EOF
echo "$skipped" | grep -qx 'delete' || fail "the guard did not recognize the planted menu item 'Delete'"
for safe in "deleted items" "rename" "frame refresh" "restore view"; do
  echo "$skipped" | grep -qF "$safe" && fail "the guard would skip the safe control '$safe'"
done
[ "$(trace top "$sweep_dir" "delete in frame")" -ge 200 ] || fail "the control inside the frame is not placed where it is on the page"
pass "guard held: $((planted + 1)) planted dangerous controls recognized, none clicked, safe controls still used, still signed in"

B="$(copy reach "$(login_with right)" yes)"
perl -pi -e 's{/app\.html"$}{/idle.html"} if /^ORIGIN=/' "$B/props.config.sh"
perl -0pi -e 's/export const FEATURES: Feature\[\] = \[.*?\n\];\n//s' "$B/spec/config.ts"
grep -q FEATURES "$B/spec/config.ts" && fail "could not replace the features in the test copy"
cat >> "$B/spec/config.ts" <<'FEATURES'
export const FEATURES: Feature[] = [
  { name: "archive", url: /\/archive\.html/, start: "/archive.html" },
  { name: "billing", url: /\/billing\b/ },
  { name: "exit", url: /\/logout/, start: "/logout" },
];
FEATURES
reach_out="$(quietly "$B/props.sh" sweep 10s)"
reach_dir="$(run_dir_of "$reach_out")"
[ "$(coverage "$reach_dir" features_reached | xargs)" = "archive" ] || fail "a page that no link leads to was not reached through its start address"
[ "$(coverage "$reach_dir" features_not_reached | xargs)" = "billing exit" ] || fail "the summary does not name the features the run never reached"
echo "$reach_out" | grep -q '"requests_blocked": 0,' || fail "the run visited a start address that is dangerous"
pass "features: a page that no link leads to is reached through its start address, a dangerous start address is never visited, and an unreached feature is named"

B="$(copy enter "$(login_with right)" yes)"
on_page "$B" enter.html
m="$(mark)"
enter_out="$(quietly "$B/props.sh" sweep 20s)"
enter_dir="$(run_dir_of "$enter_out")"
for field in note why outside input override safe; do
  [ "$(trace clicked "$enter_dir" "$field")" -gt 0 ] || fail "the run never put the cursor in the '$field' field"
done
violated "$enter_out" noDangerousRequestAttempted && fail "Enter submitted a form that sends a dangerous request"
for held in button outside input override; do
  logged "$m" "/api/ok\?enter-$held" && fail "Enter submitted the form '$held', which a dangerous button or method sends"
done
logged "$m" '/api/ok\?enter-safe' || fail "Enter never submitted the safe form: the guard holds too much"
held_buttons="$(coverage "$enter_dir" dangerous_controls_skipped)"
for name in 'delete with reason' 'delete from outside' 'delete by input'; do
  echo "$held_buttons" | grep -qx "$name" || fail "the guard did not recognize the dangerous submit button '$name'"
done
pass "Enter is held back in a form with a dangerous address, method, or submit button, inside the form or outside it, and it submits a safe form"

B="$(copy known "$(login_with right)" yes)"
on_page "$B" known.html
reported="$(trace violated-at-start "$(run_dir_of "$(quietly "$B/props.sh" sweep 5s)")" | xargs)"
[ -z "$reported" ] || fail "an issue listed in KNOWN_ISSUES was reported anyway: $reported"
perl -pi -e 's/2999-12-31/2000-01-01/' "$B/spec/config.ts"
grep -q '2000-01-01' "$B/spec/config.ts" || fail "could not expire the known issues in the test copy"
expired_dir="$(run_dir_of "$(quietly "$B/props.sh" sweep 5s)")"
reported="$(trace violated-at-start "$expired_dir" | xargs)"
[ "$reported" = "noConsoleErrors noFailedRequests noHttpErrorCodes noUncaughtExceptions noUnhandledPromiseRejections" ] || fail "the known issues past their date were not all reported: $reported"
failures="$(coverage "$expired_dir" requests_failed_distinct)"
for kind in 'legacy ' 'legacy?xhr '; do
  echo "$failures" | grep -qF "/api/$kind" || fail "a failed request is missing from the summary: /api/$kind"
done
echo "$failures" | grep -qF '/api/ok?reused' && fail "a request that succeeded is listed as failed, because its XHR object was used again"
pass "a known issue of each kind is ignored until its date and reported after it"

B="$(copy onload "$(login_with right)" yes)"
on_page "$B" probe.html
m="$(mark)"
onload_dir="$(run_dir_of "$(quietly "$B/props.sh" sweep 10s)")"
reached="$(since "$m" | grep -E '/__destructive/|DELETE /api/ok|/api/ok\?(field|declared-field)' || true)"
[ -z "$reached" ] || fail "a dangerous request that a page sent while it loaded reached the server: $reached"
stopped="$(trace blocked-requests "$onload_dir")"
while IFS= read -r want; do
  echo "$stopped" | grep -qE "^${want% *} [^ ]*${want##* }\$" || fail "the request block never stopped '$want' while the page loaded"
done <<'EOF'
fetch POST /__destructive/load-fetch
fetch POST /__destructive/load-early
fetch DELETE /api/ok\?method
fetch POST /__destructive/load-frame
fetch POST /__destructive/load-srcdoc
fetch DELETE /api/ok\?request
fetch POST /__destructive/load-string
xhr POST /__destructive/load-xhr
beacon POST /__destructive/load-beacon
form.submit\(\) POST /__destructive/load-submit
form POST /__destructive/load-form
form DELETE /api/ok\?field
form POST /__destructive/load-shadow-target
form POST /__destructive/load-declared-click
form POST /__destructive/load-declared-script
link GET /__destructive/load-link
link GET /__destructive/load-loose
open GET /__destructive/load-open
navigate GET /__destructive/load-assign
navigate DELETE /api/ok\?declared-field
EOF
pass "requests that a page sends while it loads are stopped: a kept reference to fetch, an address that is not plain text, a frame, an inline frame, a method alone, a method override, a new tab, a redirect, a link outside the document, and forms in each kind of shadow tree"
for marker in srcdoc fetch-refused xhr-refused jumped; do
  logged "$m" "GET /api/ok\?$marker " || fail "the page never sent its '$marker' request: a safe request in an inline frame must go through, a stopped request must fail where the app can see it, and a link to a place on the same page must work"
done
echo "$stopped" | grep -q 'delete-section' && fail "a link to a place on the same page was stopped as a dangerous request"
logged "$m" 'GET /api/ok\?pushed ' || fail "the request block refused a change of address inside the page, which sends no request"
pass "a stopped request fails like a dropped connection, a safe request in an inline frame goes through, and a link to a place on the same page works"
for kept in 'fetch kept payload' 'xhr kept payload' 'beacon None payload'; do
  logged "$m" "^echo $kept\$" || fail "a safe request lost its method, a header, or its body on its way through the request block: $kept"
done
pass "a safe fetch, XHR, and beacon keep their method, header, and body"

B="$(copy tabs "$(login_with right)" yes)"
on_page "$B" tabs.html
m="$(mark)"
tabs_out="$(quietly "$B/props.sh" sweep 10s)"
violated "$tabs_out" noNewTab && fail "a control that opens a new tab took the page out of view"
for control in tab-link tab-open tab-form tab-button tick; do
  [ "$(trace clicked "$(run_dir_of "$tabs_out")" "$control")" -gt 0 ] || fail "the run never clicked the control '$control' on the page of new tabs"
done
logged "$m" 'GET /idle\.html\?tab' && fail "the run opened a new tab"
pass "a run opens no new tab: a link, a form, a submit button, and window.open are held, and the page stays in view"
C="$(copy tabsopen "$(login_with right)" yes)"
on_page "$C" tabs.html
perl -pi -e 's/(const opensTab = \(target: string \| null\): boolean =>)/$1 false \&\&/' "$C/spec/network.ts"
cmp -s "$C/spec/network.ts" "$SKILL/templates/spec/network.ts" && fail "could not let new tabs open in the test copy"
reseal "$C"
violated "$(quietly "$C/props.sh" run 30s)" noNewTab || fail "with new tabs let through, noNewTab did not break (the check cannot fail)"
pass "with new tabs let through, noNewTab breaks"

B="$(copy halted "$(login_with right)" yes)"
on_page "$B" tabs.html
perl -pi -e 's{^export const FEATURES: Feature\[\] = \[\];$}{export const FEATURES: Feature[] = [{ name: "tabs", url: /tabs\\.html/ }];}' "$B/spec/config.ts"
grep -q 'name: "tabs"' "$B/spec/config.ts" || fail "could not list the page as a feature in the test copy"
driver_of() {
  for _ in $(seq 150); do pgrep -P "$1" -f "bombadil browser" && return 0; sleep 0.1; done
  fail "bombadil never started"
}
"$B/props.sh" sweep 40s > "$EVIDENCE/interrupted.out" 2>> "$EVIDENCE/stderr.log" &
halted=$!
driver="$(driver_of "$halted")"
sleep 6
kill -INT "$driver"
rc=0; wait "$halted" || rc=$?
[ "$rc" -eq 1 ] && [ "$(cat "$(run_dir_of "$(cat "$EVIDENCE/interrupted.out")").exit")" = 1 ] || fail "a run that an interrupt stopped exited $rc. It must exit 1 and leave a record of 1"
pass "a run that an interrupt stops is recorded as failed"
"$B/props.sh" sweep 40s > /dev/null 2>> "$EVIDENCE/stderr.log" &
halted=$!
disown "$halted"
driver="$(driver_of "$halted")"
kill -TERM "$halted"
for _ in $(seq 50); do kill -0 "$driver" 2> /dev/null || break; sleep 0.1; done
kill -0 "$driver" 2> /dev/null && fail "stopping props.sh left bombadil running"
pass "stopping props.sh stops bombadil"

B="$(copy frozen "$(login_with right)" yes)"
on_page "$B" freeze.html
perl -pi -e 's{^export const FEATURES: Feature\[\] = \[\];$}{export const FEATURES: Feature[] = [{ name: "freeze", url: /freeze\\.html/ }];}' "$B/spec/config.ts"
grep -q 'name: "freeze"' "$B/spec/config.ts" || fail "could not list the page as a feature in the test copy"
[ "$(exit_of "$B/props.sh" run 10s)" -eq 3 ] && grep -q 'no new state came in the last half' "$EVIDENCE/last.out" || fail "a run on a page that stopped answering after two steps did not exit 3"
pass "a run on a page that stops answering exits 3"

B="$(copy signedout "$(login_with right)" yes)"
perl -pi -e 's{/app\.html"$}{/expired.html"} if /^ORIGIN=/' "$B/props.config.sh"
perl -pi -e 's{^  urls: \[\.\.\.DEFAULTS\.signedOutUrls\],}{  urls: [],}' "$B/spec/config.ts"
grep -q '^  urls: \[\],$' "$B/spec/config.ts" || fail "could not empty the signed-out addresses in the test copy"
violated "$(quietly "$B/props.sh" run 10s)" signedIn || fail "a page that shows the sign-in form did not break signedIn"
perl -pi -e 's{/expired\.html"$}{/login.html"} if /^ORIGIN=/' "$B/props.config.sh"
perl -pi -e 's{^  urls: \[\],}{  urls: [...DEFAULTS.signedOutUrls],}; s{^  selectors: .*}{  selectors: [],}' "$B/spec/config.ts"
grep -q '^  selectors: \[\],$' "$B/spec/config.ts" && grep -q 'signedOutUrls\],$' "$B/spec/config.ts" || fail "could not swap the signed-out signs in the test copy"
violated "$(quietly "$B/props.sh" run 10s)" signedIn || fail "a page at a sign-in address did not break signedIn"
pass "signedIn fails on a sign-in form and on a sign-in address"
perl -pi -e 's{/login\.html"$}{/missing.html"} if /^ORIGIN=/' "$B/props.config.sh"
violated "$(quietly "$B/props.sh" run 10s)" noHttpErrorCodes || fail "a page that answers 404 did not break noHttpErrorCodes"
pass "noHttpErrorCodes fails on a page that answers 404"

B="$(copy shapes "$(login_with right)" yes)"
on_page "$B" shapes.html
recognized="$(trace danger-names "$(run_dir_of "$(quietly "$B/props.sh" sweep 3s)")")"
expected="$(sort <<'EOF'
tidy up
delete icon
delete entry
delete workspace
delete image
delete history on exit
delete now proceed
proceed
purge data after a month
delete vector
delete every draft
delete row item
delete forever
delete options
delete focus
d elete letter
del ete all
rem ove tag
log-out now
wipe on close
button
x delete by shadow label
delete by link
delete by checkbox
delete by radio
delete by switch
delete by tab
delete by menuitemcheckbox
delete by menuitemradio
delete by option
delete by treeitem
delete by gridcell
a month delete after
delete after
y delete picture
delete archive archive
delete by button
delete by menuitem
clear the cache
delete every stored report and every exported file of this w
EOF
)"
[ "$recognized" = "$expected" ] || fail "the guard does not recognize exactly the dangerous shapes on the shapes page: $(echo "$recognized" | tr '\n' ',')"
pass "the guard reads a control's name from nested labels, split words, alt text, form labels, roles, and its selector, and passes each look-alike"

C="$(copy clickguardoff "$(login_with right)" yes)"
perl -0pi -e 's/(export function safe\(action: ActionTemplate\): boolean \{)/$1\n  return true;/' "$C/spec/guard.ts"
cmp -s "$C/spec/guard.ts" "$SKILL/templates/spec/guard.ts" && fail "could not switch the guard off in the test copy"
reseal "$C"
m="$(mark)"
off_out="$(quietly "$C/props.sh" sweep 30s)"
off_dir="$(run_dir_of "$off_out")"
violated "$off_out" noDangerousRequestAttempted || fail "with the guard off, no dangerous request was attempted (the check cannot fail)"
[ "$(trace acted "$off_dir" DoubleClick)" -gt 0 ] || fail "with the guard off, the run never used the double-click from customActions"
logged "$m" '/__destructive/|/logout' && fail "with the guard off, the request block let a dangerous request through"
kinds="$(trace blocked "$off_dir")"
for kind in "xhr POST" "fetch POST" "beacon POST" "form.submit() POST"; do
  echo "$kinds" | grep -qxF "$kind" || fail "with the guard off, the request block never stopped a '$kind'"
done
trace blocked-requests "$off_dir" | grep -q '^form POST .*/__destructive/formaction$' || fail "with the guard off, the request block never stopped the submit button that posts to another address"
attempts="$(echo "$off_out" | sed -n 's/.*"requests_blocked": \([0-9]*\).*/\1/p')"
[ "$attempts" -gt "$(coverage "$off_dir" requests_blocked_distinct | wc -l)" ] || fail "with the guard off, the request block counted each stopped request once, not each attempt ($attempts)"
kept="$(trace kept-after-click "$off_dir" "Log out" /logout)"
[ "${kept%% *}" -gt 0 ] && [ "${kept%% *}" = "${kept##* }" ] || fail "with the guard off, the stopped sign-out is missing from the record once the page has moved on (kept after $kept clicks)"
pass "request block held on its own: xhr, fetch, beacon and form submits attempted, none reached the server"

D="$(copy bothoff "$(login_with right)" yes)"
cat > "$D/spec/config.ts" <<'CONFIG'
import { DEFAULTS, type Feature, type KnownIssue } from "./defaults.ts";

export const DANGER_WORDS = ["log out"];
export const DANGER_SELECTORS: string[] = [];
export const DANGER_REQUESTS: { methods: string[]; urls: RegExp[] } = { methods: [], urls: [] };
export const SIGNED_OUT: { urls: RegExp[]; selectors: string[] } = { urls: [...DEFAULTS.signedOutUrls], selectors: [] };
export const KNOWN_ISSUES: KnownIssue[] = [];
export const FEATURES: Feature[] = [];
CONFIG
m="$(mark)"
quietly "$D/props.sh" sweep 25s > /dev/null
hits="$(since "$m" | grep -oE '/__destructive/[a-z0-9-]+' | sort -u | tr '\n' ' ' || true)"
[ -n "$hits" ] || fail "with both protections told about no control but the sign-out button, nothing dangerous reached the server (the guard checks cannot fail)"
pass "both protections told about no control but the sign-out button: dangerous requests reach the server ($hits)"

run_out="$(quietly "$A/props.sh" run 60s)"
run_dir="$(run_dir_of "$run_out")"
echo "$run_out" | grep -q '"property"' || fail "run stopped without a violation"
"$A/props.sh" shrink "$run_dir" > "$EVIDENCE/shrink.out" || fail "shrink failed (see $EVIDENCE/shrink.out)"
before="$(trace steps "$run_dir")"; after="$(trace steps "$run_dir-shrunk")"
[ "$after" -le "$before" ] || fail "shrink of the run left $after steps (from $before)"
pass "shrink picked the run's first broken property by itself ($before steps to $after)"
set +e; "$A/props.sh" repro "$run_dir-shrunk" > "$EVIDENCE/repro.out"; rc=$?; set -e
[ "$rc" -eq 2 ] || fail "replaying the shrunk steps did not fail again (exit $rc)"
pass "repro of the shrunk steps fails again"
"$A/props.sh" report "$run_dir-shrunk" > /dev/null || fail "report failed"
grep -q '<img alt="" src="data:image/jpeg' "$run_dir-shrunk/report.html" || fail "the report holds no screenshot"
pass "report written with its screenshots"

first_crash="$(trace first "$sweep_dir" noUncaughtExceptions)"
"$A/props.sh" shrink "$sweep_dir" noUncaughtExceptions 3m > "$EVIDENCE/shrink-sweep.out" || fail "shrink of one property out of a multi-property sweep failed (see $EVIDENCE/shrink-sweep.out)"
cut="$(trace steps "$sweep_dir-shrunk")"
[ "$cut" -lt "$first_crash" ] || fail "shrink of noUncaughtExceptions left $cut steps (first crash at step $first_crash)"
[ "$(trace first "$sweep_dir-shrunk" noUncaughtExceptions)" -ge 0 ] || fail "the shrunk steps do not break noUncaughtExceptions"
pass "shrink cut a multi-property sweep to $cut steps for noUncaughtExceptions (first crash at step $first_crash)"

set +e; "$A/props.sh" confirm "$sweep_dir-shrunk" noUncaughtExceptions 20s > "$EVIDENCE/confirm-before.out"; rc=$?; set -e
[ "$rc" -eq 2 ] || fail "confirm passed before the bug was fixed (exit $rc)"
curl -s -o /dev/null -X POST "$BASE/__fixture/fix"
set +e; "$A/props.sh" confirm "$sweep_dir-shrunk" noUncaughtExceptions 20s > "$EVIDENCE/confirm-after.out"; rc=$?; set -e
[ "$rc" -eq 0 ] && grep -q 'held in a fresh' "$EVIDENCE/confirm-after.out" || fail "confirm did not pass after the bug was fixed (exit $rc; see $EVIDENCE/confirm-after.out)"
pass "confirm fails before the fix and passes after it"

E="$(copy shipped "$(login_with right)" yes)"
cp "$SKILL/templates/spec/config.ts" "$SKILL/templates/spec/actions.ts" "$SKILL/templates/spec/properties.ts" "$E/spec/"
shipped_out="$(quietly "$E/props.sh" run 10s)"
shipped_dir="$(run_dir_of "$shipped_out")"
[ -s "$shipped_dir/trace.jsonl" ] || fail "the app files a new skill starts from did not load (see $shipped_dir.log)"
pass "the app files a new skill starts from load and run"

B="$(copy brokenspec "$(login_with right)" yes)"
printf '\nexport const BROKEN = ;\n' >> "$B/spec/config.ts"
[ "$(exit_of "$B/props.sh" run 10s)" -eq 17 ] || fail "a spec that does not load did not exit 17"
pass "a spec that does not load is reported, not shown as an empty run"

grep -l "fixture-ok" "$EVIDENCE"/*.log > /dev/null 2>&1 && fail "a log in $EVIDENCE contains the session cookie"
pass "no log contains the session cookie"

moves=0
scrolls=0
for run in "$EVIDENCE"/*/; do
  [ -f "$run/trace.jsonl" ] || continue
  moves=$((moves + $(trace acted "${run%/}" Back) + $(trace acted "${run%/}" Reload)))
  scrolls=$((scrolls + $(trace acted "${run%/}" ScrollDown) + $(trace acted "${run%/}" ScrollUp)))
done
[ "$moves" -gt 0 ] || fail "no run ever went back or reloaded"
[ "$scrolls" -gt 0 ] || fail "no run ever scrolled"
pass "the runs went back or reloaded $moves times, and scrolled $scrolls times"

cleanup; trap - EXIT
[ ! -d "$WORK" ] || fail "cleanup left the working copies"
[ -f "$run_dir-shrunk/trace.jsonl" ] || fail "cleanup removed the evidence"
pass "evidence kept in $EVIDENCE"
echo "SELFTEST PASS"
