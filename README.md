# code-docs-tools

A Claude Code marketplace with one plugin, `code-docs-lookup`, which answers Claude Code
questions from a local copy of the official docs.

## Install

```sh
claude plugin marketplace add /home/skogix/claude-docs
claude plugin install code-docs-lookup@code-docs-tools
```

Use it with `/code-docs-lookup:ask <question>` or `/code-docs-lookup:claude-code-docs <question>`.
Status and open issues are in [HANDOVER.md](HANDOVER.md).

## Tests

```sh
tests/offline.sh        # no model calls: docs cache, scripts, reference, plugin, install
tests/environment.sh    # one run in a fresh config dir; checks the run's own events
tests/agent.sh          # one real `claude -p` run; calls the API (costs money)
```
