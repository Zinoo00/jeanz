import { actions, extract, registerCustomAction } from "@antithesishq/bombadil/browser";
import { DANGER_REQUESTS, FEATURES } from "./config.ts";
import { dangerousRequest, featuresAt } from "./rules.ts";

const visit = registerCustomAction("visit", async (_document, window, url: string) => {
  window.location.assign(url);
});

const jeanzFeatures = extract((state) => ({
  here: featuresAt(FEATURES, state.window.location.href),
  all: FEATURES.map((f) => f.name),
}));

export const visits = actions(() =>
  FEATURES.flatMap((f) =>
    f.start !== undefined && !jeanzFeatures.current.here.includes(f.name) && !dangerousRequest(DANGER_REQUESTS, "GET", f.start) ? [visit(f.start)] : [],
  ),
);
