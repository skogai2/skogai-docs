# Handover: code-docs-lookup

## Goal
Claude answers Claude Code questions from the official docs, not from memory, and cites only pages it read.

## Steps that matter

1. **Docs cache.** `plugins/code-docs-lookup/scripts/sync-docs.sh` downloads the docs bundle and splits it into one file per page plus `index.txt`. The plugin passes `-c ${CLAUDE_PLUGIN_DATA}/docs`. *Verified:* `tests/offline.sh`.
2. **Lookup.** `search-docs.sh` finds pages with all the given terms. `show-doc.sh` prints a page, or its headings with `-H`, and ends with a `source:` URL. *Verified:* `tests/offline.sh`.
3. **Env reference.** `tools/build-env-reference.py` builds `references/env-vars.md` from the docs table (378 variables). The committed file must match the generator's output. *Verified:* `tests/offline.sh`.
4. **Plugin and marketplace.** `.claude-plugin/marketplace.json` lists `plugins/code-docs-lookup`. The manifest validates, and the plugin installs and shows as enabled in a fresh config dir. *Verified:* `tests/offline.sh`.
5. **Isolated runs.** `tests/run-case.sh` gives each run its own `CLAUDE_CONFIG_DIR` (also set in the run's `settings.json` `env`), an empty working dir under `/tmp`, only `Bash` and `Skill` as built-in tools, no MCP, bundled skills hidden with `skillOverrides`, and the plugin scripts pre-approved. *Verified:* `tests/environment.sh`, which reads the init event and the transcript.
6. **Judge a run from events, not prose.** `tests/check-run.py` checks the tool calls: docs scripts were called, no web tools, every cited page was printed by a script, and nothing from the real `~/.claude` appears. *Verified:* a named-skill run passes all checks.

## Open problems

- **The plain prompt does not use the skill.** With `claude -p "which env var disable telemetry in claude code"`, the model's own Skill call returns `is_error: true` ("Execute skill: code-docs-lookup:claude-code-docs"), and the skill body never reaches the model. The model then tries web access, which is denied, and answers from memory. The named form `/code-docs-lookup:claude-code-docs …` passes every check. **Cause not found.** The docs don't describe this error.
- **`--system-prompt` is not verified.** The run passes it, but no event records the system prompt.
- **`/code-docs-lookup:ask` needs the same check.** It has not been run through `tests/agent.sh`.

## Gotchas found while building this

- `CLAUDE.md` and other `.claude` folders above the working dir load even with `CLAUDE_CONFIG_DIR` set. Keep runs out of `$HOME`.
- `--bare` skips installed plugins, so it cannot be used here.
- `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` are substituted in skill and command text and in Bash rules in `allowed-tools`. They are not exported to the Bash tool, and a `Read(...)` rule with them is not substituted.
- A pipe into `head` can make a script exit 141 (SIGPIPE) under `pipefail`. Capture output before taking the first line.
- Plugin install in a directory marketplace loads the plugin in place from the repo.

## Run it

```sh
tests/offline.sh && tests/environment.sh     # cheap; should pass
tests/agent.sh                               # costs money; currently fails on the plain prompt
```

Run outputs go to `/tmp/code-docs-lookup-runs/`. Each one holds a copy of the login in its config dir, so delete old runs.
