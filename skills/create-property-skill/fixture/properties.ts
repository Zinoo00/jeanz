import { always, eventually, now } from "@antithesishq/bombadil";
import { extract } from "@antithesishq/bombadil/browser";

const spinnerVisible = extract(
  (state) => state.document.querySelector("#spinner")?.classList.contains("visible") ?? false,
);

export const spinnerClears = always(
  now(() => spinnerVisible.current).implies(eventually(() => !spinnerVisible.current).within(3, "seconds")),
);
