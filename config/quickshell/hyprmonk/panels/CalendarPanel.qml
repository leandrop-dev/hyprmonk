// The calendar, under the bar's clock: a month at a time, today filled with
// the accent, holidays (services/Calendar.qml) written in it and a dot for
// each event (services/Events.qml). The arrows or a scroll change the month;
// a click on its name comes back to this one. A click on a day lists what is
// on it under the month (today until then), where a local event can be
// added or deleted.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: panel

    // Names in the shell's language (services/I18n.qml). Weeks start on
    // Monday (0 Sunday to 6 Saturday): not from the locale, whose data has
    // Portugal starting on Sunday. Days by two letters in English (Mo, Tu),
    // three where two would repeat (Seg, Ter, Qua, Qui, Sex in Portuguese).
    readonly property var names: I18n.locale
    readonly property int firstDay: 1
    readonly property var dayNames: Array.from({ length: 7 }, (_, day) => {
        const name = names.dayName(day, Locale.ShortFormat).replace(".", "");
        return panel.capital(name.slice(0, I18n.language === "en" ? 2 : 3));
    })
    // The country's own names for its holidays first, in its language.
    readonly property bool localFirst: I18n.language.endsWith("_" + Calendar.country)

    function capital(text: string): string {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    readonly property date today: clock.date
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)
    // The day listed under the month: today, or one clicked.
    property date selected: today
    readonly property var holidays: Calendar.holidaysOn(selected)
    readonly property var events: Events.eventsOn(selected)
    property bool adding: false  // the form for a new local event shown

    onMonthChanged: Calendar.need(month)
    onDaysChanged: Events.show(days[0], days[41])
    onSelectedChanged: adding = false
    Component.onCompleted: {
        Calendar.need(month);
        Events.show(days[0], days[41]);
    }

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
            text: panel.capital(panel.names.toString(panel.month, I18n.tr("MMMM yyyy")))
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.fontSize

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    panel.month = new Date(panel.today.getFullYear(), panel.today.getMonth(), 1);
                    panel.selected = panel.today;
                }
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
                readonly property bool isSelected: panel.sameDay(modelData, panel.selected)
                // A holiday's number is in the accent (fainter when only
                // optional or regional).
                readonly property var holidays: Calendar.holidaysOn(modelData)
                readonly property bool holiday: holidays.length > 0
                readonly property bool fullHoliday: holidays.some(entry => !entry.optional && !entry.regional)

                Layout.preferredWidth: 34
                Layout.preferredHeight: 30
                radius: Theme.moduleRadius
                color: isToday ? Theme.accent : dayMouse.containsMouse ? Theme.fg(Theme.hoverOpacity) : "transparent"
                border.width: isSelected && !isToday ? 1 : 0
                border.color: Theme.fg(0.45)

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.getDate()
                    color: cell.isToday ? Theme.background
                         : cell.holiday ? Qt.alpha(Theme.accent, (cell.fullHoliday ? 1 : 0.6) * (cell.inMonth ? 1 : 0.4))
                         : cell.inMonth ? Theme.foreground : Theme.fg(0.25)
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                    font.bold: cell.isToday || cell.fullHoliday
                }

                // A dot for each event (three at most), in its calendar's colour.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    spacing: 2

                    Repeater {
                        model: Events.eventsOn(cell.modelData).slice(0, 3)

                        Rectangle {
                            required property var modelData

                            width: 4
                            height: 4
                            radius: 2
                            color: cell.isToday ? Theme.background : Events.colourOf(modelData.calendar)
                            opacity: cell.inMonth ? 1 : 0.4
                        }
                    }
                }

                MouseArea {
                    id: dayMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.selected = cell.modelData;
                        if (!cell.inMonth) panel.month = new Date(cell.modelData.getFullYear(), cell.modelData.getMonth(), 1);
                    }
                }
            }
        }

        // A scroll anywhere on the days changes the month.
        WheelHandler {
            onWheel: event => panel.shift(event.angleDelta.y > 0 ? -1 : 1)
        }
    }

    // The selected day: its name, then its holidays (the local name under the
    // English one when they differ).
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: grid.implicitWidth
        Layout.preferredHeight: 1
        color: Theme.rim
    }

    Text {
        Layout.preferredWidth: grid.implicitWidth
        Layout.alignment: Qt.AlignHCenter
        text: panel.sameDay(panel.selected, panel.today) ? I18n.tr("Today") : panel.capital(panel.names.toString(panel.selected, I18n.tr("dddd d MMMM")))
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    Repeater {
        model: panel.holidays

        RowLayout {
            required property var modelData

            Layout.preferredWidth: grid.implicitWidth
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignTop
                text: "\u{F00ED}"  // a calendar
                color: Qt.alpha(Theme.accent, modelData.optional || modelData.regional ? 0.6 : 1)
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: panel.localFirst ? modelData.local : modelData.name
                    wrapMode: Text.Wrap
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.bodyFontSize
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: [modelData.local !== modelData.name ? (panel.localFirst ? modelData.name : modelData.local) : "",
                           modelData.regional ? I18n.tr("regional") : "", modelData.optional ? I18n.tr("optional") : ""]
                        .filter(part => part !== "").join(" · ")
                    wrapMode: Text.Wrap
                    color: Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.smallFontSize
                }
            }
        }
    }

    // Its events: the time (or all day), the title, and the calendar when not
    // the local one. A local event can be deleted from here.
    Repeater {
        model: panel.events

        Item {
            id: eventRow

            required property var modelData

            Layout.preferredWidth: grid.implicitWidth
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: eventColumn.implicitHeight

            Rectangle {
                id: bar
                width: 3
                height: parent.height
                radius: 1.5
                color: Events.colourOf(eventRow.modelData.calendar)
            }

            ColumnLayout {
                id: eventColumn

                anchors.left: bar.right
                anchors.leftMargin: 9
                anchors.right: remove.left
                anchors.rightMargin: 4
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: eventRow.modelData.title + (eventRow.modelData.repeats ? "  \u{F0456}" : "")  // a repeat sign
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.bodyFontSize
                }

                Text {
                    Layout.fillWidth: true
                    text: [eventRow.modelData.allDay ? I18n.tr("All day") : eventRow.modelData.start + " – " + eventRow.modelData.end,
                           eventRow.modelData.location,
                           eventRow.modelData.calendar === "local" ? "" : Events.nameOf(eventRow.modelData.calendar)]
                        .filter(part => part).join(" · ")
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    color: Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.smallFontSize
                }
            }

            HoverHandler {
                id: rowHover
            }

            Text {
                id: remove

                anchors.right: parent.right
                anchors.top: parent.top
                visible: eventRow.modelData.calendar === "local"
                opacity: rowHover.hovered ? (removeMouse.containsMouse ? 1 : 0.6) : 0
                text: "\u{F0156}"  // a cross
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize

                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Events.remove(eventRow.modelData.uid)
                }
            }
        }
    }

    Text {
        Layout.preferredWidth: grid.implicitWidth
        Layout.alignment: Qt.AlignHCenter
        visible: panel.holidays.length === 0 && panel.events.length === 0 && !panel.adding
        text: I18n.tr("Nothing on this day")
        color: Theme.fg(0.45)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    // A new local event on the selected day: its title, from and to (none
    // for all day) and how often it repeats.
    Text {
        Layout.preferredWidth: grid.implicitWidth
        Layout.alignment: Qt.AlignHCenter
        visible: Events.available && !panel.adding
        text: "\u{F0415}  " + I18n.tr("Add an event")  // a plus
        color: addMouse.containsMouse ? Theme.foreground : Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize

        MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                panel.adding = true;
                title.text = "";
                startTime.text = "";
                endTime.text = "";
                form.repeat = "";
                title.takeFocus();
            }
        }
    }

    ColumnLayout {
        id: form

        property string repeat: ""
        readonly property var timePattern: /^([01]?\d|2[0-3]):[0-5]\d$/
        readonly property bool timesOk: (startTime.text === "" && endTime.text === "")
            || (timePattern.test(startTime.text) && (endTime.text === "" || timePattern.test(endTime.text)))
        readonly property bool ready: title.text.trim() !== "" && timesOk

        function save(): void {
            if (!ready) return;
            Events.add(title.text, panel.selected, startTime.text, endTime.text, repeat);
            panel.adding = false;
        }

        Layout.preferredWidth: grid.implicitWidth
        Layout.alignment: Qt.AlignHCenter
        visible: panel.adding
        spacing: 6

        TextField {
            id: title
            Layout.fillWidth: true
            placeholder: I18n.tr("Title")
            onAccepted: form.save()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: startTime
                Layout.preferredWidth: 64
                placeholder: I18n.tr("from")
                horizontalAlignment: TextInput.AlignHCenter
                onAccepted: form.save()
            }

            TextField {
                id: endTime
                Layout.preferredWidth: 64
                placeholder: I18n.tr("to")
                horizontalAlignment: TextInput.AlignHCenter
                onAccepted: form.save()
            }

            Text {
                Layout.fillWidth: true
                text: form.timesOk ? (startTime.text === "" ? I18n.tr("all day") : "") : I18n.tr("as 14:30")
                color: form.timesOk ? Theme.fg(Theme.dimOpacity) : Theme.warning
                font.family: Theme.font
                font.pixelSize: Theme.smallFontSize
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [{ key: "", name: "Once" }, { key: "weekly", name: "Weekly" },
                        { key: "monthly", name: "Monthly" }, { key: "yearly", name: "Yearly" }]

                Chip {
                    required property var modelData
                    text: modelData.name
                    on: form.repeat === modelData.key
                    onClicked: form.repeat = modelData.key
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 6

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: I18n.tr("Cancel")
                onClicked: panel.adding = false
            }

            Button {
                text: I18n.tr("Add")
                primary: true
                enabled: form.ready
                onClicked: form.save()
            }
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
