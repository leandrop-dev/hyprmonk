// The centre card's handle: what the speakers play, as a wave through cava's
// ten bands (services/Cava.qml), warmer towards the accent the louder it is;
// a faint flat line in silence. Like the media beside it: click, the media
// panel; right click, play/pause; scroll, next or previous track.
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

    // The levels drawn ease towards cava's, a step per frame, so the wave
    // moves smoothly at cava's 30 frames a second.
    property var shown: Array(Cava.bands).fill(0)

    Timer {
        id: easing
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            let moving = false;
            root.shown = root.shown.map((level, i) => {
                const target = Cava.levels[i] ?? 0;
                if (Math.abs(target - level) < 0.005) return target;
                moving = true;
                return level + (target - level) * 0.35;
            });
            wave.requestPaint();
            if (!moving) stop();
        }
    }

    Connections {
        target: Cava

        function onLevelsChanged(): void {
            easing.start();
        }
    }

    // The foreground, dim, warming to the accent at full level.
    function tint(level: real): color {
        if (Cava.silent) return Theme.fg(0.25);
        const from = Theme.fg(0.45), to = Theme.accent;
        return Qt.rgba(from.r + (to.r - from.r) * level, from.g + (to.g - from.g) * level,
                       from.b + (to.b - from.b) * level, from.a + (to.a - from.a) * level);
    }

    contents: [
        Canvas {
            id: wave

            implicitWidth: (Cava.bands - 1) * root.step + 4
            implicitHeight: 22

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 2;
                ctx.lineCap = "round";
                const levels = root.shown;
                const y = level => height / 2 + 7 - level * 14;
                // One curve per band, its colour from the louder end.
                for (let i = 0; i < levels.length - 1; i++) {
                    const x1 = 2 + i * root.step, x2 = x1 + root.step, mid = (x1 + x2) / 2;
                    ctx.strokeStyle = root.tint(Math.max(levels[i], levels[i + 1]));
                    ctx.beginPath();
                    ctx.moveTo(x1, y(levels[i]));
                    ctx.bezierCurveTo(mid, y(levels[i]), mid, y(levels[i + 1]), x2, y(levels[i + 1]));
                    ctx.stroke();
                }
            }
        }
    ]
}
