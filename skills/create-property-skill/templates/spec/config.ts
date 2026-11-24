import { DEFAULTS, type Feature, type KnownIssue } from "./defaults.ts";

export const DANGER_WORDS: string[] = [...DEFAULTS.dangerWords];

export const DANGER_SELECTORS: string[] = [...DEFAULTS.dangerSelectors];

export const DANGER_REQUESTS: { methods: string[]; urls: RegExp[] } = {
  methods: [...DEFAULTS.dangerMethods],
  urls: [...DEFAULTS.dangerUrls],
};

export const SIGNED_OUT: { urls: RegExp[]; selectors: string[] } = {
  urls: [...DEFAULTS.signedOutUrls],
  selectors: [],
};

export const KNOWN_ISSUES: KnownIssue[] = [];

export const FEATURES: Feature[] = [];
