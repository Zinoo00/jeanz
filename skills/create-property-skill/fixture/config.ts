import { DEFAULTS, type Feature, type KnownIssue } from "./defaults.ts";

export const DANGER_WORDS = [...DEFAULTS.dangerWords, "삭제"];

export const DANGER_SELECTORS = [...DEFAULTS.dangerSelectors];

export const DANGER_REQUESTS = {
  methods: [...DEFAULTS.dangerMethods],
  urls: [...DEFAULTS.dangerUrls, /\/__destructive\//],
};

export const SIGNED_OUT = {
  urls: [...DEFAULTS.signedOutUrls],
  selectors: ["form[action='/login']"],
};

export const KNOWN_ISSUES: KnownIssue[] = [
  { check: "console", match: /known noisy widget/, reason: "planted for the self-test", until: "2999-12-31" },
  { check: "request", match: /\/api\/legacy/, reason: "planted for the self-test", until: "2999-12-31" },
  { check: "exception", match: /known legacy widget/, reason: "planted for the self-test", until: "2999-12-31" },
  { check: "rejection", match: /known legacy promise/, reason: "planted for the self-test", until: "2999-12-31" },
  { check: "page", match: /\/known\.html/, reason: "planted for the self-test", until: "2999-12-31" },
];

export const FEATURES: Feature[] = [
  { name: "items", url: /\/app\.html/, start: "/app.html" },
  { name: "archive", url: /\/archive\.html/, start: "/archive.html" },
  { name: "billing", url: /\/billing\b/ },
];
