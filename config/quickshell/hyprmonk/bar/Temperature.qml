// CPU package temperature from the hwmon sensor named `sensor`
// (coretemp on Intel; k10temp on AMD). hwmon numbers change between boots,
// so the sensor is looked up by name once, then read every few seconds.
import QtQuick
import Quickshell.Io
import qs

BarText {
    id: root

    property string sensor: "coretemp"
    property int hot: 85
    property real celsius: NaN

    visible: !isNaN(celsius)
    text: "\u{F050F} " + Math.round(celsius) + "°C"
    color: celsius >= hot ? Theme.warning : Theme.text

    Process {
        running: true
        command: ["sh", "-c", 'grep -lx "$1" /sys/class/hwmon/hwmon*/name', "sh", root.sensor]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.split("\n")[0];
                if (name) reading.path = name.replace(/name$/, "temp1_input");
            }
        }
    }

    FileView {
        id: reading
        onLoaded: root.celsius = Number(text()) / 1000
    }

    Timer {
        running: reading.path !== ""
        interval: 5000
        repeat: true
        onTriggered: reading.reload()
    }
}
