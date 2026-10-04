#!/usr/bin/env bash
# Shared helpers for the stage scripts. Source it; don't run it.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$REPO/plugins/code-docs-lookup"
TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
export REPO PLUGIN TEST_TMP

pass() { echo "  ok    $*"; }
fail() { echo "  FAIL  $*" >&2; exit 1; }

# check <description> <command...>: passes when the command exits 0.
check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}
