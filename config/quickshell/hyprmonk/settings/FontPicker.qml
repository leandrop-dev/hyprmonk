// One of the two fonts (Settings > Appearance > Fonts): our set as small
// cards written in each font, those installed, and a search through every
// font on the system, its results in a list over the page. The one in use
// is ringed; a font found by search and picked joins the cards. Fonts
// installed while the shell runs show after it restarts (Qt reads the list
// once).
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

ColumnLayout {
    id: picker

    property string title: ""
    property var families: []  // our set, in order
    property string current: ""  // "" until one is picked
    property string note: ""
    // The one in use: the shell's own until one is picked.
    readonly property string inUse: current || Theme.defaultFont
    property string sample: "Aa"

    signal picked(string family)

    readonly property var installed: Qt.fontFamilies()
    readonly property var shown: {
        const ours = families.filter(family => installed.includes(family));
        return ours.includes(inUse) ? ours : ours.concat([inUse]);
    }
    readonly property var found: {
        const words = search.text.trim().toLowerCase().split(/\s+/).filter(word => word !== "");
        if (words.length === 0) return [];
        return installed.filter(family => words.every(word => family.toLowerCase().includes(word))).slice(0, 12);
    }

    // "JetBrainsMono Nerd Font" as "JetBrainsMono".
    function short(family: string): string {
        return family.replace(/ Nerd Font( Mono| Propo)?$/, "");
    }

    spacing: 8

    SectionLabel {
        text: picker.title
    }

    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: picker.shown

            PreviewCard {
                required property string modelData

                label: picker.short(modelData)
                chosen: modelData === picker.inUse
                onClicked: picker.picked(modelData)

                Text {
                    anchors.centerIn: parent
                    text: picker.sample
                    color: Theme.foreground
                    font.family: modelData
                    font.pixelSize: 24
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: picker.note !== ""
        text: picker.note
        wrapMode: Text.Wrap
        color: Theme.fg(0.6)
        font.family: Theme.font
        font.pixelSize: Theme.smallFontSize
    }

    // Any other font on the system, each written in itself.
    SearchField {
        id: search

        Layout.preferredWidth: 260
        placeholder: "Search every font"
        message: "No font by that name"
        results: picker.found.map(family => ({ text: family, family, selected: family === picker.inUse }))
        onPicked: result => {
            picker.picked(result.text);
            text = "";
        }
    }
}
