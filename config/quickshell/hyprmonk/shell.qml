// hyprmonk's shell: `qs -c hyprmonk`. A bar per screen, the notification
// pop-ups and centre, the OSD, quick actions, the power menu, the lock screen
// and the polkit agent.
import Quickshell
import qs.bar
import qs.lock
import qs.notifications
import qs.osd
import qs.polkit
import qs.power
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
    PowerMenu {}
    Lock {}
    Polkit {}
}
