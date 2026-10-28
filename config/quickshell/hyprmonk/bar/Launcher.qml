// The distro logo; a click opens the app launcher.
import Quickshell

Module {
    icon: "\u{F385}"
    iconSize: 20
    interactive: true
    onClicked: Quickshell.execDetached(["hyprlauncher"])
}
