// The workspaces on this bar's monitor, in the style picked in Settings > Bar:
// - pills: slim pills without numbers, the active one wider and in the accent;
// - numbers: their numbers, the active one in the accent;
// - dots: a dot each, the active one larger and in the accent;
// - chomper: a dot each, and a round mouth in the accent sitting on the
//   active one, which goes straight to the next, chomping on the way.
// A click switches to one. With a count picked in Settings > Bar, 1 to that
// many always show: one not open yet is empty (dimmer), unless it is open on
// another monitor.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services

Item {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: sample === null ? Hyprland.monitorFor(screen) : null
    readonly property int count: Settings.barChoice("workspaces")
    property string style: Settings.barChoice("workspaceStyle")
    // For a preview (Settings > Bar): made-up workspaces to show instead,
    // which stay the same objects, and the id of the active one.
    property var sample: null
    property int sampleActive: 1

    // The empty ones' stand-ins, made once each so their slots keep them.
    property var spare: ({})
    function spareFor(id: int): var {
        if (!spare[id]) spare[id] = { id, name: String(id), active: false, urgent: false, empty: true };
        return spare[id];
    }

    readonly property var shown: {
        if (root.sample !== null) return root.sample;
        const open = Hyprland.workspaces.values.filter(ws => ws.id > 0);
        const here = open.filter(ws => ws.monitor === root.monitor);
        const list = here.slice();
        for (let id = 1; id <= root.count; id++)
            if (!open.some(ws => ws.id === id)) list.push(root.spareFor(id));
        return list.sort((a, b) => a.id - b.id);
    }
    readonly property int activeIndex: shown.findIndex(ws => root.isActive(ws))

    function isActive(ws: var): bool {
        return sample !== null ? ws.id === sampleActive : ws.active;
    }

    implicitWidth: slots.implicitWidth + 12
    implicitHeight: Theme.barHeight - Theme.cardPadding * 2

    Row {
        id: slots

        anchors.centerIn: parent
        spacing: root.style === "pills" ? 5 : root.style === "numbers" ? 2 : 4

        Repeater {
            id: repeater

            // ScriptModel keeps the slots that stay, and their animations,
            // when a workspace comes or goes.
            model: ScriptModel {
                values: root.shown
            }

            Item {
                id: slot

                required property var modelData
                readonly property bool active: root.isActive(modelData)
                readonly property bool empty: modelData.empty === true
                readonly property bool urgent: modelData.urgent
                readonly property bool hovered: mouse.containsMouse

                width: root.style === "pills" ? (active ? 30 : 16)
                     : root.style === "numbers" ? Math.max(16, number.implicitWidth + 8)
                     : root.style === "dots" ? (active ? 14 : 8)
                     : 12
                height: 18

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                // Pills.
                Rectangle {
                    anchors.fill: parent
                    visible: root.style === "pills"
                    radius: height / 2
                    color: slot.active ? Qt.alpha(Theme.accent, 0.55)
                         : Theme.fg(slot.empty ? (slot.hovered ? 0.12 : 0.04) : (slot.hovered ? 0.24 : 0.16))
                    border.width: 1
                    border.color: slot.active ? Qt.alpha(Theme.accent, 0.8) : Theme.fg(slot.empty ? 0.14 : 0.22)
                }

                BarText {
                    id: number

                    anchors.centerIn: parent
                    visible: root.style === "numbers"
                    text: slot.modelData.name
                    font.pixelSize: Theme.fontSize
                    font.bold: slot.active
                    color: slot.urgent ? Theme.warning : slot.active ? Theme.accent : Theme.foreground
                    opacity: slot.active ? 1 : (slot.empty ? 0.3 : 0.6) + (slot.hovered ? 0.25 : 0)
                }

                // A dot: the style itself, or the chomper's trail.
                Rectangle {
                    anchors.centerIn: parent
                    visible: root.style === "dots" || (root.style === "chomper" && !slot.active)
                    width: root.style === "chomper" ? 5 : slot.active ? 12 : 8
                    height: width
                    radius: width / 2
                    color: slot.urgent ? Theme.warning
                         : slot.active ? Theme.accent
                         : slot.empty ? "transparent" : Theme.fg(slot.hovered ? 0.7 : 0.45)
                    border.width: slot.empty && !slot.urgent ? 1 : 0
                    border.color: Theme.fg(slot.hovered ? 0.5 : 0.3)
                    Behavior on width {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: root.sample === null
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // The config is Lua, so dispatches are Lua too.
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${slot.modelData.id} })`)
                }
            }
        }
    }

    // The chomper: a disc with a mouth, facing where it goes, which opens and
    // shuts as it travels.
    Item {
        id: chomper

        // Its place in the row, from the active one's index: the slots are all
        // as wide in this style, and an index stays put while a workspace is
        // made, where the new slot's x would read 0 for a moment. While no
        // workspace here is active (one being made), it stays where it was.
        property int place: 0
        property real offset: place * (12 + slots.spacing) + 6 - width / 2
        readonly property bool travelling: travel.running
        property bool facingLeft: false
        property real mouth: 40

        Connections {
            target: root

            function onActiveIndexChanged(): void {
                if (root.activeIndex < 0 || root.activeIndex === chomper.place) return;
                chomper.facingLeft = root.activeIndex < chomper.place;
                chomper.place = root.activeIndex;
            }
        }

        Component.onCompleted: place = Math.max(0, root.activeIndex)

        visible: root.style === "chomper" && repeater.count > 0
        width: 14
        height: 14
        anchors.verticalCenter: parent.verticalCenter
        x: slots.x + offset

        Behavior on offset {
            enabled: chomper.visible

            NumberAnimation {
                id: travel
                duration: 300
                easing.type: Easing.InOutQuad
            }
        }

        SequentialAnimation on mouth {
            running: chomper.travelling
            loops: Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation { to: 5; duration: 90 }
            NumberAnimation { to: 55; duration: 90 }
        }

        transform: Scale {
            origin.x: chomper.width / 2
            xScale: chomper.facingLeft ? -1 : 1
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.accent
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 7
                startY: 7

                PathAngleArc {
                    centerX: 7
                    centerY: 7
                    radiusX: 7
                    radiusY: 7
                    startAngle: chomper.mouth / 2
                    sweepAngle: 360 - chomper.mouth
                    moveToStart: false
                }

                PathLine {
                    x: 7
                    y: 7
                }
            }
        }
    }
}
