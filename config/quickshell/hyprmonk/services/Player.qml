// The media player the bar and its media panel show: the one picked in the
// panel while it is still open, else the one playing, else the first that can
// play.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer picked: null

    readonly property MprisPlayer current: (picked && players.includes(picked) ? picked : null)
        ?? players.find(p => p.isPlaying)
        ?? players.find(p => p.canPlay)
        ?? null

    // Title and artist on one line, for the bar.
    readonly property string summary: {
        if (!current) return "";
        return [current.trackTitle, current.trackArtist].filter(s => s).join(" · ");
    }

    // The next player along, for the panel's switch.
    function pickNext(): void {
        if (players.length < 2) return;
        picked = players[(players.indexOf(current) + 1) % players.length];
    }

    // The track's length in seconds, 0 when it has none (a live stream).
    // Browsers drop the length from their metadata a moment after a seek and
    // only send it again on the next play or pause, so the last one seen for
    // this track is kept. A live stream reports no length, or the largest one
    // there is (2^63 µs): anything over a day counts as none.
    readonly property string track: current ? [current.identity, current.trackTitle, current.trackArtist].join("\n") : ""
    readonly property real reported: current?.lengthSupported && current.length > 0 && current.length < 86400 ? current.length : 0
    property string knownTrack: ""
    property real knownLength: 0
    readonly property real length: reported > 0 ? reported : (track === knownTrack ? knownLength : 0)

    function remember(): void {
        if (reported > 0) {
            knownTrack = track;
            knownLength = reported;
        }
    }

    onReportedChanged: remember()
    onTrackChanged: remember()
    Component.onCompleted: remember()

    // 4:07, or 1:02:03 past an hour.
    function time(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s % 60) : m + ":" + pad(s % 60);
    }
}
