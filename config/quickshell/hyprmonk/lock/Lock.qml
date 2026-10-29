// The lock screen: Wayland's session lock, so nothing reaches the desktop
// until the password checks out (lock/pam/hyprmonk-lock). Each screen gets a
// surface; the focused one at lock time carries the clock and the password
// field, the rest only the frosted wallpaper. The surfaces are opaque.
//
// If the shell dies while locked, restarting it locks again
// (misc.allow_session_lock_restore in look.lua).
//
// IPC: qs -c hyprmonk ipc call lock lock
//      qs -c hyprmonk ipc call lock preview  (the surface in a plain window,
//      no lock: for working on the look, and for trying the password check
//      safely. The right password, Escape or calling it again closes it.)
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.services

Scope {
    id: root

    property string primary: ""      // the screen with the clock and the field
    property string password: ""
    property bool checking: false
    property string error: ""        // why the last try failed
    property int failures: 0
    property bool previewing: false

    function lock(): void {
        if (session.locked) return;
        reset();
        Overlays.close();
        Panels.close();
        session.locked = true;
        // Set here, not from the lock's signal: it is not sent on unlock.
        Session.locked = true;
    }

    function reset(): void {
        primary = Hyprland.focusedMonitor?.name ?? "";
        password = "";
        error = "";
        failures = 0;
        checking = false;
    }

    function submit(): void {
        if (checking || password === "") return;
        error = "";
        checking = pam.start();
        if (!checking) error = "Could not start the password check";
    }

    WlSessionLock {
        id: session


        surface: WlSessionLockSurface {
            id: surface

            color: "transparent"

            LockSurface {
                anchors.fill: parent
                lock: root
                screen: surface.screen
            }
        }
    }

    PamContext {
        id: pam

        configDirectory: "pam"
        config: "hyprmonk-lock"

        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(root.password);
            root.password = "";
        }

        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                session.locked = false;
                Session.locked = false;
                root.previewing = false;
                root.reset();
                return;
            }
            root.failures += 1;
            root.error = result === PamResult.Failed ? "Wrong password" : PamResult.toString(result);
        }

        onError: error => {
            root.checking = false;
            root.password = "";
            root.error = PamError.toString(error);
        }
    }

    PanelWindow {
        id: previewWindow

        visible: root.previewing
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "hyprmonk-lock-preview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.previewing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        LockSurface {
            anchors.fill: parent
            lock: root
            screen: previewWindow.screen
            focus: true
            Keys.onEscapePressed: root.previewing = false
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function preview(): void {
            root.reset();
            root.previewing = !root.previewing;
        }
    }
}
