# code-docs-tools

A Claude Code marketplace with one plugin, `code-docs-lookup`. It lets Claude search,
question and research the official Claude Code documentation from a local copy,
instead of relying on memory.

## Install

From a Claude Code session:

```text
/plugin marketplace add /home/skogix/claude-docs
/plugin install code-docs-lookup@code-docs-tools
```

Or from a shell:

```sh
claude plugin marketplace add /home/skogix/claude-docs
claude plugin install code-docs-lookup@code-docs-tools
```

Once the repo is pushed to a git host, the marketplace can be added with its URL instead of a local path.

To try the plugin without installing it:

```sh
claude --plugin-dir /home/skogix/claude-docs/plugins/code-docs-lookup
```

## Use

Ask a question directly, for example "how do hook exit codes work?", or run the command:

```text
/code-docs-lookup:ask allowed tools in skill frontmatter
```

## Layout

```
.claude-plugin/marketplace.json            marketplace catalog
plugins/code-docs-lookup/
  .claude-plugin/plugin.json               plugin manifest
  skills/claude-code-docs/SKILL.md         makes Claude search the docs before answering
  commands/ask.md                          /code-docs-lookup:ask <question>
  scripts/sync-docs.sh                     downloads and splits the docs bundle
  scripts/search-docs.sh                   finds pages containing all the given terms
  scripts/show-doc.sh                      prints one page, or its headings with -H
scripts/claude-code-documentation.sh       older standalone script, not used by the plugin
```

The docs come from `https://code.claude.com/docs/llms-full.txt`. The sync script downloads it once and
splits it into one Markdown file per page, plus `index.txt`.

When the plugin runs, the docs are cached in its persistent data directory,
`${CLAUDE_PLUGIN_DATA}/docs` (under `~/.claude/plugins/data/`). Skill and command calls pass that path with `-c`.
Outside the plugin, the scripts default to `$CLAUDE_DOCS_DIR`, then `~/.cache/claude-code-docs`.
The first search syncs automatically if the cache is empty.

Manual use:

```sh
S=plugins/code-docs-lookup/scripts
$S/sync-docs.sh --force                 # refresh the default cache
$S/search-docs.sh "hooks" "exit"        # pages containing both terms
$S/search-docs.sh -r "mcp|model context" -n 15
$S/show-doc.sh -H hooks                 # headings of the hooks page
$S/show-doc.sh hooks                    # whole page
# any command takes -c <dir> to use another cache
```

## Requirements

`bash`, `curl`, `awk`, `grep`, `sed`. Internet access is needed for the first sync and for `--force`.
