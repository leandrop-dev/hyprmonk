// Quick actions (Super+A): a card in the middle of the focused screen with
// the switches used most, under their sections. Typing filters them (the
// letters in order, gaps allowed: "gm" finds "Game mode"); the arrows or Tab
// move, Enter or a click runs one and closes the card; Escape or a click
// elsewhere closes it. An action with options (the panels' tone, the
// spectrum's style, the login screen's look) opens them in the same card instead; Escape, or
// Backspace with nothing typed, goes back.
//
// IPC: qs -c hyprmonk ipc call overlays toggle quickactions
import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets

Scope {
    id: root

    readonly property bool open: Overlays.open === "quickactions"
    property string query: ""
    property int current: 0
    property Action opened: null  // the action whose options are showing

    readonly property list<Action> actions: [
        Action {
            section: "Audio"
            icon: "\u{F04C3}"
            label: "Audio output"
            value: Audio.sinkName
            available: Audio.sinks.length > 0
            onRun: {
                const sinks = Audio.sinks;
                Audio.setDefault(sinks[(sinks.indexOf(Audio.sink) + 1) % sinks.length]);
            }
        },
        Action {
            section: "Audio"
            icon: "\u{F036C}"
            label: "Microphone"
            on: !Audio.micMuted
            available: Audio.source?.audio != null
            onRun: Audio.source.audio.muted = !Audio.source.audio.muted
        },
        Action {
            section: "System"
            icon: "\u{F0297}"
            label: "Game mode"
            on: GameMode.on
            onRun: GameMode.toggle()
        },
        Action {
            section: "System"
            icon: "\u{F009B}"
            label: "Do not disturb"
            on: Notifications.doNotDisturb
            onRun: Notifications.doNotDisturb = !Notifications.doNotDisturb
        },
        Action {
            section: "System"
            icon: "\u{F04C5}"
            label: "Power profile"
            value: Power.profileName
            options: Power.names
            onPicked: option => Power.setProfile(option)
        },
        Action {
            section: "System"
            icon: "\u{F030C}"
            label: "Keyboard layout"
            value: Keyboard.layouts[Keyboard.index] ?? ""
            available: Keyboard.layouts.length > 1
            onRun: Keyboard.next()
        },
        Action {
            section: "System"
            icon: "\u{F0425}"
            label: "Power menu"
            onRun: Overlays.toggle("power")
        },
        Action {
            section: "Recording"
            icon: "\u{F044A}"
            label: "Screen recording"
            on: Recorder.active
            onRun: Recorder.toggle()
        },
        Action {
            section: "Recording"
            icon: "\u{F0489}"
            label: "Record area"
            value: Recorder.area
            options: Recorder.areas
            stays: true
            onPicked: option => Recorder.setArea(option)
        },
        Action {
            section: "Recording"
            icon: "\u{F04C3}"
            label: "Record system sound"
            on: Recorder.sound
            stays: true
            onRun: Recorder.setSound(!Recorder.sound)
        },
        Action {
            section: "Recording"
            icon: "\u{F036C}"
            label: "Record microphone"
            on: Recorder.microphone
            stays: true
            onRun: Recorder.setMicrophone(!Recorder.microphone)
        },
        Action {
            section: "Recording"
            icon: "\u{F0459}"
            label: "Keep the last minute"
            on: Recorder.replaying
            onRun: Recorder.toggleReplay()
        },
        Action {
            section: "Recording"
            icon: "\u{F0193}"
            label: "Save the last minute"
            available: Recorder.replaying
            onRun: Recorder.saveReplay()
        },
        Action {
            section: "Appearance"
            icon: "\u{F050E}"
            label: "Appearance"
            value: Theme.tones[Theme.savedTone].label
            options: {
                const tones = Object.values(Theme.tones);
                return tones.filter(tone => !tone.light).concat(tones.filter(tone => tone.light)).map(tone => tone.label);
            }
            sections: {
                const sections = {};
                for (const tone of Object.values(Theme.tones)) sections[tone.label] = tone.light ? "Light" : "Dark";
                return sections;
            }
            previews: true
            onPicked: option => Theme.setTone(Object.keys(Theme.tones).find(name => Theme.tones[name].label === option))
            onPreviewed: option => Theme.previewTone = Object.keys(Theme.tones).find(name => Theme.tones[name].label === option) ?? ""
            onUnpreviewed: Theme.previewTone = ""
        },
        Action {
            section: "Appearance"
            icon: "\u{F0128}"
            label: "Spectrum"
            value: Cava.styles[Cava.savedStyle]
            options: Object.values(Cava.styles)
            previews: true
            onPicked: option => Cava.setStyle(Object.keys(Cava.styles).find(name => Cava.styles[name] === option))
            onPreviewed: option => Cava.previewStyle = Object.keys(Cava.styles).find(name => Cava.styles[name] === option) ?? ""
            onUnpreviewed: Cava.previewStyle = ""
        },
        Action {
            section: "Appearance"
            icon: "\u{F0E09}"
            label: "Wallpaper"
            onRun: Overlays.toggle("wallpapers")
        },
        Action {
            section: "Appearance"
            icon: "\u{F049D}"
            label: "Random wallpaper"
            available: Wallpaper.files.length > 1
            onRun: Wallpaper.random()
        },
        Action {
            section: "Appearance"
            icon: "\u{F0342}"
            label: "Login look"
            value: Login.label(Login.current)
            options: Login.labels
            available: Login.ready
            onPicked: option => Login.pick(Login.looks[Login.labels.indexOf(option)])
        }
    ]

    // The rows: the actions, or the options of the one opened.
    readonly property var items: opened
        ? opened.options.map(option => ({
            section: opened.sections[option] ?? opened.label,
            icon: option === opened.value ? "\u{F043E}" : "\u{F043D}",
            label: option,
            chosen: option === opened.value,
            value: "",
            options: []
        }))
        : actions.filter(a => a.available)
    readonly property var shown: items.filter(item => matches(item.label, query))

    // The letters typed appear in the label in order (spaces ignored).
    function matches(label: string, typed: string): bool {
        const text = label.toLowerCase();
        let at = 0;
        for (const c of typed.toLowerCase().replace(/\s/g, "")) {
            at = text.indexOf(c, at) + 1;
            if (at === 0) return false;
        }
        return true;
    }

    readonly property int rowHeight: 42
    readonly property int headingHeight: 26

    function clearSearch(): void {
        search.text = "";
        query = "";
    }

    // While a list that previews is open, the option under the cursor is
    // tried live; Enter keeps it, leaving the list puts back what was there.
    readonly property string tried: opened?.previews ? (shown[current]?.label ?? "") : ""

    onTriedChanged: if (opened?.previews && tried !== "") opened.previewed(tried)

    onOpenChanged: {
        if (!open) {
            opened?.unpreviewed();
            return;
        }
        pointer = Qt.point(-1, -1);
        search.forceActiveFocus();
        Login.refresh();
    }

    // Each open starts from the top of the full list, put back while hidden.
    function reset(): void {
        opened = null;
        clearSearch();
        current = 0;
    }

    // Hovering picks only when the pointer really moves: rows that appear or
    // slide under a still pointer (typing, scrolling, the card opening) are
    // not picked. `pointer` is where it was last, in the window; (-1, -1)
    // until it moves after the card opens.
    property point pointer: Qt.point(-1, -1)

    function hover(at: point, index: int): void {
        if (pointer.x >= 0 && (at.x !== pointer.x || at.y !== pointer.y)) current = index;
        pointer = at;
    }

    function move(step: int): void {
        if (shown.length > 0) current = (current + step + shown.length) % shown.length;
    }

    function run(item: var): void {
        if (!item) return;
        if (opened) {
            opened.picked(item.label);
            if (opened.stays) back();
            else Overlays.close();
        } else if (item.options.length > 0) {
            opened = item;
            clearSearch();
            current = Math.max(0, item.options.indexOf(item.value));
        } else {
            if (!item.stays) Overlays.close();
            item.run();
        }
    }

    function back(): void {
        const from = opened;
        from.unpreviewed();
        opened = null;
        clearSearch();
        current = Math.max(0, shown.indexOf(from));
    }

    Overlay {
        id: window

        readonly property int top: 44  // the search line, above the list
        // The list scrolls past this.
        readonly property int listMax: windowHeight - margin * 2 - top - 12

        name: "hyprmonk-quickactions"
        open: root.open
        cardHeight: top + list.height + 12
        // Most of the screen's height, the card at its top: filtering or
        // opening options changes the card's height, never where it starts.
        windowHeight: Math.round((screen?.height ?? 1080) * 0.8)
        onDismissed: Overlays.close()
        onFolded: root.reset()

        TextInput {
            id: search

            x: 20
            y: 16
            width: window.cardWidth - 40
            focus: true
            color: Theme.foreground
            selectionColor: Qt.alpha(Theme.accent, 0.4)
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize

            onTextEdited: {
                root.query = text;
                root.current = 0;
            }

            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            Keys.onTabPressed: root.move(1)
            Keys.onBacktabPressed: root.move(-1)
            Keys.onReturnPressed: root.run(root.shown[root.current])
            Keys.onEnterPressed: root.run(root.shown[root.current])
            Keys.onEscapePressed: {
                if (root.opened) root.back();
                else Overlays.close();
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Backspace && text === "" && root.opened) {
                    root.back();
                    event.accepted = true;
                }
            }

            Text {
                visible: !search.text
                text: root.opened?.label ?? "Quick actions"
                color: Theme.fg(Theme.dimOpacity)
                font: search.font
            }
        }

        SectionList {
            id: list

            x: 12
            y: window.top
            width: window.cardWidth - 24
            height: Math.min(contentHeight, window.listMax)
            interactive: contentHeight > height
            model: root.shown
            current: root.current
            rowHeight: root.rowHeight
            headingHeight: root.headingHeight

            heading: SectionLabel {
                required property var modelData

                leftPadding: 12
                bottomPadding: 6
                verticalAlignment: Text.AlignBottom
                text: modelData.section
                font.pixelSize: 10
                font.capitalization: Font.MixedCase
            }

            delegate: Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool picked: index === root.current

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: mouse => root.hover(mapToItem(null, mouse.x, mouse.y), row.index)
                    onClicked: root.run(row.modelData)
                }

                Text {
                    id: glyph

                    x: 12
                    width: 22
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: row.modelData.icon
                    color: row.modelData.on === true || row.modelData.chosen === true
                        ? Theme.accent : Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: 18
                    scale: row.picked ? 1.15 : 1

                    Behavior on scale {
                        NumberAnimation { duration: 120 }
                    }
                }

                Text {
                    anchors.left: glyph.right
                    anchors.leftMargin: 12
                    anchors.right: pill.visible ? pill.left : parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    textFormat: Text.PlainText
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                Chip {
                    id: pill

                    readonly property bool isSwitch: row.modelData.on !== undefined

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 160)
                    visible: isSwitch || row.modelData.value !== ""
                    text: isSwitch ? (row.modelData.on ? "on" : "off") : row.modelData.value
                    on: row.modelData.on
                    onClicked: root.run(row.modelData)
                }
            }
        }
    }
}
