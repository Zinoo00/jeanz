# How to run a property skill

This guide is sealed. It is the same in every app, and `/jeanz:maintain-property-skill` upgrades it. What is true of this app alone is in `SKILL.md`.

Run every command from this folder. Runs and evidence go to `OUT_ROOT` in `props.config.sh`, and they stay after the instance stops.

## Files

Change only these files to fit the app:

- `props.config.sh`
- `spec/config.ts`
- `spec/actions.ts`
- `spec/properties.ts`
- `SKILL.md`

Every other file is sealed. `doctor` refuses to run when a sealed file was edited. Put an extra spec file of this app in a folder under `spec/`.

## Run

1. Start the instance the way `SKILL.md` says. `props.sh` refuses to run unless `DISPOSABLE="yes"` and the instance is on this machine or listed in `DISPOSABLE_HOSTS`. Never set that flag for an instance with real data or a live outbound channel, such as email, messages, payments, or webhooks.
2. Run `./props.sh doctor`. It checks the settings, the pinned Bombadil, the sealed files, the disposable flag, the login, and that `READY_URL` shows `READY_TEXT` only while signed in. `READY_URL` must be on the host and port of `ORIGIN`. With no `LOGIN` and no `HEADERS`, `doctor` says that the settings hold no sign-in. Each refusal has its own exit code, and `./props.sh` with no command lists the codes. Fix what it reports.
3. Run `./props.sh run 5m`. It explores until the first violation and prints a summary. The summary holds the coverage, then each violation with its condition, its evidence, the steps before it, and its screenshot. Exit 2 means a property was violated. Exit 0 means that no property broke and the run reached every feature in `FEATURES`. Exit 3 means that no property broke, but the run cannot vouch for the whole app. Exit 1 means that Bombadil failed or was stopped before any property broke. The run names its log.
   - `properties` lists the properties that the run checked. A property that is not in the list is switched off.
   - `states` counts the states that the run checked, and `actions` counts its steps by kind. A run with few states for its time limit checked little. A run that gets no new state in its last half exits 3. The page stopped answering, or it took that long to answer. The last action in the run's log is the step that got no answer.
   - `features_listed` counts the features in `FEATURES`. At zero, the run exits 3.
   - The features in `features_not_reached` were not checked, and the run exits 3. Give each one a `start` address, or run longer.
   - `dangerous_controls_skipped` lists the controls that the guard took for dangerous. A safe control in that list is not being tested.
   - `requests_blocked` counts the requests that the request block stopped, and `requests_blocked_distinct` lists them. A control that the guard let through sent each one, or the page's own code did.
   - `requests_failed` counts the 5xx answers to `fetch` and XHR, and `requests_failed_distinct` lists them.
4. Run `./props.sh sweep 30m` for a long pass that keeps every violation, for example before a release.
5. Start a run that outlasts your command timeout as a background command. It prints its summary when it ends. To stop it early, send `kill` to `props.sh`, which then stops Bombadil and its browser.
6. Stop only the instance you started.

## Triage a violation

1. Run `./props.sh shrink <run> [property]`. It cuts the run to fewer steps that still break the property. Without a property name, it takes the first one broken.
2. Run `./props.sh repro <run>-shrunk`. It must fail again. If the replay diverges, triage the original run.
3. Run `./props.sh report <run>-shrunk`. It writes `report.html`, which shows the steps with a screenshot after each. Read it, then pick the class of the violation.
   - **Product bug.** Fix the root cause (`jeanz:principle-fix-root-causes`).
   - **Wrong property.** The rule is wrong, and the app is right. Fix the property and say why. Never weaken a property to make a run pass.
   - **Known issue.** The bug is real, already known, and not this change's to fix. Add a `KNOWN_ISSUES` entry in `spec/config.ts` with a reason and a date, and tell the user. Never use an entry to hide a new bug.
   - **Tool artifact.** The instance or Bombadil caused it. Write it under Gotchas in `SKILL.md`.
   - **`noDangerousRequestAttempted`.** The request block stopped a request, and `requests_blocked_distinct` names it. When a control sent it, add the control's label or selector to `spec/config.ts`. When the request is safe, narrow `DANGER_REQUESTS`. When the page sends a dangerous request by itself, report it.
