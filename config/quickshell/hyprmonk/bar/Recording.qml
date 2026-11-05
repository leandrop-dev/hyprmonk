// A red dot and the time, only while the screen is being recorded, and two
// bars for the dot while paused. Click: stop. Right click: pause or resume.
import QtQuick
import qs
import qs.services

Module {
    visible: Recorder.active
    interactive: true
    icon: Recorder.paused ? "\u{F03E4}" : "\u{F044A}"
    label: Recorder.elapsed
    color: Theme.warning
    tooltip: Recorder.paused ? I18n.tr("Paused\nClick to stop, right click to resume")
                             : I18n.tr("Recording\nClick to stop, right click to pause")

    onClicked: button => {
        if (button === Qt.LeftButton) Recorder.toggle();
        else if (button === Qt.RightButton) Recorder.pause();
    }
}
