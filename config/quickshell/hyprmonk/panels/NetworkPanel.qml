// The network panel, under the bar's network button: Ethernet when a cable is
// in, the Wi-Fi switch and the networks in reach, and the connection editor
// for the rest (VPNs, WPA-Enterprise). A network's row opens its actions, so
// a stray click never drops the connection.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: panel

    property string expanded: ""  // the network showing its actions
    property string asking: ""    // a saved network whose password failed
    property string failure: ""   // why the expanded one did not connect
    property string arming: ""    // the network waiting for Forget's second press

    function expand(name: string): void {
        expanded = expanded === name ? "" : name;
        asking = "";
        failure = "";
        arming = "";
    }

    function failed(network: WifiNetwork, reason: int): void {
        expanded = network.name;
        if (reason === ConnectionFailReason.NoSecrets) {
            asking = network.name;
            failure = "That password did not work";
        } else {
            failure = reason === ConnectionFailReason.WifiAuthTimeout ? "The network did not answer"
                    : reason === ConnectionFailReason.WifiNetworkLost ? "The network went out of reach"
                    : "Could not connect";
        }
    }

    function forget(network: WifiNetwork): void {
        if (arming !== network.name) {
            arming = network.name;
            return;
        }
        network.forget();
        expand("");
    }

    spacing: 10

    Component.onCompleted: Net.scanning = true
    Component.onDestruction: Net.scanning = false

    SectionLabel {
        visible: ethernet.visible
        text: "Ethernet"
    }

    OptionRow {
        id: ethernet

        Layout.fillWidth: true
        visible: Net.wired?.hasLink ?? false
        icon: "\u{F0200}"
        text: "Ethernet"
        detail: Net.wiredUp ? Net.wired.linkSpeed + " Mb/s" : "Not connected"
        selected: Net.wiredUp
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: ethernet.visible ? 6 : 0
        visible: Net.wifi !== null

        SectionLabel {
            Layout.fillWidth: true
            text: "Wi-Fi"
        }

        Searching {
            Layout.rightMargin: 4
            running: (Net.wifi?.scannerEnabled ?? false) && Networking.wifiEnabled
        }

        Chip {
            visible: Networking.wifiHardwareEnabled
            text: Networking.wifiEnabled ? "on" : "off"
            on: Networking.wifiEnabled
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: Net.wifi === null ? ""
            : !Networking.wifiHardwareEnabled ? "Off by a switch or key on the machine"
            : !Networking.wifiEnabled ? "Wi-Fi is off"
            : Net.sorted.length === 0 ? "Looking for networks"
            : ""
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.bodyFontSize
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 340)
        visible: Networking.wifiEnabled
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds

        // ScriptModel keeps a network's row, and its password field, as the
        // list changes around it.
        model: ScriptModel {
            values: Net.sorted
        }

        delegate: ColumnLayout {
            id: row

            required property WifiNetwork modelData
            readonly property bool open: panel.expanded === modelData.name
            readonly property bool wantsPassword: open && !modelData.connected && Net.takesPassword(modelData)
                                                  && (!modelData.known || panel.asking === modelData.name)
            readonly property bool needsEditor: !modelData.known && !Net.isOpen(modelData) && !Net.takesPassword(modelData)

            function connect(): void {
                panel.failure = "";
                if (wantsPassword) {
                    if (field.text === "") return;
                    panel.asking = "";
                    modelData.connectWithPsk(field.text);
                    field.text = "";
                } else {
                    modelData.connect();
                }
            }

            width: ListView.view.width
            spacing: 6

            onWantsPasswordChanged: if (wantsPassword) field.forceActiveFocus()

            Connections {
                target: row.modelData

                function onConnectionFailed(reason): void {
                    panel.failed(row.modelData, reason);
                }

                function onConnectedChanged(): void {
                    if (row.modelData.connected && row.open) panel.expand("");
                }
            }

            OptionRow {
                Layout.fillWidth: true
                icon: Net.signalIcon(row.modelData)
                text: row.modelData.name
                detail: row.modelData.stateChanging ? "Connecting"
                      : row.modelData.connected ? "Connected"
                      : row.modelData.known ? "Saved"
                      : Net.isOpen(row.modelData) ? "Open" : "\u{F033E}"
                selected: row.modelData.connected
                onClicked: panel.expand(row.modelData.name)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                visible: row.wantsPassword
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
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.foreground
                    selectionColor: Qt.alpha(Theme.accent, 0.55)
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                    clip: true

                    Keys.onReturnPressed: row.connect()
                    Keys.onEnterPressed: row.connect()
                    Keys.onEscapePressed: Panels.close()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: "Password"
                        color: Theme.fg(Theme.dimOpacity)
                        font: field.font
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                visible: row.open && (panel.failure !== "" || row.needsEditor)
                text: panel.failure || "Set this one up in Connections"
                color: panel.failure ? Theme.warning : Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.bottomMargin: 4
                visible: row.open
                spacing: 6

                Button {
                    Layout.fillWidth: true
                    visible: !row.needsEditor
                    enabled: !row.modelData.stateChanging
                    primary: !row.modelData.connected
                    text: row.modelData.connected ? "Disconnect" : "Connect"
                    onClicked: row.modelData.connected ? row.modelData.disconnect() : row.connect()
                }

                Button {
                    Layout.fillWidth: true
                    visible: row.modelData.known
                    text: panel.arming === row.modelData.name ? "Again" : "Forget"
                    onClicked: panel.forget(row.modelData)
                }
            }
        }
    }

    Button {
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: "\u{F0493}  Connections"
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"]);
            Panels.close();
        }
    }
}
