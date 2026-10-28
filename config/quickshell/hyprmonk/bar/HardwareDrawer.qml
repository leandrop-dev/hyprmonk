// The left card's hardware drawer: the CPU temperature stays; a click on it
// slides out CPU use, memory in use, used disk space on / and network speed
// (services/Hardware.qml, read only while open); another click folds them.
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

    Temperature {
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

            Module {
                icon: "\u{F0EE0}"
                label: isNaN(Hardware.cpu) ? "–" : String(Math.round(Hardware.cpu)).padStart(2) + "%"
            }

            Module {
                icon: "\u{F035B}"
                label: Hardware.human(Hardware.memUsed)
            }

            Module {
                icon: "\u{F02CA}"
                label: Hardware.human(Hardware.diskUsed)
            }

            Module {
                icon: "\u{F06F3}"
                label: isNaN(Hardware.down) ? "–"
                    : Hardware.human(Hardware.down).padStart(4) + "↓ " + Hardware.human(Hardware.up).padStart(4) + "↑"
            }
        }
    }
}
