// The left card's hardware drawer: the running cat stays; a click on it
// slides out the CPU temperature and use, the GPU, memory and disk space on
// / as used/total, and network speed (services/Hardware.qml, read only while open); another
// click folds them. Hovering one shows its details, in fixed-width columns.
// With Settings > Bar > Look > Hardware on Panel, the cat opens
// panels/HardwarePanel.qml instead.
import QtQuick
import QtQuick.Layouts
import qs
import qs.widgets
import qs.services

RowLayout {
    id: drawer

    property bool open: false
    // Settings > Bar: the cat opens a panel of bars instead.
    readonly property bool asPanel: Settings.barChoice("hardware") === "panel"
    property real room: Infinity
    property real reveal: open ? 1 : 0

    spacing: 2

    onOpenChanged: open ? Hardware.watch() : Hardware.unwatch()
    onAsPanelChanged: if (asPanel) open = false
    Component.onCompleted: if (open) Hardware.watch()
    Component.onDestruction: if (open) Hardware.unwatch()

    Behavior on reveal {
        CardAnimation {}
    }

    Runcat {
        id: cat
        interactive: true
        active: drawer.asPanel ? Panels.open === "hardware" : drawer.open
        onClicked: button => {
            if (button !== Qt.LeftButton) return;
            if (drawer.asPanel) Panels.toggle("hardware");
            else drawer.open = !drawer.open;
        }
    }

    Item {
        visible: drawer.reveal > 0
        clip: true
        implicitWidth: Math.max(0, Math.min(modules.implicitWidth * drawer.reveal, drawer.room - cat.implicitWidth - drawer.spacing))
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
                    return I18n.tr("CPU %1%", Math.round(Hardware.cpu)) + "\n" + rows.join("\n");
                }
            }

            // The GPU: temperature and video memory. Hidden when it cannot be read.
            Module {
                readonly property int hot: 85

                visible: !isNaN(Hardware.gpuTemp)
                icon: "\u{F08AE}"
                label: Settings.degrees(Hardware.gpuTemp) + " " + Hardware.used(Hardware.vramUsed, Hardware.vramTotal)
                tooltip: Hardware.gpuName + "\n" + I18n.tr("Use %1%", Math.round(Hardware.gpuUse))
                    + "\nVideo memory " + Hardware.human(Hardware.vramUsed) + " / " + Hardware.human(Hardware.vramTotal)
                color: Hardware.gpuTemp >= hot ? Theme.warning : Theme.foreground
            }

            // The apps using the most, each with everything it started.
            Module {
                icon: "\u{F035B}"
                label: Hardware.used(Hardware.memUsed, Hardware.memTotal)
                tooltip: I18n.tr("Memory %1 / %2", Hardware.human(Hardware.memUsed), Hardware.human(Hardware.memTotal))
                    + Hardware.apps.map(app => "\n" + app.name.slice(0, 16).padEnd(17) + Hardware.human(app.bytes).padStart(6)).join("")

                onTooltipShownChanged: tooltipShown ? Hardware.watchApps() : Hardware.unwatchApps()
                Component.onDestruction: if (tooltipShown) Hardware.unwatchApps()
            }

            // Every disk: used, size and how full.
            Module {
                icon: "\u{F02CA}"
                label: Hardware.used(Hardware.diskUsed, Hardware.diskSize)
                tooltip: I18n.tr("Disks") + Hardware.disks.map(disk => "\n" + disk.mount.padEnd(8)
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
