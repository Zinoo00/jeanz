import itertools
import json
import sys


def snapshot(row, name):
    return next((s["value"] for s in row["snapshots"] if s["name"] == name and s["value"] is not None), None)


def main(command, run, *rest):
    with open(f"{run}/trace.jsonl", encoding="utf-8") as trace:
        rows = [json.loads(line) for line in trace if line.strip()]
    if command == "steps":
        print(sum(1 for row in rows if row["action"]))
    elif command == "first":
        print(next((i for i, row in enumerate(rows) if any(v["name"] == rest[0] for v in row.get("violations") or [])), -1))
    elif command == "violated-at-start":
        leading = list(itertools.takewhile(lambda row: row["state"]["url"] == rows[0]["state"]["url"], rows))
        print("\n".join(sorted({v["name"] for row in leading for v in row.get("violations") or []})))
    elif command == "clicked":
        targets = [body.get("fingerprint") or {} for row in rows if isinstance(row["action"], dict) for body in row["action"].values() if isinstance(body, dict)]
        print(sum(1 for fingerprint in targets if fingerprint.get("id") == rest[0]))
    elif command == "acted":
        kinds = [row["action"] if isinstance(row["action"], str) else next(iter(row["action"])) for row in rows if row["action"]]
        print(kinds.count(rest[0]))
    elif command == "kept-after-click":
        label, ending = rest

        def clicked(row):
            bodies = row["action"].values() if isinstance(row["action"], dict) else []
            prints = [body.get("fingerprint") or {} for body in bodies if isinstance(body, dict)]
            return any(label in (fp.get("textContent"), fp.get("text_content")) for fp in prints)

        after = [row for row in rows if clicked(row)]
        kept = [row for row in after if any(e.endswith(ending) for e in (snapshot(row, "jeanzNetwork") or {}).get("blocked", []))]
        print(f"{len(kept)} of {len(after)}")
    elif command == "danger-names":
        print("\n".join(sorted({r["name"] for r in (snapshot(rows[0], "jeanzDanger") or {}).get("rects", [])})))
    elif command == "blocked":
        print("\n".join(sorted({e.split(" http")[0] for row in rows for e in (snapshot(row, "jeanzNetwork") or {}).get("blocked", [])})))
    elif command == "blocked-requests":
        print("\n".join(sorted({e for row in rows for e in (snapshot(row, "jeanzNetwork") or {}).get("blocked", [])})))
    elif command == "top":
        rects = (snapshot(rows[0], "jeanzDanger") or {}).get("rects", [])
        print(next((int(r["top"]) for r in rects if rest[0] in r["name"]), -1))
    else:
        sys.exit(f"unknown command {command}")


if __name__ == "__main__":
    main(*sys.argv[1:])
