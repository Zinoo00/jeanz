import json
import re
import sys
from pathlib import Path

KEYS = ("name", "description", "model", "effort", "disable-model-invocation", "icon", "color", "paths")
SWITCHES = ("disable-model-invocation",)
NOT_TEXT = re.compile(
    r"(true|false|yes|no|on|off|y|n|null|~|[-+]?(\.\d+|\d[\d_]*(\.[\d_]*)?)(e[-+]?\d+)?|0x[0-9a-f_]+|0o[0-7_]+|[-+]?\.(inf|nan)|\d{4}-\d{1,2}-\d{1,2}([t ].*)?)",
    re.I,
)


def parsed(value):
    try:
        found = json.loads(value)
    except ValueError:
        return None
    if isinstance(found, str) or (isinstance(found, list) and all(isinstance(item, str) for item in found)):
        return found
    return None


def value_finding(key, value):
    if "\t" in value:
        return f"a tab in the value of `{key}`: use spaces"
    value = value.strip()
    if value == "":
        return f"an empty value for `{key}`: write the value on the same line"
    if key in SWITCHES:
        return None if value in ("true", "false") else f"a value that is not true or false, for `{key}`: write true or false"
    if value[0] in '"[':
        if parsed(value) is None:
            return f"a quoted or bracketed value that does not parse, for `{key}`: write a JSON string or a JSON list of strings"
        return None
    if NOT_TEXT.fullmatch(value):
        return f"a plain value that YAML reads as a number, a date, or a truth value, for `{key}`: wrap it in double quotes"
    if not re.match(r"[A-Za-z0-9/]", value) or ": " in value or " #" in value or value.endswith(":"):
        return f"a plain value that YAML reads another way, for `{key}`: wrap it in double quotes"
    return None


def findings(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    expected = path.parent.name if path.name == "SKILL.md" else path.stem
    if not lines or lines[0] != "---":
        yield "the file does not start with a `---` line: put the frontmatter first"
        return
    if "---" not in lines[1:]:
        yield "the frontmatter has no closing `---` line: add it"
        return
    fields = {}
    for line in lines[1 : lines.index("---", 1)]:
        match = re.fullmatch(r"([a-z][a-z-]*):(?: (.*))?", line)
        if not match:
            yield f"a frontmatter line that is not `key: value`, which reads '{line.strip()[:40]}': write one key and its value on each line"
            continue
        key, value = match.group(1), match.group(2) or ""
        if key not in KEYS:
            yield f"an unknown frontmatter key `{key}`: the known keys are {', '.join(KEYS)}. Add a key that Claude Code reads to KEYS in tools/frontmatter.py"
        if key in fields:
            yield f"a frontmatter key that appears twice, `{key}`: keep one"
        fields[key] = value.strip()
        finding = value_finding(key, value)
        if finding:
            yield finding
    name = fields.get("name", "")
    name = parsed(name) if name.startswith('"') and isinstance(parsed(name), str) else name
    if name != expected:
        yield f"the name does not match the folder or the file: `{name}` is not `{expected}`"
    if "description" not in fields:
        yield "no description: say what it does and when to use it"


def main(paths):
    found = [f"{path}: {finding}" for path in paths for finding in findings(Path(path))]
    print("\n".join(found), end="\n" if found else "")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
