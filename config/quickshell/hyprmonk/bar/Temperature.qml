// The CPU package temperature (services/Hardware.qml, read while the drawer
// is open), in the warning colour from `hot` up.
import QtQuick
import qs
import qs.services

Module {
    id: root

    property int hot: 85
    readonly property real celsius: Hardware.cpuTemp

    visible: !isNaN(celsius)
    icon: "\u{F050F}"
    label: Settings.degrees(celsius)
    tooltip: I18n.tr("CPU temperature\n%1 sensor, hot from %2", Hardware.cpuSensor, Settings.degrees(hot))
    color: celsius >= hot ? Theme.warning : Theme.foreground
}
