// Day/month and time, updated on the minute. Click: the calendar.
import QtQuick
import Quickshell
import qs.services

Module {
    interactive: true
    icon: "\u{F00ED}"
    label: Qt.formatDateTime(clock.date, "dd/MM HH:mm")

    onClicked: button => { if (button === Qt.LeftButton) Panels.toggle("calendar"); }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
