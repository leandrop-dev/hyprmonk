// hyprmonk's shell: `qs -c hyprmonk`. A bar per screen, the notification
// pop-ups and centre, the OSD and the polkit agent.
import Quickshell
import qs.bar
import qs.notifications
import qs.osd
import qs.polkit

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
    Osd {}
    Polkit {}
}
