# layout_snapshot — save the full terminator layout (windows, tab order,
# splits, each terminal's uuid and cwd) every 10 minutes for cc-restore.
import json
import os

from gi.repository import GLib

import terminatorlib.plugin as plugin
from terminatorlib.terminator import Terminator
from terminatorlib.util import err

AVAILABLE = ['LayoutSnapshot']

SNAPSHOT_DIR = os.environ.get('CLAUDE_SESSIONS_DIR', '@SESSIONS_DIR@')
SNAPSHOT_FILE = os.path.join(SNAPSHOT_DIR, 'terminator-layout.json')
SAVE_INTERVAL_SECONDS = 600


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
                os.makedirs(SNAPSHOT_DIR, exist_ok=True)
                temporary_file = SNAPSHOT_FILE + '.tmp'
                with open(temporary_file, 'w') as output:
                    json.dump(layout, output, indent=2, default=str)
                os.replace(temporary_file, SNAPSHOT_FILE)
        except Exception as error:
            err('LayoutSnapshot: saving layout failed: %s' % error)
        # returning True keeps the GLib timer running
        return True
