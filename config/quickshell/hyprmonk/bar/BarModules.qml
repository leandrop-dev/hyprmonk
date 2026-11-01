// The modules of one of the bar's cards, in the order Settings left them.
// `room` is the most they may take: the hardware drawer stops there.
import QtQuick
import Qt.labs.qmlmodels
import Quickshell
import qs.services

Repeater {
    id: list

    required property ShellScreen screen
    required property bool panelOpen
    property real room: Infinity

    // What the rest of the card takes from the drawer, spacing included.
    readonly property real others: {
        if (!model.includes("hardware")) return 0;
        let width = 0;
        for (let i = 0; i < count; i++) {
            const item = itemAt(i);
            if (item && model[i] !== "hardware" && item.visible) width += item.implicitWidth + 2;
        }
        return width;
    }

    function opened(name: string): bool {
        return panelOpen && Panels.open === name;
    }

    delegate: DelegateChooser {
        role: "modelData"

        DelegateChoice {
            roleValue: "launcher"
            LauncherButton {}
        }
        DelegateChoice {
            roleValue: "workspaces"
            Workspaces { screen: list.screen }
        }
        DelegateChoice {
            roleValue: "overview"
            Overview {}
        }
        DelegateChoice {
            roleValue: "hardware"
            HardwareDrawer { room: list.room - list.others }
        }
        DelegateChoice {
            roleValue: "recording"
            Recording {}
        }
        DelegateChoice {
            roleValue: "replay"
            Replay {}
        }
        DelegateChoice {
            roleValue: "tray"
            TrayIcons {}
        }
        DelegateChoice {
            roleValue: "network"
            NetworkButton { active: list.opened("network") }
        }
        DelegateChoice {
            roleValue: "bluetooth"
            BluetoothButton { active: list.opened("bluetooth") }
        }
        DelegateChoice {
            roleValue: "batteries"
            Batteries { active: list.opened("batteries") }
        }
        DelegateChoice {
            roleValue: "volume"
            Volume { active: list.opened("sound") }
        }
        DelegateChoice {
            roleValue: "microphone"
            Microphone { active: list.opened("microphone") }
        }
        DelegateChoice {
            roleValue: "notifications"
            NotificationBell {}
        }
        DelegateChoice {
            roleValue: "clock"
            Clock { active: list.opened("calendar") }
        }
        DelegateChoice {
            roleValue: "quickactions"
            QuickActionsButton {}
        }
        DelegateChoice {
            roleValue: "power"
            PowerButton {}
        }
    }
}
