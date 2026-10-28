// The distro logo; a click opens the app launcher.
import Quickshell
import qs.services

Module {
    icon: Distro.logo
    iconSize: 20
    interactive: true
    onClicked: Quickshell.execDetached(["hyprlauncher"])
}
