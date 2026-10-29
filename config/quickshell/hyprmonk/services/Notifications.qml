// The notification daemon (org.freedesktop.Notifications). Every notification
// is kept for the centre until dismissed; new ones also pop up, unless do not
// disturb or game mode is on (critical ones always do).
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

    // Milliseconds a pop-up stays when the sender does not say.
    readonly property int defaultTimeout: 10000
    readonly property int lowTimeout: 5000
    readonly property int maxPopups: 4

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

    function clearAll(): void {
        for (const notification of server.trackedNotifications.values.slice())
            notification.dismiss();
    }

    function ago(notification: Notification): string {
        const at = arrived[notification.id];
        if (!at) return "";
        const minutes = Math.floor((now - at) / 60000);
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
            notification.tracked = true;
            root.arrived[notification.id] = new Date();
            notification.closed.connect(() => {
                root.hidePopup(notification);
                delete root.arrived[notification.id];
            });
            // After a shell reload the old ones come back; they already popped up.
            if (notification.lastGeneration) return;
            if ((root.doNotDisturb || GameMode.on) && notification.urgency !== NotificationUrgency.Critical) return;
            root.popups = [notification, ...root.popups].slice(0, root.maxPopups);
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Do not disturb survives restarts.
    FileView {
        path: Theme.stateDir + "/notifications.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property bool doNotDisturb: false
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
