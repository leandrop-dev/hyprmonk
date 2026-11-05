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
            failure = I18n.tr("That password did not work");
        } else {
            failure = reason === ConnectionFailReason.WifiAuthTimeout ? I18n.tr("The network did not answer")
                    : reason === ConnectionFailReason.WifiNetworkLost ? I18n.tr("The network went out of reach")
                    : I18n.tr("Could not connect");
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

    Component.onCompleted: Net.watchers += 1
    Component.onDestruction: Net.watchers -= 1

    SectionLabel {
        visible: ethernet.visible
        text: I18n.tr("Ethernet")
    }

    OptionRow {
        id: ethernet

        Layout.fillWidth: true
        visible: Net.wired?.hasLink ?? false
        icon: "\u{F0200}"
        text: I18n.tr("Ethernet")
        detail: Net.wiredUp ? I18n.tr("%1 Mb/s", Net.wired.linkSpeed) : I18n.tr("Not connected")
        selected: Net.wiredUp
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: ethernet.visible ? 6 : 0
        visible: Net.wifi !== null

        SectionLabel {
            Layout.fillWidth: true
            text: I18n.tr("Wi-Fi")
        }

        Searching {
            Layout.rightMargin: 4
            running: (Net.wifi?.scannerEnabled ?? false) && Networking.wifiEnabled
        }

        Chip {
            visible: Networking.wifiHardwareEnabled
            text: Networking.wifiEnabled ? I18n.tr("on") : I18n.tr("off")
            on: Networking.wifiEnabled
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
        }
    }

    Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: Net.wifi === null ? ""
            : !Networking.wifiHardwareEnabled ? I18n.tr("Off by a switch or key on the machine")
            : !Networking.wifiEnabled ? I18n.tr("Wi-Fi is off")
            : Net.sorted.length === 0 ? I18n.tr("Looking for networks")
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

            required property int index
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
            // Its actions and field stay in view as it opens. Later: the list
            // has not taken in the new height yet.
            onHeightChanged: if (open) Qt.callLater(ListView.view.positionViewAtIndex, index, ListView.Contain)

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
                detail: row.modelData.stateChanging ? I18n.tr("Connecting")
                      : row.modelData.connected ? I18n.tr("Connected")
                      : row.modelData.known ? I18n.tr("Saved")
                      : Net.isOpen(row.modelData) ? I18n.trc("network", "Open") : "\u{F033E}"
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
                        text: I18n.tr("Password")
                        color: Theme.fg(Theme.dimOpacity)
                        font: field.font
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                visible: row.open && (panel.failure !== "" || row.needsEditor)
                text: panel.failure || I18n.tr("Set this one up in Connections")
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
                    text: row.modelData.connected ? I18n.tr("Disconnect") : I18n.tr("Connect")
                    onClicked: row.modelData.connected ? row.modelData.disconnect() : row.connect()
                }

                Button {
                    Layout.fillWidth: true
                    visible: row.modelData.known
                    text: panel.arming === row.modelData.name ? I18n.tr("Again") : I18n.tr("Forget")
                    onClicked: panel.forget(row.modelData)
                }
            }
        }
    }

    Button {
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: "\u{F0493}  " + I18n.tr("Connections")
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"]);
            Panels.close();
        }
    }
}
