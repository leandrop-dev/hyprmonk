// The Bluetooth panel, under the bar's Bluetooth button: the switch, the
// devices paired and those in reach. A device's row opens its actions.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: panel

    property string expanded: ""  // the address showing its actions
    property string failed: ""    // the address that would not connect
    property string arming: ""    // the address waiting for Forget's second press

    function expand(address: string): void {
        expanded = expanded === address ? "" : address;
        failed = "";
        arming = "";
    }

    function forget(device: BluetoothDevice): void {
        if (arming !== device.address) {
            arming = device.address;
            return;
        }
        device.forget();
        expand("");
    }

    spacing: 10

    Component.onCompleted: Bluez.scanning = true
    Component.onDestruction: Bluez.scanning = false

    RowLayout {
        Layout.fillWidth: true

        SectionLabel {
            Layout.fillWidth: true
            text: "Bluetooth"
        }

        Searching {
            Layout.rightMargin: 4
            running: Bluez.adapter?.discovering ?? false
        }

        Chip {
            visible: Bluez.adapter?.state !== BluetoothAdapterState.Blocked
            text: Bluez.on ? "on" : "off"
            on: Bluez.on
            onClicked: Bluez.adapter.enabled = !Bluez.on
        }
    }

    Text {
        Layout.fillWidth: true
        visible: !Bluez.on
        text: Bluez.adapter?.state === BluetoothAdapterState.Blocked ? "Blocked by a switch or key on the machine" : "Bluetooth is off"
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.bodyFontSize
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: Bluez.on
        spacing: 2

        Repeater {
            model: ScriptModel {
                values: Bluez.paired
            }

            delegate: deviceRow
        }
    }

    SectionLabel {
        Layout.topMargin: Bluez.paired.length > 0 ? 6 : 0
        visible: Bluez.on
        text: "In reach"
    }

    Text {
        Layout.fillWidth: true
        visible: Bluez.on
        text: "Others see this machine as " + (Bluez.adapter?.name ?? "") + " while this is open"
        textFormat: Text.PlainText
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.bodyFontSize
    }

    Text {
        Layout.fillWidth: true
        visible: Bluez.on && Bluez.available.length === 0
        text: "Looking for devices"
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.bodyFontSize
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 240)
        visible: Bluez.on
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: Bluez.available
        }

        delegate: deviceRow
    }

    Component {
        id: deviceRow

        ColumnLayout {
            id: row

            required property BluetoothDevice modelData
            readonly property bool open: panel.expanded === modelData.address
            readonly property bool busy: modelData.pairing
                                         || modelData.state === BluetoothDeviceState.Connecting
                                         || modelData.state === BluetoothDeviceState.Disconnecting
            property int was: modelData.state

            Layout.fillWidth: true
            width: ListView.view ? ListView.view.width : implicitWidth
            spacing: 6

            Connections {
                target: row.modelData

                function onStateChanged(): void {
                    const now = row.modelData.state;
                    if (row.was === BluetoothDeviceState.Connecting && now === BluetoothDeviceState.Disconnected)
                        panel.failed = row.modelData.address;
                    row.was = now;
                }
            }

            OptionRow {
                Layout.fillWidth: true
                icon: Bluez.deviceIcon(row.modelData)
                text: row.modelData.name
                detail: row.modelData.pairing ? "Pairing"
                      : row.modelData.state === BluetoothDeviceState.Connecting ? "Connecting"
                      : row.modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting"
                      : row.modelData.connected && row.modelData.batteryAvailable ? Math.round(row.modelData.battery * 100) + "%"
                      : row.modelData.connected ? "Connected"
                      : row.modelData.paired ? "Paired" : ""
                selected: row.modelData.connected
                onClicked: panel.expand(row.modelData.address)
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                visible: row.open && text !== ""
                text: Bluez.pairFailed === row.modelData.address ? "Could not pair. If it asks for a code, use bluetoothctl"
                    : panel.failed === row.modelData.address ? "Could not connect"
                    : ""
                color: Theme.warning
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.bottomMargin: 4
                visible: row.open
                spacing: 6

                Button {
                    Layout.fillWidth: true
                    enabled: !row.busy || row.modelData.pairing
                    primary: !row.modelData.connected
                    text: row.modelData.pairing ? "Cancel"
                        : row.modelData.connected ? "Disconnect"
                        : row.modelData.paired ? "Connect" : "Pair"
                    onClicked: {
                        const device = row.modelData;
                        panel.failed = "";
                        if (device.pairing) device.cancelPair();
                        else if (device.connected) device.disconnect();
                        else if (device.paired) device.connect();
                        else Bluez.pair(device);
                    }
                }

                Button {
                    Layout.fillWidth: true
                    visible: row.modelData.paired
                    enabled: !row.busy
                    text: panel.arming === row.modelData.address ? "Again" : "Forget"
                    onClicked: panel.forget(row.modelData)
                }
            }
        }
    }
}
