// What Settings (Super+comma) changes, kept in settings.json in the state
// directory. Only what was changed is kept: the rest follows the repo's config.
//
// The window options reach Hyprland twice: at once through `hyprctl eval`, and
// in settings.lua, which hyprland.lua loads after look.lua so they survive a
// restart. Game mode turns blur and shadows off whatever these say. A screen's
// mode reaches settings.lua only once kept.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // `fallback` is look.lua's value, which the slider shows until it is moved.
    readonly property var windowOptions: [
        { key: "gapsIn", group: "Gaps", label: "Between windows", from: 0, to: 30, fallback: 4,
          lua: "general = { gaps_in = %1 }" },
        { key: "gapsOut", group: "Gaps", label: "Around the screen", from: 0, to: 40, fallback: 10,
          lua: "general = { gaps_out = %1 }" },
        { key: "borderSize", group: "Borders", label: "Border size", from: 0, to: 8, fallback: 2,
          lua: "general = { border_size = %1 }" },
        { key: "rounding", group: "Borders", label: "Rounding", from: 0, to: 30, fallback: 10,
          lua: "decoration = { rounding = %1 }" },
        { key: "blurSize", group: "Blur", label: "Size", from: 1, to: 20, fallback: 6,
          lua: "decoration = { blur = { size = %1 } }" },
        { key: "blurPasses", group: "Blur", label: "Passes", from: 1, to: 4, fallback: 2,
          lua: "decoration = { blur = { passes = %1 } }" }
    ]

    // What was changed, in range: the file can be edited by hand.
    readonly property var windowValues: {
        const values = {};
        for (const option of windowOptions) {
            const value = Number(saved.window[option.key]);
            if (saved.window[option.key] !== undefined && Number.isFinite(value))
                values[option.key] = clamp(option, value);
        }
        return values;
    }
    readonly property bool windowChanged: Object.keys(windowValues).length > 0

    readonly property string hyprland: "-- Written by the shell (services/Settings.qml). Do not edit.\n"
        + windowOptions.filter(option => option.key in windowValues)
            .map(option => line(option, windowValues[option.key]) + "\n").join("")
        + Object.keys(displayValues).map(name => displayLine(name, displayValues[name]) + "\n").join("")

    // What Settings > Display kept, by screen (services/Display.qml). This
    // ends up as Lua and the file can be edited by hand: only what looks right.
    readonly property var displayValues: {
        const values = {};
        for (const name of Object.keys(saved.display)) {
            const value = saved.display[name];
            if (/^[\w.-]+$/.test(name) && /^\d+x\d+@[\d.]+$/.test(value?.mode)
                    && /^-?\d+x-?\d+$/.test(value?.position) && Number(value?.scale) > 0)
                values[name] = value;
        }
        return values;
    }
    property bool reloadOnSave: false  // the config has to take back a screen

    function displayLine(name: string, value: var): string {
        return `hl.monitor({ output = "${name}", mode = "${value.mode}", position = "${value.position}", scale = ${Number(value.scale)} })`;
    }

    function displayKept(name: string): bool {
        return name in displayValues;
    }

    function setDisplay(name: string, value: var): void {
        saved.display = Object.assign({}, saved.display, { [name]: value });
    }

    function resetDisplay(name: string): void {
        const left = Object.assign({}, saved.display);
        delete left[name];
        reloadOnSave = true;
        saved.display = left;
    }

    // The bar's left and right cards, in order; the centre card stays as it
    // is. `panel` is what the module opens: it opens under the module's card.
    // Recording and Replay only show while they run, and cannot be hidden.
    readonly property var barModules: [
        { key: "launcher", label: "Launcher", icon: "\u{F003B}" },
        { key: "workspaces", label: "Workspaces", icon: "\u{F0570}" },
        { key: "overview", label: "Overview", icon: "\u{F0F8D}" },
        { key: "hardware", label: "Hardware", icon: "\u{F011B}" },
        { key: "recording", label: "Recording", icon: "\u{F044A}", fixed: true },
        { key: "replay", label: "Replay", icon: "\u{F0459}", fixed: true },
        { key: "tray", label: "Tray", icon: "\u{F0493}", panel: "tray" },
        { key: "network", label: "Network", icon: "\u{F05A9}", panel: "network" },
        { key: "bluetooth", label: "Bluetooth", icon: "\u{F00AF}", panel: "bluetooth" },
        { key: "batteries", label: "Batteries", icon: "\u{F0079}", panel: "batteries" },
        { key: "volume", label: "Volume", icon: "\u{F057E}", panel: "sound" },
        { key: "microphone", label: "Microphone", icon: "\u{F036C}", panel: "microphone" },
        { key: "notifications", label: "Notifications", icon: "\u{F009A}" },
        { key: "clock", label: "Clock", icon: "\u{F00ED}", panel: "calendar" },
        { key: "quickactions", label: "Quick actions", icon: "\u{F1542}" },
        { key: "power", label: "Power", icon: "\u{F0425}" }
    ]
    readonly property var barDefaults: ({
        left: ["launcher", "workspaces", "overview", "hardware"],
        right: ["recording", "replay", "tray", "network", "bluetooth", "batteries", "volume",
                "microphone", "notifications", "clock", "quickactions", "power"],
        hidden: []
    })

    // Each known module once, wherever it was left; one not placed yet (new
    // since the file was written) joins its default card.
    readonly property var bar: {
        const seen = {};
        const clean = (list, kept) => Array.from(list ?? []).filter(key => {
            const take = barModule(key) !== undefined && !seen[key] && kept(barModule(key));
            if (take) seen[key] = true;
            return take;
        });
        const all = () => true;
        const placed = {
            left: clean(saved.bar.left, all),
            right: clean(saved.bar.right, all),
            hidden: clean(saved.bar.hidden, module => !module.fixed)
        };
        placed.left.push(...barDefaults.left.filter(key => !seen[key]));
        placed.right.push(...barDefaults.right.filter(key => !seen[key]));
        return placed;
    }
    readonly property bool barChanged: JSON.stringify(bar) !== JSON.stringify(barDefaults)

    function barModule(key: string): var {
        return barModules.find(module => module.key === key);
    }

    function barPanel(key: string): string {
        return barModule(key)?.panel ?? "";
    }

    // Into `side` ("left", "right" or "hidden") before what is now at `index`.
    function moveBarModule(key: string, side: string, index: int): void {
        if (side === "hidden" && barModule(key).fixed) return;
        const next = { left: bar.left.slice(), right: bar.right.slice(), hidden: bar.hidden.slice() };
        for (const name of Object.keys(next)) {
            const at = next[name].indexOf(key);
            if (at < 0) continue;
            next[name].splice(at, 1);
            if (name === side && at < index) index -= 1;
        }
        next[side].splice(index, 0, key);
        saved.bar = next;
    }

    function resetBar(): void {
        saved.bar = {};
    }

    function clamp(option: var, value: real): int {
        return Math.max(option.from, Math.min(option.to, Math.round(value)));
    }

    function line(option: var, value: int): string {
        return "hl.config({ " + option.lua.arg(value) + " })";
    }

    function windowValue(option: var): int {
        return windowValues[option.key] ?? option.fallback;
    }

    function setWindow(option: var, value: real): void {
        const next = clamp(option, value);
        if (next === windowValue(option)) return;
        saved.window = Object.assign({}, saved.window, { [option.key]: next });
        Quickshell.execDetached(["hyprctl", "eval", line(option, next)]);
    }

    function resetWindow(): void {
        const lines = windowOptions.filter(option => option.key in windowValues)
            .map(option => line(option, option.fallback));
        saved.window = {};
        if (lines.length > 0) Quickshell.execDetached(["hyprctl", "eval", lines.join("\n")]);
    }

    onHyprlandChanged: output.setText(hyprland)

    FileView {
        path: Theme.stateDir + "/settings.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: saved
            property var window: ({})
            property var bar: ({})
            property var display: ({})
        }
    }

    FileView {
        id: output
        path: Theme.stateDir + "/settings.lua"
        blockLoading: true
        printErrors: false
        onSaved: {
            if (!root.reloadOnSave) return;
            root.reloadOnSave = false;
            Quickshell.execDetached(["hyprctl", "reload", "config-only"]);
        }
    }
}
