// One quick action: its row (icon, label and a pill on the right) and what it
// does when run. Given `options`, running it opens them as a list of their
// own, the pill's `value` marked, and `picked` says which was chosen. With
// `previews`, the option under the cursor is tried as it moves (`previewed`)
// and put back when the list is left without picking (`unpreviewed`).
import QtQuick

QtObject {
    property string section: ""
    property string icon: ""
    property string label: ""
    property var on: undefined   // a switch: true or false; undefined for none
    property string value: ""    // a word for the pill instead ("balanced")
    property bool available: true
    property var options: []
    property bool previews: false

    signal run()
    signal picked(string option)
    signal previewed(string option)
    signal unpreviewed()
}
