// Text in the bar's font, size and colour.
import QtQuick
import qs

Text {
    // What other apps send (titles, names) shows as written, never as markup.
    textFormat: Text.PlainText
    color: Theme.foreground
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    verticalAlignment: Text.AlignVCenter
}
