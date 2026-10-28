// Sound through Pipewire, for the bar, its sound panel and the OSD: the
// default output and input, the devices to pick from, and the apps playing
// or recording.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string sinkName: nameOf(sink)
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

    // Devices and apps, by name. A node's `properties` stay empty until it is
    // tracked; its type is known at once.
    readonly property var sinks: byType(PwNodeType.AudioSink)
    readonly property var sources: byType(PwNodeType.AudioSource)
    readonly property var playing: byType(PwNodeType.AudioOutStream)
    readonly property var recording: byType(PwNodeType.AudioInStream)

    function byType(type: int): var {
        return Pipewire.nodes.values
            .filter(n => n.type === type)
            .sort((a, b) => nameOf(a).localeCompare(nameOf(b)));
    }

    function nameOf(node: PwNode): string {
        if (!node) return "";
        if (node.isStream) return node.properties?.["application.name"] || node.description || node.name;
        return node.nickname || node.description || node.name;
    }

    // A glyph for what the device is.
    function deviceIcon(node: PwNode): string {
        const props = node?.properties ?? {};
        if (props["device.api"] === "bluez5") return "\u{F00AF}";
        switch (props["device.form-factor"]) {
        case "headset": return "\u{F02CE}";
        case "headphone": return "\u{F02CB}";
        case "microphone": return "\u{F036C}";
        case "webcam": return "\u{F0567}";
        }
        if (/HDMI|DisplayPort/.test(node?.description ?? "")) return "\u{F0379}";
        return node?.isSink ? "\u{F04C3}" : "\u{F036C}";
    }

    // An app's own icon, when it names one or has a desktop entry.
    function appIcon(node: PwNode): string {
        const props = node?.properties ?? {};
        const name = props["application.icon-name"]
            || DesktopEntries.heuristicLookup(props["application.name"] ?? "")?.icon
            || "";
        return name ? Quickshell.iconPath(name, true) : "";
    }

    function setVolume(value: real): void {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    function setDefault(node: PwNode): void {
        if (node.isSink) Pipewire.preferredDefaultAudioSink = node;
        else Pipewire.preferredDefaultAudioSource = node;
    }

    // Pipewire only fills in a node's audio properties while it is tracked.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
