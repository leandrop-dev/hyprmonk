// The screens as they sit, for Settings > Display. Clicking one picks it;
// dragging it picks it and moves it, and where it is dropped it snaps against
// another screen (Display.placeAt). Like a mode, a move waits for Apply.
import QtQuick
import qs
import qs.services

Rectangle {
    id: map

    readonly property var boxes: Display.boxes
    readonly property real minX: boxes.reduce((low, box) => Math.min(low, box.x), Infinity)
    readonly property real minY: boxes.reduce((low, box) => Math.min(low, box.y), Infinity)
    readonly property real maxX: boxes.reduce((high, box) => Math.max(high, box.x + box.width), -Infinity)
    readonly property real maxY: boxes.reduce((high, box) => Math.max(high, box.y + box.height), -Infinity)
    // The screens fill most of the map, leaving room to drag one around them.
    readonly property real ratio: boxes.length === 0 ? 1
        : Math.min(width * 0.7 / (maxX - minX), height * 0.7 / (maxY - minY))
    readonly property real offsetX: (width - (maxX - minX) * ratio) / 2 - minX * ratio
    readonly property real offsetY: (height - (maxY - minY) * ratio) / 2 - minY * ratio

    implicitHeight: 150
    radius: Theme.moduleRadius
    color: Theme.fg(0.04)
    clip: true

    Repeater {
        // By count, not by box: the boxes change as a screen is picked, and a
        // new delegate would drop the press that picked it.
        model: Display.monitors.length

        Rectangle {
            id: tile

            required property int index
            readonly property var box: map.boxes[index] ?? { name: "", x: 0, y: 0, width: 0, height: 0 }
            readonly property bool picked: box.name === Display.monitor?.name
            readonly property bool locked: Display.trying && !picked  // a try belongs to one screen
            property real dragX: 0
            property real dragY: 0

            x: map.offsetX + box.x * map.ratio + dragX
            y: map.offsetY + box.y * map.ratio + dragY
            width: box.width * map.ratio
            height: box.height * map.ratio
            z: mouse.pressed ? 1 : 0
            radius: 6
            color: picked ? Qt.alpha(Theme.accent, 0.55) : Theme.fg(mouse.containsMouse && !locked ? 0.16 : 0.08)
            border.width: 1
            border.color: picked ? Qt.alpha(Theme.accent, 0.8) : Theme.rim

            Text {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 8)
                elide: Text.ElideRight
                text: tile.box.name
                textFormat: Text.PlainText
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.smallFontSize
            }

            MouseArea {
                id: mouse

                property point start

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: tile.locked ? Qt.ArrowCursor : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressed: event => {
                    if (tile.locked) {
                        event.accepted = false;
                        return;
                    }
                    if (!tile.picked) {
                        Display.clearChoice();
                        Display.picked = tile.box.name;
                    }
                    start = mapToItem(map, event.x, event.y);
                }
                onPositionChanged: event => {
                    if (!pressed) return;
                    const here = mapToItem(map, event.x, event.y);
                    tile.dragX = here.x - start.x;
                    tile.dragY = here.y - start.y;
                }
                onReleased: {
                    if (Math.hypot(tile.dragX, tile.dragY) > 3)
                        Display.placeAt(tile.box.x + tile.dragX / map.ratio, tile.box.y + tile.dragY / map.ratio, 12 / map.ratio);
                    tile.dragX = 0;
                    tile.dragY = 0;
                }
                onCanceled: {
                    tile.dragX = 0;
                    tile.dragY = 0;
                }
            }
        }
    }
}
