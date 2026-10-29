// The media panel, under the bar's centre card: the track's art (blurred
// behind everything, and sharp on the left), its title, artist and album, a
// seek bar, and shuffle, previous, play/pause, next and repeat. The player's
// name switches between players when there are several. The lyrics button
// beside it swaps the track and seek bar for synced lyrics (LyricsView);
// "In bar" then puts the line being sung in the bar too.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

ClippingRectangle {
    id: panel

    readonly property MprisPlayer player: Player.current
    readonly property bool hasLength: Player.length > 0

    implicitHeight: 172
    radius: Theme.moduleRadius + 2
    color: Theme.fg(0.04)

    // The position is read when asked: ask every second while it plays.
    Timer {
        running: panel.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: panel.player.positionChanged()
    }

    Image {
        id: backdrop
        anchors.fill: parent
        source: panel.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(256, 256)
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        visible: backdrop.status === Image.Ready
        source: backdrop
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.35
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 18

        ClippingRectangle {
            implicitWidth: 132
            implicitHeight: 132
            radius: Theme.moduleRadius
            color: Theme.fg(0.08)

            Image {
                id: art
                anchors.fill: parent
                source: panel.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(264, 264)
            }

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "\u{F075A}"
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: 40
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: Player.players.length > 1 ? panel.player?.identity + "  \u{F04E1}" : (panel.player?.identity ?? "")
                    color: Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.smallFontSize
                    elide: Text.ElideRight

                    MouseArea {
                        anchors.fill: parent
                        enabled: Player.players.length > 1
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Player.pickNext()
                    }
                }

                Chip {
                    visible: Lyrics.shown
                    text: "In bar"
                    on: Lyrics.inBar
                    onClicked: Lyrics.setInBar(!Lyrics.inBar)
                }

                Control {
                    size: 22
                    glyph: "\u{F0757}"
                    on: Lyrics.shown
                    onClicked: Lyrics.setShown(!Lyrics.shown)
                }
            }

            LyricsView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 2
                visible: Lyrics.shown
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: !Lyrics.shown
                text: panel.player?.trackTitle || "Unknown track"
                textFormat: Text.PlainText
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== "" && !Lyrics.shown
                text: [panel.player?.trackArtist, panel.player?.trackAlbum].filter(s => s).join(" · ")
                textFormat: Text.PlainText
                color: Theme.fg(0.7)
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
                visible: !Lyrics.shown
            }

            Slider {
                Layout.fillWidth: true
                visible: panel.hasLength && !Lyrics.shown
                value: panel.hasLength ? panel.player.position / Player.length : 0
                dim: !(panel.player?.canSeek ?? false)
                onMoved: value => {
                    if (panel.player?.canSeek) panel.player.position = value * Player.length;
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !Lyrics.shown

                Text {
                    text: panel.hasLength ? Player.time(panel.player.position) : "Live"
                    color: Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.smallFontSize
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    visible: panel.hasLength
                    text: panel.hasLength ? Player.time(Player.length) : ""
                    color: Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.smallFontSize
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 14

                Control {
                    visible: panel.player?.shuffleSupported ?? false
                    glyph: "\u{F049D}"
                    on: panel.player?.shuffle ?? false
                    onClicked: panel.player.shuffle = !panel.player.shuffle
                }

                Control {
                    glyph: "\u{F04AE}"
                    enabled: panel.player?.canGoPrevious ?? false
                    onClicked: panel.player.previous()
                }

                // Play/pause: the one filled with the accent.
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: Theme.accent
                    opacity: panel.player?.canTogglePlaying ? 1 : Theme.dimOpacity

                    Text {
                        anchors.centerIn: parent
                        text: panel.player?.isPlaying ? "\u{F03E4}" : "\u{F040A}"
                        color: Theme.background
                        font.family: Theme.font
                        font.pixelSize: 20
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (panel.player?.canTogglePlaying) panel.player.togglePlaying()
                    }
                }

                Control {
                    glyph: "\u{F04AD}"
                    enabled: panel.player?.canGoNext ?? false
                    onClicked: panel.player.next()
                }

                // Repeat: off, the playlist, or this track.
                Control {
                    visible: panel.player?.loopSupported ?? false
                    readonly property int loop: panel.player?.loopState ?? MprisLoopState.None
                    glyph: loop === MprisLoopState.Track ? "\u{F0458}" : "\u{F0456}"
                    on: loop !== MprisLoopState.None
                    onClicked: panel.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                        : loop === MprisLoopState.Playlist ? MprisLoopState.Track
                        : MprisLoopState.None
                }
            }
        }
    }

    // A small round button for the player's controls; accent while `on`.
    component Control: Rectangle {
        id: control

        property string glyph: ""
        property bool on: false
        property int size: 30
        signal clicked()

        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        opacity: enabled ? 1 : Theme.dimOpacity
        color: mouse.containsMouse ? Theme.fg(Theme.hoverOpacity) : "transparent"

        Text {
            anchors.centerIn: parent
            text: control.glyph
            color: control.on ? Theme.accent : Theme.foreground
            font.family: Theme.font
            font.pixelSize: Math.round(control.size * 0.53)
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }
}
