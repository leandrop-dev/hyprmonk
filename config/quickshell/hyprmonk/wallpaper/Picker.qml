// The wallpaper picker (Super+W): the pictures in the wallpaper folder as
// tiles, the one in use marked. A click or Enter sets the picked one and
// leaves the picker open to try others; typing filters by file name, the
// arrows move, Escape or a click elsewhere closes it.
//
// IPC: qs -c hyprmonk ipc call overlays toggle wallpapers
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

Scope {
    id: root

    readonly property bool open: Overlays.open === "wallpapers"
    property string query: ""
    property int current: 0

    readonly property var shown: Wallpaper.files.filter(file => {
        const name = file.slice(file.lastIndexOf("/") + 1).toLowerCase();
        return query.toLowerCase().split(/\s+/).every(word => name.includes(word));
    })

    readonly property int columns: 4
    readonly property int gap: 8

    function nameOf(file: string): string {
        return file.slice(file.lastIndexOf("/") + 1);
    }

    function move(step: int): void {
        if (shown.length > 0) current = Math.max(0, Math.min(shown.length - 1, current + step));
    }

    function pick(): void {
        if (current < shown.length) Wallpaper.set(shown[current]);
    }

    onOpenChanged: {
        if (!open) return;
        search.text = "";
        query = "";
        current = Math.max(0, shown.indexOf(Wallpaper.path));
        grid.positionViewAtIndex(current, GridView.Contain);
        search.forceActiveFocus();
    }

    Overlay {
        id: window

        readonly property int top: 44
        readonly property int bottom: 36
        readonly property int tileWidth: Math.floor((cardWidth - 24) / root.columns)
        readonly property int tileHeight: Math.round((tileWidth - root.gap) * 9 / 16) + root.gap
        readonly property int rows: Math.max(1, Math.min(3, Math.ceil(Wallpaper.files.length / root.columns)))

        name: "hyprmonk-wallpapers"
        open: root.open
        cardWidth: 900
        // Sized for every picture, so filtering does not resize it.
        cardHeight: top + rows * tileHeight + bottom
        onDismissed: Overlays.close()

        Text {
            x: 20
            y: 15
            text: "\u{F0E09}"
            color: Theme.fg(Theme.dimOpacity)
            font.family: Theme.font
            font.pixelSize: 16
        }

        TextInput {
            id: search

            x: 46
            y: 16
            width: window.cardWidth - 66
            focus: true
            color: Theme.foreground
            selectionColor: Qt.alpha(Theme.accent, 0.4)
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize

            onTextEdited: {
                root.query = text;
                root.current = 0;
            }

            Keys.onLeftPressed: event => {
                if (text !== "") event.accepted = false;
                else root.move(-1);
            }
            Keys.onRightPressed: event => {
                if (text !== "") event.accepted = false;
                else root.move(1);
            }
            Keys.onUpPressed: root.move(-root.columns)
            Keys.onDownPressed: root.move(root.columns)
            Keys.onTabPressed: root.move(1)
            Keys.onBacktabPressed: root.move(-1)
            Keys.onReturnPressed: root.pick()
            Keys.onEnterPressed: root.pick()
            Keys.onEscapePressed: Overlays.close()

            Text {
                visible: !search.text
                text: "Wallpapers"
                color: Theme.fg(Theme.dimOpacity)
                font: search.font
            }
        }

        GridView {
            id: grid

            x: 12
            y: window.top
            width: window.tileWidth * root.columns
            height: window.rows * window.tileHeight
            cellWidth: window.tileWidth
            cellHeight: window.tileHeight
            model: root.shown
            currentIndex: root.current
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

            delegate: Item {
                id: tile

                required property string modelData
                required property int index
                readonly property bool picked: index === root.current
                readonly property bool inUse: modelData === Wallpaper.path

                width: grid.cellWidth
                height: grid.cellHeight

                ClippingRectangle {
                    id: frame

                    anchors.fill: parent
                    anchors.margins: root.gap / 2
                    radius: Theme.moduleRadius
                    color: Theme.fg(0.05)

                    Image {
                        anchors.fill: parent
                        source: "file://" + tile.modelData
                        sourceSize: Qt.size(width, height)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 160 }
                        }
                    }
                }

                // Over the picture, so the rim is not clipped under it.
                Rectangle {
                    anchors.fill: frame
                    radius: frame.radius
                    color: mouse.containsMouse && !tile.picked ? Theme.fg(Theme.hoverOpacity) : "transparent"
                    border.width: tile.picked ? 2 : 1
                    border.color: tile.picked ? Theme.accent : Theme.rim
                }

                Rectangle {
                    visible: tile.inUse
                    anchors.right: frame.right
                    anchors.bottom: frame.bottom
                    anchors.margins: 6
                    width: 22
                    height: 22
                    radius: 11
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "\u{F012C}"
                        color: Theme.background
                        font.family: Theme.font
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.current = tile.index;
                        root.pick();
                    }
                }
            }
        }

        Text {
            anchors.centerIn: grid
            visible: root.shown.length === 0
            text: Wallpaper.files.length === 0 ? "No pictures in " + Wallpaper.folder : "No match"
            color: Theme.fg(Theme.dimOpacity)
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
        }

        Text {
            x: 20
            y: window.cardHeight - window.bottom + 8
            width: window.cardWidth - 40
            text: root.current < root.shown.length ? root.nameOf(root.shown[root.current]) : ""
            elide: Text.ElideMiddle
            color: Theme.fg(0.6)
            font.family: Theme.font
            font.pixelSize: Theme.bodyFontSize
        }
    }
}
