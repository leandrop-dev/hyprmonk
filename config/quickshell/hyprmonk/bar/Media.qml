// What is playing (services/Player.qml): the cover in a circle, title and
// artist (or, with lyrics "In bar", the line being sung), and how far into
// the track an underline has come. It slides out of the centre card on hover
// (bar/Bar.qml). Click: the media panel; right
// click: play/pause; scroll: next or previous track.
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services

Module {
    id: root

    readonly property var player: Player.current

    interactive: player !== null
    dim: !player?.isPlaying

    onClicked: button => {
        if (!player) return;
        if (button === Qt.LeftButton) Panels.toggle("media");
        else if (button === Qt.RightButton && player.canTogglePlaying) player.togglePlaying();
    }
    onScrolled: steps => {
        if (steps > 0 && player?.canGoNext) player.next();
        else if (steps < 0 && player?.canGoPrevious) player.previous();
    }

    // The position is read when asked: ask every second while it plays.
    Timer {
        running: root.visible && (root.player?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    contents: [
        ClippingRectangle {
            implicitWidth: 20
            implicitHeight: 20
            radius: 10
            color: Theme.fg(0.08)

            Image {
                id: cover
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(40, 40)
            }

            BarText {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                text: "\u{F075A}"
                font.pixelSize: 12
            }
        },

        BarText {
            id: title

            Layout.maximumWidth: 360
            text: Lyrics.inBar && Lyrics.line !== "" ? Lyrics.line : Player.summary
            elide: Text.ElideRight

            // How far into the track.
            Rectangle {
                visible: Player.length > 0
                anchors.top: parent.bottom
                anchors.topMargin: 1
                width: parent.width * Math.min(1, (root.player?.position ?? 0) / Math.max(1, Player.length))
                height: 2
                radius: 1
                color: Theme.foreground
                opacity: 0.8
            }
        }
    ]
}
