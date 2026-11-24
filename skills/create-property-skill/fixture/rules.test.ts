import assert from "node:assert/strict";
import { test } from "node:test";
import { DEFAULTS, type Feature, type KnownIssue } from "../templates/spec/defaults.ts";
import { dangerousName, dangerousRequest, featuresAt, formMethod, hits, known, namedByValue, namesNewTab, serverFailed, signedOutAt, typedInto } from "../templates/spec/rules.ts";

const words = [...DEFAULTS.dangerWords, "삭제"];
const requests = { methods: [...DEFAULTS.dangerMethods], urls: [...DEFAULTS.dangerUrls] };

test("a name is dangerous when a listed word stands on its own in it", () => {
  const cases: [string, boolean][] = [
    ["Delete", true],
    ["Delete account", true],
    ["Permanently delete", true],
    ["removeEntry", true],
    ["Remove (double-click)", true],
    ["Erase", true],
    ["Wipe data", true],
    ["Discard draft", true],
    ["Log out", true],
    ["LOGOUT", true],
    ["Sign out", true],
    ["전체삭제", true],
    ["Ｄｅｌｅｔｅ", true],
    ["Deleted items", false],
    ["Undelete", false],
    ["Removal policy", false],
    ["Rename", false],
    ["Signature", false],
    ["Log\n   out", true],
    ["Sign\tout", true],
    ["Undelete, then delete", true],
    ["Undelete", false],
    ["", false],
    ["Log-out", true],
    ["Sign_out now", true],
    ["Log\u2011out", true],
    ["Blog-outline", false],
    ["De\u00ADlete", true],
    ["Dele\u200Bte account", true],
    ["Un\u00ADdelete", false],
  ];
  for (const [name, expected] of cases) assert.equal(dangerousName(words, name), expected, name);
  assert.equal(dangerousName(["opt-out"], "Opt out of email"), true, "a listed word with a hyphen");
  assert.equal(dangerousName([""], "Save"), false, "an empty word");
  assert.equal(dangerousName(["  "], "Save now"), false, "a blank word");
});

test("a request is dangerous by its method or by its address", () => {
  const cases: [string, string, boolean][] = [
    ["DELETE", "/api/ok", true],
    ["delete", "/api/ok", true],
    ["GET", "/api/items/3/delete", true],
    ["POST", "/account/removeAll", true],
    ["POST", "/api/DeleteUser", true],
    ["GET", "/logout", true],
    ["GET", "/users/sign_out", true],
    ["GET", "/auth/signOut", true],
    ["POST", "/api/logOut", true],
    ["GET", "/api/ok", false],
    ["GET", "/api/ok?deleted", false],
    ["GET", "/api/undelete/3", false],
    ["POST", "/api/removals", false],
  ];
  for (const [method, url, expected] of cases) assert.equal(dangerousRequest(requests, method, url), expected, `${method} ${url}`);
});

test("a known issue applies only with a reason, before its date, to its own check", () => {
  const issue: KnownIssue = { check: "console", match: /noisy widget/, reason: "planted", until: "2026-06-30" };
  const lastDay = new Date(2026, 5, 30, 23, 59);
  const nextDay = new Date(2026, 6, 1, 0, 0);
  const cases: [KnownIssue, Date, KnownIssue["check"], string, boolean][] = [
    [issue, lastDay, "console", "the noisy widget failed", true],
    [issue, new Date(2026, 5, 1, 0, 0), "console", "the noisy widget failed", true],
    [issue, nextDay, "console", "the noisy widget failed", false],
    [{ ...issue, until: "2026-06-15" }, lastDay, "console", "the noisy widget failed", false],
    [issue, new Date(2027, 0, 1, 12, 0), "console", "the noisy widget failed", false],
    [issue, lastDay, "request", "the noisy widget failed", false],
    [issue, lastDay, "console", "another error", false],
    [{ ...issue, reason: "  " }, lastDay, "console", "the noisy widget failed", false],
    [{ ...issue, until: "next month" }, lastDay, "console", "the noisy widget failed", false],
    [{ ...issue, until: "2026-7-1" }, lastDay, "console", "the noisy widget failed", false],
  ];
  for (const [entry, now, check, text, expected] of cases) {
    assert.equal(known([entry], now, check, text), expected, `${entry.reason}|${entry.until}|${now.toString()}|${check}|${text}`);
  }
});

test("a feature is reached when its pattern matches the address", () => {
  const features: Feature[] = [
    { name: "items", url: /\/items\b/, start: "/items" },
    { name: "billing", url: /\/billing\b/ },
  ];
  assert.deepEqual(featuresAt(features, "http://127.0.0.1/items?page=2"), ["items"]);
  assert.deepEqual(featuresAt(features, "http://127.0.0.1/"), []);
});

test("a sign-in address means signed out", () => {
  const cases: [string, boolean][] = [
    ["http://127.0.0.1/login", true],
    ["http://127.0.0.1/signin?next=%2F", true],
    ["http://127.0.0.1/app/sign-in", true],
    ["http://127.0.0.1/users/sign_in", true],
    ["http://127.0.0.1/account/log-in/", true],
    ["http://127.0.0.1/login.html", true],
    ["http://127.0.0.1/Login#next", true],
    ["http://127.0.0.1/dashboard", false],
    ["http://127.0.0.1/settings/login-history", false],
    ["http://127.0.0.1/blog/signin-tips", false],
    ["http://127.0.0.1/login?next=/dashboard", true],
    ["http://127.0.0.1/#/login", true],
    ["http://127.0.0.1/dashboard?next=/login", false],
  ];
  for (const [href, expected] of cases) assert.equal(signedOutAt(DEFAULTS.signedOutUrls, href), expected, href);
});

