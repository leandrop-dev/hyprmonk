// The hardware panel, under the running cat when Settings > Bar > Look >
// Hardware is on Panel: each reading of services/Hardware.qml as a bar that
// fills as it changes. The processor (use, each core, temperature), the GPU
// when it can be read (use, temperature, video memory), memory and every
// disk, and the network, its speeds against the fastest seen while open.
// Read only while it is open.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: panel

    readonly property int hot: 85  // °C, the warning colour from here
    // The fastest seen while open, from 1 MB/s, so a trickle is not a full bar.
    property real fastest: 1048576

    spacing: 6

    Component.onCompleted: Hardware.watch()
    Component.onDestruction: Hardware.unwatch()

    Connections {
        target: Hardware

        function onDownChanged(): void {
            panel.fastest = Math.max(panel.fastest, Hardware.down || 0, Hardware.up || 0);
        }
    }

    function speed(bytes: real): string {
        return isNaN(bytes) ? "–" : Hardware.human(bytes) + "/s";
    }

    function percent(value: real): string {
        return isNaN(value) ? "–" : Math.round(value) + "%";
    }

    SectionLabel {
        text: I18n.tr("Processor")
    }

    ReadingBar {
        Layout.fillWidth: true
        icon: "\u{F0EE0}"
        label: I18n.tr("Use")
        value: panel.percent(Hardware.cpu)
        level: Hardware.cpu / 100
        warnAt: 0.9
    }

    // Each core, as thin upright bars.
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 22
        visible: Hardware.cores.length > 0
        spacing: 3

        Repeater {
            model: Hardware.cores.length

            Rectangle {
                id: core

                required property int index
                readonly property real use: Math.max(0, Math.min(100, Hardware.cores[index] ?? 0)) / 100

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 2
                color: Theme.fg(0.07)

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * core.use
                    radius: 2
                    color: Qt.alpha(core.use >= 0.9 ? Theme.warning : Theme.accent, 0.7)

                    Behavior on height {
                        NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    ReadingBar {
        Layout.fillWidth: true
        visible: !isNaN(Hardware.cpuTemp)
        icon: "\u{F050F}"
        label: I18n.tr("Temperature")
        value: Settings.degrees(Hardware.cpuTemp)
        level: Hardware.cpuTemp / 100
        warnAt: panel.hot / 100
    }

    SectionLabel {
        Layout.topMargin: 6
        visible: !isNaN(Hardware.gpuTemp)
        text: Hardware.gpuName || I18n.tr("Graphics")
    }

    ReadingBar {
        Layout.fillWidth: true
        visible: !isNaN(Hardware.gpuUse)
        icon: "\u{F08AE}"
        label: I18n.tr("Use")
        value: panel.percent(Hardware.gpuUse)
        level: Hardware.gpuUse / 100
        warnAt: 0.9
    }

    ReadingBar {
        Layout.fillWidth: true
        visible: !isNaN(Hardware.gpuTemp)
        icon: "\u{F050F}"
        label: I18n.tr("Temperature")
        value: Settings.degrees(Hardware.gpuTemp)
        level: Hardware.gpuTemp / 100
        warnAt: panel.hot / 100
    }

    ReadingBar {
        Layout.fillWidth: true
        visible: !isNaN(Hardware.vramTotal)
        icon: "\u{F035B}"
        label: I18n.tr("Video memory")
        value: Hardware.human(Hardware.vramUsed) + " / " + Hardware.human(Hardware.vramTotal)
        level: Hardware.vramUsed / Hardware.vramTotal
        warnAt: 0.9
    }

    SectionLabel {
        Layout.topMargin: 6
        text: I18n.tr("Memory and disks")
    }

    ReadingBar {
        Layout.fillWidth: true
        icon: "\u{F035B}"
        label: I18n.tr("Memory")
        value: Hardware.human(Hardware.memUsed) + " / " + Hardware.human(Hardware.memTotal)
        level: Hardware.memUsed / Hardware.memTotal
        warnAt: 0.9
    }

    Repeater {
        model: Hardware.disks

        ReadingBar {
            required property var modelData

            Layout.fillWidth: true
            icon: "\u{F02CA}"
            // A disk under /run/media or /mnt by its own name.
            label: modelData.mount === "/" ? "/" : modelData.mount.split("/").pop()
            value: Hardware.human(modelData.used) + " / " + Hardware.human(modelData.size)
            level: modelData.used / modelData.size
            warnAt: 0.9
        }
    }

    SectionLabel {
        Layout.topMargin: 6
        text: I18n.tr("Network")
    }

    ReadingBar {
        Layout.fillWidth: true
        icon: "\u{F01DA}"
        label: I18n.tr("Down")
        value: panel.speed(Hardware.down)
        level: Hardware.down / panel.fastest
    }

    ReadingBar {
        Layout.fillWidth: true
        icon: "\u{F0552}"
        label: I18n.tr("Up")
        value: panel.speed(Hardware.up)
        level: Hardware.up / panel.fastest
    }
}
