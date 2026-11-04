// The dock on one screen: the open apps (services/Windows.qml) on a card
// like the bar's, centred on the bottom edge, keeping its height clear of
// windows. Hidden while no app is open. Blurred by Hyprland like every
// hyprmonk-* layer (rules.lua).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: dock

    readonly property int size: 44
    readonly property int workspace: Hyprland.monitorFor(screen)?.activeWorkspace?.id ?? -1
    readonly property var groups: Windows.groups("all", workspace)
    // The app whose window list is open (DockApp.qml).
    property Item listOwner: null

    visible: groups.length > 0
    anchors.bottom: true
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight + Theme.barGap * 2
    exclusiveZone: implicitHeight
    color: "transparent"

    WlrLayershell.namespace: "hyprmonk-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: card

        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.barGap
        implicitWidth: row.implicitWidth + Theme.cardPadding * 2
        implicitHeight: dock.size + Theme.cardPadding * 2
        radius: Theme.cardRadius
        color: Theme.card
        border.width: 1
        border.color: Theme.rim

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 2

            // Keys only, so an app's button stays (hover and all) while its
            // windows change.
            Repeater {
                model: ScriptModel {
                    values: dock.groups.map(group => group.key)
                }

                DockApp {
                    required property string modelData
                    group: dock.groups.find(g => g.key === modelData) ?? null
                    size: dock.size
                    listOwner: dock.listOwner
                    onListWanted: who => dock.listOwner = who
                }
            }
        }
    }
}
