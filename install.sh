#!/usr/bin/env bash
# install.sh — install cc-session-restore for the current user.
#   ./install.sh                                  save to ~/.local/state/cc-session-restore
#   CLAUDE_SESSIONS_DIR=/some/dir ./install.sh    save somewhere else
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSIONS_DIR="${CLAUDE_SESSIONS_DIR:-$HOME/.local/state/cc-session-restore}"
BIN_DIR="$HOME/.local/bin"
PLUGIN_DIR="$HOME/.config/terminator/plugins"
SYSTEMD_DIR="$HOME/.config/systemd/user"
APPLICATIONS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
DESKTOP_FILE="cc-session-restore.desktop"

missing=()
for command_name in jq terminator python3 systemctl zenity; do
  command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done
python3 -c 'import configobj' 2>/dev/null || missing+=("python3-configobj")
if [ "${#missing[@]}" -gt 0 ]; then
  echo "missing: ${missing[*]}" >&2
  echo "on Ubuntu: sudo apt install jq terminator python3-configobj zenity" >&2
  exit 1
fi

# copy a file and fill in the install paths
install_file() {
  local source_file="$1" target_file="$2" mode="$3"
  mkdir -p "$(dirname "$target_file")"
  sed -e "s#@SESSIONS_DIR@#$SESSIONS_DIR#g" -e "s#@BIN_DIR@#$BIN_DIR#g" "$source_file" > "$target_file"
  chmod "$mode" "$target_file"
  echo "  $target_file"
}

echo "installing files:"
mkdir -p "$SESSIONS_DIR"
for script in cc-snapshot cc-restore cc-restore-layout; do
  install_file "$REPO_DIR/bin/$script" "$BIN_DIR/$script" 755
done
install_file "$REPO_DIR/terminator/layout_snapshot.py" "$PLUGIN_DIR/layout_snapshot.py" 644
for unit in cc-snapshot.service cc-snapshot.timer cc-snapshot-shutdown.service; do
  install_file "$REPO_DIR/systemd/$unit" "$SYSTEMD_DIR/$unit" 644
done
install_file "$REPO_DIR/desktop/$DESKTOP_FILE" "$APPLICATIONS_DIR/$DESKTOP_FILE" 644
install_file "$REPO_DIR/desktop/cc-session-restore.svg" "$ICON_DIR/cc-session-restore.svg" 644

echo "enabling the terminator plugin"
python3 - <<'PYTHON'
import os
from configobj import ConfigObj

config_path = os.path.expanduser('~/.config/terminator/config')
os.makedirs(os.path.dirname(config_path), exist_ok=True)
config = ConfigObj(config_path, encoding='utf-8')
if 'global_config' not in config:
    config['global_config'] = {}
# terminator enables these three when the key is absent, so keep them
plugins = config['global_config'].get('enabled_plugins',
                                      ['LaunchpadBugURLHandler', 'LaunchpadCodeURLHandler', 'APTURLHandler'])
if isinstance(plugins, str):
    plugins = [plugins]
if 'LayoutSnapshot' not in plugins:
    plugins.append('LayoutSnapshot')
config['global_config']['enabled_plugins'] = plugins
config.write()
PYTHON

echo "starting the snapshot timer"
systemctl --user daemon-reload
systemctl --user enable --now cc-snapshot.timer cc-snapshot-shutdown.service

if command -v gsettings >/dev/null 2>&1 && gsettings get org.gnome.shell favorite-apps >/dev/null 2>&1; then
  favorites=$(gsettings get org.gnome.shell favorite-apps)
  case "$favorites" in
    *"'$DESKTOP_FILE'"*) ;;
    "@as []") gsettings set org.gnome.shell favorite-apps "['$DESKTOP_FILE']" ;;
    *) gsettings set org.gnome.shell favorite-apps "${favorites%]}, '$DESKTOP_FILE']" ;;
  esac
  echo "pinned to the dock"
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note: $BIN_DIR is not in PATH; add it to use cc-restore from a terminal" ;;
esac

echo
echo "done. snapshots go to $SESSIONS_DIR"
if pgrep -u "$USER" -x terminator >/dev/null; then
  echo "terminator is running: run cc-snapshot, close every terminator window, then click the dock icon."
  echo "the layout plugin loads only when terminator starts."
fi
