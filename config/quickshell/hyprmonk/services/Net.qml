// Network state for the bar and the network panel, from Quickshell's
// Networking (NetworkManager). Scanning runs only while `scanning` is set: the
// panel sets it while it is open.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    property bool scanning: false

    readonly property var devices: Networking.devices.values
    readonly property WifiDevice wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property WiredDevice wired: devices.find(d => d.type === DeviceType.Wired) ?? null

    readonly property var networks: wifi?.networks.values ?? []
    readonly property WifiNetwork current: networks.find(n => n.connected) ?? null
    readonly property bool wiredUp: wired?.connected ?? false
    readonly property bool online: wiredUp || current !== null

    // Connected, then saved, then by bars of signal and name: exact strength
    // would swap rows under the pointer as it wavers.
    readonly property var sorted: networks.filter(n => n.name !== "").sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (bars(b) - bars(a)) || a.name.localeCompare(b.name))

    readonly property string icon: wiredUp ? "\u{F0200}"
                                 : current ? signalIcon(current)
                                 : Networking.wifiEnabled && wifi ? "\u{F092F}" : "\u{F05AA}"

    // What the bar's tooltip says: the first line is its title.
    readonly property string summary: wiredUp ? "Ethernet\n" + wired.linkSpeed + " Mb/s"
                                    : current ? current.name + "\nSignal " + Math.round(current.signalStrength * 100) + "%"
                                    : "Not connected"

    function bars(network: WifiNetwork): int {
        return Math.min(Math.floor(network.signalStrength * 4), 3);
    }

    function signalIcon(network: WifiNetwork): string {
        return ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"][bars(network)];
    }

    // A password this panel can send: what the rest need, the connection editor has.
    function takesPassword(network: WifiNetwork): bool {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security);
    }

    function isOpen(network: WifiNetwork): bool {
        return [WifiSecurityType.Open, WifiSecurityType.Owe].includes(network.security);
    }

    Binding {
        target: root.wifi
        property: "scannerEnabled"
        value: root.scanning
        when: root.wifi !== null
    }
}
