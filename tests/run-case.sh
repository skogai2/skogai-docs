#!/usr/bin/env bash
set -euo pipefail

# Usage: tests/run-case.sh <name> <prompt>
#
# One run = a fresh, isolated Claude Code environment:
#   - CLAUDE_CONFIG_DIR is a new empty dir under $RUNS. Its settings.json sets
#     env.CLAUDE_CONFIG_DIR too, so every tool call in the session sees it.
#   - The login is copied in (.credentials.json only).
#   - The working dir is a new empty dir. Nothing above it in the tree is
#     in the test except what Claude Code loads from outside the repo.
#   - Only the plugin is installed (from this repo's marketplace).
#   - Built-in tools are restricted with --tools, MCP tools are denied,
#     project and local settings are not loaded, and the system prompt is replaced.
#   - Scripts are pre-approved with --allowedTools.
# Outputs in <run>/: stream.jsonl (every event), stderr.log, answer.txt, and the
# real session transcript under config/projects/.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_CONFIG="${SRC_CLAUDE_CONFIG:-$HOME/.claude}"
RUNS="${RUNS_DIR:-/tmp/code-docs-lookup-runs}"
PLUGIN_SCRIPTS="$REPO/plugins/code-docs-lookup/scripts"

if [[ $# -ne 2 ]]; then
    echo "usage: tests/run-case.sh <name> <prompt>" >&2
    exit 2
fi
name="$1"
prompt="$2"

run="$RUNS/$(date -u +%Y%m%dT%H%M%SZ)-$name"
cfg="$run/config"
work="$run/work"
mkdir -p "$cfg" "$work"

# 1. Config dir: login plus settings that also export CLAUDE_CONFIG_DIR into the session.
install -m 600 "$SRC_CONFIG/.credentials.json" "$cfg/.credentials.json"
# Bundled skills are hidden by name. Plugin skills are not affected by skillOverrides.
BUNDLED_SKILLS=(design design-sync dataviz update-config verify debug code-review simplify batch
    fewer-permission-prompts doctor loop schedule claude-api run run-skill-generator plugin-authoring
    anthropic-skills:docs anthropic-skills:google-workspace anthropic-skills:learn
    anthropic-skills:skill-creator anthropic-skills:xlsx anthropic-skills:pptx anthropic-skills:pdf
    anthropic-skills:docx)
overrides=$(printf '"%s": "off",' "${BUNDLED_SKILLS[@]}")
overrides="{${overrides%,}}"
printf '{\n  "env": { "CLAUDE_CONFIG_DIR": "%s" },\n  "skillOverrides": %s\n}\n' "$cfg" "$overrides" > "$cfg/settings.json"

export CLAUDE_CONFIG_DIR="$cfg"

# 2. Plugin, from this repo's marketplace, into this config dir only.
claude plugin marketplace add "$REPO" > "$run/install.log" 2>&1
claude plugin install code-docs-lookup@code-docs-tools >> "$run/install.log" 2>&1

# 3. Empty working dir, then the session.
#    Sandbox lists:
#      --tools            only Bash and Skill are built in
#      --disallowedTools  no MCP tools
#      --setting-sources  user only: no project or local settings
#      --system-prompt    replaces the default system prompt
#      --allowedTools     the plugin scripts run without a prompt (EXTRA_ALLOWED adds one more rule)
cd "$work"
claude -p "$prompt" \
    --output-format stream-json --verbose --max-budget-usd 1 \
    --tools "Bash,Skill" \
    --disallowedTools "mcp__*" \
    --setting-sources user \
    --system-prompt "Answer using the tools you have. Do not guess." \
    --allowedTools "Bash($PLUGIN_SCRIPTS/*)" ${EXTRA_ALLOWED:+--allowedTools "$EXTRA_ALLOWED"} \
    < /dev/null > "$run/stream.jsonl" 2> "$run/stderr.log" || true

python3 - "$run" <<'PY'
import json, pathlib, sys
run = pathlib.Path(sys.argv[1])
answer = ""
for line in (run / "stream.jsonl").read_text().splitlines():
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if e.get("type") == "result":
        answer = e.get("result", "")
(run / "answer.txt").write_text(answer + "\n")
PY

echo "run: $run"
