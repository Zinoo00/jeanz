import { always } from "@antithesishq/bombadil";
import { extract } from "@antithesishq/bombadil/browser";
import { DANGER_REQUESTS } from "./config.ts";
import { formRequest, isElement, isForm } from "./dom.ts";
import { knownIssue } from "./health.ts";
import { dangerousRequest, formMethod, namesNewTab, serverFailed } from "./rules.ts";

type Log = { blocked: string[]; failed: string[] };
type Realm = Window & typeof globalThis;
type Open = (this: XMLHttpRequest, method: string, url: string | URL, async: boolean, username?: string | null, password?: string | null) => void;

declare global {
  interface Window {
    __jeanzLog?: Log;
  }
  interface XMLHttpRequest {
    __jeanzRequest?: { method: string; url: string; async: boolean };
  }
}

const CARRIED = "__jeanzLog";

function isLines(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((line) => typeof line === "string");
}

function isLog(value: unknown): value is Log {
  return typeof value === "object" && value !== null && "blocked" in value && isLines(value.blocked) && "failed" in value && isLines(value.failed);
}

function carry(w: Window, log: Log): void {
  try {
    w.sessionStorage.setItem(CARRIED, JSON.stringify(log));
  } catch {
    return;
  }
}

function carried(w: Window): Log {
  const fresh: Log = { blocked: [], failed: [] };
  try {
    const kept: unknown = JSON.parse(w.sessionStorage.getItem(CARRIED) ?? "null");
    w.sessionStorage.removeItem(CARRIED);
    return isLog(kept) ? kept : fresh;
  } catch {
    return fresh;
  }
}

function sharedLog(w: Window): Log {
  let owner = w;
  while (owner.frameElement) owner = owner.parent;
  owner.__jeanzLog ??= carried(owner);
  return owner.__jeanzLog;
}

function isRequest(input: unknown): input is Request {
  return typeof input === "object" && input !== null && "url" in input && "method" in input && typeof input.url === "string" && typeof input.method === "string";
}

function requestUrl(input: unknown): string {
  return isRequest(input) ? input.url : String(input);
}

function requestMethod(input: unknown, init: RequestInit | undefined): string {
  if (init?.method) return String(init.method);
  return isRequest(input) ? input.method : "GET";
}

function isShadowRoot(node: EventTarget): node is ShadowRoot {
  return "host" in node && "nodeType" in node && node.nodeType === 11;
}

const REFUSED = "jeanz-request-block:refused";

