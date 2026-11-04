// hyprmonk's shell: `qs -c hyprmonk`. The wallpaper, a bar and a dock per screen, the
// notification pop-ups and centre, the OSD, the launcher, quick actions, the
// power menu, the key guide, the wallpaper picker, settings, the screenshot
// mode's card, the lock screen and the polkit agent; and the Appearance tone carried
// to GTK apps, Hyprland and kitty.
import QtQuick
import Quickshell
import qs
import qs.bar
import qs.dock
import qs.keyguide
import qs.launcher
import qs.lock
import qs.notifications
import qs.osd
import qs.polkit
import qs.power
import qs.quickactions
import qs.screenshot
import qs.services
import qs.settings
import qs.wallpaper

ShellRoot {
    // Sounds listens for cards, panels and devices from the start (and
    // answers IPC), so it is loaded here rather than at the first click.
    Component.onCompleted: {
        Idle.start();
        void Sounds.on;
    }

    ThemeOutputs {}
    Background {}

    Variants {
        model: Quickshell.screens

        Bar {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Dock {
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
    SettingsCard {}
    ScreenshotMode {}
    Lock {}
    Polkit {}
}
