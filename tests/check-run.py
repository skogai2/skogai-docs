#!/usr/bin/env python3
"""Check one `claude -p` run against the docs requirements.

Usage: check-run.py <run-dir>

Reads stream.jsonl (the run's event log) and answer.txt. It never trusts the
answer's prose on its own. It checks the tool calls that actually happened.
Exits 1 if any requirement fails.
"""
import json
import pathlib
import re
import sys

URL = re.compile(r"https://code\.claude\.com/docs/en/[A-Za-z0-9/_.-]+")
SCRIPTS = ("search-docs.sh", "show-doc.sh", "sync-docs.sh")


def events(run):
    out = []
    for line in (run / "stream.jsonl").read_text().splitlines():
        try:
            out.append(json.loads(line))
        except ValueError:
            pass
    return out


def result_text(block):
    content = block.get("content", "")
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content if isinstance(b, dict))
    return str(content)


def main(run):
    run = pathlib.Path(run)
    evs = events(run)
    calls = []      # (name, input) in order
    results = {}    # tool_use_id -> text
    for e in evs:
        msg = e.get("message", {})
        if e.get("type") == "assistant":
            for c in msg.get("content", []):
                if c.get("type") == "tool_use":
                    calls.append((c["id"], c["name"], c.get("input", {})))
        if e.get("type") == "user" and isinstance(msg.get("content"), list):
            for c in msg["content"]:
                if c.get("type") == "tool_result":
                    results[c.get("tool_use_id")] = result_text(c)
    answer = (run / "answer.txt").read_text() if (run / "answer.txt").exists() else ""

    (run / "tool-calls.txt").write_text("".join(
        f"{name} {json.dumps(inp, ensure_ascii=False)}\n" for _, name, inp in calls))

    docs_calls = [(i, n, inp) for i, n, inp in calls
                  if n == "Bash" and any(s in inp.get("command", "") for s in SCRIPTS)]
    read_calls = [(i, n, inp) for i, n, inp in calls
                  if n == "Bash" and any(s in inp.get("command", "") for s in ("search-docs.sh", "show-doc.sh"))]
    web_calls = [n for _, n, _ in calls if n in ("WebFetch", "WebSearch")]

    # Only text printed by our scripts counts as "read".
    read_text = "\n".join(results.get(i, "") for i, _, _ in read_calls)
    read_urls = {u.rstrip(".,;:") for u in URL.findall(read_text)}
    cited = {u.rstrip(".,;:") for u in URL.findall(answer)}

    # Isolation: nothing from the real config dir may show up in this run's transcripts.
    real_config = str(pathlib.Path.home() / ".claude") + "/"
    leaks = []
    for f in sorted((run / "config" / "projects").rglob("*.jsonl")):
        for n, line in enumerate(f.read_text().splitlines(), 1):
            if real_config in line:
                leaks.append(f"{f.name}:{n}")

    checks = [
        ("no path from the real config dir in the transcripts", not leaks),
        ("run produced a result event", any(e.get("type") == "result" for e in evs)),
        ("answer is not empty", bool(answer.strip())),
        ("docs scripts were called", bool(docs_calls)),
        ("search or show-doc was called", bool(read_calls)),
        ("no WebFetch or WebSearch", not web_calls),
        ("answer cites at least one docs page", bool(cited)),
        ("every cited page was printed by a script", bool(cited) and cited <= read_urls),
    ]
    failed = False
    for desc, ok in checks:
        print(f"  {'ok  ' if ok else 'FAIL'}  {desc}")
        failed |= not ok
    if leaks:
        print("        real-config references at:", ", ".join(leaks[:5]))
    if cited - read_urls:
        print("        cited but never read:", ", ".join(sorted(cited - read_urls)))
    if web_calls:
        print("        used:", ", ".join(web_calls))
    return 1 if failed else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
