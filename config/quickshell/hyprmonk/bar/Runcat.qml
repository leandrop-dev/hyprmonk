// The running cat: faster the busier the CPU, from 6 frames a second when
// idle to 90 at full load, as runcat-text runs it. The five frames are glyphs
// of its font (assets/runcat, BSD-2-Clause).
import QtQuick
import qs
import qs.services

Module {
    id: root

    property int frame: 0
    readonly property real load: isNaN(Hardware.cpu) ? 0 : Math.max(0, Math.min(100, Hardware.cpu)) / 100

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
        running: true
        repeat: true
        interval: 1000 / 6 - (1000 / 6 - 1000 / 90) * root.load
        onTriggered: root.frame = (root.frame + 1) % 5
    }
}
