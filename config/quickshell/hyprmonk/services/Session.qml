// What the rest of the shell pauses for: the screen locked (reported by
// lock/Lock.qml) or a game running. Animations and timers nobody can see stop
// meanwhile (`seen`).
pragma Singleton

import Quickshell

Singleton {
    property bool locked: false
    readonly property bool seen: !locked && !GameMode.on
}
