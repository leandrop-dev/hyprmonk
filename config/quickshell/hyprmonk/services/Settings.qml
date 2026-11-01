// What Settings (Super+comma) changes, kept in settings.json in the state
// directory. Only what was changed is kept: the rest follows the repo's config.
//
// The window options reach Hyprland twice: at once through `hyprctl eval`, and
// in settings.lua, which hyprland.lua loads after look.lua so they survive a
// restart. Game mode turns blur and shadows off whatever these say.
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
        }
    }

    FileView {
        id: output
        path: Theme.stateDir + "/settings.lua"
        blockLoading: true
        printErrors: false
    }
}
