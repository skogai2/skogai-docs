# code-docs-lookup

A Claude Code plugin that lets Claude search, question and research the official
Claude Code documentation from a local copy, instead of relying on memory.

## What's inside

- `skills/claude-code-docs/` — skill that makes Claude search the docs before answering Claude Code questions.
- `commands/ask.md` — `/code-docs-lookup:ask <question>` for an explicit lookup.
- `scripts/sync-docs.sh` — downloads the docs bundle (`https://code.claude.com/docs/llms-full.txt`) once and splits it into one Markdown file per page, plus `index.txt`.
- `scripts/search-docs.sh` — searches the cache for pages containing all the given terms.
- `scripts/show-doc.sh` — prints one cached page, or its headings with `-H`.

When the plugin runs, the docs are cached in its persistent data directory,
`${CLAUDE_PLUGIN_DATA}/docs` (under `~/.claude/plugins/data/`). Skill and command calls pass that path with `-c`.
Outside the plugin, the scripts default to `$CLAUDE_DOCS_DIR`, then `~/.cache/claude-code-docs`.
The first search syncs automatically if the cache is empty.

## Try it

```sh
claude --plugin-dir /home/skogix/claude-docs
```

Then ask, for example: "how do hook exit codes work?" or `/code-docs-lookup:ask allowed tools in skill frontmatter`.

Manual use:

```sh
scripts/sync-docs.sh --force                 # refresh the default cache
scripts/search-docs.sh "hooks" "exit"        # pages containing both terms
scripts/search-docs.sh -r "mcp|model context" -n 15
scripts/show-doc.sh -H hooks                 # headings of the hooks page
scripts/show-doc.sh hooks                    # whole page
# any command takes -c <dir> to use another cache
```

## Requirements

`bash`, `curl`, `awk`, `grep`, `sed`. Internet access is needed for the first sync and for `--force`.

`scripts/claude-code-documentation.sh` is an older script that writes to `/tmp` and
builds an overview file. It is not used by the plugin.
