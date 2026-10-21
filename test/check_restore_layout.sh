#!/usr/bin/env bash
# check_restore_layout.sh — run cc-restore-layout on a fake layout in a throwaway HOME
# and check that the Claude terminal got its resume command and terminator can read the result.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT
mkdir -p "$TEST_HOME/.config/terminator"

cat > "$TEST_HOME/sessions.json" <<EOF
{"savedAt": "test", "sessions": [
  {"sessionId": "aaaa-session", "cwd": "$TEST_HOME", "name": "first",
   "terminalUuid": "urn:uuid:11111111-1111-1111-1111-111111111111"},
  {"sessionId": "bbbb-session", "cwd": "$TEST_HOME", "name": "not-in-layout",
   "terminalUuid": "urn:uuid:99999999-9999-9999-9999-999999999999"}
]}
EOF

cat > "$TEST_HOME/layout.json" <<EOF
{
  "window0": {"type": "Window", "parent": "", "order": 0, "position": "10:20", "maximised": false,
              "size": [1200, 800], "title": "old title"},
  "child0": {"type": "Notebook", "parent": "window0", "order": 0, "labels": [null, "work"], "active_page": 1},
  "child1": {"type": "HPaned", "parent": "child0", "order": 0, "ratio": 0.5},
  "terminal2": {"type": "Terminal", "parent": "child1", "order": 0,
                "uuid": "11111111-1111-1111-1111-111111111111", "directory": "/tmp"},
  "terminal3": {"type": "Terminal", "parent": "child1", "order": 1,
                "uuid": "22222222-2222-2222-2222-222222222222", "directory": "/no/such/dir"},
  "terminal4": {"type": "Terminal", "parent": "child0", "order": 1,
                "uuid": "33333333-3333-3333-3333-333333333333", "directory": "/tmp"}
}
EOF

placed=$(HOME="$TEST_HOME" python3 "$REPO_DIR/bin/cc-restore-layout" "$TEST_HOME/sessions.json" "$TEST_HOME/layout.json")
[ "$placed" = "aaaa-session" ] || { echo "FAIL: placed ids: $placed"; exit 1; }

XDG_CONFIG_HOME="$TEST_HOME/.config" TEST_HOME="$TEST_HOME" python3 - <<'PYTHON'
import os
from terminatorlib.config import Config

layout = Config().layout_get_config('claude_restore')
assert layout['terminal2']['command'] == 'claude --resume aaaa-session; exec bash', layout['terminal2']
assert layout['terminal2']['directory'] == os.environ['TEST_HOME']
assert 'directory' not in layout['terminal3']
assert layout['terminal4']['command'] == ''
assert 'title' not in layout['window0']
PYTHON

echo "OK"
