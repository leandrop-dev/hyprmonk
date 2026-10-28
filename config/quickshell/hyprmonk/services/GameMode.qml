// Game mode: Hyprland drops animations, blur and shadows and lets fullscreen
// windows use variable refresh (hypr/gamemode.lua); notifications only reach
// the centre, without popping up (Notifications.qml); the power profile goes
// to Performance, and back to the one before when it ends (unless another
// was picked meanwhile).
// The switch is a file in the state directory that the config reads on every
// load, so turning it on or off writes the file and reloads Hyprland's config.
// Its second line keeps the profile to go back to, across shell restarts.
//
// IPC: qs -c hyprmonk ipc call gamemode toggle  (prints the new state)
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs

Singleton {
    id: root

    property bool on: false
    property string profileBefore: ""  // "" when game mode did not change it

    function toggle(): void {
        if (on) {
            if (profileBefore !== "" && PowerProfiles.profile === PowerProfile.Performance)
                PowerProfiles.profile = PowerProfile[profileBefore];
            profileBefore = "";
        } else if (PowerProfiles.hasPerformanceProfile && PowerProfiles.profile !== PowerProfile.Performance) {
            profileBefore = PowerProfiles.profile === PowerProfile.PowerSaver ? "PowerSaver" : "Balanced";
            PowerProfiles.profile = PowerProfile.Performance;
        }
        on = !on;
        file.setText((on ? "on" : "off") + "\n" + profileBefore + "\n");
        Quickshell.execDetached(["hyprctl", "reload", "config-only"]);
    }

    IpcHandler {
        target: "gamemode"

        function toggle(): bool {
            root.toggle();
            return root.on;
        }
    }

    FileView {
        id: file
        path: Theme.stateDir + "/game-mode"
        blockWrites: true
        printErrors: false
        onLoaded: {
            const [state, profile] = text().split("\n");
            root.on = state.trim() === "on";
            root.profileBefore = root.on ? (profile ?? "").trim() : "";
        }
        onLoadFailed: root.on = false
    }
}
