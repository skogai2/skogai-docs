#!/usr/bin/env bash
# Stage 01: sync-docs.sh builds a complete, well-formed docs cache.
source "$(dirname "$0")/../lib.sh"
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
