import { always } from "@antithesishq/bombadil";
import { extract } from "@antithesishq/bombadil/browser";
import { SIGNED_OUT } from "./config.ts";
import { signedOutAt } from "./rules.ts";

const signedOut = extract(
  (state) =>
    signedOutAt(SIGNED_OUT.urls, state.window.location.href) ||
    SIGNED_OUT.selectors.some((s) => state.document.querySelector(s) !== null),
);

export const signedIn = always(() => !signedOut.current);
