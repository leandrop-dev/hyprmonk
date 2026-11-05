// How the cards open and close (widgets/CardAnimation.qml): one curve and
// one time for all of them, the bar's panels and drawers, the dock, the
// cards in the middle of the screen, the OSD, the screenshot bar and the
// notification popups. The curve is the windows' own easeOutQuint
// (hypr/look.lua); the time follows Settings > Windows' animation speed, and
// is none while animations are off or game mode holds them off. Hyprland's
// own fade is off for the cards that animate this way (hypr/rules.lua), so
// this is the only one they get.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property var curve: [0.23, 1, 0.32, 1, 1, 1]
    readonly property bool on: Settings.windowChoiceValues.animations !== false && !GameMode.on
    readonly property int card: on ? Math.round(220 * Settings.animationScale[Settings.windowChoiceValues.animationSpeed ?? "normal"]) : 0
}
