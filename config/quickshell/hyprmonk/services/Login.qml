// The login screen's look (SDDM's astronaut theme, `install.sh login`): one
// of the theme's own, or Desktop, the wallpaper and the saved tone's colours
// (written by ThemeOutputs.qml). The theme reads the look that
// /var/lib/hyprmonk-login/current.conf links to, a folder the installer
// gives the user: picking one changes the link, with no password asked. It
// shows at the next login. Read again each time quick actions open.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: "/var/lib/hyprmonk-login"
    readonly property string theme: "/usr/share/sddm/themes/sddm-astronaut-theme"
    property bool ready: false  // set up by the installer
    property var looks: []  // the theme's, by name, then "desktop"
    property string current: ""
    readonly property var labels: looks.map(label)

    // pixel_sakura_static: "Pixel sakura static".
    function label(name: string): string {
        const words = name.replace(/[_-]/g, " ");
        return words.charAt(0).toUpperCase() + words.slice(1);
    }

    function pick(name: string): void {
        if (!looks.includes(name) || link.running) return;
        const target = name === "desktop" ? `${dir}/desktop.conf` : `${theme}/Themes/${name}.conf`;
        link.command = ["ln", "-sfn", target, `${dir}/current.conf`];
        link.running = true;
    }

    function refresh(): void {
        list.running = true;
    }

    Process {
        id: link
        onExited: code => {
            if (code !== 0) console.warn("login: could not pick the look", command[2]);
            root.refresh();
        }
    }

    // The link's target, then the theme's looks; nothing before the
    // installer has made the link.
    Process {
        id: list
        command: ["sh", "-c", 'readlink "$1/current.conf" && ls "$2/Themes"', "sh", root.dir, root.theme]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(line => line !== "");
                root.ready = lines.length > 1;
                if (!root.ready) return;
                root.current = lines[0].split("/").pop().replace(/\.conf$/, "");
                root.looks = lines.slice(1)
                    .filter(name => name.endsWith(".conf") && !name.startsWith("hyprmonk-"))
                    .map(name => name.slice(0, -5))
                    .concat("desktop");
            }
        }
    }
}
