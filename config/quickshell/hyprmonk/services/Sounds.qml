// Interface sounds, picked in Settings > Sounds: a click, a switch going on
// or off, a card opening or closing, a notification, and a device connecting
// or going. Each set is a folder in assets/sounds holding one WAV per kind
// (Qt's SoundEffect plays WAV, with little delay): hyprmonk's own, made by
// its make.sh, or serpantinum's. The notification tone can come from either.
//
// Quiet while turned off, in game mode and in do not disturb; a sound for
// something that shows anyway (an urgent notification) still plays then,
// unless sounds are off.
//
// IPC: qs -c hyprmonk ipc call sounds play <kind>
//      qs -c hyprmonk ipc call sounds set <on|set|tone|volume> <value>
pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property list<string> kinds: ["click", "on", "off", "open", "close", "notify", "connect", "disconnect"]
    readonly property bool on: Settings.soundChoice("on")
    readonly property string set: Settings.soundChoice("set")
    readonly property string tone: Settings.soundChoice("tone")
    readonly property bool quiet: !on || GameMode.on || Notifications.doNotDisturb
    // The slider's percent, squared, so its middle sounds about half as loud.
    readonly property real volume: Math.pow(Settings.soundVolume / 100, 2)

    function file(kind: string): url {
        if (kind === "notify" && tone === "chime") return Qt.resolvedUrl("../assets/sounds/hyprmonk/notify.wav");
        if (kind === "notify" && tone !== "set") return Qt.resolvedUrl(`../assets/sounds/serpantinum/tones/${tone}.wav`);
        return Qt.resolvedUrl(`../assets/sounds/${set}/${kind}.wav`);
    }

    // `always` for something shown whatever the mode: plays unless sounds
    // are off.
    function play(kind: string, always: bool): void {
        if (!on || (quiet && !always)) return;
        effects.objectAt(kinds.indexOf(kind))?.play();
    }

    // For Settings > Sounds: plays even while they are off.
    function preview(kind: string): void {
        effects.objectAt(kinds.indexOf(kind))?.play();
    }

    // What the shell does on its own is heard from here; clicks from the
    // widgets (Button, Chip, OptionRow) and quick actions, and notifications
    // from services/Notifications.qml.
    // Cards (launcher, quick actions, Settings...) and bar panels: opening
    // one plays "open", even over another; closing the last plays "close".
    Connections {
        target: Overlays

        function onOpenChanged(): void {
            root.play(Overlays.open !== "" ? "open" : "close", false);
        }
    }

    Connections {
        target: Panels

        function onOpenChanged(): void {
            root.play(Panels.open !== "" ? "open" : "close", false);
        }
    }

    // Devices: going online or off, and a Bluetooth device coming or going.
    // Not while the shell starts, as they are first found.
    property bool listening: false
    readonly property bool online: Net.online
    readonly property int bluetooth: Bluez.connected.length
    property int bluetoothBefore: 0

    onOnlineChanged: if (listening) play(online ? "connect" : "disconnect", false)
    onBluetoothChanged: {
        if (listening && bluetooth !== bluetoothBefore) play(bluetooth > bluetoothBefore ? "connect" : "disconnect", false);
        bluetoothBefore = bluetooth;
    }

    Timer {
        running: true
        interval: 3000
        onTriggered: {
            root.bluetoothBefore = root.bluetooth;
            root.listening = true;
        }
    }

    Instantiator {
        id: effects

        model: root.kinds

        SoundEffect {
            required property string modelData

            source: root.file(modelData)
            volume: root.volume
        }
    }

    IpcHandler {
        target: "sounds"

        function play(kind: string): void {
            root.preview(kind);
        }

        function set(key: string, value: string): void {
            if (key === "volume") Settings.setSoundVolume(Number(value));
            else Settings.setSoundChoice(key, value === "true" ? true : value === "false" ? false : value);
        }
    }
}
