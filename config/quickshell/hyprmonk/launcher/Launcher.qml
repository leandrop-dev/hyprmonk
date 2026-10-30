// The launcher (Super+Space, or the distro logo): a card in the middle of
// the focused screen. On the left, the search, the tabs (Apps, Commands,
// SSH, Clipboard) and what matches; on the right, the one picked, large.
//
// Typing searches; the arrows move, Tab and Shift+Tab switch tabs, Enter
// starts the one picked (in Commands, Shift+Enter runs it in the terminal; in
// Clipboard it goes back on the clipboard and Shift+Delete forgets it);
// Escape or a click elsewhere closes it. Lists come from services/Apps.qml
// and services/Clipboard.qml.
//
// IPC: qs -c hyprmonk ipc call overlays toggle launcher | clipboard
//      (clipboard opens it on that tab)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.widgets

Scope {
    id: root

    readonly property bool open: Overlays.open === "launcher" || Overlays.open === "clipboard"
    property string query: ""
    property int tab: 0
    property int current: 0

    readonly property var tabs: [
        { label: "Apps", icon: "\u{F003B}", hint: "Search apps", find: Apps.findApps },
        { label: "Commands", icon: "\u{F018D}", hint: "Run a command", find: Apps.findCommands },
        { label: "SSH", icon: "\u{F048D}", hint: "Connect to a host", find: Apps.findHosts },
        { label: "Clipboard", icon: "\u{F018F}", hint: "Search what you copied", find: Clipboard.find }
    ]
    readonly property var shown: tabs[tab].find(query)
    readonly property var picked: shown[current] ?? null

    // The list can change without a key pressed (the PATH scan finishing,
    // apps installed): `current` stays inside it. A new model also puts the
    // view's own index back to 0, so the view is told again (list below).
    onShownChanged: if (current >= shown.length) current = Math.max(0, shown.length - 1)
    onCurrentChanged: list.currentIndex = current
    onPickedChanged: Clipboard.preview(picked)

    onOpenChanged: {
        if (!open) return;
        pointer = Qt.point(-1, -1);
        Apps.refreshPrograms();
        Clipboard.refresh();
        if (Overlays.open === "clipboard") tab = tabs.length - 1;
        search.forceActiveFocus();
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

    function reset(): void {
        search.text = "";
        query = "";
        current = 0;
    }

    function switchTab(step: int): void {
        tab = (tab + step + tabs.length) % tabs.length;
        reset();
    }

    function move(step: int): void {
        if (shown.length > 0) current = Math.max(0, Math.min(shown.length - 1, current + step));
    }

    function start(item: var, inTerminal: bool): void {
        if (!item) return;
        Overlays.close();
        if (item.kind === "clip") Clipboard.copy(item);
        else Apps.launch(item, inTerminal);
    }

    // What each kind shows: an app its own icon, the rest a glyph.
    function glyphOf(item: var): string {
        if (item?.kind === "clip") return item.image ? "\u{F02E9}" : "\u{F018F}";
        return item?.kind === "command" ? "\u{F018D}" : item?.kind === "host" ? "\u{F048D}" : "";
    }

    function detailOf(item: var): string {
        if (!item) return "";
        if (item.kind === "command") return item.typed ? "Run as typed" : "On PATH";
        if (item.kind === "host") return item.detail || (item.typed ? "Connect as typed" : "");
        return item.detail ?? "";
    }

    Overlay {
        id: window

        readonly property int listWidth: Math.round(cardWidth * 0.42)
        readonly property int rowHeight: 48

        name: "hyprmonk-launcher"
        open: root.open
        cardWidth: 820
        cardHeight: 480
        onDismissed: Overlays.close()
        // Put back while hidden: each open starts on Apps, empty, at the top.
        onFolded: {
            root.tab = 0;
            root.reset();
        }

        // The left column: search, tabs, list.
        ColumnLayout {
            x: 16
            y: 16
            width: window.listWidth - 32
            height: window.cardHeight - 32
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: Theme.moduleRadius
                color: Theme.fg(0.06)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "\u{F0349}"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }

                    TextInput {
                        id: search

                        Layout.fillWidth: true
                        focus: true
                        clip: true
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
                        Keys.onTabPressed: root.switchTab(1)
                        Keys.onBacktabPressed: root.switchTab(-1)
                        Keys.onEscapePressed: Overlays.close()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.start(root.picked, (event.modifiers & Qt.ShiftModifier) !== 0);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier) && root.picked?.kind === "clip") {
                                Clipboard.remove(root.picked);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                root.move(6);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageUp) {
                                root.move(-6);
                                event.accepted = true;
                            }
                        }

                        Text {
                            visible: !search.text
                            text: root.tabs[root.tab].hint + "…"
                            color: Theme.fg(Theme.dimOpacity)
                            font: search.font
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: root.tabs

                    Rectangle {
                        id: tabButton

                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === root.tab

                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Theme.moduleRadius
                        color: chosen ? Theme.selection
                             : tabMouse.containsMouse ? Theme.fg(Theme.hoverOpacity) : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: tabButton.modelData.label
                            color: tabButton.chosen ? Theme.foreground : Theme.fg(Theme.dimOpacity)
                            font.family: Theme.font
                            font.pixelSize: Theme.smallFontSize
                            font.bold: tabButton.chosen
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.tab = tabButton.index;
                                root.reset();
                                search.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.shown
                onModelChanged: currentIndex = root.current
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 120
                highlightFollowsCurrentItem: true
                highlight: Rectangle {
                    radius: 10
                    color: Theme.selection
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    width: list.width
                    height: window.rowHeight

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => root.hover(mapToItem(null, mouse.x, mouse.y), row.index)
                        onClicked: root.start(row.modelData, false)
                    }

                    Item {
                        id: rowIcon

                        x: 10
                        width: 28
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter

                        IconImage {
                            anchors.fill: parent
                            visible: row.modelData.kind === "app"
                            source: row.modelData.icon ?? ""
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.glyphOf(row.modelData)
                            color: Theme.foreground
                            font.family: Theme.font
                            font.pixelSize: 18
                        }
                    }

                    Text {
                        anchors.left: rowIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        textFormat: Text.PlainText
                        color: Theme.foreground
                        font.family: Theme.font
                        font.pixelSize: Theme.rowFontSize
                        font.italic: row.modelData.typed === true
                        elide: Text.ElideRight
                    }
                }

                Text {
                    visible: root.shown.length === 0
                    x: 10
                    height: window.rowHeight
                    verticalAlignment: Text.AlignVCenter
                    text: root.query !== "" ? "Nothing matches"
                        : root.tab === 2 ? "No hosts in ~/.ssh/config: type one"
                        : root.tab === 3 ? "Nothing copied yet"
                        : "Nothing matches"
                    color: Theme.fg(Theme.dimOpacity)
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                }
            }
        }

        Rectangle {
            x: window.listWidth
            y: 0
            width: 1
            height: window.cardHeight
            color: Theme.rim
        }

        // The right side: the one picked, large.
        ColumnLayout {
            x: window.listWidth + 1
            width: window.cardWidth - window.listWidth - 1
            anchors.verticalCenter: parent.verticalCenter
            visible: root.picked !== null && root.picked.kind !== "clip"
            spacing: 14

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 112
                implicitHeight: 112
                radius: 24
                color: Theme.fg(0.06)

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 80
                    visible: root.picked?.kind === "app"
                    source: root.picked?.kind === "app" ? root.picked.icon : ""
                }

                Text {
                    anchors.centerIn: parent
                    text: root.glyphOf(root.picked)
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: 52
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width - 48
                text: root.picked?.name ?? ""
                textFormat: Text.PlainText
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: 18
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width - 64
                visible: text !== ""
                text: root.detailOf(root.picked)
                textFormat: Text.PlainText
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        // A copied thing shows itself: the text, or the image and what it is.
        ColumnLayout {
            x: window.listWidth + 17
            y: 16
            width: window.cardWidth - window.listWidth - 33
            height: window.cardHeight - 56
            visible: root.picked?.kind === "clip"
            spacing: 10

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.picked?.image
                text: root.picked?.text ?? ""
                textFormat: Text.PlainText
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
            }

            Image {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.picked?.image ?? false
                source: Clipboard.imagePath
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: root.picked?.image ?? false
                text: (root.picked?.name ?? "") + ", " + (root.picked?.detail ?? "")
                textFormat: Text.PlainText
                color: Theme.fg(Theme.dimOpacity)
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
            }
        }

        // The keys, at the foot of the right side.
        Text {
            x: window.listWidth + 1
            width: window.cardWidth - window.listWidth - 1
            y: window.cardHeight - height - 16
            horizontalAlignment: Text.AlignHCenter
            text: root.tab === 1 ? "Enter run  ·  Shift+Enter in terminal  ·  Tab switch"
                : root.tab === 3 ? "Enter copy  ·  Shift+Delete forget  ·  Tab switch"
                : "Enter open  ·  Tab switch  ·  Esc close"
            color: Theme.fg(0.3)
            font.family: Theme.font
            font.pixelSize: Theme.smallFontSize
        }
    }
}
