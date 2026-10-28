// hyprmonk's shell: `qs -c hyprmonk`. A bar per screen, the notification
// pop-ups and the notification centre.
import Quickshell
import qs.bar
import qs.notifications

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    Popups {}
    Center {}
}
