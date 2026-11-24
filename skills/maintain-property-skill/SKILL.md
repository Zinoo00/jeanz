---
name: maintain-property-skill
description: "Upkeep pass for a properties-<app> skill. Bring its sealed files up to the current jeanz templates, prove it against the app again, and delete known issues that are fixed. Use for /maintain-property-skill, after jeanz changes its property templates, or when props.sh doctor reports changed sealed files."
disable-model-invocation: true
---

# Maintain a property skill

A `properties-<app>` skill made by [create-property-skill](../create-property-skill/SKILL.md) holds sealed files, which belong to jeanz and are identical in every app, and the app's own files. Its `GUIDE.md` lists both kinds. This pass keeps both current.

## Outcomes

Pick one outcome, and say which.

- **Clean.** The sealed files are current, `doctor` passes, a run exits 0, and nothing needs changing.
- **Changed.** You upgraded sealed files or corrected app files, and a run proves each change.
- **Blocked.** Say exactly what stopped the pass, such as no safe instance or a broken login.

## Pass

1. **Locate the skill.** Look in the repo's `.claude/skills/properties-*/`, then in `~/.claude/skills/properties-*/`. When there are several, ask which one. When there is none, stop and point the user at `/jeanz:create-property-skill`.
2. **Upgrade the sealed files.** Run `scripts/upgrade.sh <skill folder>` from this skill's folder. It replaces every sealed file with the current template and removes one that jeanz no longer ships. It leaves the app's files alone. It exits 2 when something is left for you, and it names each thing. That can be a setting or an import that the app's files lack, or an edited sealed file. Do what each line says, then run it again until it exits 0.
3. **Recover an edit the upgrade replaced.** The upgrade keeps an edited sealed file in `replaced/`. Put what the app needs into the app's files, then delete the folder. The upgrade refuses to run again while the folder is there. If no app file can express it, the flaw is in jeanz. Fix the template there, add a fixture case that fails without the fix, and upgrade again. Never edit a sealed file in place.
4. **Run the doctor.** Start the instance the skill names and run `./props.sh doctor`. When the app changed its login, its ready text, or its start command, fix the app's files.
5. **Prove it again.** Run `./props.sh run 5m` and read the coverage.
   - On exit 3, give a missed feature a `start` address, or remove a feature the app dropped.
   - Compare `dangerous_controls_skipped` with the app. Add what is missing to `spec/config.ts`. Filter out a default entry that skips something safe, and write the reason under Gotchas.
6. **Delete known issues that are fixed.** For each `KNOWN_ISSUES` entry whose issue is fixed, delete the entry and show a run that stays clean. An entry past its date stops applying, so its issue shows again. Fix the issue, or renew the entry with a new reason and date when the user agrees.
7. **Triage what the run found.** Follow the skill's own `GUIDE.md`. Report a product bug. Do not hide it behind a new `KNOWN_ISSUES` entry.

Edit only the skill's folder. Stop the instance you started. Report these facts:

- the outcome
- the sealed files you updated
- each change to an app file, with the run that proves it
- what is left for the user
