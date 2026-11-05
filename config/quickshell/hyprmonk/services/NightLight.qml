// The night light: warmer colours on every screen, off, between set times or
// always. hyprsunset holds the colour (config/systemd/user/hyprmonk-sunset
// .service); this works out how warm it should be from minute to minute and
// tells it through hyprctl. Between set times it fades in over half an hour
// from the start and out over the half hour before the end. While it is off
// hyprsunset is stopped, and the screens are left as they are.
//
// IPC: qs -c hyprmonk ipc call nightlight mode off|scheduled|always
//      qs -c hyprmonk ipc call nightlight status
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property var modes: ["off", "scheduled", "always"]
    readonly property var modeLabels: ({ off: "Off", scheduled: "Between set times", always: "Always" })
    readonly property var warmthRange: ({ from: 2500, to: 6000, value: 5500 })  // kelvin
    readonly property int neutral: 6500  // what the screens show without it
    readonly property int fade: 30  // minutes

    // How warm for what, for Settings: each step a picked warmth. After a
    // table in KTC's guide to colour temperature for late-night gaming, in
    // our own words and stopping at the slider's ends.
    readonly property var guide: [
        { kelvin: 6000, name: "Barely warm", use: "Evenings with a lamp on; colours stay true" },
        { kelvin: 5500, name: "Warm white", use: "A good start for late games and films" },
        { kelvin: 5000, name: "Warm", use: "Long sessions in a dark room; whites turn cream" },
        { kelvin: 4000, name: "Amber", use: "Reading and browsing near bedtime; sepia colours" },
        { kelvin: 3000, name: "Deep amber", use: "The last hour before sleep; colours fade" },
        { kelvin: 2500, name: "Candlelight", use: "Winding down only; colours hard to tell apart" }
    ]

    readonly property string mode: modes.includes(saved.mode) ? saved.mode : "off"
    readonly property int warmth: Math.max(warmthRange.from, Math.min(warmthRange.to, saved.warmth))
    readonly property int from: wrap(saved.from)  // minutes after midnight
    readonly property int to: wrap(saved.to)

    // How far in it is now, from 0 (not at all) to 1 (the full warmth).
    property real level: 0
    readonly property int kelvin: Math.round(neutral - level * (neutral - warmth))
    readonly property bool warm: level > 0

    // A word on what it does next, for Settings.
    readonly property string status: {
        if (mode === "off") return "Off";
        if (mode === "always") return "On, at " + warmth + " K";
        return warm ? "On until " + clock(to) : "Comes on at " + clock(from);
    }

    function wrap(minutes: int): int {
        return ((Math.round(minutes) % 1440) + 1440) % 1440;
    }

    // A time of day in the bar's clock format (Settings > Bar > Look).
    function clock(minutes: int): string {
        const at = new Date(2000, 0, 1, Math.floor(minutes / 60), minutes % 60);
        return Qt.formatDateTime(at, Settings.barChoice("hours") === "12" ? "h:mm AP" : "HH:mm");
    }

    function setMode(value: string): void {
        if (modes.includes(value)) saved.mode = value;
    }

    function setWarmth(value: real): void {
        saved.warmth = Math.max(warmthRange.from, Math.min(warmthRange.to, Math.round(value / 100) * 100));
    }

    function setFrom(minutes: real): void {
        saved.from = wrap(minutes);
    }

    function setTo(minutes: real): void {
        saved.to = wrap(minutes);
    }

    // Between from and to (round midnight when it ends earlier than it
    // starts), the fade at each end half the time at most.
    function levelAt(date: date): real {
        if (mode === "off") return 0;
        if (mode === "always") return 1;
        const now = date.getHours() * 60 + date.getMinutes() + date.getSeconds() / 60;
        const span = (to - from + 1440) % 1440;
        const since = (now - from + 1440) % 1440;
        if (span === 0 || since >= span) return 0;
        const ramp = Math.min(fade, span / 2);
        return Math.min(1, since / ramp, (span - since) / ramp);
    }

    function update(): void {
        level = levelAt(new Date());
    }

    onModeChanged: {
        update();
        send();
    }
    onFromChanged: update()
    onToChanged: update()
    onKelvinChanged: send()

    // While on, hyprsunset runs (and keeps running at the neutral colour
    // between set times, so the evening starts without a wait); the marker
    // lets its unit start at login. hyprsunset takes a moment to answer
    // after a start, hence the tries.
    function send(): void {
        if (!ready) return;
        if (applying.running) {
            queued = true;
            return;
        }
        applying.command = mode === "off"
            ? ["sh", "-c", 'rm -f "$1"; systemctl --user stop hyprmonk-sunset', "sh", marker]
            : ["sh", "-c", 'touch "$1"; systemctl --user start hyprmonk-sunset || exit 1; '
                + 'for try in $(seq 25); do hyprctl hyprsunset $2 >/dev/null && exit 0; sleep 0.2; done; exit 1',
                "sh", marker, warm ? "temperature " + kelvin : "identity"];
        applying.running = true;
    }

    property bool ready: false
    property bool queued: false
    readonly property string marker: Theme.stateDir + "/night-light.on"

    // Each minute, or each 20 s while fading.
    Timer {
        running: root.mode === "scheduled"
        repeat: true
        interval: root.level > 0 && root.level < 1 ? 20000 : 60000
        onTriggered: root.update()
    }

    Process {
        id: applying

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("night light:", text.trim())
        }
        onExited: code => {
            if (code !== 0 && root.mode !== "off") console.warn("night light: hyprsunset did not answer");
            if (root.queued) {
                root.queued = false;
                root.send();
            }
        }
    }

    function start(): void {
        update();
        ready = true;
        send();
    }

    FileView {
        path: Theme.stateDir + "/night-light.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.start()
        onLoadFailed: root.start()

        JsonAdapter {
            id: saved
            property string mode: "off"  // one of modes
            property int warmth: 5500  // kelvin
            property int from: 1200  // 20:00
            property int to: 420  // 07:00
        }
    }

    IpcHandler {
        target: "nightlight"

        function mode(value: string): string {
            root.setMode(value);
            return root.mode;
        }

        function status(): string {
            return root.mode + ", " + (root.warm ? root.kelvin + " K" : "neutral") + " (" + root.status + ")";
        }
    }
}
