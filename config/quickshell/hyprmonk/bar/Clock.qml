// Day/month and time, 24-hour, updated on the minute; Settings > Bar can
// make it 12-hour, add seconds or leave the date out. Click: the calendar.
import QtQuick
import Quickshell
import qs.services

Module {
    id: root

    readonly property bool seconds: Settings.barChoice("seconds")
    readonly property string time: (Settings.barChoice("hours") === "12" ? "h:mm" : "HH:mm")
        + (seconds ? ":ss" : "") + (Settings.barChoice("hours") === "12" ? " AP" : "")

    interactive: true
    icon: "\u{F00ED}"
    label: Qt.formatDateTime(clock.date, (Settings.barChoice("date") ? "dd/MM " : "") + time)

    onClicked: button => { if (button === Qt.LeftButton) Panels.toggle("calendar"); }

    SystemClock {
        id: clock
        precision: root.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
