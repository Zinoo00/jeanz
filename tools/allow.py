import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIST = ROOT / "tools" / "check-allow.txt"


def entries():
    for line in LIST.read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            path, _, text = line.partition(": ")
            yield path, text, line


def allows(path, text):
    return any(p == path and t and t in text for p, t, _ in entries())


def stale():
    for path, text, line in entries():
        file = ROOT / path
        if not path or not text or not file.is_file() or text not in file.read_text(encoding="utf-8"):
            yield line


def main(mode):
    if mode == "stale":
        print("\n".join(stale()), end="")
        return
    for hit in sys.stdin:
        path, _, rest = hit.partition(":")
        if not allows(path.removeprefix("./"), rest):
            sys.stdout.write(hit)


if __name__ == "__main__":
    main(sys.argv[1])
