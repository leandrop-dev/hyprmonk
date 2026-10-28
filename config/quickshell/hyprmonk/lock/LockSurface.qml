// What one screen shows while locked. On the main screen: the wallpaper with
// a frosted band along the bottom, a large clock and the date low on the
// left, a glass bar along the bottom with the avatar (~/.face), the user, the
// password field, the keyboard layout (when not the default) and the
// batteries, and what is playing above the bar's right end (music players
// only: a browser's tab titles stay private). Other screens show only the
// frosted wallpaper. The desktop never shows through.
//
// Sizes follow HyprFlow's lock, laid out for 2560x1440 and scaled to the
// screen.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services

Rectangle {
    id: surface

    required property var lock
    required property ShellScreen screen

    readonly property bool main: lock.primary === "" || screen?.name === lock.primary
    readonly property real s: Math.min(width / 2560, height / 1440)

    // Until the wallpaper is in, or with none set.
    color: Theme.background

    // The wallpaper as the desktop draws it (the same size, so the decoded
    // picture is shared).
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Wallpaper.path ? "file://" + Wallpaper.path : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
        asynchronous: true
    }

    // Frosted and a little darker: the band behind the clock and the bar on
    // the main screen, fading in over its top third; all of it elsewhere.
    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 48
        brightness: -0.12
        contrast: -0.05
        maskEnabled: surface.main
        maskSource: band
        maskThresholdMin: 0.5  // with the spread: the mask's alpha 0 to 1, in full
        maskSpreadAtMin: 1
    }

    Item {
        id: band

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 560 * surface.s
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1 / 3; color: "white" }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Clock and date, their left edge on the bar's text.
    Text {
        id: time

        visible: surface.main
        x: bar.x + 7 * surface.s
        anchors.baseline: bar.top
        anchors.baselineOffset: -32 * surface.s
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.foreground
        font.family: Theme.font
        font.weight: Font.ExtraBold
        font.pixelSize: Math.round(300 * surface.s)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.8
            shadowOpacity: 0.45
        }
    }

    Text {
        visible: surface.main
        x: bar.x + 7 * surface.s
        // Above the digits' tops (0.73 of the size in JetBrains Mono).
        anchors.baseline: time.baseline
        anchors.baselineOffset: -(0.73 * time.font.pixelSize + 20 * surface.s)
        text: Qt.locale("en_GB").toString(clock.date, "dddd dd · MMMM").toUpperCase()
        color: Theme.fg(0.73)
        font.family: Theme.font
        font.pixelSize: Math.round(26 * surface.s)
    }

    // Now playing.
    readonly property var player: Player.current
    readonly property bool music: player !== null && (player.trackTitle ?? "") !== ""
        && !/firefox|zen|chrom|brave|vivaldi|librewolf|opera|edge/i.test((player.desktopEntry ?? "") + " " + player.identity)

    ClippingRectangle {
        id: art

        visible: surface.main && surface.music && cover.status === Image.Ready
        anchors.right: bar.right
        anchors.bottom: bar.top
        anchors.bottomMargin: 32 * surface.s
        width: 96 * surface.s
        height: width
        radius: 10 * surface.s
        color: "transparent"

        Image {
            id: cover
            anchors.fill: parent
            source: surface.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(192, 192)
        }
    }

    Column {
        visible: surface.main && surface.music
        anchors.right: art.visible ? art.left : bar.right
        anchors.rightMargin: art.visible ? 28 * surface.s : 0
        anchors.bottom: art.bottom
        anchors.bottomMargin: 12 * surface.s
        width: 600 * surface.s
        spacing: 6 * surface.s

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: surface.player?.trackTitle ?? ""
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Math.round(24 * surface.s)
            elide: Text.ElideLeft
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignRight
            visible: text !== ""
            text: surface.player?.trackArtist ?? ""
            color: Theme.fg(0.73)
            font.family: Theme.font
            font.pixelSize: Math.round(20 * surface.s)
            elide: Text.ElideLeft
        }
    }

    // The glass bar.
    Rectangle {
        id: bar

        visible: surface.main
        x: 128 * surface.s
        y: surface.height - height - 48 * surface.s
        width: surface.width - 2 * x
        height: 120 * surface.s
        radius: 24 * surface.s
        color: Qt.alpha(Theme.background, 0.72)
        border.width: 1
        border.color: Theme.fg(0.16)

        // The avatar: ~/.face, else the system's logo.
        Rectangle {
            id: avatar

            x: 24 * surface.s
            anchors.verticalCenter: parent.verticalCenter
            width: 80 * surface.s
            height: width
            radius: width / 2
            color: Theme.fg(0.08)
            border.width: 2
            border.color: Theme.foreground

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: width / 2
                color: "transparent"

                // Only asked for once the file is known to be there.
                FileView {
                    id: faceFile
                    property bool exists: false
                    path: Quickshell.env("HOME") + "/.face"
                    printErrors: false
                    onLoaded: exists = true
                    onLoadFailed: exists = false
                }

                Image {
                    id: face
                    anchors.fill: parent
                    source: faceFile.exists ? "file://" + faceFile.path : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(160, 160)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                text: Distro.logo
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Math.round(40 * surface.s)
            }
        }

        Text {
            anchors.left: avatar.right
            anchors.leftMargin: 24 * surface.s
            anchors.verticalCenter: parent.verticalCenter
            text: Quickshell.env("USER")
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Math.round(22 * surface.s)
        }

        // The password field.
        Rectangle {
            id: field

            readonly property bool failed: surface.lock.error !== ""

            anchors.centerIn: parent
            width: Math.max(320, surface.width - 1320 * surface.s)
            height: 76 * surface.s
            radius: 14 * surface.s
            color: Qt.alpha(Theme.background, 0.52)
            border.width: 1
            border.color: failed ? Theme.warning
                : surface.lock.checking ? Theme.accent : Theme.fg(0.14)
            transform: Translate { id: shake }

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: 24 * surface.s
                anchors.rightMargin: 24 * surface.s
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                focus: surface.main
                readOnly: surface.lock.checking
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Math.round(26 * surface.s)
                font.letterSpacing: 6 * surface.s
                cursorVisible: false
                cursorDelegate: Item {}

                onTextEdited: {
                    surface.lock.password = text;
                    surface.lock.error = "";
                }
                Keys.onReturnPressed: surface.lock.submit()
                Keys.onEnterPressed: surface.lock.submit()
                // Clears what was typed; with nothing typed it passes on (the
                // preview closes).
                Keys.onEscapePressed: event => {
                    event.accepted = text !== "";
                    text = "";
                    surface.lock.password = "";
                }
            }

            Text {
                anchors.centerIn: parent
                visible: input.text === ""
                text: surface.lock.checking ? "Checking…"
                    : field.failed ? surface.lock.error + " (" + surface.lock.failures + ")"
                    : "Type to unlock"
                color: field.failed ? Theme.warning : Theme.fg(0.55)
                font.family: Theme.font
                font.pixelSize: Math.round(20 * surface.s)
                font.italic: field.failed
            }

            SequentialAnimation {
                id: shaking
                NumberAnimation { target: shake; property: "x"; to: -12; duration: 50 }
                NumberAnimation { target: shake; property: "x"; to: 12; duration: 80 }
                NumberAnimation { target: shake; property: "x"; to: -6; duration: 70 }
                NumberAnimation { target: shake; property: "x"; to: 0; duration: 60 }
            }
        }

        // The layout when it is not the default, then the batteries.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 92 * surface.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 32 * surface.s

            Text {
                visible: !Keyboard.isDefault && Keyboard.name !== ""
                text: "\u{F030C}  " + Keyboard.name
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: Math.round(20 * surface.s)
            }

            Repeater {
                model: Battery.devices

                Text {
                    required property var modelData

                    text: (modelData.charging ? "\u{F0084}" : modelData.icon) + " " + modelData.percent + "%"
                    color: Battery.isLow(modelData) ? Theme.warning : Theme.fg(0.73)
                    font.family: Theme.font
                    font.pixelSize: Math.round(20 * surface.s)
                }
            }
        }
    }

    Connections {
        target: surface.lock

        // The password is cleared once sent or on a new lock.
        function onPasswordChanged(): void {
            if (input.text !== surface.lock.password) input.text = surface.lock.password;
        }

        function onFailuresChanged(): void {
            if (surface.lock.failures > 0) shaking.restart();
        }
    }

    Component.onCompleted: if (main) input.forceActiveFocus()
}
