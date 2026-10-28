// The default input: click to mute or unmute; red while muted.
import QtQuick
import Quickshell.Services.Pipewire
import qs

Module {
    id: root

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: source?.audio?.muted ?? false

    visible: source !== null
    interactive: true
    icon: muted ? "\u{F036D}" : "\u{F036C}"
    color: muted ? Theme.warning : Theme.foreground

    PwObjectTracker {
        objects: [root.source]
    }

    onClicked: root.source.audio.muted = !root.muted
}
