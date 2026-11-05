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

    Component.onCompleted: Bluez.watchers += 1
    Component.onDestruction: {
        Bluez.watchers -= 1;
        if (!Bluez.scanning) Bluez.answer(false, "");  // nothing left to answer it
    }

    RowLayout {
        Layout.fillWidth: true

        SectionLabel {
            Layout.fillWidth: true
            text: I18n.tr("Bluetooth")
        }

        Searching {
            Layout.rightMargin: 4
            running: Bluez.adapter?.discovering ?? false
        }

        Chip {
            visible: Bluez.on && !Bluez.searching
            text: I18n.tr("search")
            onClicked: Bluez.search()
        }

        Chip {
            visible: Bluez.adapter?.state !== BluetoothAdapterState.Blocked
            text: Bluez.on ? I18n.tr("on") : I18n.tr("off")
            on: Bluez.on
            onClicked: Bluez.adapter.enabled = !Bluez.on
        }
    }

    // What a pairing needs from you (services/Bluez.qml).
    Rectangle {
        id: ask

        readonly property var request: Bluez.request
        readonly property string kind: request?.kind ?? ""
        readonly property bool shows: kind.startsWith("show-")
        readonly property bool types: kind === "passkey" || kind === "pin"
        // Six digits, zeros kept: a passkey comes as a number.
        readonly property string code: {
            const code = String(request?.code ?? "");
            return kind === "show-pin" ? code : code === "" ? "" : code.padStart(6, "0");
        }

        function accept(): void {
            if (types && field.text === "") return;
            Bluez.answer(true, field.text);
            field.text = "";
        }

        Layout.fillWidth: true
        visible: request !== null
        implicitHeight: askColumn.implicitHeight + 24
        radius: Theme.moduleRadius
        color: Theme.fg(0.06)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.8)

        onTypesChanged: if (types) field.forceActiveFocus()

        ColumnLayout {
            id: askColumn

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            Text {
                Layout.fillWidth: true
                readonly property string name: ask.request?.name ?? ""

                text: ask.shows ? I18n.tr("Type this on %1", name)
                    : ask.types ? I18n.tr("Code for %1", name)
                    : I18n.tr("Pair with %1?", name)
                textFormat: Text.PlainText
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                visible: ask.code !== ""
                text: ask.code
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: 24
                font.bold: true
                font.letterSpacing: 4
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: ask.kind === "confirmation" ? I18n.tr("Pair only if the device shows the same code")
                    : ask.kind === "show-passkey" ? I18n.tr("Then press Enter on it")
                    : ask.types ? I18n.tr("The one the device shows, or 0000 if it shows none")
                    : ""
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                visible: ask.types
                implicitHeight: 30
                radius: Theme.moduleRadius
                color: Theme.fg(0.06)
                border.width: 1
                border.color: field.activeFocus ? Qt.alpha(Theme.accent, 0.8) : Theme.rim

                TextInput {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground
                    selectionColor: Qt.alpha(Theme.accent, 0.55)
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                    clip: true

                    Keys.onReturnPressed: ask.accept()
                    Keys.onEnterPressed: ask.accept()
                    Keys.onEscapePressed: Panels.close()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !ask.shows
                spacing: 6

                Button {
                    Layout.fillWidth: true
                    primary: true
                    text: I18n.tr("Pair")
                    onClicked: ask.accept()
                }

                Button {
                    Layout.fillWidth: true
                    text: I18n.tr("Cancel")
                    onClicked: Bluez.answer(false, "")
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: !Bluez.on
        text: Bluez.adapter?.state === BluetoothAdapterState.Blocked ? I18n.tr("Blocked by a switch or key on the machine") : I18n.tr("Bluetooth is off")
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
        text: I18n.tr("In reach")
    }

    Text {
        Layout.fillWidth: true
        visible: Bluez.on
        text: I18n.tr("Others see this machine as %1 while this is open", Bluez.adapter?.name ?? "")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.bodyFontSize
    }

    Text {
        Layout.fillWidth: true
        visible: Bluez.on && Bluez.available.length === 0
        text: Bluez.searching ? I18n.tr("Looking for devices") : I18n.tr("Nothing found")
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

            required property int index
            required property BluetoothDevice modelData
            readonly property bool open: panel.expanded === modelData?.address
            readonly property bool busy: modelData?.pairing
                                         || modelData?.state === BluetoothDeviceState.Connecting
                                         || modelData?.state === BluetoothDeviceState.Disconnecting
            property int was: modelData?.state ?? BluetoothDeviceState.Disconnected

            // Its actions stay in view as it opens (paired rows are not in a
            // view). Later: the list has not taken in the new height yet.
            onHeightChanged: if (open && ListView.view) Qt.callLater(ListView.view.positionViewAtIndex, index, ListView.Contain)

            Layout.fillWidth: true
            width: ListView.view ? ListView.view.width : implicitWidth
            spacing: 6

            Connections {
                target: row.modelData

                function onStateChanged(): void {
                    const now = row.modelData?.state;
                    if (row.was === BluetoothDeviceState.Connecting && now === BluetoothDeviceState.Disconnected)
                        panel.failed = row.modelData?.address;
                    row.was = now;
                }
            }

            OptionRow {
                Layout.fillWidth: true
                icon: Bluez.deviceIcon(row.modelData)
                text: row.modelData?.name
                detail: row.modelData?.pairing ? I18n.tr("Pairing")
                      : row.modelData?.state === BluetoothDeviceState.Connecting ? I18n.tr("Connecting")
                      : row.modelData?.state === BluetoothDeviceState.Disconnecting ? I18n.tr("Disconnecting")
                      : row.modelData?.connected && row.modelData?.batteryAvailable ? Math.round(row.modelData?.battery * 100) + "%"
                      : row.modelData?.connected ? I18n.tr("Connected")
                      : row.modelData?.paired ? I18n.tr("Paired") : ""
                selected: row.modelData?.connected
                onClicked: panel.expand(row.modelData?.address)
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                visible: row.open && text !== ""
                text: Bluez.pairFailed === row.modelData?.address ? I18n.tr("Could not pair")
                    : panel.failed === row.modelData?.address ? I18n.tr("Could not connect")
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
                    enabled: !row.busy || row.modelData?.pairing
                    primary: !row.modelData?.connected
                    text: row.modelData?.pairing ? I18n.tr("Cancel")
                        : row.modelData?.connected ? I18n.tr("Disconnect")
                        : row.modelData?.paired ? I18n.tr("Connect") : I18n.tr("Pair")
                    onClicked: {
                        const device = row.modelData;
                        if (!device) return;
                        panel.failed = "";
                        if (device.pairing) device.cancelPair();
                        else if (device.connected) device.disconnect();
                        else if (device.paired) device.connect();
                        else Bluez.pair(device);
                    }
                }

                Button {
                    Layout.fillWidth: true
                    visible: row.modelData?.paired
                    enabled: !row.busy
                    text: panel.arming === row.modelData?.address ? I18n.tr("Again") : I18n.tr("Forget")
                    onClicked: if (row.modelData) panel.forget(row.modelData)
                }
            }
        }
    }
}
