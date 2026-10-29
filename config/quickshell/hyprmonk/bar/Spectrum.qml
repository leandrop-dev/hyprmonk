// The centre card's handle: what the speakers play, through cava's ten bands
// (services/Cava.qml), drawn in the style picked there: a wave, bars from the
// middle, an equalizer from the floor, the same with falling peak caps,
// stacked LEDs, dots on faint stems, or thin lines mirrored around the
// centre. Warmer towards the accent the louder; faint and flat in silence.
// Like the media beside it: click, the media panel; right click, play/pause;
// scroll, next or previous track.
import QtQuick
import qs
import qs.services

Module {
    id: root

    readonly property var player: Player.current
    readonly property int step: 6  // px between bands

    interactive: player !== null

    onClicked: button => {
        if (!player) return;
        if (button === Qt.LeftButton) Panels.toggle("media");
        else if (button === Qt.RightButton && player.canTogglePlaying) player.togglePlaying();
    }
    onScrolled: steps => {
        if (steps > 0 && player?.canGoNext) player.next();
        else if (steps < 0 && player?.canGoPrevious) player.previous();
    }

    // The levels drawn ease towards cava's, a step per tick at cava's own 30
    // frames a second, and the drawing is redone only when something moved.
    // Peaks (the caps) hold a band's highest level for a moment, then fall.
    property var shown: Array(Cava.bands).fill(0)
    property var peaks: Array(Cava.bands).fill(0)
    property var holds: Array(Cava.bands).fill(0)  // ticks a cap still holds

    readonly property real ease: 0.58      // of the way to cava's level, per tick
    readonly property int peakHold: 10     // ticks, about a third of a second
    readonly property real peakFall: 0.04  // per tick once released

    Timer {
        id: easing
        interval: 33
        repeat: true
        running: true
        onTriggered: {
            let moving = false;
            const shown = root.shown.map((level, i) => {
                const target = Cava.levels[i] ?? 0;
                if (Math.abs(target - level) < 0.005) return target;
                moving = true;
                return level + (target - level) * root.ease;
            });
            const holds = root.holds.slice();
            const peaks = root.peaks.map((peak, i) => {
                if (shown[i] >= peak) {
                    holds[i] = root.peakHold;
                    return shown[i];
                }
                moving = true;
                if (holds[i] > 0) {
                    holds[i]--;
                    return peak;
                }
                return Math.max(shown[i], peak - root.peakFall);
            });
            const changed = shown.some((level, i) => level !== root.shown[i])
                || peaks.some((peak, i) => peak !== root.peaks[i]);
            root.shown = shown;
            root.peaks = peaks;
            root.holds = holds;
            if (changed) canvas.requestPaint();
            if (!moving) stop();
        }
    }

    Connections {
        target: Cava

        function onLevelsChanged(): void {
            easing.start();
        }

        function onStyleChanged(): void {
            canvas.requestPaint();
        }
    }

    // The foreground, dim, warming to the accent at full level.
    readonly property color quiet: Theme.fg(0.45)
    readonly property color loud: Theme.accent

    onQuietChanged: canvas.requestPaint()
    onLoudChanged: canvas.requestPaint()

    function tint(level: real): color {
        if (Cava.silent) return Theme.fg(0.25);
        const from = quiet, to = loud;
        return Qt.rgba(from.r + (to.r - from.r) * level, from.g + (to.g - from.g) * level,
                       from.b + (to.b - from.b) * level, from.a + (to.a - from.a) * level);
    }

    contents: [
        Canvas {
            id: canvas

            implicitWidth: (Cava.bands - 1) * root.step + 4
            implicitHeight: 22

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const draw = {
                    wave: drawWave,
                    bars: drawBars,
                    equalizer: drawEqualizer,
                    peaks: drawPeaks,
                    leds: drawLeds,
                    dots: drawDots,
                    mirror: drawMirror
                }[Cava.style] ?? drawWave;
                draw(ctx, root.shown);
            }

            // The middle of band i, and the height a level reaches (silence
            // still shows a sliver, so the module never looks empty).
            function bandX(i: int): real { return 2 + i * root.step; }
            function reach(level: real, most: real): real { return Math.max(2, level * most); }

            function bar(ctx: var, left: real, top: real, width: real, height: real): void {
                const r = Math.min(width, height) / 2;
                ctx.beginPath();
                ctx.roundedRect(left, top, width, height, r, r);
                ctx.fill();
            }

            // One smooth line through the levels, a curve per band coloured
            // by its louder end.
            function drawWave(ctx: var, levels: var): void {
                ctx.lineWidth = 2;
                ctx.lineCap = "round";
                const y = level => height / 2 + 7 - level * 14;
                for (let i = 0; i < levels.length - 1; i++) {
                    const mid = (bandX(i) + bandX(i + 1)) / 2;
                    ctx.strokeStyle = root.tint(Math.max(levels[i], levels[i + 1]));
                    ctx.beginPath();
                    ctx.moveTo(bandX(i), y(levels[i]));
                    ctx.bezierCurveTo(mid, y(levels[i]), mid, y(levels[i + 1]), bandX(i + 1), y(levels[i + 1]));
                    ctx.stroke();
                }
            }

            // From the middle, up and down.
            function drawBars(ctx: var, levels: var): void {
                levels.forEach((level, i) => {
                    const h = reach(level, height - 2);
                    ctx.fillStyle = root.tint(level);
                    bar(ctx, bandX(i) - 1.5, (height - h) / 2, 3, h);
                });
            }

            // From a floor near the bottom, up.
            function drawEqualizer(ctx: var, levels: var): void {
                const floor = height - 2;
                levels.forEach((level, i) => {
                    const h = reach(level, floor - 2);
                    ctx.fillStyle = root.tint(level);
                    bar(ctx, bandX(i) - 1.5, floor - h, 3, h);
                });
            }

            // The equalizer, shorter, with each band's cap above it.
            function drawPeaks(ctx: var, levels: var): void {
                const floor = height - 2, most = floor - 5;
                levels.forEach((level, i) => {
                    const h = reach(level, most);
                    ctx.fillStyle = root.tint(level);
                    bar(ctx, bandX(i) - 1.5, floor - h, 3, h);
                    ctx.fillStyle = root.tint(root.peaks[i]);
                    ctx.fillRect(bandX(i) - 1.5, floor - reach(root.peaks[i], most) - 3, 3, 1.5);
                });
            }

            // Seven segments a band, lit from the bottom, each warmer.
            function drawLeds(ctx: var, levels: var): void {
                const segments = 7, size = 2, gap = 1;
                const bottom = (height + segments * (size + gap) - gap) / 2;
                levels.forEach((level, i) => {
                    const lit = Math.max(1, Math.round(level * segments));
                    for (let s = 0; s < segments; s++) {
                        ctx.fillStyle = s < lit ? root.tint((s + 1) / segments) : Theme.fg(0.08);
                        ctx.fillRect(bandX(i) - 1.5, bottom - (s + 1) * (size + gap) + gap, 3, size);
                    }
                });
            }

            // A dot at the band's level, on a faint stem from the floor.
            function drawDots(ctx: var, levels: var): void {
                const floor = height - 2, most = floor - 4;
                levels.forEach((level, i) => {
                    const top = floor - level * most;
                    ctx.fillStyle = Theme.fg(0.1);
                    ctx.fillRect(bandX(i) - 0.5, top, 1, floor - top);
                    ctx.fillStyle = root.tint(level);
                    ctx.beginPath();
                    ctx.arc(bandX(i), top, 2, 0, Math.PI * 2);
                    ctx.fill();
                });
            }

            // Twenty thin lines from the middle, the lows in the centre and
            // the highs at both ends.
            function drawMirror(ctx: var, levels: var): void {
                const count = levels.length * 2;
                const gap = (width - 2) / (count - 1);
                for (let j = 0; j < count; j++) {
                    const band = Math.abs(j - (count - 1) / 2) - 0.5;
                    const level = levels[Math.round(band)] ?? 0;
                    const h = reach(level, height - 2);
                    ctx.fillStyle = root.tint(level);
                    ctx.fillRect(1 + j * gap - 0.5, (height - h) / 2, 1.5, h);
                }
            }
        }
    ]
}