function hook(w: Realm, log: Log): void {
  const absolute = (raw: string): string | null => {
    try {
      const url = new w.URL(raw, w.document.baseURI);
      url.hash = "";
      return url.href;
    } catch {
      return null;
    }
  };
  const framed = (within: Window, name: string): boolean => {
    for (let i = 0; i < within.frames.length; i += 1) {
      const frame = within.frames[i];
      try {
        if (frame && (frame.name === name || framed(frame, name))) return true;
      } catch {
        continue;
      }
    }
    return false;
  };
  const opensTab = (target: string | null): boolean => namesNewTab(target ?? "") && !framed(w.top ?? w, target ?? "");
  const failed = (method: string, raw: string, status: number) => {
    const line = `${method.toUpperCase()} ${absolute(raw) ?? raw} -> ${status}`;
    if (serverFailed(status) && !knownIssue("request", line)) log.failed.push(line);
  };
  const block = (how: string, method: string, raw: string): boolean => {
    const url = absolute(raw);
    if (url === null || !dangerousRequest(DANGER_REQUESTS, method, url)) return false;
    log.blocked.push(`${how} ${method.toUpperCase()} ${url}`);
    return true;
  };

  const realFetch = w.fetch.bind(w);
  w.fetch = (input: RequestInfo | URL, init?: RequestInit) => {
    const url = requestUrl(input);
    const method = requestMethod(input, init);
    if (block("fetch", method, url)) return Promise.reject(new w.TypeError("Failed to fetch"));
    return realFetch(input, init).then((res) => {
      failed(method, url, res.status);
      return res;
    });
  };

  const xhr = w.XMLHttpRequest.prototype;
  const realXhrOpen: Open = xhr.open;
  const realSend = xhr.send;
  xhr.open = function (this: XMLHttpRequest, method: string, url: string | URL, async: boolean = true, username?: string | null, password?: string | null) {
    this.__jeanzRequest = { method, url: String(url), async };
    return realXhrOpen.call(this, method, url, async, username, password);
  };
  xhr.send = function (this: XMLHttpRequest, body?: Document | XMLHttpRequestBodyInit | null) {
    const request = this.__jeanzRequest ?? { method: "GET", url: "", async: true };
    if (block("xhr", request.method, request.url)) {
      realXhrOpen.call(this, "GET", REFUSED, request.async);
      return realSend.call(this);
    }
    this.addEventListener("loadend", () => {
      if (this.__jeanzRequest === request) failed(request.method, request.url, this.status);
    });
    return realSend.call(this, body);
  };

  const beacon = w.Navigator.prototype;
  const realBeacon = beacon.sendBeacon;
  beacon.sendBeacon = function (this: Navigator, url: string | URL, data?: BodyInit | null) {
    return block("beacon", "POST", String(url)) || realBeacon.call(this, url, data);
  };

  const stopsForm = (form: HTMLFormElement, submitter: Element | null, how: string): boolean => {
    const request = formRequest(form, submitter, w.location.href);
    return block(how, request.method, request.url) || opensTab(submitter?.getAttribute("formtarget") ?? form.getAttribute("target"));
  };
  const stopsLink = (link: Element): boolean => block("link", "GET", link.getAttribute("href") ?? "") || opensTab(link.getAttribute("target"));
  const heard = new WeakSet<Node>();
  const listen = (root: Document | ShadowRoot) => {
    if (heard.has(root)) return;
    heard.add(root);
    root.addEventListener(
      "submit",
      (event: Event) => {
        const submitter = "submitter" in event && isElement(event.submitter) ? event.submitter : null;
        if (isForm(event.target) && stopsForm(event.target, submitter, "form")) event.preventDefault();
      },
      true,
    );
    root.addEventListener(
      "click",
      (event: Event) => {
        const link = event.composedPath().find((node) => isElement(node) && node.matches("a[href]"));
        if (isElement(link) && stopsLink(link)) event.preventDefault();
      },
      true,
    );
  };
  w.addEventListener("click", (event) => event.composedPath().filter(isShadowRoot).forEach(listen), true);
  listen(w.document);
  const realAttach = w.Element.prototype.attachShadow;
  w.Element.prototype.attachShadow = function (this: Element, init: ShadowRootInit) {
    const root = realAttach.call(this, init);
    listen(root);
    return root;
  };
  const form = w.HTMLFormElement.prototype;
  const realSubmit = form.submit;
  const realRequestSubmit = form.requestSubmit;
  form.submit = function (this: HTMLFormElement) {
    if (!stopsForm(this, null, "form.submit()")) realSubmit.call(this);
  };
  form.requestSubmit = function (this: HTMLFormElement, submitter?: HTMLElement | null) {
    if (!stopsForm(this, submitter ?? null, "form")) realRequestSubmit.call(this, submitter);
  };
  const realClick = w.HTMLElement.prototype.click;
  w.HTMLElement.prototype.click = function (this: HTMLElement) {
    if (this.isConnected || !this.matches("a[href]") || !stopsLink(this)) realClick.call(this);
  };
  const realOpen = w.open.bind(w);
  w.open = (url?: string | URL, target?: string, features?: string) => {
    if (url !== undefined && block("open", "GET", String(url))) return null;
    return opensTab(target ?? "_blank") ? null : realOpen(url, target, features);
  };
  w.navigation.addEventListener("navigate", (event) => {
    if (event.destination.sameDocument || !event.cancelable) return;
    const field = event.formData?.get("_method");
    const method = event.formData ? formMethod("POST", typeof field === "string" ? field : null) : "GET";
    if (block("navigate", method, event.destination.url)) event.preventDefault();
  });
}

if (typeof window !== "undefined") {
  const log = sharedLog(window);
  hook(window, log);
  if (!window.frameElement) window.addEventListener("pagehide", () => carry(window, log));
}

function distinct(lines: string[]): string[] {
  return [...new Set(lines)].slice(-40);
}

const jeanzNetwork = extract((state) => {
  const log = sharedLog(state.window);
  return { blocked: distinct(log.blocked), blockedCount: log.blocked.length, failed: distinct(log.failed), failedCount: log.failed.length };
});

export const noDangerousRequestAttempted = always(() => jeanzNetwork.current.blockedCount === 0);

export const noFailedRequests = always(() => jeanzNetwork.current.failedCount === 0);

const inFront = extract((state) => state.document.visibilityState === "visible");

export const noNewTab = always(() => inFront.current);
