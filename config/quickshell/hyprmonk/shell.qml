// hyprmonk's shell: `qs -c hyprmonk`. A bar per screen, the notification
// pop-ups and centre, the OSD, quick actions and the polkit agent.
import Quickshell
import qs.bar
import qs.notifications
import qs.osd
import qs.polkit
import qs.quickactions

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
    QuickActions {}
    Polkit {}
}
