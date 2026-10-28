// Day/month and time, updated on the minute.
import Quickshell

Module {
    icon: "\u{F00ED}"
    label: Qt.formatDateTime(clock.date, "dd/MM HH:mm")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
