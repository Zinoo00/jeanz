#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v agy > /dev/null || { echo "agy is not on PATH: install the Antigravity CLI first" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/jeanz" "$work/jeanz/rules"
git -C "$ROOT" archive HEAD | tar -x -C "$work/jeanz"
perl -0pi -e 's/\A(---\n.*?\n---\n)/$1 =~ s{^(?:model|effort):.*\n}{}mgr/se' "$work"/jeanz/agents/*.md
cp "$work/jeanz/tools/antigravity/rules.md" "$work/jeanz/rules/AGENTS.md"
agy plugin install "$work/jeanz"
agy plugin validate "$HOME/.gemini/config/plugins/jeanz"
