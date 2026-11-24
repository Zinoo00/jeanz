export type KnownIssue = {
  check: "console" | "exception" | "rejection" | "request" | "page";
  match: RegExp;
  reason: string;
  until: string;
};

export type Feature = { name: string; url: RegExp; start?: string };

export const DEFAULTS = {
  dangerWords: ["delete", "remove", "erase", "destroy", "wipe", "purge", "discard", "log out", "logout", "log off", "logoff", "sign out", "signout"],
  dangerSelectors: ["[data-destructive]"],
  dangerMethods: ["DELETE"],
  dangerUrls: [
    /(^|[^a-zA-Z])(delete|remove|destroy|purge|log[-_]?[Oo](ut|ff)|sign[-_]?[Oo]ut)(?![a-z])/,
    /(Delete|Remove|Destroy|Purge|Log[-_]?[Oo](ut|ff)|Sign[-_]?[Oo]ut)(?![a-z])/,
  ],
  signedOutUrls: [/^[^?]*\/(log[-_]?in|sign[-_]?in)(\.[a-z0-9]+)?\/?([?#]|$)/i],
};
