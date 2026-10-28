// Lights through OpenRGB: every device it finds (the motherboard's headers,
// the keyboard, the mouse) in the accent, or off. The keyboard can run one of
// its own effects instead, in the accent when the effect takes a colour.
//
// hyprmonk leaves the lights alone until they are switched from the quick
// actions. The choice is kept in the state directory and applied again when
// the shell starts and whenever the accent changes. Each `openrgb` call finds
// the devices again (about a second), so one asleep earlier is caught later.
//
// IPC: qs -c hyprmonk ipc call lights toggle | apply
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var devices: []  // [{name, type, modes}], from `openrgb -ld`
    readonly property var keyboard: devices.find(d => d.type === "Keyboard") ?? null
    readonly property var keyboardEffects: keyboard ? keyboard.modes.filter(m => m !== "Direct") : []
    readonly property string keyboardEffect: settings.keyboardEffect || solidMode(keyboard)

    // Untouched until switched: "" then, else "on" or "off".
    readonly property bool managed: settings.lights !== ""
    readonly property bool on: settings.lights === "on"

    // LEDs show a colour best at full saturation and value; a grey accent
    // becomes white.
    readonly property color colour: Theme.accent.hsvSaturation < 0.15 ? "white"
        : Qt.hsva(Theme.accent.hsvHue, 1, 1, 1)

    function toggle(): void {
        settings.lights = on ? "off" : "on";
        apply();
    }

    function setKeyboardEffect(effect: string): void {
        settings.keyboardEffect = effect;
        settings.lights = "on";
        apply();
    }

    // Finds the devices again; the quick actions ask on each open. One
    // `openrgb` at a time: two would talk to the same devices at once.
    function refresh(): void {
        if (!setter.running) list.running = true;
    }

    // The mode that holds one colour on a device ("Static", "Solid Color"),
    // or "" when it only takes colours directly.
    function solidMode(device: var): string {
        return ["Static", "Solid Color"].find(m => device?.modes.includes(m)) ?? "";
    }

    function command(): var {
        const hex = colour.toString().slice(1).toUpperCase();
        const args = ["openrgb"];
        for (const device of devices) {
            const solid = solidMode(device);
            const fixed = solid ? ["-m", solid] : [];
            args.push("-d", device.name);
            if (!on)
                args.push(...(device.modes.includes("Off") ? ["-m", "Off"] : [...fixed, "-c", "000000"]));
            else if (device === keyboard && settings.keyboardEffect)
                args.push("-m", settings.keyboardEffect, "-c", hex);
            else
                args.push(...fixed, "-c", hex);
        }
        return args;
    }

    // Asked while the devices were unknown or a call was still running.
    property bool pending: false

    function apply(): void {
        if (!managed) return;
        if (devices.length === 0 || list.running || setter.running) {
            pending = true;
            return;
        }
        pending = false;
        setter.command = command();
        setter.running = true;
    }

    // `openrgb -ld` gives "N: Name", then indented fields; modes are words,
    // quoted when they have spaces, the current one in brackets.
    function parse(text: string): var {
        const found = [];
        for (const line of text.split("\n")) {
            const head = line.match(/^\d+: (.+)$/);
            if (head) {
                found.push({ name: head[1].trim(), type: "", modes: [] });
                continue;
            }
            const field = line.match(/^\s+(Type|Modes):\s*(.*)$/);
            const device = found[found.length - 1];
            if (!field || !device) continue;
            if (field[1] === "Type")
                device.type = field[2].trim();
            else
                device.modes = (field[2].match(/\[?'[^']*'\]?|\S+/g) ?? [])
                    .map(m => m.replace(/^\[|\]$/g, "").replace(/^'|'$/g, ""));
        }
        return found;
    }

    Process {
        id: list
        command: ["openrgb", "-ld"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.devices = root.parse(text);
                if (root.pending) root.apply();
            }
        }
    }

    Process {
        id: setter
        onExited: if (root.pending) root.apply()
    }

    // The accent settles once matugen's colours load: wait for it.
    Timer {
        id: settle
        interval: 500
        onTriggered: root.apply()
    }

    Connections {
        target: Theme

        function onAccentChanged(): void {
            if (root.on) settle.restart();
        }
    }

    FileView {
        path: Theme.stateDir + "/lights.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: settle.restart()

        JsonAdapter {
            id: settings
            property string lights: ""
            property string keyboardEffect: ""
        }
    }

    IpcHandler {
        target: "lights"

        function toggle(): bool {
            root.toggle();
            return root.on;
        }

        function apply(): void {
            root.apply();
        }
    }
}
