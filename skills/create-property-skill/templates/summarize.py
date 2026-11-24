import base64
import html
import json
import os
import sys
from collections import Counter
from pathlib import Path

USAGE = "usage: summarize.py RUN_DIR [--first-property | --violates PROPERTY | --checks PROPERTY | --properties | --clash | --verdict | --stepped | --html FILE]"
SEALED_CELLS = "jeanz"


def describe(action):
    if action is None:
        return "start"
    if isinstance(action, str):
        return action
    kind, body = next(iter(action.items()))
    if not isinstance(body, dict):
        return kind
    if kind == "Custom":
        return f"{body.get('name')} {json.dumps(body.get('arguments'), ensure_ascii=False)[:60]}"
    fp = body.get("fingerprint") or {}
    label = fp.get("text_content") or fp.get("accessible_name") or fp.get("id") or fp.get("tag")
    if label:
        return f"{kind} {label!r}"
    if "text" in body:
        return f"{kind} {json.dumps(body['text'], ensure_ascii=False)[:40]}"
    if "code" in body:
        return f"{kind} key {body['code']}"
    return kind


def kind_of(action):
    return action if isinstance(action, str) else next(iter(action))


def snapshot(row, name):
    return next((x["value"] for x in row["snapshots"] if x["name"] == name and x["value"] is not None), None)


def clip(value):
    if isinstance(value, str):
        return value if len(value) <= 300 else value[:300] + "..."
    if isinstance(value, list):
        return [clip(v) for v in value[-5:]]
    if isinstance(value, dict):
        return {k: clip(v) for k, v in value.items()}
    return value


def evidence(violation):
    found, conditions = {}, []

    def walk(node):
        if isinstance(node, list):
            for v in node:
                walk(v)
        elif isinstance(node, dict):
            for key, value in node.items():
                if key in ("condition", "function") and isinstance(value, str):
                    if value not in conditions:
                        conditions.append(value)
                elif key.endswith("snapshots") and isinstance(value, list):
                    found.update({s["name"]: clip(s.get("value")) for s in value if isinstance(s, dict) and s.get("name")})
                else:
                    walk(value)

    walk(violation)
    return "; ".join(conditions) or None, found


def screenshot(run_dir, recorded):
    if not recorded:
        return None
    for candidate in (Path(recorded), Path(run_dir) / "screenshots" / Path(recorded).name):
        if candidate.exists():
            return str(candidate)
    return None


def most(names):
    return sorted(names)[:60]


def clash(rows):
    names = Counter(x["name"] for row in rows[:1] for x in row["snapshots"] if (x["name"] or "").startswith(SEALED_CELLS))
    return sorted(name for name, count in names.items() if count > 1)


def summarize(run_dir):
    with (Path(run_dir) / "trace.jsonl").open(encoding="utf-8") as trace:
        rows = [json.loads(line) for line in trace if line.strip()]
    counts, first = Counter(), {}
    reached, listed, controls, blocked, stopped, failed, failures = set(), [], set(), 0, set(), 0, set()
    properties = []
    for i, row in enumerate(rows):
        properties = snapshot(row, "jeanzProperties") or properties
        for v in row.get("violations") or []:
            counts[v["name"]] += 1
            first.setdefault(v["name"], i)
        features = snapshot(row, "jeanzFeatures")
        if features:
            reached.update(features.get("here") or [])
            listed = features.get("all") or listed
        danger = snapshot(row, "jeanzDanger")
        if danger:
            controls.update(r.get("name") or "" for r in danger.get("rects") or [])
        network = snapshot(row, "jeanzNetwork")
        if network:
            blocked = max(blocked, network.get("blockedCount") or 0)
            stopped.update(network.get("blocked") or [])
            failed = max(failed, network.get("failedCount") or 0)
            failures.update(network.get("failed") or [])
    out = {
        "run": str(Path(run_dir)),
        "properties": properties,
        "coverage": {
            "states": len(rows),
            "urls": dict(Counter(row["state"].get("url") for row in rows).most_common(8)),
            "actions": dict(Counter(kind_of(row["action"]) for row in rows if row["action"] is not None)),
            "features_listed": len(listed),
            "features_reached": sorted(reached),
            "features_not_reached": [name for name in listed if name not in reached],
            "dangerous_controls_skipped": most(c for c in controls if c),
            "requests_blocked": blocked,
            "requests_blocked_distinct": most(stopped),
            "requests_failed": failed,
            "requests_failed_distinct": most(failures),
        },
        "violations": [],
    }
    for name in sorted(first, key=first.get):
        at = first[name]
        violation = next(v for v in rows[at]["violations"] if v["name"] == name)
        condition, found = evidence(violation.get("violation"))
        recorded = rows[at]["state"].get("screenshot")
        out["violations"].append(
            {
                "property": name,
                "count": counts[name],
                "first_state": at,
                "condition": condition,
                "evidence": found,
                "steps_before": [describe(rows[j]["action"]) for j in range(max(0, at - 8), at + 1)],
                "screenshot": screenshot(run_dir, recorded) or f"(missing) {recorded}",
            }
        )
    return out, rows


