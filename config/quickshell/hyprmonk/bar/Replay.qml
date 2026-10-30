// An icon while the last minute is being kept. Click: save it. Right click:
// stop keeping it.
import QtQuick
import qs
import qs.services

Module {
    visible: Recorder.replaying
    interactive: true
    icon: "\u{F0459}"
    color: Theme.warning
    tooltip: "Keeping the last minute\nClick to save, right click to stop"

    onClicked: button => {
        if (button === Qt.LeftButton) Recorder.saveReplay();
        else if (button === Qt.RightButton) Recorder.toggleReplay();
    }
}
