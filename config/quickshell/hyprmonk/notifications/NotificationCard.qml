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
import qs.widgets

Rectangle {
    id: card

    required property Notification notification
    // Pop-ups time out and float on their own; centre entries sit inside a panel.
    property bool popup: false
    // Off under a group's header, which names the app already.
    property bool showApp: true

    signal timedOut()

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property NotificationAction defaultAction: notification.actions.find(a => a.identifier === "default") ?? null
    readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")
    // A screenshot (hyprmonk's hint): its picture shown large under the text,
    // the app icon beside it.
    readonly property bool preview: notification.hints["x-hyprmonk-preview"] === true
    // `notify-send -i name` sends the name as the image (image://icon/name), not
    // as the app icon. Theme icons resolve to "" when missing, not a checkerboard.
    // A picture sent as a path comes the same way, with the path as the name.
    readonly property string pictureSource: preview ? "" : resolve(notification.image)
    readonly property string iconSource: resolve(notification.appIcon)
        || resolve(DesktopEntries.byId(notification.desktopEntry)?.icon ?? "")

    function resolve(icon: string): string {
        if (icon.startsWith("image://icon/")) {
            const name = icon.slice(13);
            return name.startsWith("/") ? "file://" + name : Quickshell.iconPath(name, true);
        }
        if (icon.startsWith("/")) return "file://" + icon;
        if (icon.includes("://")) return icon;
        return icon ? Quickshell.iconPath(icon, true) : "";
    }

    implicitHeight: layout.implicitHeight + 24
    radius: popup ? Theme.panelRadius : Theme.moduleRadius
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
        Item {
            Layout.alignment: Qt.AlignTop
            Layout.leftMargin: 4
            Layout.topMargin: 4
            implicitWidth: 20
            implicitHeight: 20
            visible: picture.status === Image.Ready || appIcon.status === Image.Ready

            Image {
                id: picture
                anchors.fill: parent
                source: card.pictureSource
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(40, 40)
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
                    text: [card.showApp ? card.notification.appName : "", Notifications.ago(card.notification)].filter(s => s).join(" · ")
                    textFormat: Text.PlainText
                    color: Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.smallFontSize
                    elide: Text.ElideRight
                }

                Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20
                    radius: width / 2
                    color: Theme.fg(close.containsMouse ? 0.15 : 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "\u{F0156}"
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.smallFontSize
                    }

                    MouseArea {
                        id: close
                        anchors.fill: parent
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
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                // Senders may use simple markup (bold, italics, links), never
                // full HTML. Images are dropped: the shell would fetch any
                // address a sender names. Only web and mail links open.
                text: (card.notification.body ?? "").replace(/<img\b[^>]*>/gi, "")
                color: Theme.fg(0.6)
                linkColor: Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 8
                elide: Text.ElideRight
                onLinkActivated: link => {
                    if (/^(https?|mailto):/i.test(link)) Qt.openUrlExternally(link);
                }
            }

            Image {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.preferredHeight: visible ? Math.min(160, width * implicitHeight / Math.max(1, implicitWidth)) : 0
                visible: card.preview && status === Image.Ready
                source: card.preview ? card.resolve(card.notification.image) : ""
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                sourceSize.width: 640
                asynchronous: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: card.buttons.length > 0
                spacing: 6

                Repeater {
                    model: card.buttons

                    Button {
                        required property NotificationAction modelData

                        // Equal widths, whatever the labels.
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
}
