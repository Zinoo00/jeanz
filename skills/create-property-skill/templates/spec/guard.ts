import { isAction, type ActionGenerator, type Range } from "@antithesishq/bombadil/actions";
import { extract, getFingerprint, type ActionTemplate, type Fingerprint, type Point } from "@antithesishq/bombadil/browser";
import { DANGER_REQUESTS, DANGER_SELECTORS, DANGER_WORDS } from "./config.ts";
import { formRequest, isElement, isForm, isFrame, isInput, isLabel, isLabelable, scopeOf } from "./dom.ts";
import { dangerousName, dangerousRequest, hits, namedByValue, normalize, typedInto, type Box } from "./rules.ts";

type Rect = Box & { name: string };
type Moved = { key: string; fromX: number; fromY: number; x: number; y: number; visible: boolean };
type Danger = { rects: Rect[]; moved: Moved[]; enterSubmitsDanger: boolean };
type Origin = { dx: number; dy: number; frame: Window | null };
type Found = Origin & { el: Element };
type Pointer = { fingerprint: Fingerprint; point: Point<Range> };

const CLICKABLE_ROLES = ["button", "link", "checkbox", "radio", "switch", "tab", "menuitem", "menuitemcheckbox", "menuitemradio", "option", "treeitem", "gridcell"];

const INTERACTIVE = [
  "a", "button", "input", "select", "textarea", "label", "summary", "[onclick]", "[tabindex]:not([tabindex='-1'])",
  ...CLICKABLE_ROLES.map((r) => `[role=${r}]`),
  ...DANGER_SELECTORS,
].join(", ");

function fingerprintKey(fp: Fingerprint): string {
  return [fp.tag, fp.id, fp.testId, fp.role, fp.accessibleName, fp.href, fp.nameAttr, fp.placeholder, fp.inputType, fp.textContent, fp.structuralPath]
    .map((v) => v ?? "")
    .join("\u0001");
}

function ownName(el: Element): (string | null)[] {
  return [el.getAttribute("aria-label"), el.getAttribute("title"), el.getAttribute("alt")];
}

function innerName(el: Element, between: string): string {
  let name = "";
  for (const child of Array.from(el.childNodes)) {
    if (child.nodeType === 3) name += child.textContent ?? "";
    if (!isElement(child)) continue;
    name += between + (child.matches(INTERACTIVE) ? " " : nameWithin(child, between)) + between;
  }
  return name;
}

function nameWithin(el: Element, between: string): string {
  return [...ownName(el), innerName(el, between)].filter(Boolean).join(" ");
}

function labelName(el: Element, between: string): string[] {
  if (!isLabelable(el)) return [];
  return Array.from(el.labels ?? []).map((label) => nameWithin(label, between));
}

function slottedName(el: Element, between: string): string {
  return Array.from(el.querySelectorAll("slot"))
    .flatMap((slot) => slot.assignedNodes({ flatten: true }))
    .map((node) => (isElement(node) ? nameWithin(node, between) : (node.textContent ?? "")))
    .join(" ");
}

function visibleName(el: Element, between: string): string {
  const labelledBy = (el.getAttribute("aria-labelledby") ?? "").split(/\s+/).filter(Boolean);
  const parts = [
    ...ownName(el),
    isInput(el) && namedByValue(el.type) ? el.value : null,
    innerName(el, between),
    slottedName(el, between),
    ...labelName(el, between),
    ...labelledBy.map((id) => {
      const label = scopeOf(el).getElementById(id);
      return label && nameWithin(label, between);
    }),
  ];
  return normalize(parts.filter(Boolean).join(" "));
}

function isDangerous(el: Element): boolean {
  if (DANGER_SELECTORS.some((s) => el.matches(s))) return true;
  if (isLabel(el)) return el.control !== null && isDangerous(el.control);
  if (typedInto(el.tagName, isInput(el) ? el.type : "")) return false;
  return [" ", ""].some((between) => dangerousName(DANGER_WORDS, visibleName(el, between)));
}

function frameOrigin(frame: Element): string {
  const src = frame.getAttribute("src") ?? "";
  try {
    return new URL(src, frame.ownerDocument.baseURI).origin;
  } catch {
    return src.slice(0, 40);
  }
}

