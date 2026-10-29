// The key guide (Super+K): every keybinding, by section, read from Hyprland
// on each open (hypr/binds.lua files each description as "Section: text").
// Binds sharing a description share a row ("Super + 1 … 0"). Typing filters:
// every word must appear in the row. The arrows and Page Up/Down move,
// Escape or a click elsewhere closes it.
//
// IPC: qs -c hyprmonk ipc call overlays toggle keyguide
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.widgets

Scope {
    id: root

    readonly property bool open: Overlays.open === "keyguide"
    property var rows: []  // [{section, keys, description}]
    property string query: ""
    property int current: 0

    readonly property var shown: rows.filter(row => {
        const text = (row.section + " " + row.keys + " " + row.description).toLowerCase();
        return query.toLowerCase().split(/\s+/).every(word => text.includes(word));
    })

    readonly property int rowHeight: 30
    readonly property int headingHeight: 28
    readonly property int keysWidth: 240

    // Modifiers in the usual order, from Hyprland's mask.
    function modifiers(mask: int): var {
        return [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
            .filter(([bit]) => mask & bit)
            .map(([, name]) => name);
    }

    readonly property var keyNames: ({
        "Return": "Enter",
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "mouse:272": "Left drag", "mouse:273": "Right drag",
        "mouse_down": "Scroll down", "mouse_up": "Scroll up",
        "XF86AudioRaiseVolume": "Volume +", "XF86AudioLowerVolume": "Volume −",
        "XF86AudioMute": "Mute", "XF86AudioMicMute": "Mic mute",
        "XF86AudioPlay": "Play", "XF86AudioPause": "Pause",
        "XF86AudioNext": "Next", "XF86AudioPrev": "Previous"
    })

    function keyName(key: string): string {
        return keyNames[key] ?? (key.length === 1 ? key.toUpperCase() : key);
    }

    // One row's keys: the modifiers once when they match, and a long run of
    // keys shortened to its ends.
    function keysOf(binds: var): string {
        const mask = binds[0].modmask;
        const keys = binds.map(b => keyName(b.key));
        if (binds.every(b => b.modmask === mask)) {
            const list = keys.length > 4 ? keys[0] + " … " + keys[keys.length - 1] : keys.join(" / ");
            return [...modifiers(mask), list].join(" + ");
        }
        return binds.map(b => [...modifiers(b.modmask), keyName(b.key)].join(" + ")).join(" / ");
    }

    function load(binds: var): void {
        const groups = [];
        for (const bind of binds) {
            // A mode's own keys show on its card (the screenshot mode's).
            if (bind.non_consuming || bind.submap || !bind.description) continue;
            const at = bind.description.indexOf(": ");
            const section = at > 0 ? bind.description.slice(0, at) : "Other";
            const description = at > 0 ? bind.description.slice(at + 2) : bind.description;
            const group = groups.find(g => g.section === section && g.description === description);
            if (group) group.binds.push(bind);
            else groups.push({ section, description, binds: [bind] });
        }
        // Sections in the order they first appear, binds in theirs. (Not
        // sort(): the QML engine's is not stable.)
        const sorted = [];
        for (const section of new Set(groups.map(g => g.section)))
            sorted.push(...groups.filter(g => g.section === section));
        root.rows = sorted.map(g => ({ section: g.section, description: g.description, keys: keysOf(g.binds) }));
    }

    onOpenChanged: {
        if (!open) return;
        reader.running = true;
        pointer = Qt.point(-1, -1);
        search.forceActiveFocus();
    }

    // Each open starts from the top of the full list, put back while hidden.
    function reset(): void {
        search.text = "";
        query = "";
        current = 0;
        list.contentY = 0;
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
        if (shown.length > 0) current = Math.max(0, Math.min(shown.length - 1, current + step));
    }

    // Read once at start too, so the first open has its size at once.
    Process {
        id: reader
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.load(JSON.parse(text))
        }
    }

    Overlay {
        id: window

        readonly property int top: 44
        readonly property int listMax: Math.round((screen?.height ?? 1080) * 0.6)

        name: "hyprmonk-keyguide"
        open: root.open
        cardWidth: 900
        // Sized for every row, so filtering does not resize it.
        cardHeight: top + Math.min(list.measure(root.rows).height, listMax) + 12
        windowHeight: top + listMax + 12 + margin * 2
        onDismissed: Overlays.close()
        onFolded: root.reset()

        Text {
            x: 20
            y: 15
            text: "\u{F030C}"
            color: Theme.fg(Theme.dimOpacity)
            font.family: Theme.font
            font.pixelSize: 16
        }

        TextInput {
            id: search

            x: 46
            y: 16
            width: window.cardWidth - 66
            focus: true
            color: Theme.foreground
            selectionColor: Qt.alpha(Theme.accent, 0.4)
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize

            onTextEdited: {
                root.query = text;
                root.current = 0;
                list.contentY = 0;
            }

            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            Keys.onTabPressed: root.move(1)
            Keys.onBacktabPressed: root.move(-1)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_PageDown) root.move(10);
                else if (event.key === Qt.Key_PageUp) root.move(-10);
                else return;
                event.accepted = true;
            }
            Keys.onEscapePressed: Overlays.close()

            Text {
                visible: !search.text
                text: "Keybindings"
                color: Theme.fg(Theme.dimOpacity)
                font: search.font
            }
        }

        SectionList {
            id: list

            x: 12
            y: window.top
            width: window.cardWidth - 24
            height: window.cardHeight - window.top - 12
            model: root.shown
            current: root.current
            rowHeight: root.rowHeight
            headingHeight: root.headingHeight
            highlightRadius: 8
            emptyFontSize: Theme.rowFontSize

            heading: SectionLabel {
                required property var modelData

                leftPadding: 8
                bottomPadding: 6
                verticalAlignment: Text.AlignBottom
                text: modelData.section
                font.bold: true
            }

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: mouse => root.hover(mapToItem(null, mouse.x, mouse.y), row.index)
                }

                Rectangle {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(keys.implicitWidth + 12, root.keysWidth - 12)
                    height: 22
                    radius: 6
                    color: Theme.fg(0.08)

                    Text {
                        id: keys
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 12)
                        elide: Text.ElideRight
                        text: row.modelData.keys
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.smallFontSize
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    x: root.keysWidth + 12
                    width: parent.width - x - 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.description
                    textFormat: Text.PlainText
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                    elide: Text.ElideRight
                }
            }
        }
    }
}
