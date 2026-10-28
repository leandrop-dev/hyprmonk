// The calendar, under the bar's clock: a month at a time, today filled with
// the accent. The arrows or a scroll change the month; a click on its name
// comes back to this one.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

ColumnLayout {
    id: panel

    // Names in English like the rest of the shell. Weeks start on Monday
    // (0 Sunday to 6 Saturday): not from the locale, whose data has Portugal
    // (LC_TIME pt_PT) starting on Sunday.
    readonly property var english: Qt.locale("en_GB")
    readonly property int firstDay: 1
    readonly property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    readonly property date today: clock.date
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)

    // Six weeks from the start of the week the month begins in.
    readonly property var days: {
        const lead = (month.getDay() - firstDay + 7) % 7;
        return Array.from({ length: 42 }, (_, i) =>
            new Date(month.getFullYear(), month.getMonth(), 1 - lead + i));
    }

    function shift(months: int): void {
        month = new Date(month.getFullYear(), month.getMonth() + months, 1);
    }

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    spacing: 8

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: grid.implicitWidth
        Layout.maximumWidth: grid.implicitWidth
        spacing: 0

        Arrow {
            glyph: "\u{F0141}"
            onClicked: panel.shift(-1)
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: panel.english.toString(panel.month, "MMMM yyyy")
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSize

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.month = new Date(panel.today.getFullYear(), panel.today.getMonth(), 1)
            }
        }

        Arrow {
            glyph: "\u{F0142}"
            onClicked: panel.shift(1)
        }
    }

    GridLayout {
        id: grid

        Layout.alignment: Qt.AlignHCenter
        columns: 7
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
            model: 7

            Text {
                required property int index

                Layout.preferredWidth: 34
                Layout.preferredHeight: 24
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: panel.dayNames[(panel.firstDay + index) % 7]
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.smallFontSize
            }
        }

        Repeater {
            model: panel.days

            Rectangle {
                id: cell

                required property date modelData
                readonly property bool isToday: panel.sameDay(modelData, panel.today)
                readonly property bool inMonth: modelData.getMonth() === panel.month.getMonth()

                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.moduleRadius
                color: isToday ? Theme.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.getDate()
                    color: cell.isToday ? Theme.background
                         : cell.inMonth ? Theme.foreground : Theme.fg(0.25)
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                    font.bold: cell.isToday
                }
            }
        }

        // A scroll anywhere on the days changes the month.
        WheelHandler {
            onWheel: event => panel.shift(event.angleDelta.y > 0 ? -1 : 1)
        }
    }

    component Arrow: Rectangle {
        id: arrow

        property string glyph: ""
        signal clicked()

        implicitWidth: 28
        implicitHeight: 28
        radius: Theme.moduleRadius
        color: mouse.containsMouse ? Theme.fg(Theme.hoverOpacity) : "transparent"

        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked()
        }
    }
}
