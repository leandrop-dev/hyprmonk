// The open windows, grouped by app, for the dock and the bar's window list.
// Minimising is Hyprland's side (hypr/minimise.lua): a minimised window
// waits on the special:minimized workspace, tagged hyprmonk-from-<id> with
// the workspace it came from, and focusing it brings it back there.
//
// An app keeps the place it took when its first window opened, so the list
// does not reshuffle as focus moves; its windows keep theirs the same way.
//
// IPC: qs -c hyprmonk ipc call windows list
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string hidden: "special:minimized"

    // Places, by app and by window, handed out as they first show up. Plain
    // objects changed in place, the count too: nothing needs to follow them,
    // and a property changing inside groups() would loop its bindings.
    property var places: ({})
    property var counter: ({ next: 0 })
    // When each window was last focused, to pick which of an app's windows a
    // click brings.
    property var focusedAt: ({})

    function place(key: string): int {
        if (!(key in places)) places[key] = counter.next++;
        return places[key];
    }

    function appOf(window: HyprlandToplevel): string {
        return window?.wayland?.appId || window?.lastIpcObject?.class || "";
    }

    function minimised(window: HyprlandToplevel): bool {
        return window?.workspace?.name === hidden;
    }

    // Focused, as the user sees it: a minimised window can still be
    // Hyprland's active one when nothing else took focus after it left.
    function focused(window: HyprlandToplevel): bool {
        return (window?.activated ?? false) && !minimised(window);
    }

    // The workspace a minimised window came from (its tag), or -1.
    function origin(window: HyprlandToplevel): int {
        for (const tag of window?.lastIpcObject?.tags ?? []) {
            const found = /^hyprmonk-from-(\d+)\*?$/.exec(tag);
            if (found) return Number(found[1]);
        }
        return -1;
    }

    // Windows from every workspace ("all"), or from `workspace` only, with
    // the minimised ones that came from it.
    function shown(window: HyprlandToplevel, scope: string, workspace: int): bool {
        if (!window.workspace) return false;
        if (scope !== "workspace") return true;
        return minimised(window) ? origin(window) === workspace : window.workspace.id === workspace;
    }

    // [{ key, name, icon, entry, windows, active, minimised, urgent }], in
    // the apps' places; `minimised` when every window of the app is.
    function groups(scope: string, workspace: int): var {
        const byApp = {};
        for (const window of Hyprland.toplevels.values) {
            const key = appOf(window);
            if (!key || !shown(window, scope, workspace)) continue;
            if (!byApp[key]) byApp[key] = [];
            byApp[key].push(window);
        }
        return Object.keys(byApp)
            .sort((a, b) => place("app:" + a) - place("app:" + b))
            .map(key => {
                const windows = byApp[key].sort((a, b) => place(a.address) - place(b.address));
                const entry = DesktopEntries.heuristicLookup(key);
                return {
                    key,
                    entry,
                    name: entry?.name || key,
                    icon: Quickshell.iconPath(entry?.icon ?? key, "application-x-executable"),
                    windows,
                    active: windows.some(w => focused(w)),
                    minimised: windows.every(w => minimised(w)),
                    urgent: windows.some(w => w.urgent)
                };
            });
    }

    // Restoring it if minimised, and leaving the pointer where it is
    // (minimise.lua).
    function focus(window: HyprlandToplevel): void {
        Quickshell.execDetached(["hyprctl", "eval", `hyprmonk_focus("address:0x${window.address}")`]);
    }

    // Through wlr-foreign-toplevel, which Hyprland raises as window.minimize.
    function minimise(window: HyprlandToplevel): void {
        if (minimised(window)) return;
        if (window.wayland) window.wayland.minimized = true;
        else Quickshell.execDetached(["hyprctl", "eval", `hyprmonk_minimise("address:0x${window.address}")`]);
    }

    function close(window: HyprlandToplevel): void {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${window.address}" })`);
    }

    // A click on an app, as on a Windows taskbar: its one focused window
    // minimises; with more, the next one comes; otherwise the one used last
    // (restored if minimised).
    function activate(group: var): void {
        const windows = group.windows;
        const at = windows.findIndex(w => focused(w));
        if (at >= 0 && windows.length === 1) minimise(windows[0]);
        else if (at >= 0) focus(windows[(at + 1) % windows.length]);
        else focus(windows.reduce((last, w) => (focusedAt[w.address] ?? 0) > (focusedAt[last.address] ?? 0) ? w : last));
    }

    // A new window of the app, as the launcher starts one.
    function open(group: var): void {
        const app = Apps.apps.find(a => a.entry === group.entry);
        if (app) Apps.launch(app, false);
    }

    Component.onCompleted: Hyprland.refreshToplevels()

    Connections {
        target: Hyprland

        function onActiveToplevelChanged(): void {
            const window = Hyprland.activeToplevel;
            if (window) root.focusedAt[window.address] = Date.now();
        }

        // Tags (where a minimised window came from) arrive only with a
        // refresh; a window moving workspace is when they change.
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "movewindowv2" || event.name === "openwindow") Hyprland.refreshToplevels();
        }
    }

    IpcHandler {
        target: "windows"

        // One line per app: its key, then each window as address:workspace,
        // with an m for minimised and a * for focused.
        function list(): string {
            return root.groups("all", -1).map(group => [group.key, ...group.windows.map(w =>
                `${w.address}:${w.workspace?.name}${root.minimised(w) ? "m" + root.origin(w) : ""}${root.focused(w) ? "*" : ""}`)].join("\t")).join("\n");
        }

        function activate(key: string): void {
            const group = root.groups("all", -1).find(g => g.key === key);
            if (group) root.activate(group);
        }
    }
}