def stalled(run_dir, rows):
    first, last = rows[0]["timestamp"] / 1e6, rows[-1]["timestamp"] / 1e6
    waited = os.path.getmtime(f"{Path(run_dir)}.log") - last
    return waited if waited > last - first else 0


def gap(coverage, waited):
    if coverage["features_listed"] == 0:
        return "FEATURES is empty, so the run cannot say which features it checked"
    if waited:
        return f"no new state came in the last half of the run: the last of {coverage['states']} came {waited:.0f} s before its end"
    if coverage["features_not_reached"]:
        return "the run did not reach: " + ", ".join(coverage["features_not_reached"])
    return None


def image(path):
    if not path:
        return "<p>(screenshot missing)</p>"
    return f'<img alt="" src="data:image/jpeg;base64,{base64.b64encode(Path(path).read_bytes()).decode()}">'


def report(out, rows, path):
    e = html.escape
    page = [
        "<!doctype html>",
        '<html lang="en"><head><meta charset="utf-8">',
        f"<title>{e(Path(out['run']).name)}</title>",
        "<style>body{font:15px system-ui,sans-serif;margin:24px;max-width:1100px}"
        "th{text-align:left;vertical-align:top;padding-right:16px}td{word-break:break-word}"
        "pre{background:#f4f4f4;padding:12px;overflow:auto}img{max-width:100%;border:1px solid #999}"
        "li{margin-bottom:20px}small{font-weight:normal}</style>",
        "</head><body>",
        f"<h1>{e(out['run'])}</h1>",
        "<h2>Coverage</h2><table>",
    ]
    for key, value in out["coverage"].items():
        page.append(f"<tr><th>{e(key)}</th><td>{e(json.dumps(value, ensure_ascii=False))}</td></tr>")
    page.append("</table>")
    if not out["violations"]:
        page.append("<h2>No violation</h2><p>Read the coverage before trusting this.</p>")
    for v in out["violations"]:
        page.append(f"<h2>{e(v['property'])} <small>broken {v['count']} time(s), first at state {v['first_state']}</small></h2>")
        page.append(f"<p><code>{e(v['condition'] or '')}</code></p>")
        page.append(f"<pre>{e(json.dumps(v['evidence'], indent=2, ensure_ascii=False))}</pre>")
        page.append("<ol>")
        for j in range(max(0, v["first_state"] - 5), v["first_state"] + 1):
            page.append(f"<li><p>{e(describe(rows[j]['action']))}</p>{image(screenshot(out['run'], rows[j]['state'].get('screenshot')))}</li>")
        page.append("</ol>")
    page.append("</body></html>")
    Path(path).write_text("\n".join(page), encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(USAGE)
    mode = sys.argv[2:]
    summary, trace_rows = summarize(sys.argv[1])
    broken = [v["property"] for v in summary["violations"]]
    if not mode:
        print(json.dumps(summary, indent=2, ensure_ascii=False))
    elif mode == ["--first-property"]:
        print(broken[0] if broken else "")
    elif len(mode) == 2 and mode[0] == "--violates":
        sys.exit(0 if mode[1] in broken else 3)
    elif len(mode) == 2 and mode[0] == "--checks":
        sys.exit(0 if mode[1] in summary["properties"] else 3)
    elif mode == ["--properties"]:
        print("\n".join(summary["properties"]))
    elif mode == ["--clash"]:
        print(" and ".join(clash(trace_rows)))
    elif mode == ["--verdict"]:
        if broken:
            sys.exit(2)
        missed = gap(summary["coverage"], stalled(sys.argv[1], trace_rows))
        if missed:
            print(missed)
            sys.exit(3)
    elif mode == ["--stepped"]:
        sys.exit(3 if stalled(sys.argv[1], trace_rows) else 0)
    elif len(mode) == 2 and mode[0] == "--html":
        report(summary, trace_rows, mode[1])
    else:
        sys.exit(USAGE)
