#!/usr/bin/env bash
# Runs the offline checks, then the isolated-environment check.
# The agent check (agent.sh) calls the API, so it is run on its own.
set -euo pipefail
export TEST_TMP="$(mktemp -d)"
DIR="$(dirname "$0")"
bash "$DIR/offline.sh"
bash "$DIR/environment.sh"
echo "all checks passed"
