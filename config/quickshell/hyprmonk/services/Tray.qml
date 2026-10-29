// The system tray: apps' status icons (StatusNotifierItem; the shell is the
// watcher they register with), shown in the bar, and the menu panel of the
// one picked. `path` is the submenus opened inside that menu, deepest last.
//
// IPC: qs -c hyprmonk ipc call tray list
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    // Passive ones (nothing to report) stay hidden.
    readonly property var items: SystemTray.items.values.filter(item => item.status !== Status.Passive)

    property SystemTrayItem item: null
    property var path: []
    readonly property bool menuOpen: Panels.open === "tray" && item !== null

    // A right click: its menu, or closed again if it was the one open.
    function toggleMenu(target: SystemTrayItem): void {
        if (menuOpen && item === target) {
            Panels.close();
            return;
        }
        item = target;
        path = [];
        if (Panels.open !== "tray") Panels.toggle("tray");
    }

    function enter(entry: var): void { path = [...path, entry]; }
    function back(): void { path = path.slice(0, -1); }

    // Entries the app removed read no properties once gone: the path stops
    // before the first of them.
    function prune(): void {
        const gone = path.findIndex(entry => entry.objectName === undefined);
        if (gone >= 0) path = path.slice(0, gone);
    }

    // The app quit with its menu open.
    onItemChanged: if (!item && Panels.open === "tray") Panels.close()

    Connections {
        target: Panels

        function onOpenChanged(): void {
            if (Panels.open !== "tray") root.path = [];
        }
    }

    // Some apps give their icon as "name?path=/dir" (an icon of their own,
    // outside the theme): the file in that folder.
    function iconSource(item: SystemTrayItem): string {
        const icon = item?.icon ?? "";
        const query = icon.indexOf("?path=");
        if (query < 0) return icon;
        const name = icon.slice(0, query);
        return "file://" + icon.slice(query + 6) + "/" + name.slice(name.lastIndexOf("/") + 1);
    }

    // In place of an app's icon that could not be drawn: its desktop entry's,
    // or the theme's generic one.
    function standIn(item: SystemTrayItem): string {
        const entry = DesktopEntries.heuristicLookup(item?.id ?? "") ?? DesktopEntries.heuristicLookup(nameOf(item));
        return Quickshell.iconPath(entry?.icon ?? "", "application-x-executable");
    }

    function nameOf(item: SystemTrayItem): string {
        return item?.tooltipTitle || item?.title || item?.id || "";
    }

    IpcHandler {
        target: "tray"

        function list(): string {
            return SystemTray.items.values.map(item => [item.id, item.title, ["passive", "active", "attention"][item.status], item.icon].join("\t")).join("\n");
        }
    }
}
