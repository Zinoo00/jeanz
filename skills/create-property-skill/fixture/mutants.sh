#!/bin/bash
set -uo pipefail

SKILL="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$SKILL/../.." && pwd)"
TPL=skills/create-property-skill/templates
FIX=skills/create-property-skill/fixture
SEP=' ::: '

usage() {
  cat >&2 <<'EOF'
usage: mutants.sh EVIDENCE [JOBS] [ID...]
  Breaks one sealed behavior at a time in a copy of the repo, then runs the three tests.
  A break that no test notices is a behavior with no case. Add the case, or cut the behavior.
  JOBS copies run at once (default 4). With IDs, only those breaks run. About an hour for all.
  exit 0: every break was noticed. exit 1: one survived, or its pattern no longer matches the file.
EOF
  exit 64
}

table() {
  cat <<'EOF'
g-selector ::: spec/guard.ts ::: s/  if \(DANGER_SELECTORS\.some\(\(s\) => el\.matches\(s\)\)\) return true;\n// ::: a control marked with a danger selector
g-label ::: spec/guard.ts ::: s/  if \(isLabel\(el\)\) return [^\n]*\n// ::: a label that activates a dangerous control
g-aria-label ::: spec/guard.ts ::: s/el\.getAttribute\("aria-label"\), // ::: a name in aria-label
g-title ::: spec/guard.ts ::: s/el\.getAttribute\("title"\), // ::: a name in title
g-alt ::: spec/guard.ts ::: s/, el\.getAttribute\("alt"\)\]/]/ ::: a name in alt
g-value ::: spec/guard.ts ::: s/isInput\(el\) && namedByValue\(el\.type\) \? el\.value : null,/null,/ ::: a name in a button input's value
g-text ::: spec/guard.ts ::: s/    if \(child\.nodeType === 3\) name \+= child\.textContent \?\? "";\n// ::: a name in the control's text
g-nested-control ::: spec/guard.ts ::: s/child\.matches\(INTERACTIVE\) \? " " : // ::: a nested control's name is not its parent's
g-nested-attr ::: spec/guard.ts ::: s/\(child\.matches\(INTERACTIVE\) \? " " : nameWithin\(child, between\)\)/(child.matches(INTERACTIVE) ? " " : innerName(child, between))/ ::: a name in a nested element's attribute
g-form-label ::: spec/guard.ts ::: s/    \.\.\.labelName\(el, between\),\n// ::: a name in the control's form label
g-text-field ::: spec/guard.ts ::: s/  if \(typedInto\(el\.tagName, isInput\(el\) \? el\.type : ""\)\) return false;\n// ::: a field that takes typed text is not dangerous by its name
g-slot ::: spec/guard.ts ::: s/    slottedName\(el, between\),\n// ::: a name in slotted text
g-labelledby ::: spec/guard.ts ::: s/    \.\.\.labelledBy\.map\(\(id\) => \{\n[^\n]*\n[^\n]*\n    \}\),\n// ::: a name through aria-labelledby
g-shadow ::: spec/guard.ts ::: s/    if \(host\.shadowRoot\) findAll\(host\.shadowRoot, origin, found, closed\);\n// ::: a dangerous control in a shadow tree
g-frame ::: spec/guard.ts ::: s/      findAll\(inner, \{[^\n]*\n// ::: a dangerous control in a same-origin frame
g-other-origin ::: spec/guard.ts ::: s/      closed\.push\([^\n]*\n// ::: a click into a frame from another origin
g-rect ::: spec/guard.ts ::: s/  if \(target\) return !hits\(target\.point, d\.rects\);/  if (target) return true;/ ::: a click that lands on a dangerous control
g-enter ::: spec/guard.ts ::: s/return !\(action\.PressKey\.code === 13 && d\.enterSubmitsDanger\)/return true/ ::: Enter in a form that submits to danger
g-enter-button ::: spec/guard.ts ::: s/    Array\.from\(scopeOf\(form\)\.querySelectorAll\([^\n]*\n// ::: Enter is held in a form with a dangerous button
g-enter-address ::: spec/guard.ts ::: s/ \|\|\n    dangerousRequest\(DANGER_REQUESTS, request\.method, request\.url\)// ::: Enter is held in a form that sends a dangerous request
g-double ::: spec/guard.ts ::: s/  if \(isAction\(action, "DoubleClick"\)\) return action\.DoubleClick;\n// ::: a double-click on a dangerous control
g-reachable ::: spec/guard.ts ::: s/generator\.filter\(reachable\)\.map\(retarget\)/generator.map(retarget)/ ::: no click on a control that its frame has scrolled out of view
g-retarget ::: spec/guard.ts ::: s/\.filter\(reachable\)\.map\(retarget\)\.filter\(safe\)/.filter(reachable).filter(safe)/ ::: a click in a frame lands where the control is
g-onclick ::: spec/guard.ts ::: s/"\[onclick\]", // ::: an element with an onclick handler counts as a control
g-summary ::: spec/guard.ts ::: s/"summary", // ::: a summary counts as a control
g-tabindex ::: spec/guard.ts ::: s/ "\[tabindex\]:not\(\[tabindex='-1'\]\)",// ::: a focusable element counts as a control
g-roles ::: spec/guard.ts ::: s/  \.\.\.CLICKABLE_ROLES\.map\(\(r\) => `\[role=\$\{r\}\]`\),\n// ::: an element with a clickable role counts as a control
n-fetch ::: spec/network.ts ::: s/    if \(block\("fetch", method, url\)\) return Promise\.reject\(new w\.TypeError\("Failed to fetch"\)\);\n// ::: a dangerous fetch is stopped
n-xhr ::: spec/network.ts ::: s/    if \(block\("xhr", request\.method, request\.url\)\) \{\n[^\n]*\n[^\n]*\n    \}\n// ::: a dangerous XHR is stopped
n-beacon ::: spec/network.ts ::: s/block\("beacon", "POST", String\(url\)\) \|\| realBeacon\.call\(this, url, data\)/realBeacon.call(this, url, data)/ ::: a dangerous beacon is stopped
n-submit ::: spec/network.ts ::: s/if \(isForm\(event\.target\) && stopsForm\(event\.target, submitter, "form"\)\) event\.preventDefault\(\);/void submitter;/ ::: a dangerous form submit is stopped at the form
n-form-submit ::: spec/network.ts ::: s/if \(!stopsForm\(this, null, "form\.submit\(\)"\)\) realSubmit\.call\(this\);/realSubmit.call(this);/ ::: form.submit() to a dangerous address is stopped at the call
n-link ::: spec/network.ts ::: s/if \(isElement\(link\) && stopsLink\(link\)\) event\.preventDefault\(\);/void link;/ ::: a dangerous link is stopped at the click
n-open ::: spec/network.ts ::: s/    if \(url !== undefined && block\("open", "GET", String\(url\)\)\) return null;\n// ::: window.open to a dangerous address is stopped
n-navigate ::: spec/network.ts ::: s/    if \(block\("navigate", method, event\.destination\.url\)\) event\.preventDefault\(\);\n/    void method;\n/ ::: any other dangerous navigation is stopped
n-navigate-field ::: spec/network.ts ::: s/formMethod\("POST", typeof field === "string" \? field : null\)/formMethod("POST", null)/ ::: a navigation's _method field counts as its method
n-shadow ::: spec/network.ts ::: s/    listen\(root\);\n// ::: a form or a link inside a shadow tree is stopped
n-frame-record ::: spec/network.ts ::: s/  while \(owner\.frameElement\) owner = owner\.parent;\n// ::: a request stopped in a frame joins the page's record
n-carry ::: spec/network.ts ::: s/  if \(!window\.frameElement\) window\.addEventListener\("pagehide", \(\) => carry\(window, log\)\);\n// ::: the record survives a page change
n-failed-fetch ::: spec/network.ts ::: s/      failed\(method, url, res\.status\);\n// ::: a fetch that answers 5xx is recorded
n-failed-xhr ::: spec/network.ts ::: s/      if \(this\.__jeanzRequest === request\) failed\(request\.method, request\.url, this\.status\);\n// ::: an XHR that answers 5xx is recorded
n-known ::: spec/network.ts ::: s/ && !knownIssue\("request", line\)// ::: a known failed request is not reported
n-request-object ::: spec/network.ts ::: s/return isRequest\(input\) \? input\.method : "GET";/return "GET";/ ::: a Request object carries its own method
n-base ::: spec/network.ts ::: s/new w\.URL\(raw, w\.document\.baseURI\)/new w.URL(raw, w.location.href)/ ::: a relative address in an inline frame resolves
n-refused-fetch ::: spec/network.ts ::: s/return Promise\.reject\(new w\.TypeError\("Failed to fetch"\)\)/return Promise.resolve(new w.Response("{}"))/ ::: a stopped fetch fails where the app can see it
h-console-level ::: spec/health.ts ::: s/    \.filter\(\(e\) => e\.level === "error"\)\n// ::: a console warning is not an error
h-console-known ::: spec/health.ts ::: s/\n    \.filter\(\(text\) => !knownIssue\("console", text\)\)// ::: a known console error is not reported
h-uncaught-known ::: spec/health.ts ::: s/\n    \.filter\(\(text\) => !knownIssue\(text\.startsWith\("Uncaught \(in promise\)"\) \? "rejection" : "exception", text\)\)// ::: a known exception or rejection is not reported
h-exception ::: spec/health.ts ::: s/uncaught\.current\.every\(\(e\) => !e\.startsWith\("Uncaught"\) \|\| e\.startsWith\("Uncaught \(in promise\)"\)\),/true,/ ::: an uncaught exception breaks its property
h-rejection ::: spec/health.ts ::: s/always\(\(\) => uncaught\.current\.every\(\(e\) => !e\.startsWith\("Uncaught \(in promise\)"\)\)\)/always(() => true)/ ::: a rejected promise breaks its property
h-status ::: spec/health.ts ::: s/return status >= 400 && !knownIssue\("page", line\) \? line : null;/return null;/ ::: a page that loads with an error status breaks its property
h-page-known ::: spec/health.ts ::: s/status >= 400 && !knownIssue\("page", line\)/status >= 400/ ::: a known page error is not reported
s-address ::: spec/session.ts ::: s/signedOutAt\(SIGNED_OUT\.urls, state\.window\.location\.href\) \|\|\n    // ::: signed out by address
s-element ::: spec/session.ts ::: s/ \|\|\n    SIGNED_OUT\.selectors\.some\(\(s\) => state\.document\.querySelector\(s\) !== null\)// ::: signed out by an element
r-danger ::: spec/reach.ts ::: s/ && !dangerousRequest\(DANGER_REQUESTS, "GET", f\.start\)// ::: no visit to a dangerous start address
i-visits ::: spec/index.ts ::: s/    \[1, visits\],\n// ::: a page that no link leads to is reached through its start address
i-guard ::: spec/index.ts ::: s/export const exploration = guarded\(/export const exploration = ((all: ActionGenerator<ActionTemplate>) => all)(/ ::: every action passes through the guard
i-export ::: spec/index.ts ::: s/    throw new Error\(`spec\/properties\.ts exports the action generator[^\n]*\n/    void name;\n/ ::: an action generator outside the guard stops the run
t-camel ::: spec/rules.ts ::: s/\.replace\(\/\(\[a-z\]\)\(\[A-Z\]\)\/g, "\$1 \$2"\)// ::: a camel-case name is split into words
t-width ::: spec/rules.ts ::: s/\.normalize\("NFKC"\)// ::: full-width letters match
t-before ::: spec/rules.ts ::: s/if \(!gluedBefore && !gluedAfter\) return true;/if (!gluedAfter) return true;/ ::: a word glued to letters before it does not match
t-after ::: spec/rules.ts ::: s/if \(!gluedBefore && !gluedAfter\) return true;/if (!gluedBefore) return true;/ ::: a word glued to letters after it does not match
t-global ::: spec/rules.ts ::: s/  pattern\.lastIndex = 0;\n// ::: a pattern with the g flag gives the same answer twice
t-method-case ::: spec/rules.ts ::: s/listed\.toUpperCase\(\) === method\.toUpperCase\(\)/listed === method/ ::: a method matches in any case
t-form-post ::: spec/rules.ts ::: s/method\.toUpperCase\(\) === "POST" && field \? field : method/field ? field : method/ ::: only a POST form takes its method from the field
t-reason ::: spec/rules.ts ::: s/      issue\.reason\.trim\(\) !== "" &&\n// ::: a known issue needs a reason
t-date ::: spec/rules.ts ::: s/      \/\^\\d\{4\}-\\d\{2\}-\\d\{2\}\$\/\.test\(issue\.until\) &&\n// ::: a known issue needs a full date
t-expired ::: spec/rules.ts ::: s/      issue\.until >= today &&\n// ::: a known issue ends at its date
t-check ::: spec/rules.ts ::: s/      issue\.check === check &&\n// ::: a known issue applies to its own check
t-status ::: spec/rules.ts ::: s/status >= 500/status >= 400/ ::: a 4xx answer is not a failed request
u-order ::: summarize.py ::: s/for name in sorted\(first, key=first\.get\):/for name in sorted(first, reverse=True):/ ::: the first property broken comes first
u-count ::: summarize.py ::: s/"count": counts\[name\],/"count": 1,/ ::: a violation's count
u-first ::: summarize.py ::: s/"first_state": at,/"first_state": 0,/ ::: the state where a property first broke
u-steps ::: summarize.py ::: s/range\(max\(0, at - 8\), at \+ 1\)\]/range(at, at + 1)]/ ::: the steps before a violation
u-evidence ::: summarize.py ::: s/"evidence": found,/"evidence": {},/ ::: a violation's evidence
u-condition ::: summarize.py ::: s/"condition": condition,/"condition": None,/ ::: a violation's condition
u-reached ::: summarize.py ::: s/reached\.update\(features\.get\("here"\) or \[\]\)/pass/ ::: the features a run reached
u-skipped ::: summarize.py ::: s/controls\.update\(r\.get\("name"\) or "" for r in danger\.get\("rects"\) or \[\]\)/pass/ ::: the dangerous controls a run skipped
u-blocked ::: summarize.py ::: s/stopped\.update\(network\.get\("blocked"\) or \[\]\)/pass/ ::: the requests a run stopped
u-failed ::: summarize.py ::: s/failures\.update\(network\.get\("failed"\) or \[\]\)/pass/ ::: the requests that failed in a run
u-urls ::: summarize.py ::: s/"urls": dict\(Counter\(row\["state"\]\.get\("url"\) for row in rows\)\.most_common\(8\)\),/"urls": {},/ ::: the pages a run spent its states on
u-actions ::: summarize.py ::: s/"actions": dict\(Counter\(kind_of\(row\["action"\]\) for row in rows if row\["action"\] is not None\)\),/"actions": {},/ ::: the kinds of action a run took
u-report ::: summarize.py ::: s/            page\.append\(f"<li><p>\{e\(describe[^\n]*\n/            pass\n/ ::: the report shows each step with its screenshot
p-version ::: props.sh ::: s/  \[ "\$have" = "\$BOMBADIL_VERSION" \] && return 0\n/  return 0\n/ ::: another bombadil version is refused
p-disposable ::: props.sh ::: s/  \[ "\$DISPOSABLE" = "yes" \] \|\| die[^\n]*\n// ::: an instance not marked disposable is refused
p-host ::: props.sh ::: s/  die \$E_INSTANCE "ORIGIN host[^\n]*\n/  return 0\n/ ::: a host that is not this machine is refused
p-listed-host ::: props.sh ::: s/  for h in \$\{DISPOSABLE_HOSTS\[\@\]\+"\$\{DISPOSABLE_HOSTS\[\@\]\}"\}; do \[ "\$h" = "\$host" \] && return 0; done\n// ::: a host listed as disposable is accepted
p-down ::: props.sh ::: s/  fetch -o \/dev\/null "\$ORIGIN" \|\| die[^\n]*\n/  true\n/ ::: an instance that does not answer is named
p-no-cookie ::: props.sh ::: s/  \[ \$\{#COOKIES\[\@\]\} -gt 0 \] \|\| die \$E_LOGIN "LOGIN printed no cookies"\n// ::: a LOGIN that prints no cookie is refused
p-ready-code ::: props.sh ::: s/  \[ "\$code" = 200 \] \|\| die[^\n]*\n// ::: a READY_URL that redirects is refused
p-ready-text ::: props.sh ::: s/  \[ -n "\$shown" \] \|\| die[^\n]*\n// ::: a READY_URL without READY_TEXT is refused
p-redact ::: props.sh ::: s/bombadil browser "\$\@" 2>&1 \| redact > "\$log"/bombadil browser "\$@" 2>\&1 | cat > "\$log"/ ::: a cookie stays out of the log
p-stop-first ::: props.sh ::: s/ARGS\+=\(--exit-on-violation\); // ::: run stops at the first violation
p-headers ::: props.sh ::: s/  for h in \$\{HEADERS\[\@\]\+"\$\{HEADERS\[\@\]\}"\}; do ARGS\+=\(--header "\$h"\); done\n// ::: HEADERS reach the browser
p-cookies ::: props.sh ::: s/  for c in \$\{COOKIES\[\@\]\+"\$\{COOKIES\[\@\]\}"\}; do ARGS\+=\(--cookie "\$c"\); done\n// ::: the session cookies reach the browser
p-collision ::: props.sh ::: s/set -o noclobber; // ::: two runs in one second get two folders
p-busy ::: props.sh ::: s/    if \[ -n "\$owner" \] && kill -0 "\$owner" 2> \/dev\/null; then die[^\n]*\n/    true\n/ ::: a second run on a busy instance is refused
p-not-broken ::: props.sh ::: s/  violates "\$RUN" "\$PROPERTY" \|\| die \$E_NO_RUN "\$RUN did not break \$PROPERTY"\n// ::: shrink and confirm refuse a property the run did not break
p-placeholder ::: props.sh ::: s/  \[ -z "\$unfilled" \] \|\| die[^\n]*\n// ::: a placeholder left in SKILL.md is refused
p-row ::: props.sh ::: s/    grep -qF "\\`\$name\\`" "\$HERE\/SKILL\.md" \|\| die[^\n]*\n/    true\n/ ::: a property with no row in SKILL.md is refused
p-seal-list ::: props.sh ::: s/  \[ "\$listed" = "\$sealed" \] \|\| die[^\n]*\n// ::: a file among the sealed ones that the record does not list is refused
p-seal-sum ::: props.sh ::: s/  \[ -z "\$bad" \] \|\| die \$E_SEALED "sealed files changed[^\n]*\n// ::: an edited sealed file is refused
p-allow-url ::: props.sh ::: s/      --allow-url\*\) die[^\n]*\n/      --allow-url*) true ;;\n/ ::: a setting that lets a run leave the instance is refused
p-no-state ::: props.sh ::: s/  die \$E_NO_STATE "bombadil recorded no state[^\n]*\n/  return 0\n/ ::: a run that recorded nothing is named
p-gap ::: props.sh ::: s/    3\) echo "props: no property broke[^\n]*\n/    3) return 0 ;;\n/ ::: a run that breaks nothing and misses a feature exits 3
p-star ::: props.sh ::: s/if re\.search\(r"\^\\s\*export\\s\*\\\*", text, re\.M\):\n    sys\.exit\(1\)\n// ::: properties hidden behind export * are refused
p-braces ::: props.sh ::: s/for group in re\.findall\([^\n]*\n[^\n]*\n// ::: a property exported in braces needs a row
p-settings-load ::: props.sh ::: s/broken="\$\( \(set -euo pipefail; source "\$CONFIG"\) 2>&1 > \/dev\/null\)" \|\| die[^\n]*\n// ::: a settings file that fails to load is named
p-width ::: props.sh ::: s/  \[\[ "\$WIDTH" =~ \^\[0-9\]\+\$ \]\] && \[\[ "\$HEIGHT" =~ \^\[0-9\]\+\$ \]\] \|\| die[^\n]*\n// ::: a viewport that is not a number is refused
p-blank-text ::: props.sh ::: s/\[\[ "\$READY_TEXT" =~ \[\^\[:space:\]\] \]\]/true/ ::: a blank READY_TEXT is refused
p-public-ready ::: props.sh ::: s/  ! shows_ready \|\| die[^\n]*\n// ::: a READY_URL that anyone can read is refused
p-lock-key ::: props.sh ::: s/\.lock-\$\(instance_of "\$ORIGIN"\)"/.lock-\$(echo "\$ORIGIN" | tr -c "[:alnum:]" "_")"/ ::: two pages of one instance share a lock
p-summary-fails ::: props.sh ::: s/ \|\| die 1 "could not read the trace in \$1\. It may be cut short\."/ || true/ ::: a summary that cannot read its trace fails
u-gap-empty ::: summarize.py ::: s/    if coverage\["features_listed"\] == 0:\n[^\n]*\n// ::: a run with no listed feature has a gap
u-gap-missed ::: summarize.py ::: s/    if coverage\["features_not_reached"\]:\n[^\n]*\n// ::: a run that missed a feature has a gap
n-refused-xhr ::: spec/network.ts ::: s/      realXhrOpen\.call\(this, "GET", REFUSED, request\.async\);\n      return realSend\.call\(this\);/      return;/ ::: a stopped XHR fails where the app can see it
p-replay ::: props.sh ::: s/    \[ -n "\$replayed" \] \|\| exit \$E_NO_REPLAY\n// ::: confirm does not pass when the steps never replayed
p-ready-host ::: props.sh ::: s/  \[ "\$\(instance_of "\$READY_URL"\)" = [^\n]*\n// ::: READY_URL stays on ORIGIN's host and port
p-host-prefix ::: props.sh ::: s/127\.0\.0\.1 \| localhost \| ::1\) return 0 ;;/127.0.0.1* | localhost* | ::1) return 0 ;;/ ::: a host that only starts like this machine's name is refused
p-ipv6 ::: props.sh ::: s/127\.0\.0\.1 \| localhost \| ::1\) return 0 ;;/127.0.0.1 | localhost) return 0 ;;/ ::: this machine's IPv6 address counts as this machine
p-ready-headers ::: props.sh ::: s/  for h in \$\{HEADERS\[\@\]\+"\$\{HEADERS\[\@\]\}"\}; do sign_in[^\n]*\n// ::: HEADERS reach READY_URL
p-every-cookie ::: props.sh ::: s/done <<< "\$out"\n  \[ \$\{#COOKIES/done <<< "\$(echo "\$out" | head -1)"\n  [ \${#COOKIES/ ::: each cookie that LOGIN prints is kept
p-height ::: props.sh ::: s/ --height "\$HEIGHT"// ::: HEIGHT reaches bombadil
p-args ::: props.sh ::: s/  for a in \$\{BOMBADIL_ARGS\[\@\]\+"\$\{BOMBADIL_ARGS\[\@\]\}"\}; do ARGS[^\n]*\n// ::: BOMBADIL_ARGS reach bombadil
p-lock-shrink ::: props.sh ::: s/(run_dir_arg "\$\{1:-\}"; preflight; )take_lock; /++$n == 1 ? $1 : $&/ge ::: a shrink waits for the instance
p-lock-repro ::: props.sh ::: s/(run_dir_arg "\$\{1:-\}"; preflight; )take_lock; /++$n == 2 ? $1 : $&/ge ::: a replay waits for the instance
p-lock-confirm ::: props.sh ::: s/(run_dir_arg "\$\{1:-\}"; preflight; )take_lock; /++$n == 3 ? $1 : $&/ge ::: a confirm waits for the instance
p-shrink-again ::: props.sh ::: s/ --output-path-overwrite// ::: a run can be shrunk a second time
p-spec-has ::: props.sh ::: s/    checks "\$fresh" "\$PROPERTY"\n// ::: confirm refuses a property that the loaded spec no longer has
p-row-run ::: props.sh ::: s/  for name in \$names; do\n[^\n]*\n  done\n// ::: a run refuses a property that it checked and SKILL.md does not list
p-cell-clash ::: props.sh ::: s/  \[ -z "\$clash" \] \|\| die \$E_SPEC[^\n]*\n// ::: a run refuses an app cell that takes a sealed cell's name
p-no-sign-in ::: props.sh ::: s/    \[ \$\(\(\$\{#COOKIES\[\@\]\} \+ \$\{#HEADERS\[\@\]\}\)\) -gt 0 \] \|\| signed=[^\n]*\n// ::: doctor does not say signed in when no sign-in is set
p-report-cut ::: props.sh ::: s/    summarize "\$RUN" --html "\$RUN\/report\.html"/    python3 -I "\$HERE\/summarize.py" "\$RUN" --html "\$RUN\/report.html"/ ::: a report of a cut trace fails with one line
p-indented ::: props.sh ::: s/names = re\.findall\(r"\^\\s\*export/names = re.findall(r"^export/ ::: the row check reads an indented export
u-text ::: summarize.py ::: s/fp\.get\("text_content"\)/fp.get("textContent")/ ::: a step shows the text of the control that a real trace records
u-custom ::: summarize.py ::: s/    if kind == "Custom":\n[^\n]*\n// ::: a step shows a custom action's name and arguments
u-properties ::: summarize.py ::: s/        properties = snapshot\(row, "jeanzProperties"\) or properties\n// ::: the summary lists the properties that the run checked
u-clash ::: summarize.py ::: s/    return sorted\(name for name, count in names\.items\(\) if count > 1\)/    return []/ ::: the summary finds a sealed cell's name used twice
i-properties ::: spec/index.ts ::: s/\(value instanceof Formula \? \[name\] : \[\]\)/([])/ ::: the run records the properties that its spec holds
i-properties-app ::: spec/index.ts ::: s/\{ \.\.\.sealed, \.\.\.app \}/sealed/ ::: the recorded properties include the app's own
g-split-word ::: spec/guard.ts ::: s/\[" ", ""\]\.some\(\(between\) => dangerousName\(DANGER_WORDS, visibleName\(el, between\)\)\)/dangerousName(DANGER_WORDS, visibleName(el, " "))/ ::: a word that a tag splits is read whole
g-labelled-scope ::: spec/guard.ts ::: s/scopeOf\(el\)\.getElementById\(id\)/el.ownerDocument.getElementById(id)/ ::: aria-labelledby finds its label inside a shadow tree
g-enter-outside ::: spec/guard.ts ::: s/Array\.from\(scopeOf\(form\)\.querySelectorAll\(/Array.from(form.querySelectorAll(/ ::: Enter is held for a dangerous button that sits outside its form
g-enter-input ::: spec/guard.ts ::: s/querySelectorAll\("button, input"\)/querySelectorAll("button")/ ::: Enter is held for a dangerous submit input
g-enter-none ::: spec/guard.ts ::: s/return !\(action\.PressKey\.code === 13 && d\.enterSubmitsDanger\)/return action.PressKey.code !== 13/ ::: Enter still submits a safe form
g-frame-border ::: spec/guard.ts ::: s/r\.left \+ host\.clientLeft \+ /r.left + / ::: a click in a frame lands inside the frame's border
g-frame-padding ::: spec/guard.ts ::: s/ \+ parseFloat\(style\?\.paddingTop \?\? "0"\)// ::: a click in a frame lands inside the frame's padding
g-role-list ::: spec/guard.ts ::: s/"checkbox", "radio", "switch", "tab", // ::: each clickable role counts as a control
g-radio ::: spec/rules.ts ::: s/\/\^\(checkbox\|radio\|button/\/^(checkbox|button/ ::: a radio button is named by its label
g-nameless ::: spec/guard.ts ::: s/ \|\| f\.el\.tagName\.toLowerCase\(\)// ::: a dangerous control with no name is listed by its tag
d-method-field ::: spec/dom.ts ::: s/method: formMethod\(method, isElement\(field\) && isInput\(field\) \? field\.value : null\),/method,/ ::: a form's _method field counts as its method
t-hyphen ::: spec/rules.ts ::: s/\.replace\(\/\[-_\\u2010-\\u2015\\s\]\+\/g, " "\)\.trim\(\)// ::: a hyphen in a name reads as a space
t-blank-word ::: spec/rules.ts ::: s/  if \(!word\) return false;\n// ::: an empty danger word matches nothing
t-day ::: spec/rules.ts ::: s/-\$\{two\(date\.getDate\(\)\)\}`;/`;/ ::: a known issue ends on its day, not with its month
h-now ::: spec/health.ts ::: s/known\(KNOWN_ISSUES, new Date\(\), check, text\)/known(KNOWN_ISSUES, new Date(0), check, text)/ ::: a known issue is judged against today
i-custom ::: spec/index.ts ::: s/    \.\.\.customActions\.map\([^\n]*\n// ::: the app's custom actions run
i-inputs ::: spec/index.ts ::: s/    \[50, inputs\],\n// ::: the run types into fields
i-navigation ::: spec/index.ts ::: s/    \[1, navigation\],\n// ::: the run goes back and reloads
n-fetch-string ::: spec/network.ts ::: s/return isRequest\(input\) \? input\.url : String\(input\);/return isRequest(input) ? input.url : typeof input === "string" ? input : "";/ ::: a fetch address that is not plain text is read
n-fetch-init ::: spec/network.ts ::: s/return realFetch\(input, init\)\.then/return realFetch(input).then/ ::: a safe fetch keeps its method, headers, and body
n-xhr-body ::: spec/network.ts ::: s/    return realSend\.call\(this, body\);/    return realSend.call(this);/ ::: a safe XHR keeps its body
n-beacon-data ::: spec/network.ts ::: s/\|\| realBeacon\.call\(this, url, data\)/|| realBeacon.call(this, url)/ ::: a safe beacon keeps its data
n-fragment ::: spec/network.ts ::: s/      url\.hash = "";\n// ::: a link to a place on the same page is not a request
n-shadow-path ::: spec/network.ts ::: s/  w\.addEventListener\("click", \(event\) => event\.composedPath\(\)\.filter\(isShadowRoot\)\.forEach\(listen\), true\);\n// ::: a form in a shadow tree that the markup declares is stopped
n-request-submit ::: spec/network.ts ::: s/    if \(!stopsForm\(this, submitter \?\? null, "form"\)\) realRequestSubmit\.call\(this, submitter\);/    realRequestSubmit.call(this, submitter);/ ::: requestSubmit() to a dangerous address is stopped at the call
n-loose-link ::: spec/network.ts ::: s/  w\.HTMLElement\.prototype\.click = function \(this: HTMLElement\) \{\n[^\n]*\n  \};\n// ::: a dangerous link outside the document is stopped
n-tab-link ::: spec/network.ts ::: s/ \|\| opensTab\(link\.getAttribute\("target"\)\);/;/ ::: a link that would open a new tab is held
n-tab-form ::: spec/network.ts ::: s/ \|\| opensTab\(submitter\?\.getAttribute\("formtarget"\) \?\? form\.getAttribute\("target"\)\);/;/ ::: a form that would open a new tab is held
n-tab-open ::: spec/network.ts ::: s/return opensTab\(target \?\? "_blank"\) \? null : realOpen\(url, target, features\);/return realOpen(url, target, features);/ ::: window.open that would open a new tab returns null
n-frame-target ::: spec/network.ts ::: s/ && !framed\(w\.top \?\? w, target \?\? ""\);/;/ ::: a link or a form that targets a frame of the page is let through
p-localhost ::: props.sh ::: s/127\.0\.0\.1 \| localhost \| ::1\) return 0 ;;/127.0.0.1 | ::1) return 0 ;;/ ::: an ORIGIN on localhost counts as this machine
p-seal-missing ::: props.sh ::: s/  \[ -f "\$HERE\/SEALED\.sha256" \] \|\| die \$E_SEALED "SEALED\.sha256 is missing[^\n]*\n// ::: a skill with no seal record exits 11
p-confirm-diverged ::: props.sh ::: s/    if replay_ended "\$replay"; then/    if [ -s "\$replay\/trace.jsonl" ]; then/ ::: confirm does not count a replay that exited 1 partway as replayed
p-confirm-limit ::: props.sh ::: s/    limit="\$\{3:-2m\}"/    limit="2m"/ ::: confirm runs its fresh run for LIMIT
p-inspect ::: props.sh ::: s/bombadil browser inspect "\$RUN"/bombadil inspect "\$RUN"/ ::: inspect opens bombadil's trace viewer
p-headless ::: props.sh ::: s/ARGS=\(--headless --width/ARGS=(--width/ ::: a run is headless
p-placeholder-app ::: props.sh ::: s/grep -oE '<\(app\|run-command\|stop-command\)>'/grep -oE '<(run-command|stop-command)>'/ ::: an <app> placeholder left in SKILL.md is refused
p-time-limit ::: props.sh ::: s/test "\$\{ARGS\[\@\]\}" --time-limit "\$limit" --output-path "\$out" "\$ORIGIN"/test "\${ARGS[@]}" --output-path "\$out" "\$ORIGIN"/ ::: LIMIT reaches bombadil for run and sweep
p-exit-record ::: props.sh ::: s/  \[ -z "\$RECORD" \] \|\| echo "\$1" > "\$RECORD"\n// ::: a run records how it ended
p-name-clash ::: props.sh ::: s/exports \.\*\(wraps\|Rename\) it/exports .*wraps it/ ::: a run names the app property that takes a sealed property's name
i-clash ::: spec/index.ts ::: s/  if \(sealed\[name\] instanceof Formula\) throw new Error\([^\n]*\n// ::: an app property under a sealed property's name stops the run
i-scroll ::: spec/index.ts ::: s/    \[20, scroll\],\n// ::: the run scrolls
t-typed-tag ::: spec/rules.ts ::: s/tag === "TEXTAREA" \|\| // ::: a text area takes typed text
t-value-type ::: spec/rules.ts ::: s/\/\^\(submit\|button\|reset\)\$\/i/\/^(submit|button)\$\/i/ ::: a reset input is named by its value
t-ranged-point ::: spec/rules.ts ::: s/  if \(typeof x !== "number" \|\| typeof y !== "number"\) return true;/  if (typeof x !== "number" || typeof y !== "number") return false;/ ::: a click whose point is a range counts as a hit
t-self-target ::: spec/rules.ts ::: s/\/\^\(_self\|_parent\|_top\)\?\$\/i/\/^\$\/i/ ::: a target of _self, _parent or _top names no new tab
t-invisible ::: spec/rules.ts ::: s/\.replace\(\/\[\\u00AD\\u200B-\\u200D\\u2060\\uFEFF\]\/g, ""\)// ::: a soft hyphen or a zero-width space inside a word is ignored
n-same-document ::: spec/network.ts ::: s/if \(event\.destination\.sameDocument \|\| !event\.cancelable\) return;/if (!event.cancelable) return;/ ::: a change of address inside the document is not a request
n-xhr-reuse ::: spec/network.ts ::: s/if \(this\.__jeanzRequest === request\) failed\(/failed(/ ::: an XHR object used twice records each request once
u-presskey ::: summarize.py ::: s/    if "code" in body:\n        return f"\{kind\} key \{body\['code'\]\}"\n// ::: a step shows which key was pressed
u-function ::: summarize.py ::: s/if key in \("condition", "function"\) and/if key in ("condition",) and/ ::: a violation with no condition shows its functions
u-antecedent ::: summarize.py ::: s/elif key\.endswith\("snapshots"\) and/elif key == "snapshots" and/ ::: a violation of a property that waits shows its evidence
g-comment-word ::: spec/guard.ts ::: s/    if \(!isElement\(child\)\) continue;\n/    if (!isElement(child)) { name += " "; continue; }\n/ ::: text on both sides of a comment reads as one word
g-labelled-blocks ::: spec/guard.ts ::: s/return label && nameWithin\(label, between\);/return label \&\& label.textContent;/ ::: a name through aria-labelledby keeps its words apart
g-slot-blocks ::: spec/guard.ts ::: s/\(isElement\(node\) \? nameWithin\(node, between\) : \(node\.textContent \?\? ""\)\)/(node.textContent ?? "")/ ::: slotted text keeps its words apart
p-stopped ::: props.sh ::: s/trap 'pkill -INT/trap 'echo \$? > "\${RECORD:-\/dev\/null}"; pkill -INT/ ::: a run that was stopped does not count as passed
p-violation-wins ::: props.sh ::: s/    \[ \$code -eq 2 \] \|\| explored "\$out" \|\| die 1/    [ \$rc -eq 2 ] || explored "\$out" || die 1/ ::: a violation outranks a failure of bombadil
u-verdict ::: summarize.py ::: s/        if broken:\n            sys\.exit\(2\)\n// ::: a run whose trace holds a violation exits 2
p-ready-port ::: props.sh ::: s/\[ "\$\(instance_of "\$READY_URL"\)" = "\$\(instance_of "\$ORIGIN"\)" \]/[ "\$(host_of "\$READY_URL")" = "\$(host_of "\$ORIGIN")" ]/ ::: READY_URL stays on ORIGIN's port
p-trailing-slash ::: props.sh ::: s/RUN="\$\{1%\/\}"/RUN="\$1"/ ::: a run folder named with a slash at its end is the same run
p-run-default ::: props.sh ::: s/limit="\$\{1:-5m\}"/limit="\${1:-5s}"/ ::: a run with no LIMIT explores for 5 minutes
p-shrink-limit ::: props.sh ::: s/    limit="\$\{3:-5m\}"/    limit="5m"/ ::: shrink tries for LIMIT
p-confirm-summary ::: props.sh ::: s/(Read the coverage below before trusting it\."\n)    summarize "\$fresh"\n/$1/ ::: confirm prints the coverage that it tells the reader to read
u-clip ::: summarize.py ::: s/return value if len\(value\) <= 300 else value\[:300\] \+ "\.\.\."/return value/ ::: long evidence is cut at 300 characters
u-key ::: summarize.py ::: s/"requests_blocked_distinct"/"requests_stopped_distinct"/ ::: the summary has each field that the guide names
G-command ::: GUIDE.md ::: s/\.\/props\.sh shrink <run> \[property\]/.\/props.sh minimize <run> [property]/ ::: the guide names only commands that props.sh has
u-screenshot ::: summarize.py ::: s/for candidate in \(Path\(recorded\), Path\(run_dir\) \/ "screenshots" \/ Path\(recorded\)\.name\):/for candidate in (Path(recorded),):/ ::: a report finds the screenshots of a run that was shrunk
g-select ::: spec/guard.ts ::: s/"input", "select", "textarea"/"input", "textarea"/ ::: a select counts as a control
d-labelable-select ::: spec/dom.ts ::: s/ \|\| el\.tagName === "SELECT"// ::: a select is named by its form label
g-labelledby-attr ::: spec/guard.ts ::: s/return label && nameWithin\(label, between\);/return label \&\& innerName(label, between);/ ::: a name through aria-labelledby reads the label's own attributes
n-formtarget ::: spec/network.ts ::: s/submitter\?\.getAttribute\("formtarget"\) \?\? form\.getAttribute\("target"\)/form.getAttribute("target")/ ::: a submit button that would open a new tab is held
d-formmethod ::: spec/dom.ts ::: s/submitter\?\.getAttribute\("formmethod"\) \?\? // ::: a submit button's own method counts
h-thrown-value ::: spec/health.ts ::: s/first \?\? \(value === null \|\| value === undefined \? "" : String\(value\)\)/first ?? ""/ ::: a thrown value that is no error object is shown
g-frame-top ::: spec/guard.ts ::: s/r\.top \+ host\.clientTop \+ /r.top + / ::: a click in a frame lands below the frame's top border
n-new-tab ::: spec/network.ts ::: s/always\(\(\) => inFront\.current\)/always(() => true)/ ::: a new tab breaks noNewTab
p-interrupted ::: props.sh ::: s/ \|\| explored "\$out" \|\| die 1/ || [ \$rc -eq 0 ] || die 1/ ::: a run that an interrupt stopped is not a pass
p-interrupted-fresh ::: props.sh ::: s/    explored "\$fresh" \|\| die 1/    [ \$rc -eq 0 ] || [ \$rc -eq 2 ] || die 1/ ::: confirm does not trust a fresh run that an interrupt stopped
p-interrupted-replay ::: props.sh ::: s/      0\) replay_ended "\$out" \|\| die 1[^\n]*\n         echo/      0) echo/ ::: a replay that an interrupt stopped is not a pass
p-interrupted-confirm ::: props.sh ::: s/    if replay_ended "\$replay"; then/    if [ -s "\$replay\/trace.jsonl" ] \&\& [ \$rc -ne 1 ]; then/ ::: confirm does not trust a replay that an interrupt stopped
p-stops-bombadil ::: props.sh ::: s/pkill -INT -P \$\$ -f "bombadil browser" 2> \/dev\/null \|\| true; // ::: stopping props.sh stops bombadil
p-lock-beside ::: props.sh ::: s/lock="\$\(dirname "\$OUT_ROOT"\)\//lock="\$OUT_ROOT\// ::: two skills that keep their evidence apart still share the lock of one instance
p-record-refused ::: props.sh ::: s/  die 1 "cannot write a run record in \$OUT_ROOT"\n// ::: a run says so when it cannot write its record
p-sweep-default ::: props.sh ::: s/else limit="\$\{1:-10m\}"; fi/else limit="\${1:-5m}"; fi/ ::: a sweep with no LIMIT explores for 10 minutes
p-shrink-default ::: props.sh ::: s/    limit="\$\{3:-5m\}"/    limit="\${3:-2m}"/ ::: a shrink with no LIMIT tries for 5 minutes
p-confirm-default ::: props.sh ::: s/    limit="\$\{3:-2m\}"/    limit="\${3:-5m}"/ ::: confirm with no LIMIT explores for 2 minutes
c-out-root ::: props.config.sh ::: s/-\$\(printf %s "\$HERE" \| cksum \| cut -d' ' -f1\)// ::: each checkout keeps its own evidence
u-stalled ::: summarize.py ::: s/    if waited:\n[^\n]*\n// ::: a run that gets no new state in its last half exits 3
u-stalled-after-steps ::: summarize.py ::: s/return waited if waited > last - first else 0/return waited if last == first else 0/ ::: a page that stops answering after a step fails the run
u-every-state ::: summarize.py ::: s/controls\.update\(r\.get\("name"\) or "" for r in danger\.get\("rects"\) or \[\]\)/controls = set(r.get("name") or "" for r in danger.get("rects") or [])/ ::: the summary lists the dangerous controls of every state
u-failed-count ::: summarize.py ::: s/failed = max\(failed, network\.get\("failedCount"\) or 0\)/failed = len(network.get("failed") or [])/ ::: requests_failed counts every failed answer
u-shown-screenshot ::: summarize.py ::: s/screenshot\(run_dir, recorded\) or f"\(missing\) \{recorded\}"/recorded/ ::: the summary points at a screenshot that exists
u-missing-screenshot ::: summarize.py ::: s/ or f"\(missing\) \{recorded\}"// ::: the summary says when a screenshot is missing
u-step-name ::: summarize.py ::: s/    if isinstance\(action, str\):\n        return action\n/    if isinstance(action, str):\n        return "step"\n/ ::: a step back or a reload is named in the steps before a violation
u-step-label ::: summarize.py ::: s/ or fp\.get\("accessible_name"\) or fp\.get\("id"\) or fp\.get\("tag"\)// ::: a step names its control by its text, its name, its id, or its tag
u-step-window ::: summarize.py ::: s/range\(max\(0, at - 8\), at \+ 1\)/range(0, at + 1)/ ::: the summary shows the eight steps before a violation
u-clip-list ::: summarize.py ::: s/return \[clip\(v\) for v in value\[-5:\]\]/return [clip(v) for v in value]/ ::: a list in the evidence is cut to its last five entries
u-clip-nested ::: summarize.py ::: s/return \{k: clip\(v\) for k, v in value\.items\(\)\}/return value/ ::: evidence inside a nested value is cut too
u-cap ::: summarize.py ::: s/return sorted\(names\)\[:60\]/return sorted(names)/ ::: a list in the coverage holds at most 60 entries
u-urls-cap ::: summarize.py ::: s/\.most_common\(8\)/.most_common()/ ::: the coverage names the eight pages that took most states
u-typed-cut ::: summarize.py ::: s/json\.dumps\(body\['text'\], ensure_ascii=False\)\[:40\]/json.dumps(body['text'], ensure_ascii=False)/ ::: a step shows the first 40 characters of typed text
u-custom-cut ::: summarize.py ::: s/ensure_ascii=False\)\[:60\]/ensure_ascii=False)/ ::: a step shows the first 60 characters of a custom action's arguments
n-frame-name ::: spec/network.ts ::: s/      try \{\n        if \(frame && \(frame\.name === name \|\| framed\(frame, name\)\)\) return true;\n      \} catch \{\n        continue;\n      \}\n/      if (frame \&\& (frame.name === name || framed(frame, name))) return true;\n/ ::: a frame from another origin does not break the search for a target's frame
n-each-attempt ::: spec/network.ts ::: s/    log\.blocked\.push\(`\$\{how\} \$\{method\.toUpperCase\(\)\} \$\{url\}`\);\n/    const line = `\${how} \${method.toUpperCase()} \${url}`;\n    if (!log.blocked.includes(line)) log.blocked.push(line);\n/ ::: the request block records each attempt
g-label-own ::: spec/guard.ts ::: s/map\(\(label\) => nameWithin\(label, between\)\)/map((label) => innerName(label, between))/ ::: a form label's own aria-label names its control
g-role-button ::: spec/guard.ts ::: s/const CLICKABLE_ROLES = \["button", /const CLICKABLE_ROLES = [/ ::: an element with the button role counts as a control
g-selector-wrapper ::: spec/guard.ts ::: s/  \.\.\.DANGER_SELECTORS,\n\]\.join/].join/ ::: an element that only a danger selector marks counts as a control
g-name-cut ::: spec/guard.ts ::: s/visibleName\(f\.el, " "\)\.slice\(0, 60\)/visibleName(f.el, " ")/ ::: a control's name in the record is cut at 60 characters
p-run-log ::: props.sh ::: s/ \(bombadil exit \$rc, log \$out\.log\)/ (bombadil exit \$rc)/ ::: a run names its log
p-confirm-stepped ::: props.sh ::: s/    asks "\$fresh" --stepped \|\| die 1[^\n]*\n// ::: confirm does not trust a fresh run that got no new state in its last half
u-start ::: summarize.py ::: s/        return "start"/        return "step"/ ::: the first state is named start in the steps before a violation
EOF
}

one() {
  local evidence="$1" id="$2" line file code what copy tier log killed
  line="$(table | grep -F -- "$id$SEP" | head -1)"
  [ -n "$line" ] || { echo "UNKNOWN $id"; return; }
  file="${line#*"$SEP"}"; code="${file#*"$SEP"}"; what="${code#*"$SEP"}"
  file="${file%%"$SEP"*}"; code="${code%%"$SEP"*}"
  copy="$evidence/$id/repo"
  mkdir -p "$copy"
  rsync -a --delete --exclude .git "$ROOT/" "$copy/" || { echo "BROKEN $id: could not copy the repo"; return; }
  perl -0pi -e "$code" "$copy/$TPL/$file"
  if cmp -s "$copy/$TPL/$file" "$ROOT/$TPL/$file"; then echo "NOT-APPLIED $id: the pattern for '$what' no longer matches $file"; return; fi
  case "$file" in
    *.ts) node --input-type=module -e 'import { stripTypeScriptTypes } from "node:module"; import { readFileSync, writeFileSync } from "node:fs"; writeFileSync(process.argv[2], stripTypeScriptTypes(readFileSync(process.argv[1], "utf8")));' "$copy/$TPL/$file" "$evidence/$id/stripped.mjs" && node --check "$evidence/$id/stripped.mjs" ;;
    *.py) python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())' "$copy/$TPL/$file" ;;
    *.sh) bash -n "$copy/$TPL/$file" ;;
  esac > /dev/null 2>&1 || { echo "BROKEN $id: the break for '$what' leaves $file with a syntax error"; return; }
  (cd "$copy" && tools/seal.sh > /dev/null)
  [ "${APPLY_ONLY:-}" != yes ] || { echo "APPLIES $id"; rm -rf "$evidence/$id"; return; }
  for tier in ${TIERS:-tables fast browser}; do
    log="$evidence/$id/$tier.log"
    case "$tier" in
      tables) (cd "$copy" && node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON --test "$FIX"/*.test.ts) > "$log" 2>&1 ;;
      fast) (cd "$copy" && "$FIX/props.test.sh") > "$log" 2>&1 ;;
      browser) (cd "$copy" && "$FIX/selftest.sh" "$evidence/$id/runs") > "$log" 2>&1 ;;
    esac
    if [ $? -ne 0 ]; then
      killed="$(grep -m1 -E '^(✘|✖|SELFTEST FAIL|not ok)' "$log" | cut -c1-150)"
      echo "KILLED $id ($tier): ${killed:-see $log}"
      rm -rf "$copy" "$evidence/$id/runs"
      return
    fi
  done
  echo "SURVIVED $id: nothing fails without '$what'"
}

[ $# -ge 1 ] || usage
EVIDENCE="$(mkdir -p "$1" && cd "$1" && pwd)"
shift
if [ "${1:-}" = "--one" ]; then one "$EVIDENCE" "$2"; exit 0; fi
JOBS=4
case "${1:-}" in [0-9]*) JOBS="$1"; shift ;; esac
if [ $# -gt 0 ]; then ids="$(printf '%s\n' "$@")"; else ids="$(table | sed "s/$SEP.*//")"; fi
echo "$ids" | xargs -P "$JOBS" -I '{}' "$0" "$EVIDENCE" --one '{}' | tee "$EVIDENCE/results.txt"
ran=${PIPESTATUS[1]}
left="$(grep -cvE '^(KILLED|APPLIES) ' "$EVIDENCE/results.txt" || true)"
echo "$(grep -c '^KILLED ' "$EVIDENCE/results.txt" || true) noticed, $left not noticed"
[ "$ran" -eq 0 ] && [ "$left" -eq 0 ]
