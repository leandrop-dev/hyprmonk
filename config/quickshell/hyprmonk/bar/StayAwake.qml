// Stay awake (services/Awake.qml): a cup, dim while off and in the accent
// while on. Click: turn it on or off.
import QtQuick
import qs
import qs.services

Module {
    interactive: true
    icon: Awake.on ? "\u{F0176}" : "\u{F06CA}"
    color: Awake.on ? Theme.accent : Theme.foreground
    dim: !Awake.on
    tooltip: Awake.on ? "Staying awake: the screen will not lock or go off\nClick to stop"
                      : "Stay awake\nClick to keep the screen from locking or going off"

    onClicked: Awake.toggle()
}
