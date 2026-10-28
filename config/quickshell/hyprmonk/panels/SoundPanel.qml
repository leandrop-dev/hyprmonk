// The sound panel, under the bar's volume ("output") or microphone ("input")
// module: the device in use and its level, the devices to switch to, each
// app's own level, and the mixer.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: panel

    property string kind: "output"
    readonly property bool output: kind === "output"
    readonly property PwNode device: output ? Audio.sink : Audio.source
    readonly property var devices: output ? Audio.sinks : Audio.sources
    readonly property var apps: output ? Audio.playing : Audio.recording

    spacing: 10

    // Levels and properties (an app's name, a device's kind) are only known
    // while a node is tracked: while this is open.
    PwObjectTracker {
        objects: [...panel.devices, ...panel.apps]
    }

    SectionLabel {
        text: panel.output ? "Output" : "Microphone"
    }

    LevelRow {
        Layout.fillWidth: true
        visible: panel.device !== null
        icon: panel.output ? Audio.volumeIcon : Audio.micIcon
        name: Audio.nameOf(panel.device)
        value: panel.device?.audio?.volume ?? 0
        muted: panel.device?.audio?.muted ?? false
        onMoved: value => panel.device.audio.volume = value
        onMuteToggled: panel.device.audio.muted = !panel.device.audio.muted
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: ScriptModel {
                values: panel.devices
            }

            OptionRow {
                required property PwNode modelData

                Layout.fillWidth: true
                icon: Audio.deviceIcon(modelData)
                text: Audio.nameOf(modelData)
                selected: modelData === panel.device
                onClicked: Audio.setDefault(modelData)
            }
        }
    }

    SectionLabel {
        Layout.topMargin: 6
        visible: panel.apps.length > 0
        text: panel.output ? "Apps" : "Recording"
    }

    Repeater {
        model: ScriptModel {
            values: panel.apps
        }

        LevelRow {
            required property PwNode modelData

            Layout.fillWidth: true
            icon: panel.output ? "\u{F075A}" : "\u{F036C}"
            iconSource: Audio.appIcon(modelData)
            name: Audio.nameOf(modelData)
            value: modelData.audio?.volume ?? 0
            muted: modelData.audio?.muted ?? false
            onMoved: value => modelData.audio.volume = value
            onMuteToggled: modelData.audio.muted = !modelData.audio.muted
        }
    }

    // Under the output, the microphone's level too.
    SectionLabel {
        Layout.topMargin: 6
        visible: panel.output && Audio.source !== null
        text: "Microphone"
    }

    LevelRow {
        Layout.fillWidth: true
        visible: panel.output && Audio.source !== null
        icon: Audio.micIcon
        name: Audio.nameOf(Audio.source)
        value: Audio.micVolume
        muted: Audio.micMuted
        onMoved: value => Audio.source.audio.volume = value
        onMuteToggled: Audio.source.audio.muted = !Audio.micMuted
    }

    Button {
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: "\u{F05B2}  Mixer"
        onClicked: {
            // pavucontrol's tabs: 3 output devices, 4 input devices.
            Quickshell.execDetached(["pavucontrol", "-t", panel.output ? "3" : "4"]);
            Panels.close();
        }
    }
}
