import re
import sys
from pathlib import Path

LINK = re.compile(r"\]\(\s*<?([^)\s>]+)")
DEFINITION = re.compile(r"^ {0,3}\[[^\]^][^\]]*\]:\s*<?([^\s>]+)", re.M)
ATTRIBUTE = re.compile(r"""\b(?:href|src)\s*=\s*["']([^"']+)""")
HEADED = (".md", ".template")
POINTER = re.compile(r"\b(docs/[\w-]+\.md#[\w-]+)")


def anchors(path):
    found = set()
    for heading in re.findall(r"^#+\s+(.*)$", path.read_text(encoding="utf-8"), re.M):
        text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", heading).replace("`", "")
        found.add(re.sub(r"[^\w\- ]", "", text.strip().lower()).replace(" ", "-"))
    return found


def broken(source, link):
    if re.match(r"(https?|mailto):", link):
        return False
    if link.startswith(("/", "~")):
        return True
    file, _, anchor = link.partition("#")
    base = Path(".") if source.suffix == ".txt" else source.parent
    target = base / file if file else source
    if not target.exists():
        return True
    return bool(anchor) and target.suffix in HEADED and anchor not in anchors(target)


for name in sys.stdin.read().split():
    source = Path(name)
    text = source.read_text(encoding="utf-8")
    links = POINTER.findall(text) if source.suffix == ".txt" else LINK.findall(text) + DEFINITION.findall(text) + ATTRIBUTE.findall(text)
    for link in links:
        if broken(source, link):
            print(f"{name.removeprefix('./')}: {link}")
