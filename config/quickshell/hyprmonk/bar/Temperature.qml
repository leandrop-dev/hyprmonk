// CPU package temperature from whichever hwmon sensor is here (coretemp on
// Intel; k10temp or zenpower on AMD). hwmon numbers change between boots, so
// the sensor is looked up by name once, then read every few seconds while
// `watched`.
import QtQuick
import Quickshell.Io
import qs
import qs.services

Module {
    id: root

    property bool watched: false
    property string sensor: ""
    property int hot: 85
    property real celsius: NaN

    visible: !isNaN(celsius)
    icon: "\u{F050F}"
    label: Settings.degrees(celsius)
    tooltip: "CPU temperature\n" + sensor + " sensor, hot from " + Settings.degrees(hot)
    color: celsius >= hot ? Theme.warning : Theme.foreground

    Process {
        running: true
        command: ["sh", "-c", 'grep -HxE "coretemp|k10temp|zenpower" /sys/class/hwmon/hwmon*/name']
        stdout: StdioCollector {
            onStreamFinished: {
                const [file, name] = text.split("\n")[0].split(":");
                if (!name) return;
                root.sensor = name;
                reading.path = file.replace(/name$/, "temp1_input");
            }
        }
    }

    FileView {
        id: reading
        onLoaded: root.celsius = Number(text()) / 1000
    }

    Timer {
        running: root.watched && reading.path !== ""
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: reading.reload()
    }
}