function findAll(root: Document | ShadowRoot, origin: Origin, found: Found[], closed: Rect[]): void {
  const { dx, dy } = origin;
  for (const el of Array.from(root.querySelectorAll(INTERACTIVE))) found.push({ el, ...origin });
  for (const host of Array.from(root.querySelectorAll("*"))) {
    if (host.shadowRoot) findAll(host.shadowRoot, origin, found, closed);
    if (!isFrame(host)) continue;
    const r = host.getBoundingClientRect();
    const inner = host.contentDocument;
    if (inner) {
      const style = host.ownerDocument.defaultView?.getComputedStyle(host);
      const left = r.left + host.clientLeft + parseFloat(style?.paddingLeft ?? "0");
      const top = r.top + host.clientTop + parseFloat(style?.paddingTop ?? "0");
      findAll(inner, { dx: dx + left, dy: dy + top, frame: inner.defaultView }, found, closed);
    } else if (r.width > 0 && r.height > 0) {
      closed.push({ left: dx + r.left, top: dy + r.top, right: dx + r.right, bottom: dy + r.bottom, name: `frame ${frameOrigin(host)}` });
    }
  }
}

function formOf(el: Element | null): HTMLFormElement | null {
  return el && "form" in el && isForm(el.form) ? el.form : null;
}

function submitsDanger(form: HTMLFormElement | null): boolean {
  if (!form) return false;
  const request = formRequest(form, null, "");
  return (
    Array.from(scopeOf(form).querySelectorAll("button, input")).some((el) => "form" in el && el.form === form && isDangerous(el)) ||
    dangerousRequest(DANGER_REQUESTS, request.method, request.url)
  );
}

function place(f: Found): Moved {
  const r = f.el.getBoundingClientRect();
  const fromX = r.left + r.width / 2;
  const fromY = r.top + r.height / 2;
  const inFrame = !f.frame || (fromX >= 0 && fromY >= 0 && fromX <= f.frame.innerWidth && fromY <= f.frame.innerHeight);
  return { key: fingerprintKey(getFingerprint(f.el)), fromX, fromY, x: fromX + f.dx, y: fromY + f.dy, visible: r.width > 0 && r.height > 0 && inFrame };
}

const jeanzDanger = extract((state): Danger => {
  const found: Found[] = [];
  const closed: Rect[] = [];
  findAll(state.document, { dx: 0, dy: 0, frame: null }, found, closed);
  const hits = found.filter((f) => isDangerous(f.el));
  return {
    rects: [
      ...hits.map((f) => {
        const r = f.el.getBoundingClientRect();
        return {
          left: r.left + f.dx,
          top: r.top + f.dy,
          right: r.right + f.dx,
          bottom: r.bottom + f.dy,
          name: visibleName(f.el, " ").slice(0, 60) || f.el.tagName.toLowerCase(),
        };
      }),
      ...closed,
    ],
    moved: found.filter((f) => f.frame).map(place),
    enterSubmitsDanger: submitsDanger(formOf(state.document.activeElement)),
  };
});

function pointerOf(action: ActionTemplate): Pointer | null {
  if (isAction(action, "Click")) return action.Click;
  if (isAction(action, "DoubleClick")) return action.DoubleClick;
  return null;
}

function movedFor(target: Pointer, moved: Moved[]): Moved | undefined {
  const { x, y } = target.point;
  if (typeof x !== "number" || typeof y !== "number") return undefined;
  const key = fingerprintKey(target.fingerprint);
  return moved.find((m) => m.key === key && Math.abs(m.fromX - x) < 1 && Math.abs(m.fromY - y) < 1);
}

function reachable(action: ActionTemplate): boolean {
  const target = pointerOf(action);
  return !target || (movedFor(target, jeanzDanger.current.moved)?.visible ?? true);
}

function retarget(action: ActionTemplate): ActionTemplate {
  const target = pointerOf(action);
  const m = target && movedFor(target, jeanzDanger.current.moved);
  if (!target || !m) return action;
  const moved = { ...target, point: { x: m.x, y: m.y } };
  return isAction(action, "Click") ? { Click: moved } : { DoubleClick: moved };
}

export function safe(action: ActionTemplate): boolean {
  const d = jeanzDanger.current;
  const target = pointerOf(action);
  if (target) return !hits(target.point, d.rects);
  if (isAction(action, "PressKey")) return !(action.PressKey.code === 13 && d.enterSubmitsDanger);
  return true;
}

export function guarded(generator: ActionGenerator<ActionTemplate>): ActionGenerator<ActionTemplate> {
  return generator.filter(reachable).map(retarget).filter(safe);
}
