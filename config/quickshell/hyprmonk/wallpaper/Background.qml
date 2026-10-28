// The wallpaper on every screen, on the background layer: cropped to fill,
// decoded at the screen's size, and faded in over the last one when it
// changes. Until one is set the tone's background shows.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: window

        required property ShellScreen modelData
        readonly property string source: Wallpaper.path ? "file://" + Wallpaper.path : ""

        screen: modelData
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.background

        WlrLayershell.namespace: "hyprmonk-wallpaper"
        WlrLayershell.layer: WlrLayer.Background

        // The new picture loads on top while the last stays below it, until
        // it has faded in.
        onSourceChanged: {
            below.source = above.source;
            above.opacity = 0;
            above.source = source;
        }
        Component.onCompleted: above.source = source

        Image {
            id: below
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(window.width, window.height)
            asynchronous: true
        }

        Image {
            id: above
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(window.width, window.height)
            asynchronous: true
            onStatusChanged: if (status === Image.Ready) fade.restart()

            NumberAnimation on opacity {
                id: fade
                running: false
                to: 1
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }
}
