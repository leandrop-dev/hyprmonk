// The screens and their modes, for Settings > Display. Resolution, rate,
// scale and where the screen sits are picked first, then tried together: that
// reaches Hyprland but not settings.lua, and goes back by itself after 15
// seconds unless kept, so a mode the screen cannot show fixes itself, and a
// restart would start from the last one kept.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    property var monitors: []
    property string picked: ""  // the screen being changed
    readonly property var monitor: monitors.find(screen => screen.name === picked) ?? monitors[0] ?? null

    // From "2560x1080@74.99Hz". One rate twice (59.94 and 59.940) counts once.
    readonly property var modes: {
        const found = [];
        for (const text of monitor?.availableModes ?? []) {
            const parts = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(text);
            if (!parts) continue;
            const mode = { width: Number(parts[1]), height: Number(parts[2]), rate: Number(parts[3]) };
            mode.resolution = mode.width + "x" + mode.height;
            if (!found.some(other => other.resolution === mode.resolution && other.rate === mode.rate)) found.push(mode);
        }
        return found.sort((a, b) => b.width * b.height - a.width * a.height || b.width - a.width || b.rate - a.rate);
    }
    readonly property var resolutions: modes.map(mode => mode.resolution).filter((name, index, all) => all.indexOf(name) === index)
    // What the screen is on.
    readonly property string resolution: monitor ? monitor.width + "x" + monitor.height : ""
    // The rate in its list nearest to the one the screen reports (74.991).
    readonly property real rate: ratesFor(resolution).reduce((best, rate) => Math.abs(rate - monitor.refreshRate) < Math.abs(best - monitor.refreshRate) ? rate : best, ratesFor(resolution)[0] ?? 0)

    // What the page has picked, nothing having changed yet: "" or 0 for what
    // the screen is on. `shown` is that, made to fit: a new resolution starts
    // at its fastest rate, and a scale it cannot take goes back to 100%.
    property string chosenResolution: ""
    property real chosenRate: 0
    property real chosenScale: 0
    readonly property string shownResolution: chosenResolution || resolution
    readonly property var rates: ratesFor(shownResolution)
    readonly property real shownRate: rates.includes(chosenRate) ? chosenRate
        : shownResolution === resolution ? rate : rates[0] ?? 0
    readonly property var scales: {
        const [width, height] = shownResolution.split("x").map(Number);
        return scalesFor(width, height);
    }
    readonly property real shownScale: {
        if (chosenScale === 0 && shownResolution === resolution) return monitor?.scale ?? 1;
        const wanted = chosenScale || monitor?.scale;
        return scales.includes(wanted) ? wanted : 1;
    }
    // Where it sits, as "XxY" in layout pixels (after scale).
    readonly property string position: monitor ? monitor.x + "x" + monitor.y : ""
    property string chosenPosition: ""
    readonly property string shownPosition: chosenPosition || position
    readonly property bool changed: monitor !== null && (shownResolution !== resolution || shownRate !== rate
        || shownScale !== monitor.scale || shownPosition !== position)

    // Every screen as a box in layout pixels, the one being changed as picked.
    readonly property var boxes: monitors.map(screen => {
        const own = screen.name === monitor?.name;
        const [width, height] = own ? shownResolution.split("x").map(Number) : [screen.width, screen.height];
        const [x, y] = own ? shownPosition.split("x").map(Number) : [screen.x, screen.y];
        const scale = own ? shownScale : screen.scale;
        const turned = screen.transform % 2 === 1;  // 90 or 270 degrees
        return {
            name: screen.name,
            x, y,
            width: Math.round((turned ? height : width) / scale),
            height: Math.round((turned ? width : height) / scale)
        };
    })

    property var previous: null  // what a try goes back to; null when none
    property int left: 0         // seconds until it does
    readonly property bool trying: previous !== null

    function ratesFor(name: string): var {
        return modes.filter(mode => mode.resolution === name).map(mode => mode.rate);
    }

    function clearChoice(): void {
        chosenResolution = "";
        chosenRate = 0;
        chosenScale = 0;
        chosenPosition = "";
    }

    // Where the picked screen lands when dropped at x, y: touching another
    // screen along at least half an edge, overlapping none, and lined up with an edge or the
    // middle of that screen when within `slack`. The nearest such place wins;
    // with none, it stays where it was.
    function placeAt(x: real, y: real, slack: real): void {
        const own = boxes.find(box => box.name === monitor?.name);
        const others = boxes.filter(box => box !== own);
        if (!own || others.length === 0) return;
        const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
        const lineUp = (value, targets) => {
            const near = targets.reduce((best, target) => Math.abs(target - value) < Math.abs(best - value) ? target : best);
            return Math.abs(near - value) <= slack ? near : Math.round(value);
        };
        const places = [];
        for (const other of others) {
            // At least half the shorter edge is shared.
            const shareY = Math.round(Math.min(own.height, other.height) / 2);
            const shareX = Math.round(Math.min(own.width, other.width) / 2);
            const alongY = clamp(y, other.y - own.height + shareY, other.y + other.height - shareY);
            const alongX = clamp(x, other.x - own.width + shareX, other.x + other.width - shareX);
            const ys = [other.y, other.y + other.height - own.height, other.y + Math.round((other.height - own.height) / 2)];
            const xs = [other.x, other.x + other.width - own.width, other.x + Math.round((other.width - own.width) / 2)];
            for (const sideX of [other.x - own.width, other.x + other.width])
                places.push({ x: sideX, y: lineUp(alongY, ys) });
            for (const sideY of [other.y - own.height, other.y + other.height])
                places.push({ x: lineUp(alongX, xs), y: sideY });
        }
        const overlaps = place => others.some(other => place.x < other.x + other.width && place.x + own.width > other.x
            && place.y < other.y + other.height && place.y + own.height > other.y);
        const distance = place => Math.hypot(place.x - x, place.y - y);
        const best = places.filter(place => !overlaps(place)).sort((a, b) => distance(a) - distance(b))[0];
        if (best) chosenPosition = best.x + "x" + best.y;
    }

    // Hyprland corrects a scale that does not give a whole number of pixels.
    function scalesFor(width: int, height: int): var {
        const whole = value => Math.abs(value - Math.round(value)) < 0.000001;
        return [1, 1.25, 1.5, 1.6, 1.75, 2].filter(scale => whole(width / scale) && whole(height / scale));
    }

    function refresh(): void {
        reader.running = true;
    }

    function current(): var {
        return {
            mode: resolution + "@" + rate,
            position: monitor.x + "x" + monitor.y,
            scale: monitor.scale
        };
    }

    // What was picked, on the screen. Tried again during a try, it still goes
    // back to where the first one started.
    function tryChoice(): void {
        if (!changed) return;
        const next = { mode: shownResolution + "@" + shownRate, position: shownPosition, scale: shownScale };
        previous = { name: monitor.name, was: previous?.was ?? current(), next };
        left = 15;
        apply(monitor.name, next);
    }

    function keep(): void {
        if (!trying) return;
        Settings.setDisplay(previous.name, previous.next);
        apply(previous.name, previous.next);  // a reload may have undone it meanwhile
        previous = null;
        clearChoice();
    }

    function goBack(): void {
        if (!trying) return;
        apply(previous.name, previous.was);
        previous = null;
        clearChoice();
    }

    function resetScreen(): void {
        clearChoice();
        Settings.resetDisplay(monitor.name);
    }

    function apply(name: string, value: var): void {
        Quickshell.execDetached(["hyprctl", "eval", Settings.displayLine(name, value)]);
        rereader.restart();
    }

    Timer {
        running: root.trying
        repeat: true
        interval: 1000
        onTriggered: {
            root.left -= 1;
            if (root.left <= 0) root.goBack();
        }
    }

    // After a change, once the screen has settled. What a try goes back to has
    // to be what the screen is on, and a reload can change that (the defaults).
    Timer {
        id: rereader
        interval: 700
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded") rereader.restart();
        }
    }

    Process {
        id: reader
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text);
                } catch (error) {}
            }
        }
    }
}
