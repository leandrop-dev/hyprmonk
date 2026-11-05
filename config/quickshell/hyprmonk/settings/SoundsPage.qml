// Settings > Sounds, in three sub-pages:
// - Interface (services/Sounds.qml): the interface's sounds on or off, the set
//   they come from, their volume and the notification tone, with a chip to
//   hear each one.
// - Effects (services/AudioEffects.qml): the equaliser with its presets and
//   bands, night mode and its strength, and the headphone correction,
//   searched for in AutoEQ.
// - Microphone: its noise suppression, with a way to hear it.
// Each change shows at once.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: page

    // The sub-page shown (SettingsCard.qml): interface, effects or
    // microphone.
    property string section: "interface"

    spacing: 8

    onSectionChanged: flick.contentY = 0
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
        id: flick

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
                visible: page.section === "interface"
                text: I18n.tr("Sounds")
            }

            Row {
                visible: page.section === "interface"
                text: I18n.tr("Play sounds")

                Chip {
                    text: Sounds.on ? I18n.tr("on") : I18n.tr("off")
                    on: Sounds.on
                    onClicked: Settings.setSoundChoice("on", !Sounds.on)
                }
            }

            Note {
                visible: page.section === "interface"
                text: I18n.tr("Quiet in game mode and do not disturb, except for urgent notifications.")
            }

            Row {
                visible: page.section === "interface"
                text: I18n.tr("Set")

                Repeater {
                    model: Settings.soundChoices.set

                    Chip {
                        required property string modelData

                        text: ({ hyprmonk: I18n.tr("hyprmonk"), serpantinum: I18n.tr("Serpantinum") })[modelData]
                        on: modelData === Sounds.set
                        onClicked: Settings.setSoundChoice("set", modelData)
                    }
                }
            }

            SettingSlider {
                visible: page.section === "interface"
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                label: I18n.tr("Volume")
                unit: "%"
                from: Settings.soundVolumeRange.from
                to: Settings.soundVolumeRange.to
                value: Settings.soundVolume
                onMoved: value => Settings.setSoundVolume(value)
            }

            SectionLabel {
                visible: page.section === "interface"
                text: I18n.tr("Notification tone")
            }

            // Picking one plays it.
            Flow {
                visible: page.section === "interface"
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Settings.soundChoices.tone

                    Chip {
                        required property string modelData

                        text: ({ set: I18n.tr("The set's own"), chime: I18n.tr("hyprmonk chime") })[modelData] ?? modelData
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
                visible: page.section === "interface"
                text: I18n.tr("Hear them")
            }

            Flow {
                visible: page.section === "interface"
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { kind: "click", label: I18n.tr("Click") },
                        { kind: "on", label: I18n.tr("Switch on") },
                        { kind: "off", label: I18n.tr("Switch off") },
                        { kind: "open", label: I18n.tr("Card opens") },
                        { kind: "close", label: I18n.tr("Card closes") },
                        { kind: "notify", label: I18n.tr("Notification") },
                        { kind: "connect", label: I18n.tr("Connected") },
                        { kind: "disconnect", label: I18n.tr("Disconnected") }
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
                visible: page.section === "effects"
                text: I18n.tr("Equaliser")
            }

            Row {
                visible: page.section === "effects"
                text: I18n.tr("On every output, before the correction")

                Chip {
                    text: AudioEffects.eqOn ? I18n.tr("on") : I18n.tr("off")
                    on: AudioEffects.eqOn
                    onClicked: AudioEffects.setEq(!AudioEffects.eqOn)
                }
            }

            Flow {
                visible: page.section === "effects"
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: AudioEffects.presetNames.filter(name => name !== "custom" || AudioEffects.preset === "custom" || AudioEffects.hasCustom)

                    Chip {
                        required property string modelData

                        text: I18n.tr(AudioEffects.presetLabels[modelData])
                        on: modelData === AudioEffects.preset
                        onClicked: AudioEffects.setPreset(modelData)
                    }
                }
            }

            Equaliser {
                visible: page.section === "effects"
                Layout.fillWidth: true
                Layout.topMargin: 4
                opacity: AudioEffects.eqOn ? 1 : Theme.dimOpacity
            }

            Note {
                visible: page.section === "effects"
                text: I18n.tr("Moving a band makes the preset Custom, kept for next time. The sound is lowered by the largest boost so that it never clips.")
            }

            SectionLabel {
                visible: page.section === "effects"
                Layout.topMargin: 12
                text: I18n.tr("Night mode")
            }

            Row {
                visible: page.section === "effects"
                text: I18n.tr("Quiet parts up, loud parts down")

                Chip {
                    text: AudioEffects.nightOn ? I18n.tr("on") : I18n.tr("off")
                    on: AudioEffects.nightOn
                    onClicked: AudioEffects.setNight(!AudioEffects.nightOn)
                }
            }

            Row {
                visible: page.section === "effects"
                text: I18n.tr("Strength")

                Repeater {
                    model: AudioEffects.strengthNames

                    Chip {
                        required property string modelData

                        text: I18n.tr(AudioEffects.strengthLabels[modelData])
                        on: modelData === AudioEffects.strength
                        onClicked: AudioEffects.setStrength(modelData)
                    }
                }
            }

            Note {
                visible: page.section === "effects"
                text: I18n.tr("Like a TV's night mode: quiet parts such as speech come up and loud ones such as explosions come down, so you can keep the volume low and still hear everything.")
            }

            SectionLabel {
                visible: page.section === "effects"
                Layout.topMargin: 12
                text: I18n.tr("Headphone correction")
            }

            Row {
                visible: page.section === "effects"
                text: AudioEffects.profile ? I18n.tr("%1, by %2", AudioEffects.profile.name, AudioEffects.profile.source ?? "AutoEQ") : I18n.tr("None for this output")

                Chip {
                    visible: AudioEffects.sinkName in AudioEffects.settingsProfiles
                    text: AudioEffects.ready.some(profile => AudioEffects.sinkName.includes(profile.match)) ? I18n.tr("The ready one") : I18n.tr("Remove")
                    onClicked: AudioEffects.forget(AudioEffects.sinkName)
                }

                Chip {
                    visible: AudioEffects.profile !== null
                    text: AudioEffects.correctionOn ? I18n.tr("on") : I18n.tr("off")
                    on: AudioEffects.correctionOn
                    onClicked: AudioEffects.setCorrection(!AudioEffects.correctionOn)
                }
            }

            Note {
                visible: page.section === "effects"
                text: I18n.tr("For %1: AutoEQ's correction brings headphones to a neutral sound, so some sound quieter and with less bass. Search for yours to pick another.", Audio.nameOf(AudioEffects.sink) || I18n.tr("the output"))
            }

            // Picking downloads it; the row's arrow shows while that runs.
            SearchField {
                id: search

                visible: page.section === "effects"
                Layout.fillWidth: true
                placeholder: I18n.tr("Search AutoEQ for your headphones")
                busy: AudioEffects.cataloguing
                message: I18n.tr("No headphones by that name")
                results: AudioEffects.search(search.text).map(entry => ({
                    entry,
                    icon: AudioEffects.fetching === entry.path ? "\u{F01DA}" : "\u{F02CB}",
                    text: entry.name,
                    detail: [entry.source, entry.form].filter(part => part !== "").join(", "),
                    selected: AudioEffects.settingsProfiles[AudioEffects.sinkName]?.path === entry.path
                }))
                onFocused: AudioEffects.loadCatalogue()
                onPicked: result => AudioEffects.pick(result.entry)
            }

            Note {
                visible: page.section === "effects" && (AudioEffects.catalogueFailed || AudioEffects.fetchFailed)
                color: Theme.warning
                text: AudioEffects.catalogueFailed ? I18n.tr("Could not reach AutoEQ.") : I18n.tr("Could not download that one.")
            }

            SectionLabel {
                visible: page.section === "microphone"
                text: I18n.tr("Microphone")
            }

            Row {
                visible: page.section === "microphone"
                text: I18n.tr("Noise suppression")

                Chip {
                    text: AudioEffects.noiseOn ? I18n.tr("on") : I18n.tr("off")
                    on: AudioEffects.noiseOn
                    onClicked: AudioEffects.setNoise(!AudioEffects.noiseOn)
                }
            }

            SettingSlider {
                visible: page.section === "microphone"
                Layout.fillWidth: true
                label: I18n.tr("Voice threshold")
                unit: "%"
                from: 0
                to: 95
                value: AudioEffects.threshold
                onMoved: value => AudioEffects.setThreshold(Math.round(value))
            }

            Note {
                visible: page.section === "microphone"
                text: I18n.tr("How sure it must be that it hears a voice before letting the sound through. Higher cuts more noise, and may clip the start of words.")
            }

            SettingSlider {
                visible: page.section === "microphone"
                Layout.fillWidth: true
                label: I18n.tr("Hold after speaking")
                unit: " ms"
                from: 0
                to: 1000
                value: AudioEffects.hold
                onMoved: value => AudioEffects.setHold(Math.round(value / 10) * 10)
            }

            Note {
                visible: page.section === "microphone"
                text: I18n.tr("How long it stays open once you stop. Longer lets the room in as a faint static after each sentence; shorter may clip the ends of words.")
            }

            Row {
                visible: page.section === "microphone"
                text: I18n.tr("Listen to yourself")

                Chip {
                    text: AudioEffects.listening ? I18n.tr("on") : I18n.tr("off")
                    on: AudioEffects.listening
                    onClicked: AudioEffects.listening = !AudioEffects.listening
                }
            }

            Note {
                visible: page.section === "microphone"
                Layout.bottomMargin: 4
                text: I18n.tr("Plays the microphone in your headphones as others hear it, while this page is open. Through speakers it would feed back.")
            }
        }
    }

    MoreBelow {
        flickable: flick
    }

    Button {
        Layout.alignment: Qt.AlignRight
        visible: page.section === "interface"
        enabled: Settings.soundsChanged
        text: I18n.tr("Back to the defaults")
        onClicked: Settings.resetSounds()
    }
}