test("a rule gives the same answer every time, however it is written", () => {
  const rules = { methods: ["delete"], urls: [/\/purge\//g] };
  for (const attempt of [1, 2, 3, 4]) assert.equal(dangerousRequest(rules, "POST", "/purge/all"), true, `request, attempt ${attempt}`);
  assert.equal(dangerousRequest(rules, "DELETE", "/api/ok"), true, "a method listed in lower case");
  const issue: KnownIssue = { check: "console", match: /noisy/g, reason: "planted", until: "2026-06-30" };
  for (const attempt of [1, 2]) assert.equal(known([issue], new Date(2026, 5, 30), "console", "noisy widget"), true, `known issue, attempt ${attempt}`);
  const features: Feature[] = [{ name: "items", url: /\/items/g }];
  for (const attempt of [1, 2]) assert.deepEqual(featuresAt(features, "/items"), ["items"], `feature, attempt ${attempt}`);
  for (const attempt of [1, 2]) assert.equal(signedOutAt([/\/enter/g], "/enter"), true, `sign-in address, attempt ${attempt}`);
});

test("a form sends the method that its _method field names, when the form posts", () => {
  const cases: [string, string | null, string][] = [
    ["post", "delete", "delete"],
    ["POST", "PATCH", "PATCH"],
    ["POST", null, "POST"],
    ["POST", "", "POST"],
    ["get", "delete", "get"],
  ];
  for (const [method, field, expected] of cases) assert.equal(formMethod(method, field), expected, `${method} with ${field}`);
});

test("a request failed when the server answered with a 5xx status", () => {
  const cases: [number, boolean][] = [
    [500, true],
    [503, true],
    [599, true],
    [404, false],
    [422, false],
    [200, false],
    [0, false],
  ];
  for (const [status, expected] of cases) assert.equal(serverFailed(status), expected, `status ${status}`);
});

test("each default entry is listed here with an example that it catches", () => {
  const wordExamples: Record<string, string> = {
    delete: "Delete row",
    remove: "Remove item",
    erase: "Erase disk",
    destroy: "Destroy session",
    wipe: "Wipe data",
    purge: "Purge cache",
    discard: "Discard draft",
    "log out": "Log out",
    logout: "Logout",
    "log off": "Log off",
    logoff: "Logoff",
    "sign out": "Sign out",
    signout: "Signout",
  };
  assert.deepEqual([...DEFAULTS.dangerWords].sort(), Object.keys(wordExamples).sort());
  for (const [word, example] of Object.entries(wordExamples)) assert.equal(dangerousName([word], example), true, word);

  assert.deepEqual(DEFAULTS.dangerSelectors, ["[data-destructive]"]);
  assert.deepEqual(DEFAULTS.dangerMethods, ["DELETE"]);
  assert.deepEqual(DEFAULTS.dangerUrls.map(String), [
    "/(^|[^a-zA-Z])(delete|remove|destroy|purge|log[-_]?[Oo](ut|ff)|sign[-_]?[Oo]ut)(?![a-z])/",
    "/(Delete|Remove|Destroy|Purge|Log[-_]?[Oo](ut|ff)|Sign[-_]?[Oo]ut)(?![a-z])/",
  ]);
  const addresses = [
    "/items/3/delete",
    "/cart/remove",
    "/sessions/destroy",
    "/cache/purge",
    "/logout",
    "/log_out",
    "/logoff",
    "/Account/LogOff",
    "/signout",
    "/sign-out",
    "/api/DeleteUser",
    "/api/RemoveItem",
    "/api/DestroySession",
    "/api/PurgeCache",
    "/api/LogOut",
    "/api/SignOut",
  ];
  for (const address of addresses) assert.equal(dangerousRequest({ methods: [], urls: [...DEFAULTS.dangerUrls] }, "GET", address), true, address);
  assert.deepEqual(DEFAULTS.signedOutUrls.map(String), ["/^[^?]*\\/(log[-_]?in|sign[-_]?in)(\\.[a-z0-9]+)?\\/?([?#]|$)/i"]);
});

test("a field that takes typed text is told from a control that a click activates", () => {
  for (const type of ["checkbox", "radio", "button", "submit", "reset", "image", "SUBMIT"]) assert.equal(typedInto("INPUT", type), false, type);
  for (const type of ["text", "search", "email", "password", "number", ""]) assert.equal(typedInto("INPUT", type), true, type);
  assert.equal(typedInto("TEXTAREA", ""), true);
  assert.equal(typedInto("BUTTON", "submit"), false);
  for (const type of ["submit", "button", "reset", "Button"]) assert.equal(namedByValue(type), true, type);
  for (const type of ["text", "checkbox", "image", ""]) assert.equal(namedByValue(type), false, type);
});

test("a click is judged by where it lands, and a click with no fixed point always counts as a hit", () => {
  const box = [{ left: 10, top: 10, right: 20, bottom: 20 }];
  assert.equal(hits({ x: 15, y: 15 }, box), true);
  assert.equal(hits({ x: 10, y: 20 }, box), true, "an edge");
  assert.equal(hits({ x: 21, y: 15 }, box), false);
  assert.equal(hits({ x: 15, y: 9 }, box), false);
  assert.equal(hits({ x: [0, 5], y: 15 }, box), true, "a point given as a range");
  assert.equal(hits({ x: 15, y: [0, 5] }, []), true, "a range with no box near it");
});

test("a target names a new tab unless it is this page, its parent, or the top", () => {
  for (const target of ["", "_self", "_SELF", "_parent", "_top"]) assert.equal(namesNewTab(target), false, target);
  for (const target of ["_blank", "help", "_new", "self"]) assert.equal(namesNewTab(target), true, target);
});
