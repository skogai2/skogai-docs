#!/usr/bin/env bash
# Stage 03: the env var reference is exactly what the generator builds from the docs.
source "$(dirname "$0")/../lib.sh"
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
