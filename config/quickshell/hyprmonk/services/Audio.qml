// The default output and input (Pipewire), for the bar and the OSD.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string sinkName: sink ? (sink.nickname || sink.description || sink.name) : ""
    readonly property string volumeIcon: {
        if (muted || volume === 0) return "\u{F075F}";
        if (volume < 0.34) return "\u{F057F}";
        if (volume < 0.67) return "\u{F0580}";
        return "\u{F057E}";
    }

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property string micIcon: micMuted ? "\u{F036D}" : "\u{F036C}"

    function setVolume(value: real): void {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    // Pipewire only fills in a node's audio properties while it is tracked.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
