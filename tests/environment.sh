#!/usr/bin/env bash
# Stage 00: a run really is isolated. Each claim is read from the run's own events.
source "$(dirname "$0")/lib.sh"
echo "environment: isolated run"

run_out=$(EXTRA_ALLOWED='Bash(printenv CLAUDE_CONFIG_DIR)' "$REPO/tests/run-case.sh" stage00 \
    "Run exactly this shell command and nothing else: printenv CLAUDE_CONFIG_DIR")
run=$(sed -n 's/^run: //p' <<< "$run_out")
[[ -n "$run" ]] || fail "run-case.sh reported no run directory"
pass "run directory: $run"

init=$(python3 - "$run/stream.jsonl" <<'PY'
import json, sys
for line in open(sys.argv[1]):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if e.get("type") == "system" and e.get("subtype") == "init":
        print(json.dumps({"tools": e.get("tools"), "skills": e.get("skills"), "mcp": e.get("mcp_servers"),
                          "plugins": [p.get("name") for p in e.get("plugins", [])]}))
        break
PY
)
[[ -n "$init" ]] || fail "no init event in stream.jsonl"

python3 - "$init" <<'PY' || fail "tool or skill list is not the sandbox list"
import json, sys
i = json.loads(sys.argv[1])
assert i["tools"] == ["Bash", "Skill"], i["tools"]
assert i["skills"] == ["code-docs-lookup:claude-code-docs"], i["skills"]
assert not i["mcp"], i["mcp"]
assert set(i["plugins"]) <= {"code-docs-lookup", "cc-plugin-agents-md", "cc-plugin-telemetry", "cc-plugin-plugin-authoring"}, i["plugins"]
assert "code-docs-lookup" in i["plugins"], i["plugins"]
PY
pass "built-in tools are exactly Bash and Skill"
pass "the only skill is the plugin's skill"
pass "no MCP servers"
pass "plugins are ours plus the built-in cc-plugin set"

check "settings.json sets CLAUDE_CONFIG_DIR to the run's config dir" \
    python3 -c "import json,sys; assert json.load(open(sys.argv[1]))['env']['CLAUDE_CONFIG_DIR'] == sys.argv[2]" \
    "$run/config/settings.json" "$run/config"

# The probe's Bash call printed the config dir from inside the session.
seen=$(python3 - "$run/stream.jsonl" <<'PY'
import json, sys
out = []
for line in open(sys.argv[1]):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if e.get("type") == "user" and isinstance(e.get("message", {}).get("content"), list):
        for c in e["message"]["content"]:
            if c.get("type") == "tool_result" and not c.get("is_error"):
                out.append(str(c.get("content")).strip())
print("\n".join(out))
PY
)
grep -qx "$run/config" <<< "$seen" || fail "printenv inside the session did not return the run's config dir"
pass "printenv inside the session returns the run's config dir"

check "working dir is still empty after the session" test -z "$(ls -A "$run/work")"

check "no transcript mentions the real ~/.claude" \
    bash -c "! grep -rq '$HOME/.claude/' '$run/config/projects'"

# No hook ran: the run's settings.json has no hooks, and the stream has no hook events.
check "run settings.json has no hooks" \
    python3 -c "import json,sys; assert 'hooks' not in json.load(open(sys.argv[1]))" "$run/config/settings.json"
check "stream has no hook events" bash -c "! grep -q '\"hook' '$run/stream.jsonl'"
