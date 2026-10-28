// One of the bar's cards: a rounded translucent box sized to its modules.
import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: card

    default property alias modules: row.data

    implicitWidth: row.implicitWidth + Theme.cardPadding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.cardRadius
    color: Theme.card
    border.width: 1
    border.color: Theme.rim

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2
    }
}
