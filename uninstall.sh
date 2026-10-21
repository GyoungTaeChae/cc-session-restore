#!/usr/bin/env bash
# uninstall.sh — remove cc-session-restore. Saved snapshots are kept.
set -euo pipefail

DESKTOP_FILE="cc-session-restore.desktop"

systemctl --user disable --now cc-snapshot.timer cc-snapshot-shutdown.service 2>/dev/null || true

rm -f "$HOME/.local/bin/cc-snapshot" "$HOME/.local/bin/cc-restore" "$HOME/.local/bin/cc-restore-layout"
rm -f "$HOME/.config/terminator/plugins/layout_snapshot.py"
rm -f "$HOME/.config/systemd/user/cc-snapshot.service" \
      "$HOME/.config/systemd/user/cc-snapshot.timer" \
      "$HOME/.config/systemd/user/cc-snapshot-shutdown.service"
rm -f "$HOME/.local/share/applications/$DESKTOP_FILE"
rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/cc-session-restore.svg"
systemctl --user daemon-reload || true

if [ -f "$HOME/.config/terminator/config" ] && python3 -c 'import configobj' 2>/dev/null; then
  python3 - <<'PYTHON'
import os
from configobj import ConfigObj

config_path = os.path.expanduser('~/.config/terminator/config')
config = ConfigObj(config_path, encoding='utf-8')
global_config = config.get('global_config', {})
plugins = global_config.get('enabled_plugins', [])
if isinstance(plugins, str):
    plugins = [plugins]
if 'LayoutSnapshot' in plugins:
    plugins.remove('LayoutSnapshot')
    global_config['enabled_plugins'] = plugins
if 'claude_restore' in config.get('layouts', {}):
    del config['layouts']['claude_restore']
config.write()
PYTHON
fi

if command -v gsettings >/dev/null 2>&1 && gsettings get org.gnome.shell favorite-apps >/dev/null 2>&1; then
  favorites=$(gsettings get org.gnome.shell favorite-apps)
  favorites=$(printf '%s' "$favorites" | sed -e "s/, '$DESKTOP_FILE'//" -e "s/'$DESKTOP_FILE', //" -e "s/\['$DESKTOP_FILE'\]/@as []/")
  gsettings set org.gnome.shell favorite-apps "$favorites"
fi

echo "removed. snapshots under ~/.local/state/cc-session-restore (or your CLAUDE_SESSIONS_DIR) are kept."
