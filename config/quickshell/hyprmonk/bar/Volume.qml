// The default output's volume: scroll to change it, click to mute.
import QtQuick
import qs
import qs.services

Module {
    visible: Audio.sink !== null
    interactive: true
    icon: Audio.volumeIcon
    label: Math.round(Audio.volume * 100) + "%"
    dim: Audio.muted

    onClicked: Audio.sink.audio.muted = !Audio.muted
    onScrolled: steps => Audio.setVolume(Audio.volume + steps * 0.05)
}
