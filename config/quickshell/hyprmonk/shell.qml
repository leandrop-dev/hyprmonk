// hyprmonk's shell: `qs -c hyprmonk`. One bar per screen for now.
import Quickshell
import qs.bar

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
