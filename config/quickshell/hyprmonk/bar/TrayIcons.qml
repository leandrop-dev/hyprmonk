// Apps' status icons (services/Tray.qml). Click: the app (or its menu, for
// those that only have one); middle click: its other action; right click:
// its menu, as a panel; scroll: passed to the app.
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.services

RowLayout {
    spacing: 2
    visible: Tray.items.length > 0

    Repeater {
        model: Tray.items

        Module {
            id: mod

            required property SystemTrayItem modelData

            interactive: true
            active: Tray.menuOpen && Tray.item === modelData
            tooltip: Tray.nameOf(modelData)

            onClicked: button => {
                if (button === Qt.RightButton || (button === Qt.LeftButton && modelData.onlyMenu)) {
                    if (modelData.hasMenu) Tray.toggleMenu(modelData);
                } else if (button === Qt.LeftButton) {
                    modelData.activate();
                } else if (button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                }
            }
            onScrolled: steps => modelData.scroll(steps, false)

            contents: [
                IconImage {
                    implicitSize: 16
                    source: Tray.iconSource(mod.modelData)
                },
                // Asking to be looked at.
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.leftMargin: -8
                    visible: mod.modelData.status === Status.NeedsAttention
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: Theme.accent
                }
            ]
        }
    }
}
