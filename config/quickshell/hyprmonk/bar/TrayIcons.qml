// Apps' status icons (services/Tray.qml). Click: the app (or its menu, for
// those that only have one); middle click: its other action; right click:
// its menu, as a panel; scroll: passed to the app. Symbolic icons take the
// text colour.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.services

RowLayout {
    spacing: 2
    visible: Tray.items.length > 0

    Repeater {
        // ScriptModel keeps the other icons when one comes, goes or changes.
        model: ScriptModel {
            values: Tray.items
        }

        Module {
            id: mod

            required property SystemTrayItem modelData

            interactive: true
            active: Tray.menuOpen && Tray.item === modelData
            tooltip: Tray.nameOf(modelData)

            onClicked: button => {
                if (button === Qt.RightButton || (button === Qt.LeftButton && modelData.onlyMenu)) {
                    if (modelData.hasMenu) Tray.toggleMenu(modelData);
                } else if (button === Qt.LeftButton) {
                    modelData.activate();
                } else if (button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                }
            }
            onScrolled: steps => modelData.scroll(steps, false)

            contents: [
                // A symbolic icon is a shape for the desktop to paint in its
                // text colour (as Plasma does; drawn in KDE's dark text,
                // it would vanish on the bar): only its outline is kept.
                Item {
                    id: picture

                    // The app's icon could not be drawn: a file that did not
                    // load, or Quickshell's stand-in for one it could not
                    // make (no such icon in the theme, or none sent), a
                    // black and purple checkerboard read from its corners.
                    property bool checkerboard: false
                    readonly property bool missing: icon.status === Image.Error || checkerboard
                    readonly property bool symbolic: !missing && icon.source.toString().includes("-symbolic")

                    implicitWidth: 16
                    implicitHeight: 16

                    IconImage {
                        id: icon
                        anchors.fill: parent
                        source: Tray.iconSource(mod.modelData)
                        visible: !picture.missing && !picture.symbolic
                        layer.enabled: picture.symbolic

                        onStatusChanged: {
                            picture.checkerboard = false;
                            if (status === Image.Ready) corners.read(source);
                        }
                    }

                    Canvas {
                        id: corners
                        width: 4
                        height: 4
                        opacity: 0

                        property url url

                        function read(source: url): void {
                            if (url.toString() !== "") unloadImage(url);
                            url = source;
                            if (isImageLoaded(url)) requestPaint();
                            else loadImage(url);
                        }

                        onImageLoaded: requestPaint()

                        onPaint: {
                            if (!isImageLoaded(url)) return;
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.drawImage(url, 0, 0, width, height);
                            const data = ctx.getImageData(0, 0, width, height).data;
                            const near = (x, y, colour) => {
                                const at = (y * width + x) * 4;
                                return data[at + 3] > 247 && colour.every((value, i) => Math.abs(data[at + i] - value) < 8);
                            };
                            const black = [0, 0, 0], purple = [217, 0, 216];
                            picture.checkerboard = near(0, 0, black) && near(3, 0, purple)
                                && near(0, 3, purple) && near(3, 3, black);
                        }
                    }

                    IconImage {
                        anchors.fill: parent
                        visible: picture.missing
                        source: picture.missing ? Tray.standIn(mod.modelData) : ""
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: picture.symbolic
                        color: Theme.foreground
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: icon
                        }
                    }
                },
                // Asking to be looked at.
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.leftMargin: -8
                    visible: mod.modelData.status === Status.NeedsAttention
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: Theme.accent
                }
            ]
        }
    }
}
