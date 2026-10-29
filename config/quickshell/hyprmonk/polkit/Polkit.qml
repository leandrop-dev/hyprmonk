// The polkit agent: asks for your password when something needs root (pkexec,
// systemctl, a package manager). The screen dims behind one card on the
// focused monitor; Enter authenticates, Escape cancels.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs
import qs.widgets

Scope {
    id: root

    PolkitAgent {
        id: agent

        // A request can end without Cancel (the app quits); never carry typed
        // text over to the next one.
        onAuthenticationRequestStarted: {
            field.text = "";
            window.who = flow.selectedIdentity?.displayName ?? "";
        }
    }

    PanelWindow {
        id: window

        readonly property AuthFlow flow: agent.flow
        readonly property bool waiting: !(flow?.isResponseRequired ?? false)
        // Whose password: read when the request starts (a binding on the
        // identity's name stayed empty).
        property string who: ""

        function authenticate(): void {
            if (waiting) return;
            flow.submit(field.text);
            field.text = "";
        }

        function cancel(): void {
            field.text = "";
            flow?.cancelAuthenticationRequest();
        }

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: agent.isActive

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Qt.alpha("black", 0.35)

        WlrLayershell.namespace: "hyprmonk-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        // Each prompt (the first, or again after a wrong password) gets the cursor.
        Connections {
            target: window.flow
            function onIsResponseRequiredChanged() {
                if (window.flow.isResponseRequired) field.forceActiveFocus();
            }
        }

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: 440
            implicitHeight: content.implicitHeight + 40
            radius: Theme.panelRadius
            color: Theme.card
            border.width: 1
            border.color: Theme.rim

            ColumnLayout {
                id: content

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 20
                }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: width / 2
                        color: Qt.alpha(Theme.accent, 0.2)

                        Text {
                            anchors.centerIn: parent
                            text: "\u{F033E}"
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 18
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Authentication required"
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.flow?.actionId ?? ""
                            textFormat: Text.PlainText
                            color: Theme.fg(Theme.dimOpacity)
                            font.family: Theme.font
                            font.pixelSize: Theme.smallFontSize
                            elide: Text.ElideMiddle
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: window.flow?.message ?? ""
                    color: Theme.fg(0.75)
                    font.family: Theme.font
                    font.pixelSize: Theme.bodyFontSize
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
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
                        enabled: !window.waiting
                        echoMode: window.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.foreground
                        selectionColor: Qt.alpha(Theme.accent, 0.55)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        clip: true

                        Keys.onReturnPressed: window.authenticate()
                        Keys.onEnterPressed: window.authenticate()
                        Keys.onEscapePressed: window.cancel()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text === ""
                            // polkit's prompt reads "Password: ".
                            readonly property string prompt: (window.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                            text: window.who ? prompt + " for " + window.who : prompt
                            color: Theme.fg(Theme.dimOpacity)
                            font: field.font
                        }
                    }
                }

                // polkit's own notes: "Sorry, try again." after a wrong password.
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: window.flow?.supplementaryMessage ?? ""
                    textFormat: Text.PlainText
                    color: window.flow?.supplementaryIsError ? Theme.warning : Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.bodyFontSize
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "Cancel"
                        onClicked: window.cancel()
                    }

                    Button {
                        primary: true
                        enabled: !window.waiting
                        text: window.waiting ? "Checking…" : "Authenticate"
                        onClicked: window.authenticate()
                    }
                }
            }
        }
    }
}