4. After the fix, run `./props.sh confirm <run>-shrunk`. It must exit 0, which means the recorded steps hold and a fresh run does not break the property again. It exits 18 when the spec no longer holds the property, because a property that is switched off cannot break.
5. Report the shrunk steps, the report's path, the class, and the fix.

## Turn a correction into a property

When the user corrects how the UI behaves, the correction becomes a check (`jeanz:principle-encode-lessons-in-structure`). Prefer a type, a lint, or a test when one can hold the rule (`/jeanz:correct`). Write a property when the rule is about UI behavior over time.

1. Write the property in `spec/properties.ts`, and name it for the rule.
2. Show it failing on the current code.
3. Fix the app, then show `./props.sh confirm` passing on the same steps.
4. Add a row for it to the table in `SKILL.md`. `doctor` refuses to run while a property has no row, and a run exits 19 when it checked one.

## Properties that every app gets

| Property | Rule in plain words |
|---|---|
| `noUncaughtExceptions`, `noUnhandledPromiseRejections`, `noConsoleErrors` | No crashes, rejected promises, or console errors, except `KNOWN_ISSUES` |
| `noHttpErrorCodes` | No 4xx or 5xx on a page load, except `KNOWN_ISSUES` |
| `noFailedRequests` | No `fetch` or XHR answers 5xx, except `KNOWN_ISSUES` |
| `signedIn` | The run never ends up signed out |
| `noDangerousRequestAttempted` | The request block never has to stop a request |
| `noNewTab` | The page never goes out of view, which is what a new tab does to it |

After the first failed or stopped request, its property stays broken in every later state of that run. Its count is then a count of states. The lists in the coverage say what happened.

## Protections

1. The instance runs on disposable data, with every outbound channel off or pointed at a sink. This one is the real protection.
2. `spec/guard.ts` drops a click or a double-click on a dangerous control, and Enter in a form whose submit button or request is dangerous. A control is dangerous when it matches `DANGER_WORDS` or `DANGER_SELECTORS` in `spec/config.ts`. The guard reads a control's name from its text, `aria-label`, `title`, `alt`, button value, and form label. A label is dangerous when its control is. The guard looks inside shadow trees and same-origin frames, and it drops every click inside a frame from another origin.
3. `spec/network.ts` blocks each request that matches `DANGER_REQUESTS`. That covers `fetch`, XHR, beacons, form submits, links, new tabs, and any other navigation. A form's `_method` field counts as its method. The block is installed before a page's own code runs, in the page and in its same-origin frames. It records each attempt. A stopped request fails as a dropped connection would, so what the app shows next is not the app's bug.

The guard has limits, and the request block and the disposable instance cover them:

- It judges a click, a double-click, and Enter in a form. It does not judge another key, a typed newline, or a drag that an app's own action generator sends.
- It places a click in a frame by the frame's box. In a frame that CSS scales or rotates, a click can land on a control that `dangerous_controls_skipped` lists.
- It reads text and attributes. It does not recognize a control whose only name is an icon font or a picture with no text. Mark that control with `data-destructive`.

The request block has limits, and only the disposable instance covers them:

- It matches a request's method and address. It reads no body and no header, so it cannot tell one write from another at a single address.
- It does not stop a request that loads an image, a script, a stylesheet, a frame's first page, or an event stream.
- It does not stop a request from a worker or over a WebSocket.

Custom action generators go in `customActions` in `spec/actions.ts`, where the guard wraps them. A run refuses to start when `spec/properties.ts` exports one. An action made with `registerCustomAction` runs code in the page, so the guard cannot judge it. Only the request block covers it.

## Gotchas

- A stuck state shows only while the run stays on the page. Visits to other features, back, and reload are rare on purpose. Keep a custom action that navigates rare too.
- A new tab takes the page out of view, and the run then takes a step only every 5 to 10 seconds. A link or a form that names a new tab is held, and `window.open` returns `null`, as it does when a browser blocks a pop-up. An app that uses that result unchecked throws. Fix the app, or list the error in `KNOWN_ISSUES`. A tab that opens another way breaks `noNewTab` at that step. List the control that opened it in `DANGER_SELECTORS`. Give a feature that opens only in a new tab a `start` address.
- Trust `bombadil browser <command> --help`, not the online manual. The manual runs ahead of the pinned release.
