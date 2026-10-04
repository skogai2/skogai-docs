#!/usr/bin/env bash
# Stage 04: the marketplace and plugin are valid and every file they point at exists.
source "$(dirname "$0")/../lib.sh"
echo "stage 04: marketplace and plugin files"

check "marketplace validates" claude plugin validate "$REPO"
check "plugin validates" claude plugin validate "$PLUGIN"

skill="$PLUGIN/skills/claude-code-docs/SKILL.md"
check "skill has name" grep -q '^name: claude-code-docs$' "$skill"
check "skill has description" grep -q '^description: ' "$skill"

for script in sync-docs.sh search-docs.sh show-doc.sh; do
    check "$script exists and is executable" test -x "$PLUGIN/scripts/$script"
done

ref="$PLUGIN/skills/claude-code-docs/references/env-vars.md"
check "skill links the env reference" grep -q 'references/env-vars.md' "$skill"
check "env reference file exists" test -s "$ref"

# Every script the skill or command names must exist, so the instructions can't point at nothing.
for f in "$skill" "$PLUGIN/commands/ask.md"; do
    while read -r script; do
        check "$(basename "$f") names $script" test -x "$PLUGIN/scripts/$script"
    done < <(grep -o 'scripts/[a-z-]*\.sh' "$f" | sed 's#scripts/##' | sort -u)
done

# The pre-approved rules must cover the scripts, or every call prompts.
allowed=$(grep '^allowed-tools:' "$skill")
for script in search-docs.sh show-doc.sh sync-docs.sh; do
    check "allowed-tools covers $script" grep -q "scripts/$script" <<< "$allowed"
done

# The reference is read with a Bash rule: Read rules don't get ${CLAUDE_PLUGIN_ROOT} substituted.
check "allowed-tools lets the skill cat the reference" \
    grep -q 'Bash(cat ${CLAUDE_PLUGIN_ROOT}/skills/claude-code-docs/references/\*)' <<< "$allowed"
