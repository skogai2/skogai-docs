#!/usr/bin/env bash
# Runs every stage in order. Stops at the first failing stage.
set -euo pipefail
export TEST_TMP="$(mktemp -d)"
for stage in "$(dirname "$0")"/stages/*.sh; do
    if ! bash "$stage"; then
        echo "stopped at $(basename "$stage"); later stages not run" >&2
        exit 1
    fi
done
echo "all stages passed"
