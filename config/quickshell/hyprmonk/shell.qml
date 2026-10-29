// hyprmonk's shell: `qs -c hyprmonk`. The wallpaper and a bar per screen, the
// notification pop-ups and centre, the OSD, the launcher, quick actions, the
// power menu, the key guide, the wallpaper picker, the screenshot mode's
// card, the lock screen and the polkit agent; and the Appearance tone carried
// to GTK apps, Hyprland and kitty.
import Quickshell
import qs
import qs.bar
import qs.keyguide
import qs.launcher
import qs.lock
import qs.notifications
import qs.osd
import qs.polkit
import qs.power
import qs.quickactions
import qs.screenshot
import qs.wallpaper

ShellRoot {
    ThemeOutputs {}
    Background {}

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
    Launcher {}
    QuickActions {}
    PowerMenu {}
    KeyGuide {}
    Picker {}
    ScreenshotMode {}
    Lock {}
    Polkit {}
}
