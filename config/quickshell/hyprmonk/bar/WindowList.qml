// The window list on the bar (Settings > Bar; hidden to begin with, as the
// dock shows the same): the open apps as the dock's buttons (dock/DockApp.qml),
// sized to the bar, with the same clicks and the same list of windows on
// hover, opening away from the bar's edge. Whose windows: as Settings > Dock
// picks.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.dock
import qs.services

RowLayout {
    id: list

    required property ShellScreen screen
    readonly property int workspace: Hyprland.monitorFor(screen)?.activeWorkspace?.id ?? -1
    readonly property var groups: Windows.groups(Settings.dockChoice("scope"), workspace)
    // The app whose window list is open.
    property Item listOwner: null

    visible: groups.length > 0
    spacing: 2

    Repeater {
        model: ScriptModel {
            values: list.groups.map(group => group.key)
        }

        DockApp {
            required property string modelData
            group: list.groups.find(g => g.key === modelData) ?? null
            size: Theme.barHeight - Theme.cardPadding * 2
            edge: Settings.barAtBottom ? Edges.Bottom : Edges.Top
            listOwner: list.listOwner
            onListWanted: who => list.listOwner = who
        }
    }
}
