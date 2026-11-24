import type { Feature, KnownIssue } from "./defaults.ts";

export type RequestRules = { methods: string[]; urls: RegExp[] };
export type Box = { left: number; top: number; right: number; bottom: number };

export function normalize(text: string): string {
  return text.replace(/[\u00AD\u200B-\u200D\u2060\uFEFF]/g, "").replace(/([a-z])([A-Z])/g, "$1 $2").normalize("NFKC").toLowerCase().replace(/\s+/g, " ").trim();
}

function cased(ch: string | undefined): boolean {
  return ch !== undefined && ch.toLowerCase() !== ch.toUpperCase();
}

function hasWord(text: string, word: string): boolean {
  if (!word) return false;
  for (let i = text.indexOf(word); i !== -1; i = text.indexOf(word, i + 1)) {
    const gluedBefore = cased(text[i - 1]) && cased(word[0]);
    const gluedAfter = cased(text[i + word.length]) && cased(word[word.length - 1]);
    if (!gluedBefore && !gluedAfter) return true;
  }
  return false;
}

function matches(pattern: RegExp, text: string): boolean {
  pattern.lastIndex = 0;
  return pattern.test(text);
}

function spoken(text: string): string {
  return normalize(text).replace(/[-_\u2010-\u2015\s]+/g, " ").trim();
}

export function dangerousName(words: string[], name: string): boolean {
  const text = spoken(name);
  return words.some((word) => hasWord(text, spoken(word)));
}

export function typedInto(tag: string, type: string): boolean {
  return tag === "TEXTAREA" || (tag === "INPUT" && !/^(checkbox|radio|button|submit|reset|image)$/i.test(type));
}

export function namedByValue(type: string): boolean {
  return /^(submit|button|reset)$/i.test(type);
}

export function hits(point: { x: unknown; y: unknown }, boxes: Box[]): boolean {
  const { x, y } = point;
  if (typeof x !== "number" || typeof y !== "number") return true;
  return boxes.some((box) => x >= box.left && x <= box.right && y >= box.top && y <= box.bottom);
}

export function namesNewTab(target: string): boolean {
  return !/^(_self|_parent|_top)?$/i.test(target);
}

export function dangerousRequest(rules: RequestRules, method: string, url: string): boolean {
  return rules.methods.some((listed) => listed.toUpperCase() === method.toUpperCase()) || rules.urls.some((pattern) => matches(pattern, url));
}

export function formMethod(method: string, field: string | null): string {
  return method.toUpperCase() === "POST" && field ? field : method;
}

export function serverFailed(status: number): boolean {
  return status >= 500;
}

function dayOf(date: Date): string {
  const two = (part: number) => String(part).padStart(2, "0");
  return `${date.getFullYear()}-${two(date.getMonth() + 1)}-${two(date.getDate())}`;
}

export function known(issues: KnownIssue[], now: Date, check: KnownIssue["check"], text: string): boolean {
  const today = dayOf(now);
  return issues.some(
    (issue) =>
      issue.check === check &&
      issue.reason.trim() !== "" &&
      /^\d{4}-\d{2}-\d{2}$/.test(issue.until) &&
      issue.until >= today &&
      matches(issue.match, text),
  );
}

export function featuresAt(features: Feature[], href: string): string[] {
  return features.filter((feature) => matches(feature.url, href)).map((feature) => feature.name);
}

export function signedOutAt(urls: RegExp[], href: string): boolean {
  return urls.some((pattern) => matches(pattern, href));
}
