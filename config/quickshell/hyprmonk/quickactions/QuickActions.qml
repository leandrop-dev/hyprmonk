// Quick actions (Super+A): a card in the middle of the focused screen with
// the switches used most, under their sections. Typing filters them (the
// letters in order, gaps allowed: "gm" finds "Game mode"); the arrows or Tab
// move, Enter or a click runs one and closes the card; Escape or a click
// elsewhere closes it. An action with options (the keyboard's effect) opens
// them in the same card instead; Escape, or Backspace with nothing typed,
// goes back.
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
            onRun: Power.nextProfile()
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
            section: "Appearance"
            icon: "\u{F050E}"
            label: "Appearance"
            value: Theme.tone.label
            options: Object.values(Theme.tones).map(tone => tone.label)
            onPicked: option => Theme.setTone(Object.keys(Theme.tones).find(name => Theme.tones[name].label === option))
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
            icon: "\u{F0335}"
            label: "Lights"
            on: Lights.on
            available: Lights.devices.length > 0
            onRun: Lights.toggle()
        },
        Action {
            section: "Appearance"
            icon: "\u{F09F9}"
            label: "Keyboard effect"
            value: Lights.keyboardEffect
            options: Lights.keyboardEffects
            available: Lights.keyboardEffects.length > 0
            onPicked: option => Lights.setKeyboardEffect(option)
        }
    ]

    // The rows: the actions, or the options of the one opened.
    readonly property var items: opened
        ? opened.options.map(option => ({
            section: opened.label,
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

    // A heading goes before the first row of each section.
    function startsSection(list: var, index: int): bool {
        return index === 0 || list[index].section !== list[index - 1].section;
    }

    readonly property int rowHeight: 42
    readonly property int headingHeight: 26

    function listHeight(list: var): int {
        if (list.length === 0) return rowHeight;
        return list.reduce((sum, _, i) => sum + rowHeight + (startsSection(list, i) ? headingHeight : 0), 0);
    }

    function clearSearch(): void {
        search.text = "";
        query = "";
    }

    // Each open starts from the top of the full list.
    onOpenChanged: {
        if (!open) return;
        Lights.refresh();
        opened = null;
        clearSearch();
        current = 0;
        search.forceActiveFocus();
    }

    function move(step: int): void {
        if (shown.length > 0) current = (current + step + shown.length) % shown.length;
    }

    function run(item: var): void {
        if (!item) return;
        if (opened) {
            Overlays.close();
            opened.picked(item.label);
        } else if (item.options.length > 0) {
            opened = item;
            clearSearch();
            current = Math.max(0, item.options.indexOf(item.value));
        } else {
            Overlays.close();
            item.run();
        }
    }

    function back(): void {
        const from = opened;
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

        Flickable {
            id: list

            // The picked row, from the top of the list.
            readonly property Item row: rows.count > root.current ? rows.itemAt(root.current).row : null
            readonly property real rowY: row ? row.parent.y + row.y : 0

            x: 12
            y: window.top
            width: window.cardWidth - 24
            height: Math.min(contentHeight, window.listMax)
            contentHeight: root.listHeight(root.shown)
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // Keep the picked row in view.
            onRowYChanged: {
                if (rowY < contentY) contentY = rowY;
                else if (rowY + root.rowHeight > contentY + height) contentY = rowY + root.rowHeight - height;
            }

            // The picked row; slides to the next one.
            Rectangle {
                visible: list.row !== null
                y: list.rowY
                width: list.width
                height: root.rowHeight
                radius: 10
                color: Theme.selection

                Behavior on y {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }

            Column {
                width: list.width

                Repeater {
                    id: rows

                    model: root.shown

                    Column {
                        id: entry

                        required property var modelData
                        required property int index
                        readonly property bool picked: index === root.current
                        readonly property alias row: row

                        width: list.width

                        SectionLabel {
                            visible: root.startsSection(root.shown, entry.index)
                            height: root.headingHeight
                            leftPadding: 12
                            bottomPadding: 6
                            verticalAlignment: Text.AlignBottom
                            text: entry.modelData.section
                            font.pixelSize: 10
                            font.capitalization: Font.MixedCase
                        }

                        Item {
                            id: row

                            width: list.width
                            height: root.rowHeight

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.current = entry.index
                                onClicked: root.run(entry.modelData)
                            }

                            Text {
                                id: glyph

                                x: 12
                                width: 22
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: entry.modelData.icon
                                color: entry.modelData.on === true || entry.modelData.chosen === true
                                    ? Theme.accent : Theme.foreground
                                font.family: Theme.font
                                font.pixelSize: 18
                                scale: entry.picked ? 1.15 : 1

                                Behavior on scale {
                                    NumberAnimation { duration: 120 }
                                }
                            }

                            Text {
                                anchors.left: glyph.right
                                anchors.leftMargin: 12
                                anchors.right: pill.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.label
                                color: Theme.foreground
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }

                            Chip {
                                id: pill

                                readonly property bool isSwitch: entry.modelData.on !== undefined

                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 160)
                                visible: isSwitch || entry.modelData.value !== ""
                                text: isSwitch ? (entry.modelData.on ? "on" : "off") : entry.modelData.value
                                on: entry.modelData.on
                                onClicked: root.run(entry.modelData)
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.shown.length === 0
                x: 12
                height: root.rowHeight
                verticalAlignment: Text.AlignVCenter
                text: "Nothing matches"
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }
    }
}
