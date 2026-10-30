// Bluetooth state for the bar and the Bluetooth panel, from Quickshell's
// Bluetooth (BlueZ). Only while `scanning` is set (the panel sets it while it
// is open) does this machine look for devices and let them find it.
//
// Nothing here is a pairing agent (Quickshell has none), so a device that
// asks for a code or a confirmation cannot pair: `pairFailed` says so, and
// bluetoothctl, which is an agent, does it.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    property bool scanning: false

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

    function pair(device: BluetoothDevice): void {
        pairFailed = "";
        pairing = device;
        device.pair();
    }

    // BlueZ's own names, as device.icon gives them.
    function deviceIcon(device: BluetoothDevice): string {
        const name = device.icon;
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
        value: root.scanning && root.on
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
            device.trusted = true;
            device.connect();
        }

        function onPairingChanged(): void {
            if (!root.pairing.pairing) settle.restart();
        }
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
