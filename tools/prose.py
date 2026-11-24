import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from allow import allows

ROOT = Path(__file__).resolve().parent.parent
MAX_WORDS = 25
PROPER = {"Bombadil", "Claude", "Code", "Cursor", "Lean"}
WORDS = (
    "additionally|crucial|delve|enhance|foster|landscape|pivotal|showcase|testament|underscore|vibrant|"
    "serves as|stands as|boasts|in order to|it is important to note|i hope this helps|let me know if|"
    "substrate|wedge|vector|nexus|primitive|harness|surface|scaffolding|paradigm|ratchet|north star|flywheel|"
    "utilize|leverage|simply|easy|easily|quickly|please"
)
RULES = [
    ("banned word", re.compile(rf"\b({WORDS})\b", re.I), "use the plain, concrete word (unslop 7, 8, 23, 26, 31)"),
    ("abbreviation", re.compile(r"\b(etc|e\.g|i\.e)\b\.?", re.I), "spell it out (unslop 33)"),
    ("arrow", re.compile(f"->|=>|[{chr(0x2190)}-{chr(0x21FF)}]"), "say it in words (unslop 33)"),
    ("dash", re.compile(f"[{chr(0x2014)}{chr(0x2013)}]|\\S - \\S"), "use a period or a comma (unslop 13)"),
    ("semicolon", re.compile(";"), "split the sentence (technical-writing)"),
    ("curly quote", re.compile(f"[{chr(0x201C)}{chr(0x201D)}{chr(0x2018)}{chr(0x2019)}]"), "use straight quotes (unslop 19)"),
    ("emoji", re.compile(f"[{chr(0x2600)}-{chr(0x27BF)}{chr(0x1F300)}-{chr(0x1FAFF)}]"), "remove it (unslop 18)"),
    ("colon mid-line", re.compile(r":\s+\S"), "end the line at the colon and put the list below, or write two sentences (unslop 14)"),
    ("not just X but Y", re.compile(r"\bnot (just|only|merely)\b[^.]*\bbut\b", re.I), "state the point (unslop 9)"),
    ("joined words", re.compile(r"\b[A-Za-z]+/[A-Za-z]+\b|\(s\)"), "write 'and' or 'or', or put a path in code font (technical-writing)"),
]


def plain(line):
    line = re.sub(r"`[^`]*`", "CODE", line)
    line = re.sub(r"\]\([^)]*\)", "]", line)
    return re.sub(r"https?://\S+", "URL", line)


def descriptions(value):
    if isinstance(value, dict):
        for key, inner in value.items():
            if key == "description" and isinstance(inner, str):
                yield inner
            else:
                yield from descriptions(inner)
    elif isinstance(value, list):
        for inner in value:
            yield from descriptions(inner)


def prose_lines(path):
    text = path.read_text(encoding="utf-8")
    if path.suffix == ".json":
        yield from ((1, plain(description)) for description in descriptions(json.loads(text)))
        return
    fenced = False
    front = text.startswith("---\n")
    for number, line in enumerate(text.splitlines(), 1):
        if front:
            if number > 1 and line == "---":
                front = False
            elif line.startswith("description:"):
                yield number, plain(line[len("description:"):].strip().strip('"'))
            continue
        if line.lstrip().startswith("```"):
            fenced = not fenced
        elif not fenced:
            yield number, plain(line)


def sentences(line):
    if re.fullmatch(r"\s*\|[\s|:-]*\|\s*", line):
        return []
    cells = line.strip().strip("|").split("|") if line.lstrip().startswith("|") else [line]
    found = []
    for cell in cells:
        text = re.sub(r"^\s*(#+|[-*]|\d+\.)\s+", "", cell).replace("**", "")
        found.extend(s for s in re.split(r"(?<=[.!?:])\s+", text) if s.strip())
    return found


def heading_findings(number, line, levels):
    level = len(line) - len(line.lstrip("#"))
    if levels and level > levels[-1] + 1:
        yield number, f"heading skips from level {levels[-1]} to level {level}: use level {levels[-1] + 1} (technical-writing)"
    levels.append(level)
    words = re.sub(r"^#+\s+(\d+\.\s+)?", "", line).split()
    for word in words[1:]:
        bare = word.strip(".,:()'\"")
        if bare[:1].isupper() and not bare.isupper() and bare not in PROPER and bare != "CODE":
            yield number, f"heading word '{bare}' is capitalized: use sentence case (unslop 17)"


def findings(path):
    levels = []
    for number, line in prose_lines(ROOT / path):
        if allows(path, line):
            continue
        for name, pattern, fix in RULES:
            hit = pattern.search(line)
            if hit:
                yield number, f"{name} '{hit.group(0).strip()}': {fix}"
        if line.startswith("#"):
            yield from heading_findings(number, line, levels)
        for sentence in sentences(line):
            words = len(sentence.split())
            if words > MAX_WORDS:
                yield number, f"sentence of {words} words: split it at {MAX_WORDS} (technical-writing): {sentence[:50]}..."
    if levels.count(1) != 1 and not path.endswith(".json"):
        yield 1, f"top-level headings number {levels.count(1)}: use exactly one (technical-writing)"


def main(paths):
    found = [f"{p}:{number}: {message}" for p in paths for number, message in findings(p)]
    print("\n".join(found), end="\n" if found else "")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
