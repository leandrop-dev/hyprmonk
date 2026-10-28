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

    // 4:07, or 1:02:03 past an hour.
    function time(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s % 60) : m + ":" + pad(s % 60);
    }
}
