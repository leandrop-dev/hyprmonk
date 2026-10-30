// The running cat: faster the busier the CPU, from 6 frames a second to 90 at
// full load, as runcat-text runs it. It sleeps while the machine is quiet, a
// game runs or the screen is locked: its frames were nearly all the bar's idle
// cost, and only stopping saved any (docs/optimizations.md). The five frames
// are glyphs of its font (assets/runcat, BSD-2-Clause); a sixth, added to the
// font from RunCatResources (Apache-2.0), is the cat asleep.
import QtQuick
import qs
import qs.services

Module {
    id: root

    property int frame: 0
    property bool awake: true
    readonly property bool running: awake && !Session.locked && !GameMode.on
    readonly property int asleep: 5  // the frame
    readonly property real load: isNaN(Hardware.cpu) ? 0 : Math.max(0, Math.min(100, Hardware.cpu)) / 100

    // Apart, so a load around one level does not stop and start it every second.
    readonly property real wakeAt: 0.06
    readonly property real restAt: 0.04

    onLoadChanged: awake = load >= (awake ? restAt : wakeAt)
    onRunningChanged: frame = running ? 0 : asleep

    tooltip: isNaN(Hardware.cpu) ? "" : "CPU " + Math.round(Hardware.cpu) + "%"

    FontLoader {
        id: runcat
        source: Qt.resolvedUrl("../assets/runcat/runcat.ttf")
    }

    contents: Text {
        text: String.fromCodePoint(0xE900 + root.frame)
        color: root.active ? Theme.accent : root.color
        font.family: runcat.name
        font.pixelSize: 24
    }

    Timer {
        running: root.running
        repeat: true
        interval: 1000 / 6 - (1000 / 6 - 1000 / 90) * root.load
        onTriggered: root.frame = (root.frame + 1) % 5
    }
}
