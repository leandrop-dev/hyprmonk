// Settings > Input: the keyboard layouts (the first is the default; up to
// four, switched with the bar's layout or quick actions), the mouse's
// sensitivity, acceleration and scrolling, and whether focus follows the
// pointer. Applied at once (services/Settings.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: page

    readonly property var layouts: Settings.inputValue("layouts").split(",")
    // XKB's layouts by code: { pt: "Portuguese", ... }.
    readonly property var names: {
        const names = {};
        let inside = false;
        for (const line of rules.text().split("\n")) {
            if (line.startsWith("!")) {
                inside = line.trim() === "! layout";
                continue;
            }
            const parts = inside ? /^\s+(\S+)\s+(.+)$/.exec(line) : null;
            if (parts) names[parts[1]] = parts[2].trim();
        }
        return names;
    }
    // What the typed text names: a code, else the first name starting or,
    // failing that, containing it.
    readonly property string match: {
        const typed = field.text.trim().toLowerCase();
        if (!typed) return "";
        if (typed in names) return typed;
        const codes = Object.keys(names);
        return codes.find(code => names[code].toLowerCase().startsWith(typed))
            ?? codes.find(code => names[code].toLowerCase().includes(typed)) ?? "";
    }

    function setLayouts(list: var): void {
        Settings.setInput("layouts", list.join(","));
    }

    function add(): void {
        if (!match || layouts.includes(match) || layouts.length >= 4) return;
        setLayouts(layouts.concat([match]));
        field.text = "";
    }

    spacing: 8

    FileView {
        id: rules
        path: "/usr/share/X11/xkb/rules/base.lst"
        blockLoading: true
        printErrors: false
    }

    component Row: RowLayout {
        property alias text: label.text

        Layout.fillWidth: true

        Text {
            id: label
            Layout.fillWidth: true
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
            elide: Text.ElideRight
        }
    }

    component Note: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    SectionLabel {
        text: "Keyboard layouts"
    }

    Repeater {
        model: page.layouts

        Row {
            id: layout

            required property string modelData
            required property int index

            text: (page.names[modelData] ?? modelData) + "  " + modelData

            Chip {
                visible: layout.index === 0
                text: "default"
                on: true
            }

            Chip {
                visible: layout.index > 0
                text: "Make default"
                onClicked: page.setLayouts([layout.modelData].concat(page.layouts.filter(code => code !== layout.modelData)))
            }

            Chip {
                visible: page.layouts.length > 1
                text: "Remove"
                onClicked: page.setLayouts(page.layouts.filter(code => code !== layout.modelData))
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        visible: page.layouts.length < 4
        spacing: 12

        Rectangle {
            implicitWidth: 180
            implicitHeight: 30
            radius: Theme.moduleRadius
            color: Theme.fg(0.06)
            border.width: 1
            border.color: field.activeFocus ? Qt.alpha(Theme.accent, 0.8) : Theme.rim

            TextInput {
                id: field

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground
                selectionColor: Qt.alpha(Theme.accent, 0.55)
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
                clip: true

                onAccepted: page.add()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !field.text
                    text: "Add a layout"
                    color: Theme.fg(Theme.dimOpacity)
                    font: field.font
                }
            }
        }

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            visible: field.text.trim() !== ""
            text: !page.match ? "No such layout"
                : page.layouts.includes(page.match) ? "Already there"
                : "Enter adds " + page.names[page.match]
            color: page.match && !page.layouts.includes(page.match) ? Theme.fg(Theme.dimOpacity) : Theme.warning
            font.family: Theme.font
            font.pixelSize: Theme.bodyFontSize
        }
    }

    SectionLabel {
        text: "Mouse"
    }

    SettingSlider {
        Layout.fillWidth: true
        label: "Sensitivity"
        from: -100
        to: 100
        value: Math.round(Settings.inputValue("sensitivity") * 100)
        shown: (Settings.inputValue("sensitivity") > 0 ? "+" : "") + Settings.inputValue("sensitivity").toFixed(2)
        onMoved: value => Settings.setInput("sensitivity", Math.round(value) / 100)
    }

    Row {
        Layout.topMargin: 4
        text: "Acceleration"

        Chip {
            text: "Adaptive"
            on: Settings.inputValue("accel") === "adaptive"
            onClicked: Settings.setInput("accel", "adaptive")
        }

        Chip {
            text: "Flat"
            on: Settings.inputValue("accel") === "flat"
            onClicked: Settings.setInput("accel", "flat")
        }
    }

    Row {
        text: "Natural scroll"

        Chip {
            text: Settings.inputValue("naturalScroll") ? "on" : "off"
            on: Settings.inputValue("naturalScroll")
            onClicked: Settings.setInput("naturalScroll", !Settings.inputValue("naturalScroll"))
        }
    }

    SectionLabel {
        Layout.topMargin: 12
        text: "Focus"
    }

    Row {
        text: "Focus follows the pointer"

        Chip {
            text: Settings.inputValue("followMouse") ? "on" : "off"
            on: Settings.inputValue("followMouse")
            onClicked: Settings.setInput("followMouse", !Settings.inputValue("followMouse"))
        }
    }

    Note {
        visible: !Settings.inputValue("followMouse")
        text: "A click moves the keyboard to a window; scrolling still follows the pointer."
    }

    Item {
        Layout.fillHeight: true
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Settings.inputChanged
        text: "Back to the defaults"
        onClicked: Settings.resetInput()
    }
}
