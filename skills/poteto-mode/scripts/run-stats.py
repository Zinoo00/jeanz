#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MODE = "skills/poteto-mode/SKILL.md"
DOC = re.compile(r"skills/[a-z0-9-]+/(?:SKILL\.md|worker\.md|(?:playbooks|references)/[a-z0-9-]+\.md)")
WRITERS = {"Edit", "Write", "NotebookEdit"}
PART = ('"offset"', '"limit"', "Principles")


def size(doc, whole):
    text = (ROOT / doc).read_text(encoding="utf-8")
    if not whole:
        text = text[text.index("\n## Principles"):text.index("\n## Autonomy")]
    return len(text.split())


def opened(transcript):
    turns, docs = 0, {}
    for line in transcript.read_text(encoding="utf-8", errors="ignore").splitlines():
        try:
            message = json.loads(line).get("message") or {}
        except (ValueError, AttributeError):
            continue
        blocks = message.get("content")
        if message.get("role") != "assistant" or not isinstance(blocks, list):
            continue
        turns += 1
        for block in blocks:
            if not isinstance(block, dict) or block.get("type") != "tool_use" or block.get("name") in WRITERS:
                continue
            call = json.dumps(block.get("input"))
            part = any(mark in call for mark in PART)
            for doc in set(DOC.findall(call)):
                if (ROOT / doc).is_file():
                    docs[doc] = docs.get(doc, False) or not (part and doc == MODE)
    return turns, docs


def main():
    if len(sys.argv) != 2:
        print("usage: run-stats.py <session.jsonl>", file=sys.stderr)
        print("  session.jsonl   the transcript of the chat that owns the run, with its subagents folder beside it", file=sys.stderr)
        return 2
    chat = Path(sys.argv[1])
    if not chat.is_file():
        print(f"run-stats.py: no transcript at {chat}", file=sys.stderr)
        return 1
    turns, docs = opened(chat)
    agents = [opened(path)[1] for path in sorted(chat.with_suffix("").glob("subagents/*.jsonl"))]
    print(f"turns\t{turns}")
    print(f"agents\t{len(agents)}")
    print(f"mode_rereads\t{sum(1 for found in agents if found.get(MODE))}")
    print(f"documents\t{len(docs)}")
    print(f"words\t{sum(size(doc, whole) for found in [docs, *agents] for doc, whole in found.items())}")
    return 0


sys.exit(main())
