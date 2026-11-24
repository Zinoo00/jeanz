import { actions, extract, getFingerprint } from "@antithesishq/bombadil/browser";

const TEXT_FIELDS = ["#account input[name=reason]", "#note", "#why", "#outside", "#input", "#override", "#safe"];

function locate(document: Document, selector: string) {
  const el = document.querySelector(selector);
  if (!el) return [];
  const r = el.getBoundingClientRect();
  return [{ fingerprint: getFingerprint(el), point: { x: r.left + r.width / 2, y: r.top + r.height / 2 } }];
}

const row = extract((state) => locate(state.document, "#row"));
const probes = extract((state) => locate(state.document, "#probes"));
const outer = extract((state) => locate(state.document, "#outer"));
const fields = extract((state) => TEXT_FIELDS.flatMap((selector) => locate(state.document, selector)));
const fieldFocused = extract((state) => TEXT_FIELDS.some((selector) => state.document.activeElement?.matches(selector) ?? false));

const doubleClickRow = actions(() => row.current.map((target) => ({ DoubleClick: target })));
const clickProbes = actions(() => probes.current.map((target) => ({ Click: target })));
const clickOuterFrame = actions(() => outer.current.map((target) => ({ Click: target })));
const focusField = actions(() => fields.current.map((target) => ({ Click: target })));
const enterInField = actions(() => (fieldFocused.current ? [{ PressKey: { code: 13 } }] : []));

export const customActions = [doubleClickRow, clickProbes, clickOuterFrame, focusField, enterInField];
