// Settings > Sounds (services/Sounds.qml): the interface's sounds on or off,
// the set they come from, their volume and the notification tone, with a
// chip to hear each one. Each change shows at once. Then the audio effects
// (services/AudioEffects.qml): the equaliser with its presets and bands,
// night mode and its strength,
// the headphone correction, searched for in AutoEQ, and the microphone's
// noise suppression, with a way to hear it.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

ColumnLayout {
    spacing: 8

    Component.onDestruction: AudioEffects.listening = false

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

    component Note: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.fg(0.6)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    // The options scroll; the button stays below them.
    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: 8

            SectionLabel {
                text: "Sounds"
            }

            Row {
                text: "Play sounds"

                Chip {
                    text: Sounds.on ? "on" : "off"
                    on: Sounds.on
                    onClicked: Settings.setSoundChoice("on", !Sounds.on)
                }
            }

            Note {
                text: "Quiet in game mode and do not disturb, except for urgent notifications."
            }

            Row {
                text: "Set"

                Repeater {
                    model: Settings.soundChoices.set

                    Chip {
                        required property string modelData

                        text: ({ hyprmonk: "hyprmonk", serpantinum: "Serpantinum" })[modelData]
                        on: modelData === Sounds.set
                        onClicked: Settings.setSoundChoice("set", modelData)
                    }
                }
            }

            SettingSlider {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                label: "Volume"
                unit: "%"
                from: Settings.soundVolumeRange.from
                to: Settings.soundVolumeRange.to
                value: Settings.soundVolume
                onMoved: value => Settings.setSoundVolume(value)
            }

            SectionLabel {
                text: "Notification tone"
            }

            // Picking one plays it.
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Settings.soundChoices.tone

                    Chip {
                        required property string modelData

                        text: ({ set: "The set's own", chime: "hyprmonk chime" })[modelData] ?? modelData
                        on: modelData === Sounds.tone
                        sounds: false
                        onClicked: {
                            Settings.setSoundChoice("tone", modelData);
                            Sounds.preview("notify");
                        }
                    }
                }
            }

            SectionLabel {
                text: "Hear them"
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { kind: "click", label: "Click" },
                        { kind: "on", label: "Switch on" },
                        { kind: "off", label: "Switch off" },
                        { kind: "open", label: "Card opens" },
                        { kind: "close", label: "Card closes" },
                        { kind: "notify", label: "Notification" },
                        { kind: "connect", label: "Connected" },
                        { kind: "disconnect", label: "Disconnected" }
                    ]

                    Chip {
                        required property var modelData

                        text: modelData.label
                        sounds: false
                        onClicked: Sounds.preview(modelData.kind)
                    }
                }
            }

            // services/AudioEffects.qml
            SectionLabel {
                Layout.topMargin: 12
                text: "Equaliser"
            }

            Row {
                text: "On every output, before the correction"

                Chip {
                    text: AudioEffects.eqOn ? "on" : "off"
                    on: AudioEffects.eqOn
                    onClicked: AudioEffects.setEq(!AudioEffects.eqOn)
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: AudioEffects.presetNames.filter(name => name !== "custom" || AudioEffects.preset === "custom" || AudioEffects.hasCustom)

                    Chip {
                        required property string modelData

                        text: AudioEffects.presetLabels[modelData]
                        on: modelData === AudioEffects.preset
                        onClicked: AudioEffects.setPreset(modelData)
                    }
                }
            }

            Equaliser {
                Layout.fillWidth: true
                Layout.topMargin: 4
                opacity: AudioEffects.eqOn ? 1 : Theme.dimOpacity
            }

            Note {
                text: "Moving a band makes the preset Custom, kept for next time. The sound is lowered by the largest boost so that it never clips."
            }

            SectionLabel {
                Layout.topMargin: 12
                text: "Night mode"
            }

            Row {
                text: "Quiet parts up, loud parts down"

                Chip {
                    text: AudioEffects.nightOn ? "on" : "off"
                    on: AudioEffects.nightOn
                    onClicked: AudioEffects.setNight(!AudioEffects.nightOn)
                }
            }

            Row {
                text: "Strength"

                Repeater {
                    model: AudioEffects.strengthNames

                    Chip {
                        required property string modelData

                        text: AudioEffects.strengthLabels[modelData]
                        on: modelData === AudioEffects.strength
                        onClicked: AudioEffects.setStrength(modelData)
                    }
                }
            }

            Note {
                text: "For late listening: speech stays clear and bangs do not jump out, so the volume can stay low. On every output, after the equaliser."
            }

            SectionLabel {
                Layout.topMargin: 12
                text: "Headphone correction"
            }

            Row {
                text: AudioEffects.profile ? `${AudioEffects.profile.name}, by ${AudioEffects.profile.source ?? "AutoEQ"}` : "None for this output"

                Chip {
                    visible: AudioEffects.sinkName in AudioEffects.settingsProfiles
                    text: AudioEffects.ready.some(profile => AudioEffects.sinkName.includes(profile.match)) ? "The ready one" : "Remove"
                    onClicked: AudioEffects.forget(AudioEffects.sinkName)
                }

                Chip {
                    visible: AudioEffects.profile !== null
                    text: AudioEffects.correctionOn ? "on" : "off"
                    on: AudioEffects.correctionOn
                    onClicked: AudioEffects.setCorrection(!AudioEffects.correctionOn)
                }
            }

            Note {
                text: `For ${Audio.nameOf(AudioEffects.sink) || "the output"}: AutoEQ's correction brings headphones to a neutral sound, so some sound quieter and with less bass. Search for yours to pick another.`
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.moduleRadius
                color: Theme.fg(0.06)
                border.width: 1
                border.color: search.activeFocus ? Qt.alpha(Theme.accent, 0.8) : Theme.rim

                TextInput {
                    id: search

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground
                    selectionColor: Qt.alpha(Theme.accent, 0.55)
                    font.family: Theme.font
                    font.pixelSize: Theme.rowFontSize
                    clip: true
                    onActiveFocusChanged: if (activeFocus) AudioEffects.loadCatalogue()
                    Keys.onEscapePressed: event => {
                        if (text === "") {
                            event.accepted = false;
                            return;
                        }
                        text = "";
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: "Search AutoEQ for your headphones"
                        color: Theme.fg(Theme.dimOpacity)
                        font: search.font
                    }
                }
            }

            Searching {
                running: AudioEffects.cataloguing
            }

            Note {
                visible: AudioEffects.catalogueFailed || AudioEffects.fetchFailed
                color: Theme.warning
                text: AudioEffects.catalogueFailed ? "Could not reach AutoEQ." : "Could not download that one."
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: AudioEffects.search(search.text)

                    OptionRow {
                        required property var modelData

                        Layout.fillWidth: true
                        icon: AudioEffects.fetching === modelData.path ? "\u{F01DA}" : "\u{F02CB}"
                        text: modelData.name
                        detail: [modelData.source, modelData.form].filter(part => part !== "").join(", ")
                        selected: AudioEffects.settingsProfiles[AudioEffects.sinkName]?.path === modelData.path
                        onClicked: AudioEffects.pick(modelData)
                    }
                }
            }

            SectionLabel {
                Layout.topMargin: 12
                text: "Microphone"
            }

            Row {
                text: "Noise suppression"

                Chip {
                    text: AudioEffects.noiseOn ? "on" : "off"
                    on: AudioEffects.noiseOn
                    onClicked: AudioEffects.setNoise(!AudioEffects.noiseOn)
                }
            }

            SettingSlider {
                Layout.fillWidth: true
                label: "Voice threshold"
                unit: "%"
                from: 0
                to: 95
                value: AudioEffects.threshold
                onMoved: value => AudioEffects.setThreshold(Math.round(value))
            }

            Note {
                text: "How sure it must be that it hears a voice before letting the sound through. Higher cuts more noise, and may clip the start of words."
            }

            SettingSlider {
                Layout.fillWidth: true
                label: "Hold after speaking"
                unit: " ms"
                from: 0
                to: 1000
                value: AudioEffects.hold
                onMoved: value => AudioEffects.setHold(Math.round(value / 10) * 10)
            }

            Note {
                text: "How long it stays open once you stop. Longer lets the room in as a faint static after each sentence; shorter may clip the ends of words."
            }

            Row {
                text: "Listen to yourself"

                Chip {
                    text: AudioEffects.listening ? "on" : "off"
                    on: AudioEffects.listening
                    onClicked: AudioEffects.listening = !AudioEffects.listening
                }
            }

            Note {
                Layout.bottomMargin: 4
                text: "Plays the microphone in your headphones as others hear it, while this page is open. Through speakers it would feed back."
            }
        }
    }

    Button {
        Layout.alignment: Qt.AlignRight
        enabled: Settings.soundsChanged
        text: "Back to the defaults"
        onClicked: Settings.resetSounds()
    }
}
