// The left card's hardware drawer: the running cat stays; a click on it
// slides out the CPU temperature, CPU use, memory in use, used disk space on
// / and network speed (services/Hardware.qml, read only while open); another
// click folds them. Hovering one shows its details, in fixed-width columns.
import QtQuick
import QtQuick.Layouts
import qs.services

RowLayout {
    id: drawer

    property bool open: false
    property real reveal: open ? 1 : 0

    spacing: 2

    onOpenChanged: open ? Hardware.watch() : Hardware.unwatch()
    Component.onCompleted: if (open) Hardware.watch()
    Component.onDestruction: if (open) Hardware.unwatch()

    Behavior on reveal {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Runcat {
        interactive: true
        active: drawer.open
        onClicked: button => { if (button === Qt.LeftButton) drawer.open = !drawer.open; }
    }

    Item {
        visible: drawer.reveal > 0
        clip: true
        implicitWidth: modules.implicitWidth * drawer.reveal
        implicitHeight: modules.implicitHeight

        RowLayout {
            id: modules

            spacing: 2
            opacity: Math.max(0, (drawer.reveal - 0.4) / 0.6)

            Temperature {}

            // Every core's use, four to a row.
            Module {
                icon: "\u{F0EE0}"
                label: isNaN(Hardware.cpu) ? "–" : String(Math.round(Hardware.cpu)).padStart(2) + "%"
                tooltip: {
                    if (isNaN(Hardware.cpu)) return "";
                    const rows = [];
                    for (let i = 0; i < Hardware.cores.length; i += 4)
                        rows.push(Hardware.cores.slice(i, i + 4)
                            .map((use, j) => String(i + j).padStart(2) + (Math.round(use) + "%").padStart(5))
                            .join("   "));
                    return "CPU " + Math.round(Hardware.cpu) + "%\n" + rows.join("\n");
                }
            }

            // The apps using the most, each with everything it started.
            Module {
                icon: "\u{F035B}"
                label: Hardware.human(Hardware.memUsed)
                tooltip: "Memory " + Hardware.human(Hardware.memUsed) + " / " + Hardware.human(Hardware.memTotal)
                    + Hardware.apps.map(app => "\n" + app.name.slice(0, 16).padEnd(17) + Hardware.human(app.bytes).padStart(6)).join("")

                onTooltipShownChanged: tooltipShown ? Hardware.watchApps() : Hardware.unwatchApps()
                Component.onDestruction: if (tooltipShown) Hardware.unwatchApps()
            }

            // Every disk: used, size and how full.
            Module {
                icon: "\u{F02CA}"
                label: Hardware.human(Hardware.diskUsed)
                tooltip: "Disks" + Hardware.disks.map(disk => "\n" + disk.mount.padEnd(8)
                    + Hardware.human(disk.used).padStart(6) + " / " + Hardware.human(disk.size).padStart(5)
                    + (Math.round(100 * disk.used / disk.size) + "%").padStart(5)).join("")
            }

            Module {
                icon: "\u{F06F3}"
                label: isNaN(Hardware.down) ? "–"
                    : Hardware.human(Hardware.down).padStart(4) + "↓ " + Hardware.human(Hardware.up).padStart(4) + "↑"
            }
        }
    }
}
