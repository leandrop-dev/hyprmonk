// One quick action: its row (icon, label and a pill on the right) and what it
// does when run. Given `options`, running it opens them as a list of their
// own, the pill's `value` marked, and `picked` says which was chosen. With
// `stays`, running it leaves the card open, and picking an option goes back
// to the list, for settings changed in a row.
import QtQuick

QtObject {
    property string section: ""
    property string icon: ""
    property string label: ""
    property var on: undefined   // a switch: true or false; undefined for none
    property string value: ""    // a word for the pill instead ("balanced")
    property bool available: true
    property var options: []
    property bool stays: false

    signal run()
    signal picked(string option)
}
