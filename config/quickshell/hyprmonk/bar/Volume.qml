// The default output's volume: scroll to change it, click to mute.
import QtQuick
import Quickshell.Services.Pipewire
import qs

Module {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    visible: sink !== null
    interactive: true
    icon: {
        if (muted || volume === 0) return "\u{F075F}";
        if (volume < 0.34) return "\u{F057F}";
        if (volume < 0.67) return "\u{F0580}";
        return "\u{F057E}";
    }
    label: Math.round(volume * 100) + "%"
    dim: muted

    // Pipewire only fills in a node's audio properties while it is tracked.
    PwObjectTracker {
        objects: [root.sink]
    }

    onClicked: root.sink.audio.muted = !root.muted
    onScrolled: steps => root.sink.audio.volume = Math.max(0, Math.min(1, root.volume + steps * 0.05))
}
