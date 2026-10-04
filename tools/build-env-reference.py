#!/usr/bin/env python3
"""Build the env var reference from the cached env-vars docs page.

Usage: build-env-reference.py <env-vars.md>  > references/env-vars.md

Reads the "## Variables" table, groups the rows by name prefix and keeps each
purpose text as written. Relative docs links are made absolute, so the
reference still works when it is read outside the docs cache.
"""
import collections
import re
import sys

DOCS = "https://code.claude.com/docs/en/"
ROW = re.compile(r"^\| `([A-Z0-9_]+)` \| (.*) \|$")
PREFIXES = ("CLAUDE_CODE_", "CLAUDE_", "ANTHROPIC_")


def rows_from(lines):
    start = lines.index("## Variables")
    end = lines.index("## Features that need feature-flag fetching")
    for line in lines[start:end]:
        m = ROW.match(line)
        if m:
            yield m.group(1), m.group(2)


def prefix_of(name):
    for p in PREFIXES:
        if name.startswith(p):
            return p
    return name.split("_")[0] + "_"


def absolute(text):
    return text.replace("](/docs/en/", "](" + DOCS).replace("](#", "](" + DOCS + "env-vars#")


def build(lines):
    groups = collections.OrderedDict()
    for name, purpose in rows_from(lines):
        groups.setdefault(prefix_of(name), []).append((name, absolute(purpose)))

    out = [
        "# Claude Code environment variables",
        "",
        "Reference for every environment variable in the Claude Code docs, grouped by name prefix.",
        "",
        f"Source: {DOCS}env-vars (Variables table). Re-check the source page if a variable is missing or behaves differently.",
        "",
        "## Conventions",
        "",
        "- Booleans: `1`, `true`, `yes`, `on` turn a behaviour on; `0`, `false`, `no`, `off` turn it off, in any casing.",
        "- Some variables turn behaviour on whenever they are set to any non-empty value, including `0`: `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, `DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`, `CLAUDE_CODE_TMUX_TRUECOLOR`, `FALLBACK_FOR_ALL_PRIMARY_MODELS`, `IS_DEMO`. Unset them, or set them empty, to turn the behaviour off.",
        "- `FORCE_HYPERLINK` reads a number, so only `0` turns it off.",
        "- Numeric variables accept scientific notation and digit separators, unless a row says it takes plain digits only.",
        "",
        "## Index",
        "",
    ]
    out += [f"- **{p}*** ({len(items)})" for p, items in groups.items()]
    out.append("")
    for prefix, items in groups.items():
        out += [f"## {prefix}*", "", "| Variable | Purpose |", "| :- | :- |"]
        out += [f"| `{name}` | {purpose} |" for name, purpose in items]
        out.append("")
    out += [
        "## See also",
        "",
        f"- Settings files and precedence: {DOCS}settings",
        f"- Feature flags skipped by some of these variables: {DOCS}env-vars#features-that-need-feature-flag-fetching",
    ]
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as f:
        sys.stdout.write(build(f.read().split("\n")))
