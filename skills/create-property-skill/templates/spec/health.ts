import { always } from "@antithesishq/bombadil";
import { extract, type State } from "@antithesishq/bombadil/browser";
import type { KnownIssue } from "./defaults.ts";
import { KNOWN_ISSUES } from "./config.ts";
import { known } from "./rules.ts";

export function knownIssue(check: KnownIssue["check"], text: string): boolean {
  return known(KNOWN_ISSUES, new Date(), check, text);
}

function describe(e: State["errors"]["uncaughtExceptions"][number]): string {
  const first = e.remote_object?.description?.split("\n")[0];
  const value = e.remote_object?.value;
  const detail = first ?? (value === null || value === undefined ? "" : String(value));
  const frame = e.stacktrace?.[0];
  const where = frame ? ` at ${frame.url}:${frame.line}:${frame.column}` : e.url ? ` at ${e.url}:${e.line}:${e.column}` : "";
  return `${e.text}${detail && detail !== e.text ? ` ${detail}` : ""}${where}`;
}

const consoleErrors = extract((state) =>
  state.console
    .filter((e) => e.level === "error")
    .map((e) => e.args.map(String).join(" "))
    .filter((text) => !knownIssue("console", text)),
);

const uncaught = extract((state) =>
  state.errors.uncaughtExceptions
    .map(describe)
    .filter((text) => !knownIssue(text.startsWith("Uncaught (in promise)") ? "rejection" : "exception", text)),
);

const pageStatus = extract((state) => {
  const first = state.window.performance.getEntriesByType("navigation")[0];
  const status = first && "responseStatus" in first && typeof first.responseStatus === "number" ? first.responseStatus : 0;
  const line = `${state.window.location.href} -> ${status}`;
  return status >= 400 && !knownIssue("page", line) ? line : null;
});

export const noConsoleErrors = always(() => consoleErrors.current.length === 0);

export const noUncaughtExceptions = always(() =>
  uncaught.current.every((e) => !e.startsWith("Uncaught") || e.startsWith("Uncaught (in promise)")),
);

export const noUnhandledPromiseRejections = always(() => uncaught.current.every((e) => !e.startsWith("Uncaught (in promise)")));

export const noHttpErrorCodes = always(() => pageStatus.current === null);
