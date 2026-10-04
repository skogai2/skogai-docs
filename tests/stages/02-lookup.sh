#!/usr/bin/env bash
# Stage 02: search-docs.sh and show-doc.sh find and print real pages.
source "$(dirname "$0")/../lib.sh"
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
