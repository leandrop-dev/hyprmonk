// One notification: its image or app icon, app and age, summary, body and
// action buttons. A click runs the default action (or dismisses); the middle
// button or × dismisses. As a pop-up it times out, paused while hovered.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.services

Rectangle {
    id: card

    required property Notification notification
    // Pop-ups time out and float on their own; centre entries sit inside a panel.
    property bool popup: false

    signal timedOut()

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property NotificationAction defaultAction: notification.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")
    readonly property string iconSource: {
        const icon = notification.appIcon;
        if (icon.startsWith("/")) return "file://" + icon;
        if (icon.includes("://")) return icon;
        return Quickshell.iconPath(icon, true);
    }

    implicitHeight: layout.implicitHeight + 24
    radius: popup ? Theme.cardRadius : Theme.moduleRadius
    color: popup ? Theme.card : Theme.fg(hover.hovered ? 0.08 : 0.04)
    border.width: popup || critical ? 1 : 0
    border.color: critical ? Theme.warning : Theme.rim

    HoverHandler {
        id: hover
    }

    Timer {
        readonly property int timeout: Notifications.timeoutFor(card.notification)
        running: card.popup && timeout > 0 && !hover.hovered
        interval: timeout
        onTriggered: card.timedOut()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            if (event.button === Qt.LeftButton && card.defaultAction)
                card.defaultAction.invoke();
            else
                card.notification.dismiss();
        }
    }

    RowLayout {
        id: layout

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 12

        // A picture sent with it (a contact, an album), else the app's icon.
        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40
            implicitHeight: 40
            radius: Theme.moduleRadius
            color: "transparent"
            visible: picture.status === Image.Ready || appIcon.status === Image.Ready

            Image {
                id: picture
                anchors.fill: parent
                source: card.notification.image
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(80, 80)
            }

            IconImage {
                id: appIcon
                anchors.fill: parent
                visible: picture.status !== Image.Ready
                source: picture.status === Image.Ready ? "" : card.iconSource
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: [card.notification.appName, Notifications.ago(card.notification)].filter(s => s).join(" · ")
                    color: Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.smallFontSize
                    elide: Text.ElideRight
                }

                Text {
                    text: "\u{F0156}"
                    color: Theme.fg(close.containsMouse ? 0.9 : Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize

                    MouseArea {
                        id: close
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.notification.dismiss()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification.summary
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notification.body
                color: Theme.fg(0.75)
                linkColor: Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
                // Senders may use simple markup (bold, italics, links), never full HTML.
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 8
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: card.buttons.length > 0
                spacing: 6

                Repeater {
                    model: card.buttons

                    Rectangle {
                        id: button

                        required property NotificationAction modelData

                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Theme.moduleRadius
                        color: Theme.fg(press.containsMouse ? 0.16 : 0.08)

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            horizontalAlignment: Text.AlignHCenter
                            text: button.modelData.text
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: Theme.bodyFontSize
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: press
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: button.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
