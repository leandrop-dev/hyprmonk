// Settings > Appearance: the tone, its cards and text (kept with that tone;
// only colours that read on its background are offered or taken), the
// spectrum's style, how a new wallpaper comes in, fastfetch's look and the
// login screen's look, and the two fonts, in five sub-pages: Theme, Motion
// (the spectrum and wallpaper changes), Fonts, Terminal and Login screen. A
// tone or a spectrum style under the pointer is shown until it leaves. The
// page scrolls.
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar
import qs.services
import qs.widgets

Item {
    id: page

    // The sub-page shown (SettingsCard.qml): theme, motion, fonts, terminal or login.
    property string section: "theme"

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

    onColourChanged: field.text = colour
    onSectionChanged: flick.contentY = 0
    Component.onCompleted: Login.refresh()
    Component.onDestruction: {
        Theme.previewTone = "";
        Cava.previewStyle = "";
    }

    component ToneCards: Flow {
        id: cards

        property var names: []

        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: cards.names

            // A tone in small: its background, a card on it with text in its
            // colour (with any text colour picked for it), lines of dimmer
            // text, and its accent. The wallpaper tones show the wallpaper's.
            PreviewCard {
                id: card

                required property string modelData
                readonly property var look: Theme.toneOf(modelData)
                readonly property color accent: look.accent
                    ?? (look.light ? Qt.darker(Theme.wallpaperAccent, 1.5) : Theme.wallpaperAccent)

                label: look.label
                chosen: modelData === Theme.savedTone
                fill: look.background

                // Under the pointer the shell shows it, until it leaves.
                onHoveredChanged: {
                    if (hovered) Theme.previewTone = modelData;
                    else if (Theme.previewTone === modelData) Theme.previewTone = "";
                }
                onClicked: {
                    Theme.previewTone = "";
                    Theme.setTone(modelData);
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 9
                    radius: 6
                    color: Qt.tint(card.look.background, Qt.alpha(card.look.foreground, card.look.light ? 0.06 : 0.09))
                    border.width: 1
                    border.color: Qt.alpha(card.look.foreground, 0.14)

                    Text {
                        x: 7
                        y: 3
                        text: I18n.tr("Aa")
                        color: card.look.foreground
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 7
                        y: 8
                        width: 18
                        height: 8
                        radius: 4
                        color: card.accent
                    }

                    Column {
                        x: 7
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        spacing: 3

                        Rectangle {
                            width: 52
                            height: 3
                            radius: 1.5
                            color: Qt.alpha(card.look.foreground, 0.5)
                        }

                        Rectangle {
                            width: 34
                            height: 3
                            radius: 1.5
                            color: Qt.alpha(card.look.foreground, 0.3)
                        }
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

    Flickable {
        id: flick

        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: page.width
            spacing: 8

            SectionLabel {
                visible: page.section === "theme"
                text: I18n.tr("Tone")
            }

            Note {
                visible: page.section === "theme"
                text: I18n.trc("tones", "Dark")
            }

            ToneCards {
                visible: page.section === "theme"
                names: page.darkTones
            }

            Note {
                Layout.topMargin: 4
                visible: page.section === "theme" && (page.lightTones.length > 0)
                text: I18n.trc("tones", "Light")
            }

            ToneCards {
                Layout.bottomMargin: 12
                visible: page.section === "theme" && (page.lightTones.length > 0)
                names: page.lightTones
            }

            SectionLabel {
                visible: page.section === "theme"
                Layout.bottomMargin: 2
                text: Theme.tones[Theme.savedTone].label
            }

            Note {
                visible: page.section === "theme"
                Layout.bottomMargin: 6
                text: I18n.tr("Its cards and text. Changes stay with this tone.")
            }

            SettingSlider {
                visible: page.section === "theme"
                Layout.fillWidth: true
                Layout.topMargin: 2
                label: I18n.tr("Card opacity")
                from: 30
                to: 100
                unit: "%"
                value: Math.round(Theme.cardOpacity * 100)
                onMoved: value => Theme.setCardOpacity(Math.round(value) / 100)
            }

            RowLayout {
                visible: page.section === "theme"
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 6

                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("Blur behind the cards")
                    color: Theme.foreground
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                }

                Chip {
                    text: Theme.cardBlur ? I18n.tr("on") : I18n.tr("off")
                    on: Theme.cardBlur
                    onClicked: Theme.setCardBlur(!Theme.cardBlur)
                }
            }

            RowLayout {
                visible: page.section === "theme"
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
                visible: page.section === "theme"
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
                    text: I18n.tr("Too close to the background")
                    color: Theme.warning
                    font.family: Theme.font
                    font.pixelSize: Theme.bodyFontSize
                }

                Button {
                    enabled: Theme.toneAdjusted
                    text: I18n.tr("Back to the defaults")
                    onClicked: Theme.resetTone()
                }
            }

            SectionLabel {
                visible: page.section === "motion"
                text: I18n.tr("Spectrum")
            }

            Flow {
                visible: page.section === "motion"
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: Object.keys(Cava.styles)

                    // Each style drawn from the same made-up levels, larger than on
                    // the bar; the bar shows it for real while the pointer is here.
                    PreviewCard {
                        id: styleCard

                        required property string modelData

                        label: I18n.tr(Cava.styles[modelData])
                        chosen: modelData === Cava.savedStyle
                        onHoveredChanged: {
                            if (hovered) Cava.previewStyle = modelData;
                            else if (Cava.previewStyle === modelData) Cava.previewStyle = "";
                        }
                        onClicked: {
                            Cava.previewStyle = "";
                            Cava.setStyle(modelData);
                        }

                        Spectrum {
                            anchors.centerIn: parent
                            scale: 1.5
                            style: styleCard.modelData
                            sample: [0.3, 0.65, 0.95, 0.7, 0.85, 0.5, 0.75, 0.4, 0.55, 0.25]
                        }
                    }
                }
            }

            SectionLabel {
                visible: page.section === "motion"
                Layout.topMargin: 12
                text: I18n.tr("Wallpaper changes")
            }

            Flow {
                visible: page.section === "motion"
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: Wallpaper.transitions

                    // The new picture (the accent) coming in over the last, held half
                    // way; under the pointer it plays over and over. Random goes
                    // through the three in turn.
                    PreviewCard {
                        id: change

                        required property string modelData
                        property real progress: 0.5
                        property int round: 0
                        readonly property string kind: modelData === "random" ? ["fade", "wipe", "circle"][round % 3] : modelData
                        readonly property color picture: Qt.alpha(Theme.accent, 0.75)

                        label: ({ fade: I18n.tr("Fade"), wipe: I18n.tr("Wipe"), circle: I18n.tr("Circle"), random: I18n.tr("Random") })[modelData]
                        chosen: modelData === Wallpaper.transition
                        fill: Theme.fg(0.1)
                        onClicked: Wallpaper.setTransition(modelData)
                        onHoveredChanged: {
                            if (hovered) return;
                            progress = 0.5;
                            round = 0;
                        }

                        SequentialAnimation {
                            running: change.hovered
                            loops: Animation.Infinite

                            NumberAnimation {
                                target: change
                                property: "progress"
                                from: 0
                                to: 1
                                duration: change.kind === "fade" ? 500 : 900
                                easing.type: Easing.InOutCubic
                            }
                            PauseAnimation { duration: 500 }
                            ScriptAction { script: change.round++ }
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: change.kind === "fade"
                            color: change.picture
                            opacity: change.progress
                        }

                        Rectangle {
                            visible: change.kind === "wipe"
                            width: change.progress * (parent.width + 16)
                            height: parent.height
                            gradient: Gradient {
                                orientation: Gradient.Horizontal

                                GradientStop { position: 0; color: change.picture }
                                GradientStop { position: Math.max(0, 1 - 16 / Math.max(16, change.progress * 128)); color: change.picture }
                                GradientStop { position: 1; color: "transparent" }
                            }
                        }

                        // From where a tile might have been picked.
                        Rectangle {
                            readonly property real size: change.progress * 2 * 125

                            visible: change.kind === "circle"
                            x: 32 - size / 2
                            y: 40 - size / 2
                            width: size
                            height: size
                            radius: size / 2
                            color: change.picture
                        }
                    }
                }
            }

            // Theme.qml keeps the two; ThemeOutputs.qml hands them on.
            FontPicker {
                visible: page.section === "fonts"
                Layout.fillWidth: true
                title: I18n.tr("Interface")
                families: ["JetBrainsMono Nerd Font", "Inter", "Roboto", "Ubuntu", "Adwaita Sans", "Noto Sans",
                           "Atkinson Hyperlegible", "OpenDyslexic Nerd Font"]
                current: Theme.appFont
                note: I18n.tr("The shell, GTK and Qt apps, the title bars and the login screen.")
                onPicked: family => Theme.setFont(family)
            }

            FontPicker {
                visible: page.section === "fonts"
                Layout.fillWidth: true
                Layout.topMargin: 12
                title: I18n.tr("Monospace")
                sample: "0O{}"
                families: ["JetBrainsMono Nerd Font", "FiraCode Nerd Font", "0xProto Nerd Font", "Agave Nerd Font",
                           "ComicShannsMono Nerd Font", "Cousine Nerd Font", "DaddyTimeMono Nerd Font",
                           "AtkynsonMono Nerd Font", "Adwaita Mono"]
                current: Theme.appMonoFont
                note: I18n.tr("The terminal and code in apps.")
                onPicked: family => Theme.setMonoFont(family)
            }

            SectionLabel {
                visible: page.section === "terminal"
                text: I18n.tr("Fastfetch")
            }

            Flow {
                visible: page.section === "terminal"
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Object.keys(Fastfetch.presets)

                    Chip {
                        required property string modelData

                        text: I18n.tr(Fastfetch.presets[modelData])
                        on: modelData === Fastfetch.saved
                        onClicked: Fastfetch.set(modelData)
                    }
                }
            }

            SectionLabel {
                visible: page.section === "login" && (Login.ready)
                text: I18n.tr("Login screen")
            }

            Flow {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                visible: page.section === "login" && (Login.ready)
                spacing: 8

                Repeater {
                    model: Login.looks

                    // The look's own background (a frame of a video one).
                    PreviewCard {
                        id: look

                        required property string modelData

                        label: Login.label(modelData)
                        chosen: modelData === Login.current
                        onClicked: Login.pick(modelData)

                        Image {
                            anchors.fill: parent
                            source: Login.pictures[look.modelData] ? Theme.fileUrl(Login.pictures[look.modelData]) : ""
                            sourceSize: Qt.size(224, 124)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false  // the desktop look's changes with the wallpaper
                            opacity: status === Image.Ready ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: 160 }
                            }
                        }
                    }
                }
            }
        }
    }

    MoreBelow {
        flickable: flick
    }
}
