// A panel section's name: small, dim and spaced out ("OUTPUT", "APPS").
import QtQuick
import qs

Text {
    // What other apps send (titles, names) shows as written, never as markup.
    textFormat: Text.PlainText
    color: Theme.fg(Theme.dimOpacity)
    font.family: Theme.font
    font.pixelSize: Theme.smallFontSize
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1.2
}
