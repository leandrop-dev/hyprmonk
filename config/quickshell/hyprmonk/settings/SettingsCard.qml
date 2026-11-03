// Settings (Super+comma): a card in the middle of the focused screen, with its
// pages down the side. What is changed applies at once; the arrows or Tab move
// through the pages, Escape or a click elsewhere closes the card. What it
// changes is kept by services/Settings.qml.
//
// IPC: qs -c hyprmonk ipc call overlays toggle settings
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

Overlay {
    id: window

    readonly property var pages: [
        { name: "Display", icon: "\u{F0379}", file: "DisplayPage.qml" },
        { name: "Windows", icon: "\u{F05AF}", file: "WindowsPage.qml" },
        { name: "Bar", icon: "\u{F0570}", file: "BarPage.qml" },
        { name: "Appearance", icon: "\u{F050E}", file: "AppearancePage.qml" },
        { name: "Input", icon: "\u{F030C}", file: "InputPage.qml" },
        { name: "Power", icon: "\u{F0425}", file: "PowerPage.qml" },
        { name: "Recording", icon: "\u{F044A}", file: "RecordingPage.qml" },
        { name: "Notifications", icon: "\u{F009A}", file: "NotificationsPage.qml" }
    ]
    property int current: 0

    function move(step: int): void {
        current = (current + step + pages.length) % pages.length;
    }

    name: "hyprmonk-settings"
    open: Overlays.open === "settings"
    cardWidth: 720
    cardHeight: 520
    onDismissed: Overlays.close()
    onOpenChanged: if (open) keys.forceActiveFocus()

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onUpPressed: window.move(-1)
        Keys.onDownPressed: window.move(1)
        Keys.onTabPressed: window.move(1)
        Keys.onBacktabPressed: window.move(-1)
        Keys.onEscapePressed: Overlays.close()

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            ColumnLayout {
                Layout.preferredWidth: 180
                Layout.maximumWidth: 180
                Layout.fillHeight: true
                spacing: 4

                SectionLabel {
                    Layout.leftMargin: 12
                    Layout.bottomMargin: 8
                    text: "Settings"
                }

                Repeater {
                    model: window.pages

                    OptionRow {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        icon: modelData.icon
                        text: modelData.name
                        selected: index === window.current
                        onClicked: window.current = index
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Theme.rim
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: window.visible
                source: window.pages[window.current].file
            }
        }
    }
}
