---
name: claude-code-docs
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/sync-docs.sh *) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/search-docs.sh *) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/show-doc.sh *)
description: Answer questions about Claude Code (the CLI, its settings, hooks, skills, plugins, MCP servers, slash commands, subagents, permissions, IDE and desktop integrations, the Agent SDK) by searching the official Claude Code documentation, not from memory. Use when the user asks how a Claude Code feature works, what a setting or flag does, asks to look something up in the docs, or wants research across the docs.
---

# Claude Code docs

Answer from the official docs. They change faster than memory, so search them
before answering questions about Claude Code behaviour, settings or syntax.

The docs are cached locally as one Markdown file per page, with an index.
Use only the three scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` to reach them. Always pass
`-c ${CLAUDE_PLUGIN_DATA}/docs` to them: that is the plugin's persistent data directory, and
the scripts can't see the variable themselves.
Don't read the cache files directly or with ad-hoc grep pipelines: those need
extra permission prompts, and the scripts already do the job.

## Workflow

1. **Make sure the cache exists.** Run `${CLAUDE_PLUGIN_ROOT}/scripts/sync-docs.sh -c ${CLAUDE_PLUGIN_DATA}/docs`. It is a no-op
   when the cache is already there. Use `--force` to refresh it.
2. **Search.** Run `${CLAUDE_PLUGIN_ROOT}/scripts/search-docs.sh -c ${CLAUDE_PLUGIN_DATA}/docs <term> [more terms]`.
   - Several terms must all appear in a page (AND). Use one or two specific terms,
     e.g. `"hooks" "exit code"`, rather than a whole sentence.
   - Use `-r` for regex, e.g. `-r "allowed.?tools|allowed-tools"`.
   - Use `-n <count>` to change how many pages are listed.
   - Try synonyms when nothing matches: "skill" / "SKILL.md", "subagent" / "agent", "MCP" / "mcp server".
3. **Read the pages that matter.** The search output gives a `slug:` for each page.
   For long pages, run `${CLAUDE_PLUGIN_ROOT}/scripts/show-doc.sh -c ${CLAUDE_PLUGIN_DATA}/docs -H <slug>` to see the headings,
   then `show-doc.sh -c ${CLAUDE_PLUGIN_DATA}/docs <slug>` for the whole page (or the sections you need). Read whole
   sections, not just the matched line, so you don't miss a caveat.
4. **Answer.** Give the answer directly, then cite the source URL(s) from the
   `source:` lines. Quote exact setting names, flags, JSON keys or commands from the docs.
   If the docs say something different from what you remember, say so and go with the docs.
5. **Say what the docs don't cover.** If the search finds nothing relevant, say so.
   Only then fall back to general knowledge, and label it as not from the docs.

## Research questions

For "compare X and Y", "what are all the ways to…" or "how do these pieces fit together":
search each concept separately, read the main page for each, and synthesise across
them. List the pages you used.

## Notes

- Don't paste whole pages into the answer. Summarise and link.
- Code examples in the docs are the authoritative syntax. Copy them rather than rewriting from memory.
- The docs cover the `en` locale only, from `https://code.claude.com/docs/en/`.
