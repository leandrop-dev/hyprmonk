// The wallpaper on every screen, on the background layer: cropped to fill,
// decoded at the screen's size, and brought in over the last one when it
// changes, as picked in Settings > Appearance (services/Wallpaper.qml):
// - fade: fading in (400 ms);
// - wipe: a soft edge sweeping across, from one of eight directions at
//   random (900 ms);
// - circle: a soft-edged circle growing from where it was picked, the same
//   spot on every screen, so on another screen it comes in from that side;
//   from the middle when it was set without the picker (1100 ms);
// - random: one of those each time.
// Wipe and circle draw the new picture through a mask (MultiEffect), a
// gradient that moves; no shaders of our own. Until one is set the tone's
// background shows.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: window

        required property ShellScreen modelData
        readonly property string source: Wallpaper.path ? Theme.fileUrl(Wallpaper.path) : ""

        // The change under way: its kind, how far it has come (0 to 1), and
        // for a circle where it starts, for a wipe which way it goes.
        property string kind: "fade"
        property real progress: 1
        property point from: Qt.point(width / 2, height / 2)
        property point direction: Qt.point(1, 0)
        readonly property real edge: 160  // the soft edge's width
        readonly property bool masking: kind !== "fade" && progress < 1

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
        // it is in; then the last one is let go (a screen-sized picture held
        // for nothing).
        onSourceChanged: {
            reveal.stop();  // or it lets go of `below` under a picture still loading
            below.source = above.source;
            const kinds = ["fade", "wipe", "circle"];
            kind = Wallpaper.transition === "random" ? kinds[Math.floor(Math.random() * kinds.length)] : Wallpaper.transition;
            const origin = Wallpaper.origin;
            from = origin ? Qt.point(origin.x - modelData.x, origin.y - modelData.y) : Qt.point(width / 2, height / 2);
            const angle = Math.floor(Math.random() * 8) * Math.PI / 4;
            direction = Qt.point(Math.round(Math.cos(angle)), Math.round(Math.sin(angle)));
            progress = 0;
            above.source = source;
        }
        Component.onCompleted: above.source = source

        NumberAnimation {
            id: reveal

            target: window
            property: "progress"
            from: 0
            to: 1
            duration: window.kind === "fade" ? 400 : window.kind === "wipe" ? 900 : 1100
            easing.type: window.kind === "fade" ? Easing.OutCubic : Easing.InOutCubic
            onFinished: below.source = ""
        }

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
            // While masked, the effect below draws it instead.
            visible: !window.masking
            opacity: window.kind === "fade" ? window.progress : 1
            onStatusChanged: if (status === Image.Ready) reveal.restart()
        }

        MultiEffect {
            anchors.fill: parent
            visible: window.masking
            source: above
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        // Opaque where the new picture shows, clear where the last one still
        // does, with the soft edge between.
        Item {
            id: mask

            anchors.fill: parent
            visible: false
            layer.enabled: true

            // The circle reaches past the farthest corner, edge and all.
            readonly property real reach: Math.max(
                Math.hypot(window.from.x, window.from.y),
                Math.hypot(width - window.from.x, window.from.y),
                Math.hypot(window.from.x, height - window.from.y),
                Math.hypot(width - window.from.x, height - window.from.y)) + window.edge
            readonly property real radius: Math.max(1, window.progress * reach)

            // The wipe starts at the corner it leaves from and crosses the
            // screen's length along its direction, edge and all.
            readonly property real dx: window.direction.x
            readonly property real dy: window.direction.y
            readonly property real length: (Math.abs(dx * width) + Math.abs(dy * height)) / Math.hypot(dx, dy)
            readonly property real front: window.progress * (length + window.edge)
            readonly property point start: Qt.point(dx < 0 ? width : 0, dy < 0 ? height : 0)
            readonly property real ux: dx / Math.hypot(dx, dy)
            readonly property real uy: dy / Math.hypot(dx, dy)

            Shape {
                anchors.fill: parent

                ShapePath {
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillGradient: window.kind === "circle" ? circle : wipe

                    PathRectangle {
                        width: mask.width
                        height: mask.height
                    }
                }
            }

            RadialGradient {
                id: circle

                centerX: window.from.x
                centerY: window.from.y
                centerRadius: mask.radius
                focalX: window.from.x
                focalY: window.from.y

                GradientStop { position: 0; color: "white" }
                GradientStop { position: Math.max(0, 1 - window.edge / mask.radius); color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }

            LinearGradient {
                id: wipe

                x1: mask.start.x + mask.ux * (mask.front - window.edge)
                y1: mask.start.y + mask.uy * (mask.front - window.edge)
                x2: mask.start.x + mask.ux * mask.front
                y2: mask.start.y + mask.uy * mask.front

                GradientStop { position: 0; color: "white" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
}
