#!/usr/bin/env bash
# Stage 06: a real `claude -p` run uses the docs scripts and cites only pages it read.
# This calls the API and costs money (capped by --max-budget-usd in run-case.sh).
source "$(dirname "$0")/../lib.sh"
echo "stage 06: agent run"

prompt="${PROMPT:-which env var disable telemetry in claude code}"
run=$("$REPO/tests/run-case.sh" stage06 "$prompt" | sed -n 's/^run: //p')
[[ -n "$run" ]] || fail "run-case.sh did not report a run directory"
pass "run recorded at $run"

python3 "$REPO/tests/check-run.py" "$run" || fail "run did not meet the docs requirements"
