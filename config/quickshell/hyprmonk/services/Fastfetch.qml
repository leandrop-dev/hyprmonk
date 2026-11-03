// The look of the `fastfetch` command: one of `presets` (config/fastfetch,
// or fastfetch's own for "default"), picked in Settings > Appearance and kept
// in fastfetch.json. ThemeOutputs hands it to zsh with the tone's colours, so
// it shows from the next prompt.
//
// IPC: qs -c hyprmonk ipc call fastfetch set NAME
pragma Singleton

import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property var presets: ({
        default: "Default",
        compact: "Compact",
        minimal: "Minimal",
        tree: "Tree",
        sections: "Sections",
        full: "Full"
    })
    readonly property string saved: settings.preset in presets ? settings.preset : "default"

    function set(name: string): void {
        if (name in presets) settings.preset = name;
    }

    FileView {
        path: Theme.stateDir + "/fastfetch.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property string preset: "default"
        }
    }

    IpcHandler {
        target: "fastfetch"

        function set(name: string): void {
            root.set(name);
        }
    }
}
