// What Settings (Super+comma) changes, kept in settings.json in the state
// directory. Only what was changed is kept: the rest follows the repo's config.
//
// The window and input options reach Hyprland twice: at once through `hyprctl
// eval`, and in settings.lua, which hyprland.lua loads after look.lua and
// input.lua so they survive a restart. Game mode turns blur and shadows off
// whatever these say. A screen's mode reaches settings.lua only once kept.
// The power times go to hypridle instead (services/Idle.qml).
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

    // Settings > Input. `inputDefaults` are input.lua's (adaptive is
    // libinput's own for a mouse, and Hyprland takes no empty profile back).
    // `layouts` lists up to four XKB layouts, the first one the default.
    readonly property var inputDefaults: ({ layouts: "pt", sensitivity: 0, accel: "adaptive", naturalScroll: false, followMouse: true })
    readonly property var inputValues: {
        const values = {};
        const kept = saved.input;
        // Typed first: a missing value would test as the text "undefined".
        if (typeof kept.layouts === "string" && /^[a-z]+(,[a-z]+){0,3}$/.test(kept.layouts)) values.layouts = kept.layouts;
        if (typeof kept.sensitivity === "number" && Number.isFinite(kept.sensitivity))
            values.sensitivity = Math.round(Math.max(-1, Math.min(1, Number(kept.sensitivity))) * 100) / 100;
        if (kept.accel === "adaptive" || kept.accel === "flat") values.accel = kept.accel;
        for (const key of ["naturalScroll", "followMouse"])
            if (typeof kept[key] === "boolean") values[key] = kept[key];
        return values;
    }
    readonly property bool inputChanged: Object.keys(inputValues).length > 0

    readonly property string hyprland: "-- Written by the shell (services/Settings.qml). Do not edit.\n"
        + windowOptions.filter(option => option.key in windowValues)
            .map(option => line(option, windowValues[option.key]) + "\n").join("")
        + (inputChanged ? inputLine(inputValues) + "\n" : "")
        + Object.keys(displayValues).map(name => displayLine(name, displayValues[name]) + "\n").join("")

    function inputValue(key: string): var {
        return inputValues[key] ?? inputDefaults[key];
    }

    // Lua for the input values given, by their keys here.
    function inputLine(values: var): string {
        const parts = [];
        if ("layouts" in values) parts.push(`kb_layout = "${values.layouts}"`);
        if ("sensitivity" in values) parts.push(`sensitivity = ${Number(values.sensitivity)}`);
        if ("accel" in values) parts.push(`accel_profile = "${values.accel}"`);
        if ("naturalScroll" in values) parts.push(`natural_scroll = ${values.naturalScroll ? "true" : "false"}`);
        // Off: the keyboard follows clicks, while scrolling still follows the pointer.
        if ("followMouse" in values) parts.push(`follow_mouse = ${values.followMouse ? 1 : 2}`);
        return `hl.config({ input = { ${parts.join(", ")} } })`;
    }

    function setInput(key: string, value: var): void {
        const next = Object.assign({}, saved.input);
        if (value === inputDefaults[key]) delete next[key];
        else next[key] = value;
        saved.input = next;
        Quickshell.execDetached(["hyprctl", "eval", inputLine({ [key]: value })]);
        if (key === "layouts") Keyboard.refresh();
    }

    function resetInput(): void {
        const back = {};
        for (const key of Object.keys(inputValues)) back[key] = inputDefaults[key];
        saved.input = {};
        if (Object.keys(back).length > 0) Quickshell.execDetached(["hyprctl", "eval", inputLine(back)]);
        if ("layouts" in back) Keyboard.refresh();
    }

    // Settings > Power, as kept; services/Idle.qml reads and checks it.
    readonly property var power: saved.power

    function setPower(values: var): void {
        saved.power = values;
    }

    // What Settings > Display kept, by screen (services/Display.qml). This
    // ends up as Lua and the file can be edited by hand: only what looks right.
    // A screen mirroring another (`mirror`) or turned off (`disabled`) keeps
    // its own mode beside that, for when it is back on its own.
    readonly property var displayValues: {
        const values = {};
        for (const name of Object.keys(saved.display)) {
            const value = saved.display[name];
            if (/^[\w.-]+$/.test(name) && /^\d+x\d+@[\d.]+$/.test(value?.mode)
                    && /^(-?\d+x-?\d+|auto)$/.test(value?.position) && Number(value?.scale) > 0
                    && (value.mirror === undefined || /^[\w.-]+$/.test(value.mirror))
                    && (value.disabled === undefined || typeof value.disabled === "boolean"))
                values[name] = value;
        }
        return values;
    }
    property bool reloadOnSave: false  // the config has to take back a screen

    // The screen the Mirror and Main screen only layouts keep (Settings >
    // Display); "" for none picked.
    readonly property string mainScreen: /^[\w.-]+$/.test(saved.mainScreen) ? saved.mainScreen : ""

    function setMainScreen(name: string): void {
        saved.mainScreen = name;
    }

    function displayLine(name: string, value: var): string {
        if (value.disabled) return `hl.monitor({ output = "${name}", disabled = true })`;
        const mirror = value.mirror ? `, mirror = "${value.mirror}"` : "";
        return `hl.monitor({ output = "${name}", mode = "${value.mode}", position = "${value.position}", scale = ${Number(value.scale)}${mirror} })`;
    }

    // For a change made live: Hyprland keeps a mirror or a screen turned off
    // from before unless told otherwise.
    function liveDisplayLine(name: string, value: var): string {
        if (value.disabled) return displayLine(name, value);
        return displayLine(name, value).replace(/ \}\)$/, (value.mirror ? "" : `, mirror = ""`) + ", disabled = false })");
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
            property string mainScreen: ""
            property var input: ({})
            property var power: ({})
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
