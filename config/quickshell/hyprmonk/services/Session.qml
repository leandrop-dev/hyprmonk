// What the rest of the shell pauses for: the screen locked (reported by
// lock/Lock.qml). Animations nobody can see stop meanwhile.
pragma Singleton

import Quickshell

Singleton {
    property bool locked: false
}
