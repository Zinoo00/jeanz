import { formMethod } from "./rules.ts";

export function isElement(value: unknown): value is Element {
  return typeof value === "object" && value !== null && "nodeType" in value && value.nodeType === 1 && "tagName" in value;
}

export function isFrame(el: Element): el is HTMLIFrameElement {
  return el.tagName === "IFRAME";
}

export function isForm(value: unknown): value is HTMLFormElement {
  return isElement(value) && value.tagName === "FORM";
}

export function isInput(el: Element): el is HTMLInputElement {
  return el.tagName === "INPUT";
}

export function isLabel(el: Element): el is HTMLLabelElement {
  return el.tagName === "LABEL";
}

export function isLabelable(el: Element): el is HTMLInputElement | HTMLButtonElement | HTMLSelectElement {
  return el.tagName === "INPUT" || el.tagName === "BUTTON" || el.tagName === "SELECT";
}

export function scopeOf(el: Element): Document | ShadowRoot {
  const root = el.getRootNode();
  return isScope(root) ? root : el.ownerDocument;
}

function isScope(node: Node): node is Document | ShadowRoot {
  return node.nodeType === 9 || node.nodeType === 11;
}

export function formRequest(form: HTMLFormElement, submitter: Element | null, fallback: string): { method: string; url: string } {
  const field = form.elements.namedItem("_method");
  const method = submitter?.getAttribute("formmethod") ?? form.getAttribute("method") ?? "GET";
  return {
    method: formMethod(method, isElement(field) && isInput(field) ? field.value : null),
    url: submitter?.getAttribute("formaction") ?? form.getAttribute("action") ?? fallback,
  };
}
