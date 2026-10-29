// A tray app's menu, under its icon in the bar: the entries, ticks and
// radio marks where they have them, dim when disabled. A submenu opens in
// place, with a row to go back.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: panel

    readonly property var submenu: Tray.path.length > 0 ? Tray.path[Tray.path.length - 1] : null

    spacing: 2

    // One opener holds the app's menu while the panel shows it: with none,
    // Quickshell drops the menu, and every submenu entry in Tray.path with
    // it. The other opens the submenu shown, if any.
    QsMenuOpener {
        id: whole
        menu: Tray.item?.menu ?? null
    }

    QsMenuOpener {
        id: opened
        menu: panel.submenu
        // Gone when the app rebuilds its menu: back to what is left (once
        // the entry is fully gone).
        onMenuChanged: Qt.callLater(Tray.prune)
    }

    SectionLabel {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        text: Tray.nameOf(Tray.item)
        elide: Text.ElideRight
    }

    // DBus menus mark the access key with "_" ("__" is a real one).
    function label(text: string): string {
        return (text ?? "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    Entry {
        visible: panel.submenu !== null
        icon: "\u{F0141}"
        text: panel.label(panel.submenu?.text ?? "")
        bold: true
        onClicked: Tray.back()
    }

    Repeater {
        model: opened.menu ? opened.children : whole.children

        Loader {
            id: slot

            required property QsMenuEntry modelData

            Layout.fillWidth: true
            sourceComponent: modelData.isSeparator ? separator : entry

            Component {
                id: separator

                Rectangle {
                    implicitHeight: 9
                    color: "transparent"

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.fg(0.1)
                    }
                }
            }

            Component {
                id: entry

                Entry {
                    readonly property QsMenuEntry item: slot.modelData

                    enabled: item.enabled
                    text: panel.label(item.text)
                    iconSource: item.icon
                    icon: item.buttonType === QsMenuButtonType.CheckBox
                          ? (item.checkState === Qt.Checked ? "\u{F0132}" : "\u{F0131}")
                        : item.buttonType === QsMenuButtonType.RadioButton
                          ? (item.checkState === Qt.Checked ? "\u{F0134}" : "\u{F0130}")
                        : ""
                    more: item.hasChildren
                    onClicked: {
                        if (item.hasChildren) {
                            Tray.enter(item);
                        } else {
                            item.triggered();
                            Panels.close();
                        }
                    }
                }
            }
        }
    }

    component Entry: Rectangle {
        id: row

        property string icon: ""
        property string iconSource: ""
        property string text: ""
        property bool bold: false
        property bool more: false

        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.moduleRadius
        color: row.enabled && mouse.containsMouse ? Theme.fg(Theme.hoverOpacity) : "transparent"
        opacity: row.enabled ? 1 : Theme.dimOpacity

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 14

            Item {
                implicitWidth: 16
                implicitHeight: 16

                IconImage {
                    anchors.fill: parent
                    visible: row.icon === "" && row.iconSource !== ""
                    source: row.icon === "" ? row.iconSource : ""
                }

                Text {
                    anchors.centerIn: parent
                    text: row.icon
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                }
            }

            Text {
                Layout.fillWidth: true
                text: row.text
                textFormat: Text.PlainText
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
                font.bold: row.bold
                elide: Text.ElideRight
            }

            Text {
                visible: row.more
                text: "\u{F0142}"
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}
