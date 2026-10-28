// Date and time, updated on the minute.
import QtQuick
import Quickshell

BarText {
    text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
    font.bold: true

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
