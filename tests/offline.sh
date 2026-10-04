#!/usr/bin/env bash
# Offline checks: no model calls. Covers the docs cache, lookup scripts,
# the env reference, the plugin files, and a fresh-config install.
# Run from anywhere: tests/offline.sh
source "$(dirname "$0")/lib.sh"
# ---- 01-sync.sh
# Stage 01: sync-docs.sh builds a complete, well-formed docs cache.
echo "stage 01: sync"

cache="$TEST_TMP/docs"
check "sync exits 0" "$PLUGIN/scripts/sync-docs.sh" -c "$cache"
check "index.txt exists" test -s "$cache/index.txt"

pages=$(find "$cache" -name '*.md' | wc -l)
entries=$(wc -l < "$cache/index.txt")
[[ "$pages" -gt 100 ]] || fail "only $pages pages; expected the full docs set"
pass "page count is $pages"
[[ "$pages" -eq "$entries" ]] || fail "index has $entries entries but $pages pages exist"
pass "index entries match pages"

bad=0
while IFS=$'\t' read -r slug title; do
    page="$cache/$slug.md"
    [[ -s "$page" ]] || { echo "    empty or missing: $slug"; bad=$((bad + 1)); continue; }
    [[ "$(sed -n 2p "$page")" == "Source: https://code.claude.com/docs/en/$slug" ]] \
        || { echo "    bad Source line: $slug"; bad=$((bad + 1)); }
done < "$cache/index.txt"
[[ $bad -eq 0 ]] || fail "$bad page(s) failed the per-page checks"
pass "every page has a Source line that matches its slug"

check "second sync without --force is a no-op" \
    bash -c "'$PLUGIN/scripts/sync-docs.sh' -c '$cache' | grep -q 'already cached'"

# ---- 02-lookup.sh
# Stage 02: search-docs.sh and show-doc.sh find and print real pages.
echo "stage 02: search and show"

cache="$TEST_TMP/docs"
[[ -s "$cache/index.txt" ]] || fail "stage 01 cache missing; run stage 01 first"

hits=$("$PLUGIN/scripts/search-docs.sh" -c "$cache" "CLAUDE_CODE_PLUGIN_CACHE_DIR")
grep -q "slug:   env-vars" <<< "$hits" || fail "search does not find env-vars for CLAUDE_CODE_PLUGIN_CACHE_DIR"
pass "search finds env-vars for a known variable"

miss=$("$PLUGIN/scripts/search-docs.sh" -c "$cache" "zzqqnonexistentzzqq")
grep -q "no matches" <<< "$miss" || fail "search should report no matches"
pass "search reports no matches for nonsense"

heads=$("$PLUGIN/scripts/show-doc.sh" -c "$cache" -H env-vars)
grep -q "^1:# Environment variables" <<< "$heads" || fail "show-doc -H does not start with the page title"
pass "show-doc -H lists the page headings"

full=$("$PLUGIN/scripts/show-doc.sh" -c "$cache" env-vars)
grep -q "CLAUDE_CODE_PLUGIN_CACHE_DIR" <<< "$full" || fail "show-doc does not print the variables table"
pass "show-doc prints the whole page"

by_url=$("$PLUGIN/scripts/show-doc.sh" -c "$cache" https://code.claude.com/docs/en/env-vars)
[[ "$(head -1 <<< "$by_url")" == "# Environment variables" ]] || fail "show-doc does not accept a docs URL"
pass "show-doc accepts a docs URL"

if "$PLUGIN/scripts/show-doc.sh" -c "$cache" no-such-page-zzqq >/dev/null 2>&1; then
    fail "show-doc should exit non-zero for an unknown page"
fi
pass "show-doc exits non-zero for an unknown page"

grep -q "^source: https://code.claude.com/docs/en/env-vars$" <<< "$full" || fail "show-doc output has no source line"
pass "show-doc ends with the source URL"

# ---- 03-reference.sh
# Stage 03: the env var reference is exactly what the generator builds from the docs.
echo "stage 03: env reference"

cache="$TEST_TMP/docs"
[[ -s "$cache/env-vars.md" ]] || fail "stage 01 cache missing; run stage 01 first"

generated="$TEST_TMP/env-vars.md"
check "generator runs" bash -c "'$REPO/tools/build-env-reference.py' '$cache/env-vars.md' > '$generated'"

committed="$PLUGIN/skills/claude-code-docs/references/env-vars.md"
check "committed reference matches generator output" diff -q "$generated" "$committed"

source_rows=$(awk '/^## Variables/{f=1} /^## Features that need/{f=0} f && /^\| `[A-Z0-9_]+` \|/' "$cache/env-vars.md" | wc -l)
ref_rows=$(grep -c '^| `' "$committed")
[[ "$source_rows" -eq "$ref_rows" ]] || fail "reference has $ref_rows rows, docs table has $source_rows"
pass "reference has all $ref_rows variables from the docs table"

grep -q '](#' "$committed" && fail "reference has relative anchor links"
pass "reference has no relative links"

# ---- 04-plugin.sh
# Stage 04: the marketplace and plugin are valid and every file they point at exists.
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

# ---- 05-install.sh
# Stage 05: the marketplace installs the plugin into a fresh config dir and it is enabled.
echo "stage 05: install into a fresh config dir"

export CLAUDE_CONFIG_DIR="$TEST_TMP/config"
mkdir -p "$CLAUDE_CONFIG_DIR"
check "marketplace add" claude plugin marketplace add "$REPO"
check "plugin install" claude plugin install code-docs-lookup@code-docs-tools
list=$(claude plugin list)
grep -q "code-docs-lookup@code-docs-tools" <<< "$list" || fail "plugin missing from plugin list"
grep -A5 "code-docs-lookup@code-docs-tools" <<< "$list" | grep -q "Status: .*enabled" || fail "plugin is not enabled"
pass "plugin is listed and enabled"
