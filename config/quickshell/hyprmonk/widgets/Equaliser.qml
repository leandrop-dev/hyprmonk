// The equaliser's bands (services/AudioEffects.qml) as upright sliders round
// a 0 dB line: drag or scroll one to move it, half a decibel at a time. Its
// gain shows above it, its frequency below. Each move is heard at once.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Placed by hand, an equal share each: in a layout the gains' changing
// widths moved every band.
Item {
    id: equaliser

    readonly property real range: AudioEffects.bandRange
    readonly property real share: width / AudioEffects.bands.length

    // The slider, and a line of small text above and below it.
    implicitHeight: 110 + 2 * line.implicitHeight + 8

    Text {
        id: line
        visible: false
        text: "0"
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    Repeater {
        id: bands

        model: AudioEffects.bands

        ColumnLayout {
            id: band

            required property int index
            required property int modelData
            readonly property real gain: AudioEffects.gains[index] ?? 0

            function moveTo(y: real): void {
                const level = 1 - Math.max(0, Math.min(1, y / track.height));
                AudioEffects.setBand(index, (level * 2 - 1) * equaliser.range);
            }

            x: index * equaliser.share
            width: equaliser.share
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: (band.gain > 0 ? "+" : "") + band.gain
                color: band.gain === 0 ? Theme.fg(Theme.dimOpacity) : Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.smallFontSize
            }

            Item {
                id: area

                Layout.fillWidth: true
                implicitHeight: 110

                Rectangle {
                    id: track

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 4
                    height: parent.height
                    radius: 2
                    color: Theme.fg(0.15)
                }

                // 0 dB.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: track.height / 2
                    width: 14
                    height: 1
                    color: Theme.fg(0.3)
                }

                // From the 0 dB line to the knob.
                Rectangle {
                    readonly property real middle: track.height / 2
                    readonly property real knob: track.height * (1 - (band.gain / equaliser.range + 1) / 2)

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.min(middle, knob)
                    width: 4
                    height: Math.abs(knob - middle)
                    radius: 2
                    color: Theme.accent
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(0, Math.min(area.height - height, track.height * (1 - (band.gain / equaliser.range + 1) / 2) - height / 2))
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: event => band.moveTo(event.y)
                    onPositionChanged: event => { if (pressed) band.moveTo(event.y); }
                    onWheel: event => AudioEffects.setBand(band.index, band.gain + (event.angleDelta.y > 0 ? 0.5 : -0.5))
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: band.modelData >= 1000 ? `${band.modelData / 1000}k` : String(band.modelData)
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.smallFontSize
            }
        }
    }
}
