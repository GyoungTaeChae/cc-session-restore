#!/usr/bin/env bash
# check_restore_layout.sh — run cc-restore-layout on fake history and layouts in a throwaway
# HOME and check what it offers and the terminator layout it writes.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$REPO_DIR/bin/cc-restore-layout"
TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT
SNAPSHOT_DIR="$TEST_HOME/sessions"
mkdir -p "$TEST_HOME/.config/terminator" "$SNAPSHOT_DIR/history" "$SNAPSHOT_DIR/layouts"

fail() { echo "FAIL: $*"; exit 1; }

session() {
  printf '{"sessionId": "%s", "name": "%s", "cwd": "%s", "terminalUuid": "urn:uuid:%s"}' "$1" "$2" "$TEST_HOME" "$3"
}
A=$(session aaaa first 11111111-1111-1111-1111-111111111111)
B=$(session bbbb second 22222222-2222-2222-2222-222222222222)
C=$(session cccc third 44444444-4444-4444-4444-444444444444)
D=$(session dddd closed-long-ago 55555555-5555-5555-5555-555555555555)

# one hour ago all four were open, d closed first, then a window holding a and b went away
stamp() { date -d "$1" +%Y%m%d-%H%M%S; }
echo "{\"sessions\": [$A, $B, $C, $D]}" > "$SNAPSHOT_DIR/history/$(stamp '-60 min').json"
echo "{\"sessions\": [$A, $B, $C]}"     > "$SNAPSHOT_DIR/history/$(stamp '-30 min').json"
echo "{\"sessions\": [$C]}"             > "$SNAPSHOT_DIR/history/$(stamp '-10 min').json"

# window0 held a and b split side by side, window5 held c
cat > "$SNAPSHOT_DIR/layouts/$(stamp '-30 min')-100.json" <<EOF
{
  "window0": {"type": "Window", "parent": "", "order": 0, "size": [1200, 800], "title": "old title"},
  "child1": {"type": "HPaned", "parent": "window0", "order": 0, "ratio": 0.5},
  "terminal2": {"type": "Terminal", "parent": "child1", "order": 0, "uuid": "11111111-1111-1111-1111-111111111111", "directory": "/tmp"},
  "terminal3": {"type": "Terminal", "parent": "child1", "order": 1, "uuid": "22222222-2222-2222-2222-222222222222", "directory": "/no/such/dir"},
  "window5": {"type": "Window", "parent": "", "order": 0},
  "terminal6": {"type": "Terminal", "parent": "window5", "order": 0, "uuid": "44444444-4444-4444-4444-444444444444", "directory": "/tmp"}
}
EOF

running="[$C]"

# terminator open: a and b preselected, d offered but not ticked, c is running
offered=$(echo "$running" | python3 "$TOOL" candidates "$SNAPSHOT_DIR" 1 | cut -f1,2 | tr '\t\n' ': ')
[ "$offered" = "TRUE:aaaa TRUE:bbbb FALSE:dddd " ] || fail "offered with terminator open: $offered"

# terminator closed: everything in the last snapshot that is not running (here none)
offered=$(echo "[]" | python3 "$TOOL" candidates "$SNAPSHOT_DIR" 0 | cut -f1,2 | tr '\t\n' ': ')
[ "$offered" = "TRUE:cccc " ] || fail "offered with terminator closed: $offered"

HOME="$TEST_HOME" python3 "$TOOL" build "$SNAPSHOT_DIR" layout 1 aaaa bbbb dddd >/dev/null

XDG_CONFIG_HOME="$TEST_HOME/.config" TEST_HOME="$TEST_HOME" python3 - <<'PYTHON'
import os
from terminatorlib.config import Config

layout = Config().layout_get_config('claude_restore')
home = os.environ['TEST_HOME']
assert layout['terminal2']['command'] == 'claude --resume aaaa; exec bash', layout['terminal2']
assert layout['terminal2']['directory'] == home
assert layout['terminal3']['command'] == 'claude --resume bbbb; exec bash', layout['terminal3']
assert 'title' not in layout['window0']
# c is still open, so its window is left out
assert 'window5' not in layout and 'terminal6' not in layout, list(layout)
# d was never in a saved layout, so it gets a window of its own
assert layout['extra_terminal0_0']['command'] == 'claude --resume dddd; exec bash'
PYTHON

echo "OK"
