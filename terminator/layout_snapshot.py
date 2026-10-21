# layout_snapshot — save the full terminator layout (windows, tab order,
# splits, each terminal's uuid and cwd) every 10 minutes for cc-restore.
# Each save is a new file kept for 3 days, so a closed window can still be found.
import json
import os
import time

from gi.repository import GLib

import terminatorlib.plugin as plugin
from terminatorlib.terminator import Terminator
from terminatorlib.util import err

AVAILABLE = ['LayoutSnapshot']

SNAPSHOT_DIR = os.environ.get('CLAUDE_SESSIONS_DIR', '@SESSIONS_DIR@')
LAYOUT_DIR = os.path.join(SNAPSHOT_DIR, 'layouts')
SAVE_INTERVAL_SECONDS = 600
KEEP_SECONDS = 3 * 24 * 3600


class LayoutSnapshot(plugin.Plugin):
    capabilities = ['layout_snapshot']

    def __init__(self):
        plugin.Plugin.__init__(self)
        self.timer_id = GLib.timeout_add_seconds(SAVE_INTERVAL_SECONDS, self.save_layout)

    def unload(self):
        GLib.source_remove(self.timer_id)

    def save_layout(self):
        try:
            layout = Terminator().describe_layout(save_cwd=True)
            if layout:
                os.makedirs(LAYOUT_DIR, exist_ok=True)
                layout_file = os.path.join(LAYOUT_DIR, '%s-%d.json' % (time.strftime('%Y%m%d-%H%M%S'), os.getpid()))
                with open(layout_file + '.tmp', 'w') as output:
                    json.dump(layout, output, indent=2, default=str)
                os.replace(layout_file + '.tmp', layout_file)
            for name in os.listdir(LAYOUT_DIR):
                path = os.path.join(LAYOUT_DIR, name)
                if time.time() - os.path.getmtime(path) > KEEP_SECONDS:
                    os.remove(path)
        except Exception as error:
            err('LayoutSnapshot: saving layout failed: %s' % error)
        # returning True keeps the GLib timer running
        return True
