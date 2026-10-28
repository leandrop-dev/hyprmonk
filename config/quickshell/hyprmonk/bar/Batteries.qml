// Peripheral batteries: whatever UPower reports (the headset), plus what
// `hyprmonk battery` reads from devices UPower cannot see (the mouse).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs

RowLayout {
    id: root

    // The mouse sleeps between uses and its receiver answers nothing then,
    // so a reading is kept until a newer one arrives.
    property var hidDevices: []

    spacing: 2

    Repeater {
        model: UPower.devices.values.filter(d => !d.powerSupply && d.isPresent !== false && d.model !== "")

        Module {
            required property UPowerDevice modelData
            icon: "\u{F02CB}"
            label: Math.round(modelData.percentage * 100) + "%"
            color: modelData.percentage <= 0.15 ? Theme.warning : Theme.foreground
        }
    }

    Repeater {
        model: root.hidDevices.filter(d => d.percent !== null)

        Module {
            required property var modelData
            icon: modelData.charging ? "\u{F0084}" : "\u{F037D}"
            label: modelData.percent + "%"
            color: modelData.percent <= 15 && !modelData.charging ? Theme.warning : Theme.foreground
        }
    }

    Process {
        id: hyprmonk
        command: [Quickshell.env("HOME") + "/.local/bin/hyprmonk", "battery", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const fresh = JSON.parse(text);
                    // Keep the last known level of a device that is asleep now.
                    root.hidDevices = fresh.map(d => d.percent !== null ? d
                        : (root.hidDevices.find(old => old.name === d.name) ?? d));
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: true
        onTriggered: hyprmonk.running = true
    }
}
