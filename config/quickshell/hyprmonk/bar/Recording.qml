// A red dot and the time, only while the screen is being recorded. Click:
// stop.
import QtQuick
import qs
import qs.services

Module {
    visible: Recorder.active
    interactive: true
    icon: "\u{F044A}"
    label: Recorder.elapsed
    color: Theme.warning
    tooltip: "Recording\nClick to stop"

    onClicked: button => {
        if (button === Qt.LeftButton) Recorder.toggle();
    }
}
