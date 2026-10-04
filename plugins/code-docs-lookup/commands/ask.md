---
description: Search the Claude Code docs and answer a question from them
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/sync-docs.sh *) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/search-docs.sh *) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/show-doc.sh *)
argument-hint: <question or search terms>
---

Answer this question using the Claude Code documentation, following the `claude-code-docs` skill:

$ARGUMENTS

Use only these scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/`, and always pass `-c ${CLAUDE_PLUGIN_DATA}/docs` to them: run `sync-docs.sh` if the cache is missing, search with `search-docs.sh`, and read the most relevant pages with `show-doc.sh` (`-H` lists headings). Cite the source URLs. If there is no argument, ask the user what they want to look up.
