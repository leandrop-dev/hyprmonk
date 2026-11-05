// Brightness, two ways:
// - Each screen's own backlight and contrast, set in the monitor through
//   DDC/CI (ddcutil), as its buttons would. A screen that does not answer
//   (DDC/CI off in its menu, or a laptop panel) is listed without them. Read
//   when Settings asks; the monitor keeps what is set.
// - Dimming on top, by hyprsunset's colour matrix (services/NightLight.qml
//   runs it): every screen at once, and darker than a monitor goes, at some
//   cost in contrast. Kept in brightness.json in the state directory.
// Each DDC/CI write takes about a third of a second, so while a slider moves
// only the latest value waits for the one under way.
//
// IPC: qs -c hyprmonk ipc call brightness set <screen> <0-100>
//      qs -c hyprmonk ipc call brightness step <-100-100>
//      qs -c hyprmonk ipc call brightness dim <30-100>
//      qs -c hyprmonk ipc call brightness status
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    readonly property var dimRange: ({ from: 30, to: 100, value: 100 })  // %
    readonly property int dim: Math.max(dimRange.from, Math.min(dimRange.to, saved.dim))

    // The screens that answer, by connector name: { bus, brightness,
    // brightnessMax, contrast, contrastMax }, a feature missing when not
    // offered.
    property var screens: ({})
    property bool reading: false
    property bool read: false  // read at least once

    // What waits to be written, by screen and feature: { "HDMI-A-1": { 10: 80 } }.
    property var pending: ({})

    readonly property var features: ({ brightness: "10", contrast: "12" })

    Component.onCompleted: refresh()

    function setDim(value: real): void {
        saved.dim = Math.max(dimRange.from, Math.min(dimRange.to, Math.round(value)));
    }

    // The brightness keys (config/hypr/binds.lua): the focused screen's own
    // brightness, or every screen's when it does not answer; below its
    // lowest, the dimming goes on down, and going up takes that off first.
    // Steps from what was last read or set, so a change on the monitor's own
    // buttons since is not seen. Each step is shown (osd/Osd.qml).
    signal stepped(string caption, int value)

    function step(delta: int): void {
        const focused = Hyprland.focusedMonitor?.name ?? "";
        const names = screens[focused]?.brightness !== undefined ? [focused]
            : Object.keys(screens).filter(name => screens[name].brightness !== undefined);
        const lowest = names.length === 0 || names.every(name => screens[name].brightness === 0);
        if (dim < 100 || (delta < 0 && lowest)) {
            setDim(dim + delta);
            stepped(dim === 100 ? "Dimming off" : "Dimmed to " + dim + "%", 0);
            return;
        }
        for (const name of names) set(name, "brightness", screens[name].brightness + delta * screens[name].brightnessMax / 100);
        if (names.length === 0) return;
        const percent = Math.round(screens[names[0]].brightness * 100 / screens[names[0]].brightnessMax);
        stepped(percent + "%", percent);
    }

    function refresh(): void {
        if (reading) return;
        reading = true;
        detect.running = true;
    }

    // Shown at once; written to the monitor when the one before is done.
    function set(name: string, feature: string, value: real): void {
        const screen = screens[name];
        if (!screen || screen[feature] === undefined) return;
        const max = screen[feature + "Max"];
        const clamped = Math.max(0, Math.min(max, Math.round(value)));
        screens = Object.assign({}, screens, { [name]: Object.assign({}, screen, { [feature]: clamped }) });
        const waiting = Object.assign({}, pending);
        waiting[name] = Object.assign({}, waiting[name] ?? {}, { [features[feature]]: clamped });
        pending = waiting;
        write();
    }

    function write(): void {
        if (writing.running) return;
        const name = Object.keys(pending)[0];
        if (name === undefined) return;
        const code = Object.keys(pending[name])[0];
        const value = pending[name][code];
        const waiting = Object.assign({}, pending);
        delete waiting[name][code];
        if (Object.keys(waiting[name]).length === 0) delete waiting[name];
        pending = waiting;
        writing.command = ["ddcutil", "--bus", String(screens[name].bus), "setvcp", code, String(value), "--noverify"];
        writing.running = true;
    }

    // Each screen DDC/CI finds, as "<bus> <connector>", then its brightness
    // and contrast, as "VCP 10 C <now> <max>" ("VCP 12 ERR" when not
    // offered).
    Process {
        id: detect

        command: ["sh", "-c", "ddcutil detect --brief | awk '"
            + "/^Display/ { valid = 1 } /^Invalid display/ { valid = 0 } "
            + "valid && /I2C bus:/ { sub(/.*i2c-/, \"\"); bus = $0 } "
            + "valid && /DRM connector:/ { sub(/.*card[0-9]+-/, \"\"); print bus, $0 }' "
            + "| while read -r bus name; do echo \"screen $bus $name\"; ddcutil --bus \"$bus\" getvcp 10 12 --brief; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                let name = "";
                for (const line of text.split("\n")) {
                    const words = line.trim().split(/\s+/);
                    if (words[0] === "screen" && words.length >= 3) {
                        name = words[2];
                        found[name] = { bus: Number(words[1]) };
                    } else if (words[0] === "VCP" && words[2] === "C" && name !== "") {
                        const feature = words[1] === "10" ? "brightness" : words[1] === "12" ? "contrast" : "";
                        if (feature === "") continue;
                        found[name][feature] = Number(words[3]);
                        found[name][feature + "Max"] = Number(words[4]);
                    }
                }
                root.screens = found;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("brightness:", text.trim())
        }
        onExited: {
            root.reading = false;
            root.read = true;
        }
    }

    Process {
        id: writing

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("brightness:", text.trim())
        }
        onExited: root.write()
    }

    FileView {
        path: Theme.stateDir + "/brightness.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: saved
            property int dim: 100  // %, 100 for none
        }
    }

    IpcHandler {
        target: "brightness"

        function set(name: string, value: int): string {
            if (!root.screens[name]) return "no such screen answers DDC/CI: " + name;
            root.set(name, "brightness", value);
            return name + " " + root.screens[name].brightness;
        }

        function dim(value: int): int {
            root.setDim(value);
            return root.dim;
        }

        // A signed step in percent, as from the brightness keys.
        function step(delta: int): void {
            root.step(delta);
        }

        function status(): string {
            return Object.keys(root.screens).map(name => {
                const screen = root.screens[name];
                return name + ": brightness " + (screen.brightness ?? "–") + ", contrast " + (screen.contrast ?? "–");
            }).concat(["dimmed to " + root.dim + "%"]).join("\n");
        }
    }
}
