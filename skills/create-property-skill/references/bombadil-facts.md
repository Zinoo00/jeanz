# Bombadil facts to trust

These facts hold for the Bombadil version that `props.sh` pins. Read them before you trust the online manual.

- `props.sh` pins the Bombadil version that the sealed files were written against. The online manual tracks `main` and runs ahead of releases. Bombadil 0.7.10 has no `bombadil trace` command, and its `--output-path` is a folder. Trust `bombadil browser <command> --help` from the installed binary. `summarize.py` does the job of `bombadil trace`.
- Spec files import `@antithesishq/bombadil/...` without `npm install`, because the binary bundles the library. An `extract` callback runs in the page and can use module-level constants and functions.
- `test` exits 2 on a violation, and 1 when the spec did not load. SIGINT stops it with exit 0. `props.sh` therefore counts a run as whole only on the line `Test finished after time limit` or `Reproduction finished`. SIGTERM leaves Chrome running, so `props.sh` stops Bombadil with SIGINT. When a page stops answering, `test` waits until its time limit and exits 0. `props.sh` therefore fails a run that got no new state in its last half. After a new tab opens, the page reports `document.visibilityState` as `hidden`, and a step then takes 5 to 10 seconds. `test` logs `timed out waiting for response` in that state, and also on a healthy page that loads slowly, so the log line proves nothing. `sweep` runs without `--exit-on-violation`, so one bug repeats hundreds of times in its trace.
- `shrink` refuses a trace that broke more than one property unless you name one. `props.sh shrink` names the first one broken. `shrink` is experimental. When it cannot reproduce the failure, triage the original run.
- A shrunk trace records its screenshots under a folder that Bombadil deletes. `summarize.py` finds them in the run folder.
- Bombadil 0.7.10 clicks a control inside a same-origin frame at the wrong place on the page. `spec/guard.ts` moves those clicks to the control. Bombadil never picks a control that sits two frames deep.
- Bombadil prints `--cookie` and `--header` values in its log, and `props.sh` redacts them. The values still show in `ps` while a run is going.
