#!/usr/bin/env bash
# Stage 05: the marketplace installs the plugin into a fresh config dir and it is enabled.
source "$(dirname "$0")/../lib.sh"
echo "stage 05: install into a fresh config dir"

export CLAUDE_CONFIG_DIR="$TEST_TMP/config"
mkdir -p "$CLAUDE_CONFIG_DIR"
check "marketplace add" claude plugin marketplace add "$REPO"
check "plugin install" claude plugin install code-docs-lookup@code-docs-tools
list=$(claude plugin list)
grep -q "code-docs-lookup@code-docs-tools" <<< "$list" || fail "plugin missing from plugin list"
grep -A5 "code-docs-lookup@code-docs-tools" <<< "$list" | grep -q "Status: .*enabled" || fail "plugin is not enabled"
pass "plugin is listed and enabled"
