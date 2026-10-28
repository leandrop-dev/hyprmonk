// The default input; red while muted. Click: the microphone panel; right
// click: mute.
import QtQuick
import qs
import qs.services

Module {
    visible: Audio.source !== null
    interactive: true
    icon: Audio.micIcon
    color: Audio.micMuted ? Theme.warning : Theme.foreground

    onClicked: button => {
        if (button === Qt.RightButton) Audio.source.audio.muted = !Audio.micMuted;
        else if (button === Qt.LeftButton) Panels.toggle("microphone");
    }
}
