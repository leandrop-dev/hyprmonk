// The notification daemon (org.freedesktop.Notifications). Every notification
// is kept for the centre until dismissed; new ones also pop up, unless do not
// disturb or game mode is on (critical ones always do). How long they stay,
// where, how many show at once and how many the centre keeps are set in
// Settings > Notifications, kept in notifications.json.
//
// IPC: qs -c hyprmonk ipc call notifications toggle | clear | dnd | count | list
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

Singleton {
    id: root

    // Everything still open, newest first.
    readonly property var all: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length
    // The same, by app for the centre: [{app, notifications}], the app with
    // the newest first, each one's newest first.
    readonly property var groups: {
        const groups = [];
        for (const notification of all) {
            const app = notification.appName || "Other";
            const group = groups.find(g => g.app === app);
            if (group) group.notifications.push(notification);
            else groups.push({ app, notifications: [notification] });
        }
        return groups;
    }
    // The apps of those groups, in order: the centre lists these and reads
    // each group by its app (a ScriptModel of the groups themselves keeps
    // an old one for a group that moves up, Quickshell 0.3.2).
    readonly property var apps: groups.map(g => g.app)

    function notificationsOf(app: string): var {
        return groups.find(g => g.app === app)?.notifications ?? [];
    }
    // Shown as pop-ups right now, newest first.
    property var popups: []
    property bool centerOpen: false
    property alias doNotDisturb: settings.doNotDisturb

    // When each one arrived, by id, for "5m ago".
    property var arrived: ({})
    readonly property date now: clock.date

    // What Settings > Notifications offers.
    readonly property var defaults: ({ seconds: 10, position: "top-right", popupCount: 4, history: 200 })
    readonly property var choices: ({
        seconds: [5, 10, 15, 30, 60],
        position: ["top-right", "top-left", "bottom-right", "bottom-left"],
        popupCount: [1, 2, 3, 4, 6],
        history: [50, 100, 200, 500]
    })
    readonly property bool changed: Object.keys(defaults).some(key => chosen(key) !== defaults[key])

    function chosen(key: string): var {
        return choices[key].includes(settings[key]) ? settings[key] : defaults[key];
    }
    function set(key: string, value: var): void {
        if (choices[key].includes(value)) settings[key] = value;
    }
    function reset(): void {
        for (const key of Object.keys(defaults)) settings[key] = defaults[key];
    }

    // Milliseconds a pop-up stays when the sender does not say; a low one
    // half as long.
    readonly property int defaultTimeout: chosen("seconds") * 1000
    readonly property int lowTimeout: defaultTimeout / 2
    readonly property string position: chosen("position")
    readonly property int maxPopups: chosen("popupCount")
    readonly property int maxHistory: chosen("history")

    // Fewer allowed: the newest stay. A shorter history goes at once.
    onMaxPopupsChanged: popups = popups.slice(0, maxPopups)
    onMaxHistoryChanged: Qt.callLater(trimHistory)

    // How long `notification` stays as a pop-up, in ms; 0 means until dismissed.
    // expireTimeout is the sender's value in milliseconds, as D-Bus sends it
    // (the Quickshell 0.3 docs say seconds; `notify-send -t 2000` gives 2000):
    // -1 lets the server choose, 0 means never expire.
    function timeoutFor(notification: Notification): int {
        if (notification.urgency === NotificationUrgency.Critical) return 0;
        const ms = notification.expireTimeout;
        if (ms > 0) return ms;
        if (ms === 0) return 0;
        return notification.urgency === NotificationUrgency.Low ? lowTimeout : defaultTimeout;
    }

    function hidePopup(notification: Notification): void {
        popups = popups.filter(n => n !== notification);
    }

    // A pop-up ran out: it stays in the centre, unless the sender marked it
    // transient (not worth keeping).
    function popupTimedOut(notification: Notification): void {
        hidePopup(notification);
        if (notification.transient) notification.expire();
    }

    // With no card, no pop-up runs out to let a transient one go. Later: this
    // comes while the server is still handing the notification over.
    function neverShown(notification: Notification): void {
        if (notification.transient) Qt.callLater(() => notification.expire());
    }

    // The oldest go first, but never a critical one.
    function trimHistory(): void {
        const kept = server.trackedNotifications.values;
        const excess = kept.length - maxHistory;
        if (excess <= 0) return;
        kept.filter(n => n.urgency !== NotificationUrgency.Critical).slice(0, excess).forEach(n => n.expire());
    }

    function clearAll(): void {
        for (const notification of server.trackedNotifications.values.slice())
            notification.dismiss();
    }

    function ago(notification: Notification): string {
        const at = arrived[notification.id];
        const time = now;  // read whatever happens, so the binding follows the clock
        if (!at) return "";
        const minutes = Math.floor((time - at) / 60000);
        if (minutes < 1) return "now";
        if (minutes < 60) return minutes + "m";
        if (minutes < 24 * 60) return Math.floor(minutes / 60) + "h";
        return Qt.formatDateTime(at, "dd/MM");
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            // Before `tracked`: that can make the card at once, which asks for it.
            root.arrived[notification.id] = new Date();
            notification.tracked = true;
            notification.closed.connect(() => {
                root.hidePopup(notification);
                delete root.arrived[notification.id];
            });
            Qt.callLater(root.trimHistory);
            // After a shell reload the old ones come back; they already popped up.
            if (notification.lastGeneration) return;
            if ((root.doNotDisturb || GameMode.on) && notification.urgency !== NotificationUrgency.Critical) {
                root.neverShown(notification);
                return;
            }
            const popups = [notification, ...root.popups];
            root.popups = popups.slice(0, root.maxPopups);
            popups.slice(root.maxPopups).forEach(root.neverShown);
            // Shown, so heard even in do not disturb (an urgent one).
            Sounds.play("notify", true);
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // A write reads the file back: reset()'s changes would undo each other.
    Timer {
        id: saving
        interval: 200
        onTriggered: settingsFile.writeAdapter()
    }

    // Do not disturb and Settings > Notifications survive restarts.
    FileView {
        id: settingsFile
        path: Theme.stateDir + "/notifications.json"
        printErrors: false
        onAdapterUpdated: saving.restart()

        JsonAdapter {
            id: settings
            property bool doNotDisturb: false
            property int seconds: 10
            property string position: "top-right"
            property int popupCount: 4
            property int history: 200
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.centerOpen = !root.centerOpen;
        }

        function clear(): void {
            root.clearAll();
        }

        function dnd(): bool {
            root.doNotDisturb = !root.doNotDisturb;
            return root.doNotDisturb;
        }

        function count(): int {
            return root.count;
        }

        // One JSON object per open notification, newest first.
        function list(): string {
            return JSON.stringify(root.all.map(n => ({
                id: n.id,
                app: n.appName,
                summary: n.summary,
                urgency: NotificationUrgency.toString(n.urgency),
                expireTimeout: n.expireTimeout,
                transient: n.transient,
                popup: root.popups.includes(n),
                actions: n.actions.map(a => a.identifier)
            })));
        }
    }
}
