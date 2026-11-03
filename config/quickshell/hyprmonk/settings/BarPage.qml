// Settings > Bar: the modules of the bar's left and right cards, as tiles to
// drag within a card, to the other card, or to Hidden. A line shows where one
// will land, and the bar changes on release. The centre card stays as it is.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

Item {
    id: page

    readonly property var sides: [
        { key: "left", label: "Left card" },
        { key: "right", label: "Right card" },
        { key: "hidden", label: "Hidden" }
    ]
    property string dragged: ""  // the module's key; "" when none
    property point pointer: Qt.point(0, 0)
    readonly property var target: dragged === "" ? null : targetAt(pointer)  // where it would land

    // The side and index under `at`, and where the line goes, in the page.
    function targetAt(at: point): var {
        for (let i = 0; i < sections.count; i++) {
            const section = sections.itemAt(i);
            const inside = section.area.mapFromItem(page, at.x, at.y);
            if (inside.x < 0 || inside.y < 0 || inside.x > section.area.width || inside.y > section.area.height) continue;
            if (section.side === "hidden" && Settings.barModule(dragged).fixed) return null;

            const tiles = section.tiles();
            const here = section.flow.mapFromItem(page, at.x, at.y);
            let index = tiles.findIndex(tile => here.y < tile.y || (here.y < tile.y + tile.height && here.x < tile.x + tile.width / 2));
            if (index < 0) index = tiles.length;

            const edge = tiles[index] ?? tiles[index - 1];
            const line = !edge ? section.flow.mapToItem(page, 0, 0)
                : edge.mapToItem(page, index < tiles.length ? -3 : edge.width + 3, 0);
            return { side: section.side, index, x: line.x - 1, y: line.y };
        }
        return null;
    }

    function drag(key: string, at: point): void {
        dragged = key;
        pointer = at;
    }

    function drop(): void {
        if (target) Settings.moveBarModule(dragged, target.side, target.index);
        dragged = "";
    }

    component Tile: Rectangle {
        id: tile

        property var module: ({})

        implicitWidth: row.implicitWidth + 20
        implicitHeight: 30
        radius: Theme.moduleRadius
        color: Theme.fg(0.08)
        border.width: 1
        border.color: Theme.rim

        RowLayout {
            id: row

            anchors.centerIn: parent
            spacing: 8

            Text {
                text: tile.module.icon ?? ""
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
            }

            Text {
                text: tile.module.label ?? ""
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
            }
        }
    }

    component Row: RowLayout {
        property alias text: label.text

        Layout.fillWidth: true
        spacing: 6

        Text {
            id: label
            Layout.fillWidth: true
            color: Theme.foreground
            font.family: Theme.font
            font.pixelSize: Theme.rowFontSize
            elide: Text.ElideRight
        }
    }

    // A chip for each of a choice's values.
    component Choice: Repeater {
        id: choice

        property string key: ""
        property var labels: ({})

        model: Settings.barChoices[key]

        Chip {
            required property var modelData

            text: choice.labels[modelData] ?? String(modelData)
            on: modelData === Settings.barChoice(choice.key)
            onClicked: Settings.setBarChoice(choice.key, modelData)
        }
    }

    component Switch: Chip {
        property string key: ""

        on: Settings.barChoice(key)
        onClicked: Settings.setBarChoice(key, !Settings.barChoice(key))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Repeater {
            id: sections

            model: page.sides

            ColumnLayout {
                id: section

                required property var modelData
                readonly property string side: modelData.key
                readonly property alias area: area
                readonly property alias flow: flow

                function tiles(): var {
                    return Array.from(flow.children).filter(child => child.moduleKey !== undefined);
                }

                Layout.fillWidth: true
                Layout.bottomMargin: 8
                spacing: 8
                opacity: side === "hidden" && page.dragged !== "" && Settings.barModule(page.dragged).fixed ? Theme.dimOpacity : 1

                SectionLabel {
                    text: section.modelData.label
                }

                Rectangle {
                    id: area

                    Layout.fillWidth: true
                    implicitHeight: flow.implicitHeight + 16
                    radius: Theme.moduleRadius
                    color: Theme.fg(0.04)
                    border.width: 1
                    border.color: page.target?.side === section.side ? Qt.alpha(Theme.accent, 0.8) : "transparent"

                    Flow {
                        id: flow

                        x: 8
                        y: 8
                        width: parent.width - 16
                        spacing: 6

                        Repeater {
                            model: Settings.bar[section.side]

                            Tile {
                                id: placed

                                required property string modelData
                                readonly property string moduleKey: modelData

                                module: Settings.barModule(modelData)
                                opacity: page.dragged === modelData ? 0.35 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    onPositionChanged: mouse => { if (pressed) page.drag(placed.modelData, mapToItem(page, mouse.x, mouse.y)); }
                                    onReleased: if (page.dragged !== "") page.drop()
                                    onCanceled: page.dragged = ""
                                }
                            }
                        }

                        // Keeps an empty one tall enough to drop on.
                        Item {
                            visible: Settings.bar[section.side].length === 0
                            width: 1
                            height: 30
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: Settings.bar[section.side].length === 0
                        text: "Drag modules here"
                        color: Theme.fg(Theme.dimOpacity)
                        font.family: Theme.font
                        font.pixelSize: Theme.smallFontSize
                    }
                }
            }
        }

        SectionLabel {
            text: "How they show"
        }

        Row {
            text: "Clock"

            Choice {
                key: "hours"
                labels: ({ "24": "24-hour", "12": "12-hour" })
            }

            Switch {
                key: "seconds"
                text: "Seconds"
            }

            Switch {
                key: "date"
                text: "Date"
            }
        }

        Row {
            text: "Workspaces"

            Choice {
                key: "workspaces"
                labels: ({ 0: "In use", 5: "1 to 5", 10: "1 to 10" })
            }
        }

        Row {
            text: "Temperature"

            Choice {
                key: "temperature"
                labels: ({ C: "°C", F: "°F" })
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Button {
            Layout.alignment: Qt.AlignRight
            enabled: Settings.barChanged || Settings.barLookChanged
            text: "Back to the defaults"
            onClicked: Settings.resetBar()
        }
    }

    Rectangle {
        visible: page.target !== null
        x: page.target?.x ?? 0
        y: page.target?.y ?? 0
        width: 2
        height: 30
        radius: 1
        color: Theme.accent
    }

    Tile {
        visible: page.dragged !== ""
        x: page.pointer.x - width / 2
        y: page.pointer.y - height / 2
        module: Settings.barModule(page.dragged) ?? ({})
    }
}
