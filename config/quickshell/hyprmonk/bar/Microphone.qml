// The default input: click to mute or unmute; red while muted.
import QtQuick
import qs
import qs.services

Module {
    visible: Audio.source !== null
    interactive: true
    icon: Audio.micIcon
    color: Audio.micMuted ? Theme.warning : Theme.foreground

    onClicked: Audio.source.audio.muted = !Audio.micMuted
}
