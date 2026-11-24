import { Formula } from "@antithesishq/bombadil";
import { ActionGenerator } from "@antithesishq/bombadil/actions";
import { extract, weighted, type ActionTemplate } from "@antithesishq/bombadil/browser";
import { clicks, inputs, navigation, scroll } from "@antithesishq/bombadil/browser/defaults/actions";
import { customActions } from "./actions.ts";
import { guarded } from "./guard.ts";
import * as health from "./health.ts";
import * as network from "./network.ts";
import * as app from "./properties.ts";
import { visits } from "./reach.ts";
import * as session from "./session.ts";

const sealed: Record<string, unknown> = { ...health, ...network, ...session };

for (const [name, value] of Object.entries(app)) {
  if (value instanceof ActionGenerator) {
    throw new Error(`spec/properties.ts exports the action generator ${name}. Put it in customActions in spec/actions.ts, where the guard wraps it.`);
  }
  if (sealed[name] instanceof Formula) throw new Error(`spec/properties.ts exports ${name}, and a sealed file owns that name. Rename it.`);
}

export { noConsoleErrors, noHttpErrorCodes, noUncaughtExceptions, noUnhandledPromiseRejections } from "./health.ts";
export { noDangerousRequestAttempted, noFailedRequests, noNewTab } from "./network.ts";
export { signedIn } from "./session.ts";
export * from "./properties.ts";

const jeanzProperties = extract(() =>
  Object.entries({ ...sealed, ...app }).flatMap(([name, value]) => (value instanceof Formula ? [name] : [])),
);

export const exploration = guarded(
  weighted([
    [100, clicks],
    [50, inputs],
    [20, scroll],
    [1, visits],
    [1, navigation],
    ...customActions.map((generator): [number, ActionGenerator<ActionTemplate>] => [50, generator]),
  ]),
);
