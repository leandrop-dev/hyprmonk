// Settings > Language and input: the shell's language, and from the next
// login this account's apps' (services/I18n.qml); the keyboard layouts (the
// first is the default; up to four, switched with the bar's layout or
// quick actions), the mouse's sensitivity, acceleration and scrolling, and
// whether focus follows the pointer. Applied at once (services/Settings.qml).
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
    // Up to ten it names: the code typed, then names starting with it, then
    // names holding it.
    readonly property var found: {
        const typed = field.text.trim().toLowerCase();
        if (!typed) return [];
        const codes = Object.keys(names);
        const starts = codes.filter(code => names[code].toLowerCase().startsWith(typed));
        const holds = codes.filter(code => !starts.includes(code) && names[code].toLowerCase().includes(typed));
        return (typed in names ? [typed] : []).concat(starts.filter(code => code !== typed), holds.filter(code => code !== typed)).slice(0, 10);
    }

    function setLayouts(list: var): void {
        Settings.setInput("layouts", list.join(","));
    }

    function add(code: string): void {
        if (!code || layouts.includes(code) || layouts.length >= 4) return;
        setLayouts(layouts.concat([code]));
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

    // The shell's language and this account's apps' (services/I18n.qml).
    SectionLabel {
        text: I18n.tr("Language")
    }

    Flow {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: I18n.languages

            Chip {
                required property var modelData
                text: modelData.name
                on: I18n.language === modelData.code
                onClicked: I18n.setLanguage(modelData.code)
            }
        }
    }

    Note {
        text: I18n.tr("The shell changes at once; apps follow from the next login.")
    }

    Note {
        visible: !I18n.generatedFor(I18n.language)
        color: Theme.warning
        text: I18n.tr("This system cannot give apps this language yet. In a terminal: %1, then %2.",
                      "sudo sed -i 's/^#" + I18n.current.lang + "/" + I18n.current.lang + "/' /etc/locale.gen", "sudo locale-gen")
    }

    SectionLabel {
        Layout.topMargin: 8
        text: I18n.tr("Keyboard layouts")
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
                text: I18n.tr("default")
                on: true
            }

            Chip {
                visible: layout.index > 0
                text: I18n.tr("Make default")
                onClicked: page.setLayouts([layout.modelData].concat(page.layouts.filter(code => code !== layout.modelData)))
            }

            Chip {
                visible: page.layouts.length > 1
                text: I18n.tr("Remove")
                onClicked: page.setLayouts(page.layouts.filter(code => code !== layout.modelData))
            }
        }
    }

    // The layouts the typed text names, by code or name; Enter adds the best
    // (page.match) unless one is marked.
    SearchField {
        id: field

        Layout.preferredWidth: 260
        Layout.bottomMargin: 12
        visible: page.layouts.length < 4
        placeholder: I18n.tr("Add a layout")
        message: I18n.tr("No such layout")
        results: page.found.map(code => ({
            code,
            text: page.names[code],
            detail: page.layouts.includes(code) ? I18n.tr("added") : code,
            selected: page.layouts.includes(code)
        }))
        onAccepted: page.add(page.match)
        onPicked: result => page.add(result.code)
    }

    SectionLabel {
        text: I18n.tr("Mouse")
    }

    SettingSlider {
        Layout.fillWidth: true
        label: I18n.tr("Sensitivity")
        from: -100
        to: 100
        value: Math.round(Settings.inputValue("sensitivity") * 100)
        shown: (Settings.inputValue("sensitivity") > 0 ? "+" : "") + Settings.inputValue("sensitivity").toFixed(2)
        onMoved: value => Settings.setInput("sensitivity", Math.round(value) / 100)
    }

    Row {
        Layout.topMargin: 4
        text: I18n.tr("Acceleration")

        Chip {
            text: I18n.tr("Adaptive")
            on: Settings.inputValue("accel") === "adaptive"
            onClicked: Settings.setInput("accel", "adaptive")
        }

        Chip {
            text: I18n.tr("Flat")
            on: Settings.inputValue("accel") === "flat"
            onClicked: Settings.setInput("accel", "flat")
        }
    }

    Row {
        text: I18n.tr("Natural scroll")

        Chip {
            text: Settings.inputValue("naturalScroll") ? I18n.tr("on") : I18n.tr("off")
            on: Settings.inputValue("naturalScroll")
            onClicked: Settings.setInput("naturalScroll", !Settings.inputValue("naturalScroll"))
        }
    }

    SectionLabel {
        Layout.topMargin: 12
        text: I18n.tr("Focus")
    }

    Row {
        text: I18n.tr("Focus follows the pointer")

        Chip {
            text: Settings.inputValue("followMouse") ? I18n.tr("on") : I18n.tr("off")
            on: Settings.inputValue("followMouse")
            onClicked: Settings.setInput("followMouse", !Settings.inputValue("followMouse"))
        }
    }

    Note {
        visible: !Settings.inputValue("followMouse")
        text: I18n.tr("A click moves the keyboard to a window; scrolling still follows the pointer.")
    }

    Item {
        Layout.fillHeight: true
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Settings.inputChanged
        text: I18n.tr("Back to the defaults")
        onClicked: Settings.resetInput()
    }
}
