// The default output's volume. Click: the sound panel; right click: mute;
// scroll: change it.
import QtQuick
import qs
import qs.services

Module {
    visible: Audio.sink !== null
    interactive: true
    icon: Audio.volumeIcon
    label: Math.round(Audio.volume * 100) + "%"
    dim: Audio.muted

    onClicked: button => {
        if (button === Qt.RightButton) Audio.sink.audio.muted = !Audio.muted;
        else if (button === Qt.LeftButton) Panels.toggle("sound");
    }
    onScrolled: steps => Audio.setVolume(Audio.volume + steps * 0.05)
}
