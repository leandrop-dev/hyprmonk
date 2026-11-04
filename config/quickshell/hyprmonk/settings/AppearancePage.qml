// Settings > Appearance: the tone, its cards and text (kept with that tone;
// only colours that read on its background are offered or taken), the
// spectrum's style, how a new wallpaper comes in, fastfetch's look and the
// login screen's look. A tone or a spectrum style under the pointer is shown
// until it leaves. The page scrolls.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

Flickable {
    id: page

    readonly property var tone: Theme.toneOf(Theme.savedTone)
    readonly property string colour: String(tone.foreground).toLowerCase()
    readonly property var swatches: {
        const own = String(Theme.baseTone(Theme.savedTone).foreground).toLowerCase();
        const others = tone.light
            ? ["#000000", "#1f1f1f", "#3a3a3a", "#4a3a28", "#1e3a5f", "#234d2f"]
            : ["#ffffff", "#e8e6e3", "#d4d4d8", "#f5e6c8", "#cfe3ff", "#c8f0d0"];
        return [own].concat(others.filter(shade => shade !== own && Theme.readable(shade)));
    }
    // Tone names, dark ones first.
    readonly property var darkTones: Object.keys(Theme.tones).filter(name => !Theme.tones[name].light)
    readonly property var lightTones: Object.keys(Theme.tones).filter(name => Theme.tones[name].light)

    function typed(text: string): void {
        if (/^#[0-9a-f]{6}$/i.test(text) && Theme.readable(text)) Theme.setTextColour(text);
    }

    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    onColourChanged: field.text = colour
    Component.onCompleted: Login.refresh()
    Component.onDestruction: {
        Theme.previewTone = "";
        Cava.previewStyle = "";
    }

    component ToneChips: Flow {
        id: chips

        property var names: []

        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: chips.names

            Chip {
                id: chip

                required property string modelData

                text: Theme.tones[modelData].label
                on: modelData === Theme.savedTone
                onClicked: {
                    Theme.previewTone = "";
                    Theme.setTone(modelData);
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) Theme.previewTone = chip.modelData;
                        else if (Theme.previewTone === chip.modelData) Theme.previewTone = "";
                    }
                }
            }
        }
    }

    component Note: Text {
        color: Theme.fg(Theme.dimOpacity)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    ColumnLayout {
        id: column

        width: page.width
        spacing: 8

        SectionLabel {
            text: "Tone"
        }

        Note {
            text: "Dark"
        }

        ToneChips {
            names: page.darkTones
        }

        Note {
            Layout.topMargin: 4
            visible: page.lightTones.length > 0
            text: "Light"
        }

        ToneChips {
            Layout.bottomMargin: 12
            visible: page.lightTones.length > 0
            names: page.lightTones
        }

        SectionLabel {
            Layout.bottomMargin: 2
            text: Theme.tones[Theme.savedTone].label
        }

        Note {
            Layout.bottomMargin: 6
            text: "Its cards and text. Changes stay with this tone."
        }

        SettingSlider {
            Layout.fillWidth: true
            Layout.topMargin: 2
            label: "Card opacity"
            from: 30
            to: 100
            unit: "%"
            value: Math.round(Theme.cardOpacity * 100)
            onMoved: value => Theme.setCardOpacity(Math.round(value) / 100)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 6

            Text {
                Layout.fillWidth: true
                text: "Blur behind the cards"
                color: Theme.foreground
                font.family: Theme.font
                font.pixelSize: Theme.rowFontSize
            }

            Chip {
                text: Theme.cardBlur ? "on" : "off"
                on: Theme.cardBlur
                onClicked: Theme.setCardBlur(!Theme.cardBlur)
            }
        }

        RowLayout {
            Layout.topMargin: 2
            spacing: 8

            Repeater {
                model: page.swatches

                Rectangle {
                    id: swatch

                    required property string modelData

                    implicitWidth: 34
                    implicitHeight: 34
                    radius: Theme.moduleRadius
                    color: page.tone.background
                    border.width: modelData === page.colour ? 2 : 1
                    border.color: modelData === page.colour ? Theme.accent : Theme.rim

                    Text {
                        anchors.centerIn: parent
                        text: "A"
                        color: swatch.modelData
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Theme.setTextColour(swatch.modelData)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 12

            Rectangle {
                implicitWidth: 110
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
                    text: page.colour
                    maximumLength: 7
                    color: Theme.foreground
                    selectionColor: Qt.alpha(Theme.accent, 0.55)
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                    clip: true

                    onTextEdited: page.typed(text)
                }
            }

            Text {
                Layout.fillWidth: true
                visible: /^#[0-9a-f]{6}$/i.test(field.text) && !Theme.readable(field.text)
                text: "Too close to the background"
                color: Theme.warning
                font.family: Theme.font
                font.pixelSize: Theme.bodyFontSize
            }

            Button {
                enabled: Theme.toneAdjusted
                text: "Back to the defaults"
                onClicked: Theme.resetTone()
            }
        }

        SectionLabel {
            Layout.topMargin: 12
            text: "Spectrum"
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Object.keys(Cava.styles)

                Chip {
                    id: style

                    required property string modelData

                    text: Cava.styles[modelData]
                    on: modelData === Cava.savedStyle
                    onClicked: {
                        Cava.previewStyle = "";
                        Cava.setStyle(modelData);
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) Cava.previewStyle = style.modelData;
                            else if (Cava.previewStyle === style.modelData) Cava.previewStyle = "";
                        }
                    }
                }
            }
        }

        SectionLabel {
            Layout.topMargin: 12
            text: "Wallpaper changes"
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Wallpaper.transitions

                Chip {
                    required property string modelData

                    text: ({ fade: "Fade", wipe: "Wipe", circle: "Circle", random: "Random" })[modelData]
                    on: modelData === Wallpaper.transition
                    onClicked: Wallpaper.setTransition(modelData)
                }
            }
        }

        SectionLabel {
            Layout.topMargin: 12
            text: "Fastfetch"
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Object.keys(Fastfetch.presets)

                Chip {
                    required property string modelData

                    text: Fastfetch.presets[modelData]
                    on: modelData === Fastfetch.saved
                    onClicked: Fastfetch.set(modelData)
                }
            }
        }

        SectionLabel {
            Layout.topMargin: 12
            visible: Login.ready
            text: "Login screen"
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            visible: Login.ready
            spacing: 6

            Repeater {
                model: Login.looks

                Chip {
                    required property string modelData

                    text: Login.label(modelData)
                    on: modelData === Login.current
                    onClicked: Login.pick(modelData)
                }
            }
        }
    }
}
