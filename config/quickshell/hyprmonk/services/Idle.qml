// Settings > Power: how long until the screen locks and the screens go off,
// in minutes, 0 for never; kept in settings.json. hypridle reads its config
// only as it starts, so this writes its own copy of config/hypr/hypridle.conf
// with these times to hypridle.conf in the state directory, which
// hyprmonk-idle.service prefers, and restarts the service when the copy
// changes. Until something is changed the service reads the repo's file.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // The repo's times: lock after 10 minutes, screens off a minute later.
    readonly property var defaults: ({ lockAfter: 10, screensOff: 1 })
    readonly property var choices: ({ lockAfter: [5, 10, 15, 30, 60, 0], screensOff: [1, 5, 10, 30, 0] })

    readonly property var values: {
        const values = {};
        for (const key of Object.keys(defaults)) {
            const kept = Settings.power?.[key];
            if (Number.isInteger(kept) && kept >= 0 && kept <= 240) values[key] = kept;
        }
        return values;
    }
    readonly property bool changed: Object.keys(values).length > 0
    readonly property int lockAfter: values.lockAfter ?? defaults.lockAfter
    // After the lock; after going idle when it never locks.
    readonly property int screensOff: values.screensOff ?? defaults.screensOff

    // The copy: the repo's file with the listeners' times set, or left out
    // for never. Empty until the repo's file is read.
    readonly property string config: {
        const text = template.text();
        if (!text) return "";
        const listeners = text.replace(/^listener \{\n[\s\S]*?^\}\n?/gm, block => {
            if (block.includes("lock-session"))
                return lockAfter ? block.replace(/timeout\s*=\s*\d+/, `timeout    = ${lockAfter * 60}`) : "";
            if (block.includes(`action = "off"`))
                return screensOff ? block.replace(/timeout\s*=\s*\d+/, `timeout    = ${(lockAfter + screensOff) * 60}`) : "";
            return block;
        });
        return "# Written by the shell from config/hypr/hypridle.conf with the times in\n"
            + "# Settings > Power (services/Idle.qml). Do not edit.\n\n" + listeners;
    }

    function set(key: string, minutes: int): void {
        const next = Object.assign({}, Settings.power);
        if (minutes === defaults[key]) delete next[key];
        else next[key] = minutes;
        Settings.setPower(next);
    }

    function reset(): void {
        Settings.setPower({});
    }

    // Called once at start (shell.qml), so a copy follows the repo's file.
    function start(): void {
        sync.restart();
    }

    onConfigChanged: sync.restart()

    // Written once something was changed, and from then on kept in step: a
    // copy put back to the repo's times still has to change hypridle.
    Timer {
        id: sync
        interval: 400
        onTriggered: {
            if (root.config === "" || (!root.changed && output.text() === "")) return;
            if (root.config !== output.text()) output.setText(root.config);
        }
    }

    FileView {
        id: template
        path: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: output
        path: Theme.stateDir + "/hypridle.conf"
        blockLoading: true
        printErrors: false
        onSaved: Quickshell.execDetached(["systemctl", "--user", "restart", "hyprmonk-idle.service"])
    }
}
