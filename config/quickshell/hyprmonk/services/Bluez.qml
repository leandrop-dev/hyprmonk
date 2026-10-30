// Bluetooth state for the bar and the Bluetooth panel, from Quickshell's
// Bluetooth (BlueZ). Only while `scanning` is set (the panel sets it while it
// is open) does this machine let devices find it. It looks for them only for a
// moment, as it opens and on search(): a phone pairing from its own side never
// got through while the adapter searched, and was at once when it did not.
//
// Quickshell has no pairing agent, so `hyprmonk bluetooth-agent` is one: it
// passes on what BlueZ asks as `request`, for the Bluetooth panel to show, and
// answer() replies. Started again if it stops (BlueZ restarting).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Singleton {
    id: root

    property bool scanning: false
    property bool searching: false

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var devices: adapter?.devices.values ?? []
    readonly property var connected: devices.filter(d => d.connected)

    // Connected ones first.
    readonly property var paired: devices.filter(d => d.paired).sort((a, b) =>
        (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Without a name a device is only its address (BlueZ writes it with
    // dashes), which helps nobody pick it.
    readonly property var available: devices.filter(d => !d.paired && d.name.replace(/-/g, ":") !== d.address)
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property string icon: !on ? "\u{F00B2}" : connected.length > 0 ? "\u{F00B1}" : "\u{F00AF}"

    // What the bar's tooltip says: the first line is its title.
    readonly property string summary: {
        if (!on) return "Bluetooth off";
        if (connected.length === 0) return "Bluetooth\nNothing connected";
        return "Bluetooth\n" + connected.map(d => d.name + (d.batteryAvailable ? "  " + Math.round(d.battery * 100) + "%" : "")).join("\n");
    }

    property BluetoothDevice pairing: null  // the device being paired
    property string pairFailed: ""          // the address of the last that failed

    onScanningChanged: {
        if (scanning) search();
        else searching = false;
    }
    onOnChanged: if (on && scanning) search()

    function search(): void {
        searching = true;
        searchEnd.restart();
    }

    function pair(device: BluetoothDevice): void {
        pairFailed = "";
        pairing = device;
        device.pair();
    }

    // What the agent is asking, or null: its `kind`, its `code` if it has one,
    // and the `device` and `name` it is about. "confirmation" and
    // "authorization" take a yes or no, "passkey" and "pin" a typed code;
    // "show-passkey" and "show-pin" are a code to type on the device, with no
    // reply. It ends with an answer, BlueZ cancelling, or the panel closing.
    property var request: null
    property bool agentAlive: true  // false for a moment after it stops

    function received(message: var): void {
        if (message.kind === "cancel") {
            request = null;
            return;
        }
        const device = devices.find(d => d.dbusPath === message.device) ?? null;
        // A device already paired using something of ours; that needs no
        // question, and one that is not paired has no business asking.
        if (message.kind === "service") {
            reply(message.id, device?.paired ?? false, "");
            return;
        }
        request = Object.assign(message, { device, name: device?.name ?? "this device" });
        if (Panels.open !== "bluetooth") Panels.toggle("bluetooth");
    }

    function answer(accepted: bool, value: string): void {
        if (!request) return;
        const asked = request;
        request = null;
        if (asked.id === undefined) return;
        // Paired from the device's side: it gets trusted as when paired from here.
        if (accepted && asked.device && !asked.device.paired) pairing = asked.device;
        reply(asked.id, accepted, value);
    }

    function reply(id: int, accepted: bool, value: string): void {
        agent.write(JSON.stringify({ id, accepted, value }) + "\n");
    }

    // BlueZ's own names, as device.icon gives them.
    function deviceIcon(device: BluetoothDevice): string {
        const name = device?.icon ?? "";
        if (name.includes("headset") || name.includes("headphone")) return "\u{F02CB}";
        if (name.includes("audio")) return "\u{F04C3}";
        if (name.includes("mouse")) return "\u{F037D}";
        if (name.includes("keyboard")) return "\u{F030C}";
        if (name.includes("gaming")) return "\u{F0297}";
        if (name.includes("phone")) return "\u{F011C}";
        if (name.includes("computer")) return "\u{F0379}";
        return "\u{F00AF}";
    }

    Binding {
        target: root.adapter
        property: "discovering"
        value: root.searching && root.on
        when: root.adapter !== null
    }

    Binding {
        target: root.adapter
        property: "discoverable"
        value: root.scanning && root.on
        when: root.adapter !== null
    }

    Binding {
        target: root.adapter
        property: "pairable"
        value: root.scanning && root.on
        when: root.adapter !== null
    }

    // A paired device connects now and by itself from then on. Whether a pair
    // failed is only known by `paired` not following: BlueZ's error stays in
    // Quickshell's log, and `paired` may land just after `pairing` ends.
    Connections {
        target: root.pairing

        function onPairedChanged(): void {
            const device = root.pairing;
            if (!device.paired) return;
            root.pairing = null;
            root.request = null;
            device.trusted = true;
            if (!device.connected) device.connect();
        }

        function onPairingChanged(): void {
            if (!root.pairing.pairing) settle.restart();
        }
    }

    Process {
        id: agent

        running: root.adapter !== null && root.agentAlive
        command: [Quickshell.env("HOME") + "/.local/bin/hyprmonk", "bluetooth-agent"]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.received(JSON.parse(line))
        }
        onExited: {
            root.request = null;
            root.agentAlive = false;
            retry.restart();
        }
    }

    // One round of BlueZ's search takes about 10 seconds.
    Timer {
        id: searchEnd

        interval: 12000
        onTriggered: root.searching = false
    }

    Timer {
        id: retry

        interval: 5000
        onTriggered: root.agentAlive = true
    }

    Timer {
        id: settle

        interval: 500
        onTriggered: {
            if (root.pairing && !root.pairing.paired) root.pairFailed = root.pairing.address;
            root.pairing = null;
        }
    }
}
