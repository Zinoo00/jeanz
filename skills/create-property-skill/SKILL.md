---
name: create-property-skill
description: "Generate a project-local properties-<app> skill that explores a web app with Bombadil (property-based UI testing) and checks properties in every state. Use for /create-property-skill, \"set up bombadil for this app\", or when a web UI has no way to find bugs on paths nobody scripted."
disable-model-invocation: true
---

# Create a property skill

A `properties-<app>` skill lets any agent explore a web app at random and check properties in every state. It cuts a failing run to a few steps. Use it next to `verify-<app>` from [create-verification-skill](../create-verification-skill/SKILL.md). The verify skill proves that the change you made works. The property skill finds what breaks on paths nobody tried. Write the output for an agent that reads it cold, in the middle of a task.

The generated skill holds two kinds of files. The sealed files belong to jeanz and are identical in every app. They are the scripts, most of the spec, and `GUIDE.md`, which says how to run and triage. `doctor` refuses to run when one of them was edited. The app's files hold everything about this one app. They are `props.config.sh`, `spec/config.ts`, `spec/actions.ts`, `spec/properties.ts`, and `SKILL.md`. This skill fills only the app's files.

## 1. Interview the repo, not the user

Answer from the code. Ask the user only what you cannot observe. When the project has a `verify-<app>` skill, start from it. Its launch steps, its login, and its feature map answer most of this list.

- **What to explore.** The web UI. Bombadil's terminal driver is experimental, so skip terminal apps.
- **Run.** The command that starts a disposable instance on this machine, and the URL of that instance. When `verify-<app>` launches one instance for each parallel agent, a run must drive its own agent's instance. Find how the settings learn that instance's URL.
- **Signed in.** A URL whose response only a signed-in user gets, and a piece of text in that response. They go in `READY_URL` and `READY_TEXT`. `doctor` fetches the URL with `curl`. When the browser builds the page, use an API route such as the current-user endpoint. Note also what a signed-out page looks like, such as its URL or a password field.
- **Login.** A command that signs in and prints the session cookies, one `NAME=VALUE` per line. The command must exit non-zero when the sign-in fails. A `curl` call to the login endpoint usually does it. The command goes in `LOGIN`. Never click through a login page. When the app keeps its session in browser storage, stop and say so. The fix belongs in the app, whose disposable instance needs a way to sign in by cookie.
- **Dangerous controls.** Every control that destroys data the run depends on, ends the session, changes settings other people share, or has an effect outside the instance. Effects outside the instance include email, messages, payments, webhooks, and calls to other services. Record the visible label of each control in every language the UI uses. Record its selector, and the method and URL of the request it sends.
- **Isolation.** The instance must run on disposable data, with every outbound channel off or pointed at a sink. **Never run against an instance that has real data or a live outbound channel.** The disposable instance is the first protection. The guard and the request block come second and third. When you cannot confirm isolation from the code, ask the user which instance is safe, and stop until they answer.
- **Features.** Every user-facing feature. Record a URL pattern that shows the run is inside the feature, and a start URL that opens the feature directly. When the verify skill has a feature map, take the features from it.
- **Known issues.** Errors the app already shows on a normal visit, such as a console error or a failed request. Each one needs a reason and a date by which it should be gone.

## 2. Generate the skill

1. Pick the folder. When the repo is the user's to change, use `<repo>/.claude/skills/properties-<app>/`. Otherwise use `~/.claude/skills/properties-<app>/`, and never commit the skill to someone else's repo.
2. Copy `templates/` into the folder. Rename `SKILL.md.template` to `SKILL.md`. Replace every `<app>`, `<run-command>`, and `<stop-command>` in it.
3. Fill `props.config.sh`:
   - `ORIGIN`, `READY_URL`, `READY_TEXT`, and `LOGIN` come from the interview.
   - `WIDTH` and `HEIGHT` are the viewport the app is designed for.
   - `OUT_ROOT` is where runs are kept. The default is a folder under `~/.jeanz/properties/`, outside git, named for the skill's folder and a checksum of its path.
   - Set `DISPOSABLE="yes"` only after the isolation answer from step 1.
   - List a host in `DISPOSABLE_HOSTS` only when the disposable instance runs on another machine.
   - `BOMBADIL_ARGS` takes the Bombadil flags that this app needs.
4. Fill `spec/config.ts`:
   - `DANGER_WORDS`, `DANGER_SELECTORS`, and `DANGER_REQUESTS` start from the entries in `spec/defaults.ts`. Those entries destroy data or end the session in any app. Add this app's own entries. A control that carries `data-destructive` in the app needs no entry.
   - A word in `DANGER_WORDS` is lowercase and can be in any language. It matches as a whole word in a script that has letter case, and anywhere in a script that has none.
   - `DANGER_REQUESTS` lists the methods and URL patterns that the request block stops.
   - When an entry from `spec/defaults.ts` blocks something safe in this app, filter it out here and write the reason under Gotchas.
   - `SIGNED_OUT` describes a signed-out page. Its `urls` start from the sign-in addresses in `spec/defaults.ts`. Add to `selectors` an element that only a signed-out page has, such as the sign-in form.
   - `FEATURES` has one entry per feature. An entry has a `name`, a `url` pattern that shows the run is inside the feature, and a `start` address the run can visit.
   - `KNOWN_ISSUES` has one entry per known issue. An entry has the `check` it belongs to, a `match` pattern, a `reason`, and an `until` date. The checks are `console`, `exception`, `rejection`, `request`, and `page`. An entry with no reason, or past its date, does not apply.
5. Leave the sealed files as they are. Custom action generators go in `customActions` in `spec/actions.ts`.

## 3. Seed properties

Read the [Bombadil facts](references/bombadil-facts.md) before you write a property or an action generator. The template already checks the [properties that every app gets](templates/GUIDE.md#properties-that-every-app-gets). An app property cannot take one of their names.

Add one to three properties for this app in `spec/properties.ts`. Write only rules you can read in the code, such as a loading state that must clear or a total that must equal its rows. Add a row for each one to the property table in the generated `SKILL.md`, or `doctor` refuses to run. Before you trust a new property, show it failing once. Use a planted break in a scratch branch, or the commit of a past bug.

## 4. Prove the generated skill

Follow the generated skill's `GUIDE.md` once from start to end. Start the instance, run `props.sh doctor`, then run `props.sh run 5m`. Read the coverage in the summary:

- The run exits 0 or 2.
- `dangerous_controls_skipped` matches the dangerous controls from the interview, and holds nothing safe.
- The instance's request log shows no request from a dangerous control.

When the run finds a violation, run `shrink`, `repro`, and `report` on it. Stop the instance, then confirm that the run folder still exists. Fix what fails, and stop the instance after every failed attempt. A generated skill that never ran is a draft. The `status.sh` of [adopt](../adopt/SKILL.md) counts the skill only after its newest run exits 0.

## 5. Hand off

Reply with these facts:

- where the skill lives
- which instance it runs against, and why that instance is safe
- the run you did, with its duration, coverage, and violations
- the class of each violation, which is product bug, wrong property, known issue, or tool artifact
- every step you could not verify
