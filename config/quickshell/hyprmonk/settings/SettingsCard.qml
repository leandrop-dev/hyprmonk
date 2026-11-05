// Settings (Super+comma): a card in the middle of the focused screen, with its
// pages down the side in three groups. A page with sub-pages lists them under
// it while it is open, and opens on the first; they are parts of the one page
// (its `section`), so moving between them keeps what it holds. What is
// changed applies at once; the arrows or Tab move through what the side
// shows, Escape or a click elsewhere closes the card. What it changes is kept
// by services/Settings.qml.
//
// IPC: qs -c hyprmonk ipc call overlays toggle settings
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

Overlay {
    id: window

    readonly property var pages: [
        { group: "Desktop", name: "Display", icon: "\u{F0379}", file: "DisplayPage.qml",
          subs: [{ key: "screens", name: "Screens" }, { key: "brightness", name: "Brightness" },
                 { key: "night", name: "Night light" }] },
        { group: "Desktop", name: "Windows", icon: "\u{F05AF}", file: "WindowsPage.qml" },
        { group: "Desktop", name: "Bar", icon: "\u{F0570}", file: "BarPage.qml",
          subs: [{ key: "modules", name: "Modules" }, { key: "look", name: "Look" }] },
        { group: "Desktop", name: "Dock", icon: "\u{F10A9}", file: "DockPage.qml" },
        { group: "Look and sound", name: "Appearance", icon: "\u{F050E}", file: "AppearancePage.qml",
          subs: [{ key: "theme", name: "Theme" }, { key: "motion", name: "Motion" },
                 { key: "terminal", name: "Terminal" }, { key: "login", name: "Login screen" }] },
        { group: "Look and sound", name: "Sounds", icon: "\u{F057E}", file: "SoundsPage.qml",
          subs: [{ key: "interface", name: "Interface" }, { key: "effects", name: "Effects" },
                 { key: "microphone", name: "Microphone" }] },
        { group: "System", name: "Input", icon: "\u{F030C}", file: "InputPage.qml" },
        { group: "System", name: "Power", icon: "\u{F0425}", file: "PowerPage.qml" },
        { group: "System", name: "Recording", icon: "\u{F044A}", file: "RecordingPage.qml" },
        { group: "System", name: "Notifications", icon: "\u{F009A}", file: "NotificationsPage.qml" }
    ]
    property int current: 0
    property string sub: ""  // the open page's sub-page; "" when it has none

    // What the side lists: each group's name, its pages, and the open page's
    // sub-pages under it.
    readonly property var rows: {
        const rows = [];
        pages.forEach((page, index) => {
            if (index === 0 || pages[index - 1].group !== page.group) rows.push({ kind: "group", text: page.group });
            rows.push({ kind: "page", index });
            if (index === current) for (const sub of page.subs ?? []) rows.push({ kind: "sub", index, key: sub.key, text: sub.name });
        });
        return rows;
    }

    // A page opens on its first sub-page, or its last when come to from below.
    function openPage(index: int, fromBelow: bool): void {
        const subs = pages[index].subs ?? [];
        current = index;
        sub = subs.length === 0 ? "" : subs[fromBelow ? subs.length - 1 : 0].key;
    }

    // Through the pages and the open page's sub-pages, round and round.
    function move(step: int): void {
        const stops = rows.filter(row => row.kind === "sub" || (row.kind === "page" && (row.index !== current || !pages[row.index].subs)));
        const here = stops.findIndex(row => row.index === current && (row.kind === "page" || row.key === sub));
        const next = stops[(here + step + stops.length) % stops.length];
        if (next.kind === "sub") sub = next.key;
        else openPage(next.index, step < 0);
    }

    name: "hyprmonk-settings"
    open: Overlays.open === "settings"
    cardWidth: 880
    // Smaller screens get a shorter card.
    cardHeight: Math.min(680, (screen?.height ?? 1080) - 120)
    onDismissed: Overlays.close()
    onOpenChanged: if (open) keys.forceActiveFocus()

    Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onUpPressed: window.move(-1)
        Keys.onDownPressed: window.move(1)
        Keys.onTabPressed: window.move(1)
        Keys.onBacktabPressed: window.move(-1)
        Keys.onEscapePressed: Overlays.close()

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            ColumnLayout {
                Layout.preferredWidth: 200
                Layout.maximumWidth: 200
                Layout.fillHeight: true
                spacing: 2

                Repeater {
                    model: window.rows

                    Loader {
                        id: row

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.topMargin: modelData.kind === "group" && index > 0 ? 10 : 0
                        sourceComponent: modelData.kind === "group" ? groupName : entry

                        Component {
                            id: groupName

                            SectionLabel {
                                leftPadding: 12
                                bottomPadding: 4
                                text: row.modelData.text
                            }
                        }

                        Component {
                            id: entry

                            OptionRow {
                                readonly property var page: window.pages[row.modelData.index]
                                readonly property bool isSub: row.modelData.kind === "sub"
                                readonly property bool isOpen: row.modelData.index === window.current

                                // A sub-page sits in, under its page.
                                icon: isSub ? "" : page.icon
                                text: isSub ? row.modelData.text : page.name
                                // A page with sub-pages shows whether they are listed.
                                detail: isSub || !page.subs ? "" : isOpen ? "\u{F0140}" : "\u{F0142}"
                                selected: isSub ? isOpen && row.modelData.key === window.sub : isOpen && !page.subs
                                onClicked: {
                                    if (isSub) window.sub = row.modelData.key;
                                    else if (!isOpen) window.openPage(row.modelData.index, false);
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Theme.rim
            }

            Loader {
                id: content

                Layout.fillWidth: true
                Layout.fillHeight: true
                active: window.visible
                source: window.pages[window.current].file
            }

            // Which part of the page shows.
            Binding {
                // None on a page without sub-pages, which has no `section`.
                target: window.sub !== "" ? content.item : null
                property: "section"
                value: window.sub
            }
        }
    }
}
