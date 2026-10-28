// One quick action: its row (icon, label and a pill on the right) and what it
// does when run.
import QtQuick

QtObject {
    property string section: ""
    property string icon: ""
    property string label: ""
    property var on: undefined   // a switch: true or false; undefined for none
    property string value: ""    // a word for the pill instead ("balanced")
    property bool available: true

    signal run()
}
