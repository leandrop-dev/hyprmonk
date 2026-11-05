// Settings > Calendar (services/Calendar.qml), in two sub-pages:
// - Holidays: the country whose public holidays the calendar marks, found
//   by name or code, or none; and whether regional and optional days count.
// - Calendars: the calendars whose events it shows (services/Events.qml):
//   the local one and each subscribed iCal link, each in a colour.
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

Item {
    id: page

    // The sub-page shown (SettingsCard.qml): holidays or calendars.
    property string section: "holidays"

    onSectionChanged: flick.contentY = 0
    Component.onCompleted: Calendar.loadCountries()

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

    property string feedError: ""

    function addFeed(): void {
        if (!Events.available || feedLink.text.trim() === "") return;
        feedError = Events.addFeed(feedName.text, feedLink.text, "");
        if (feedError !== "") return;
        feedName.text = "";
        feedLink.text = "";
    }

    // A calendar's colours, the one it has ringed.
    component Swatches: RowLayout {
        id: swatches

        property string calendar: ""
        readonly property string current: calendar === "local" ? Events.localColour
            : (Events.feeds.find(feed => feed.id === calendar)?.colour ?? "")

        spacing: 4

        Repeater {
            model: Events.colours

            Rectangle {
                required property string modelData

                implicitWidth: 18
                implicitHeight: 18
                radius: 9
                color: modelData === "" ? Theme.accent : modelData
                border.width: modelData === swatches.current ? 2 : 0
                border.color: Theme.foreground

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Events.setColour(swatches.calendar, modelData)
                }
            }
        }
    }

    component Note: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.fg(0.6)
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

            width: parent.width
            spacing: 8

            SectionLabel {
                visible: page.section === "holidays"
                text: I18n.tr("Holidays")
            }

            Row {
                visible: page.section === "holidays"
                text: Calendar.country === "" ? I18n.tr("No country") : Calendar.countryName + " (" + Calendar.country + ")"

                Chip {
                    text: I18n.tr("None")
                    on: Calendar.country === ""
                    onClicked: Calendar.setCountry("")
                }
            }

            SearchField {
                id: countrySearch

                visible: page.section === "holidays"
                Layout.preferredWidth: 260
                placeholder: I18n.tr("Find a country")
                busy: Calendar.countries.length === 0
                message: I18n.tr("No country by that name")
                results: {
                    const typed = countrySearch.text.trim().toLowerCase();
                    if (typed === "") return [];
                    return Calendar.countries
                        .filter(entry => entry.countryCode.toLowerCase() === typed || entry.name.toLowerCase().includes(typed))
                        .map(entry => ({ code: entry.countryCode, text: entry.name, detail: entry.countryCode,
                                         selected: entry.countryCode === Calendar.country }));
                }
                onPicked: result => {
                    Calendar.setCountry(result.code);
                    text = "";
                }
                onAccepted: if (results.length > 0) picked(results[0])
            }

            Row {
                visible: page.section === "holidays"
                Layout.topMargin: 8
                text: I18n.tr("Regional days")

                Chip {
                    text: Calendar.regional ? I18n.tr("on") : I18n.tr("off")
                    on: Calendar.regional
                    onClicked: Calendar.setRegional(!Calendar.regional)
                }
            }

            Row {
                visible: page.section === "holidays"
                text: I18n.tr("Optional days")

                Chip {
                    text: Calendar.optional ? I18n.tr("on") : I18n.tr("off")
                    on: Calendar.optional
                    onClicked: Calendar.setOptional(!Calendar.optional)
                }
            }

            Note {
                visible: page.section === "holidays"
                text: I18n.tr("Regional days are kept in one part of the country only, such as Azores Day in Portugal; optional ones are days off for some, such as Carnival. Both show fainter on the calendar. The holidays come from Nager.Date and are kept, so the calendar has them offline.")
            }

            // Calendars: the local one and each subscribed link, with its
            // colour; then a new link.
            SectionLabel {
                visible: page.section === "calendars"
                text: I18n.tr("Calendars")
            }

            Note {
                visible: page.section === "calendars" && !Events.available
                color: Theme.warning
                text: I18n.tr("Events need khal and vdirsyncer, which are not installed.")
            }

            Row {
                visible: page.section === "calendars"
                text: I18n.tr("Local")

                Swatches {
                    calendar: "local"
                }
            }

            Repeater {
                model: page.section === "calendars" ? Events.feeds : []

                Row {
                    required property var modelData

                    text: modelData.name

                    Swatches {
                        calendar: modelData.id
                    }

                    Chip {
                        text: I18n.tr("Remove")
                        onClicked: Events.removeFeed(modelData.id)
                    }
                }
            }

            Note {
                visible: page.section === "calendars"
                text: I18n.tr("Events added on the calendar under the bar's clock go to Local. The others are shown as they are, without changes.")
            }

            Row {
                visible: page.section === "calendars" && Events.feeds.length > 0
                Layout.topMargin: 8
                text: Events.syncing ? I18n.tr("Fetching…")
                    : Events.synced.getTime() === 0 ? I18n.tr("Not fetched yet")
                    : I18n.tr("Fetched at %1, and every 15 minutes", Qt.formatTime(Events.synced, "HH:mm"))

                Chip {
                    text: I18n.tr("Fetch now")
                    onClicked: Events.sync()
                }
            }

            Note {
                visible: page.section === "calendars" && Events.syncError !== ""
                color: Theme.warning
                text: Events.syncError
            }

            SectionLabel {
                visible: page.section === "calendars"
                Layout.topMargin: 8
                text: I18n.tr("Add a calendar")
            }

            RowLayout {
                visible: page.section === "calendars"
                Layout.fillWidth: true
                spacing: 6

                TextField {
                    id: feedName
                    Layout.preferredWidth: 140
                    placeholder: I18n.tr("Name")
                    onAccepted: feedLink.takeFocus()
                }

                TextField {
                    id: feedLink
                    Layout.fillWidth: true
                    placeholder: I18n.tr("Its iCal link (https:// or webcal://)")
                    onAccepted: page.addFeed()
                }

                Button {
                    text: I18n.tr("Add")
                    primary: true
                    enabled: Events.available && feedLink.text.trim() !== ""
                    onClicked: page.addFeed()
                }
            }

            Note {
                visible: page.section === "calendars" && page.feedError !== ""
                color: Theme.warning
                text: page.feedError
            }

            Note {
                visible: page.section === "calendars"
                text: I18n.tr("Google Calendar, on the web: Settings, then the calendar under \"Settings for my calendars\", then \"Integrate calendar\": copy the \"Secret address in iCal format\". Outlook: Settings, Calendar, Shared calendars, Publish a calendar: the ICS link. Anyone with the link can see the calendar, so it is kept on this computer only, readable by you alone.")
            }
        }
    }

    MoreBelow {
        flickable: flick
    }
}
