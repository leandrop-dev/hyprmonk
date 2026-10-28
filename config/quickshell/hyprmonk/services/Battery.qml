// Peripheral batteries, for the bar and its battery panel: whatever UPower
// reports (the headset), plus what `hyprmonk battery` reads from devices UPower
// cannot see (the mouse). Each device has a name, icon, percent (0-100) and
// whether it is charging.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    // At or under this, a battery not charging shows in the warning colour.
    readonly property int lowPercent: 15

    readonly property var devices: [...fromUPower, ...hidDevices.filter(d => d.percent !== null)]

    readonly property var fromUPower: UPower.devices.values
        .filter(d => !d.powerSupply && d.isPresent !== false && d.model !== "")
        .map(d => ({
            name: d.model,
            icon: iconFor(d.type),
            percent: Math.round(d.percentage * 100),
            charging: d.state === UPowerDeviceState.Charging
        }))

    // The mouse sleeps between uses and its receiver answers nothing then,
    // so a reading is kept until a newer one arrives.
    property var hidDevices: []

    function iconFor(type: int): string {
        switch (type) {
        case UPowerDeviceType.Headset: return "\u{F02CE}";
        case UPowerDeviceType.Headphones: return "\u{F02CB}";
        case UPowerDeviceType.Mouse: return "\u{F037D}";
        case UPowerDeviceType.Keyboard: return "\u{F030C}";
        case UPowerDeviceType.GamingInput: return "\u{F0296}";
        case UPowerDeviceType.Phone: return "\u{F011C}";
        case UPowerDeviceType.Tablet: return "\u{F04F7}";
        }
        return "\u{F0079}";
    }

    function isLow(device: var): bool {
        return device.percent <= lowPercent && !device.charging;
    }

    // Asks the devices UPower cannot see again (the panel does as it opens).
    function refresh(): void {
        hyprmonk.running = true;
    }

    Process {
        id: hyprmonk
        command: [Quickshell.env("HOME") + "/.local/bin/hyprmonk", "battery", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const fresh = JSON.parse(text).map(d => ({
                        name: d.name,
                        icon: d.kind === "mouse" ? "\u{F037D}" : "\u{F0079}",
                        percent: d.percent,
                        charging: d.charging ?? false
                    }));
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
