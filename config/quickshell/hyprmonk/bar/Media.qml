// The centre card: what is playing (MPRIS), or a dim note when nothing is.
// Click: play/pause. Scroll: next/previous track.
import QtQuick
import Quickshell.Services.Mpris
import qs

Module {
    id: root

    // The player that is playing, else the first one that can play.
    readonly property MprisPlayer player: Mpris.players.values.find(p => p.isPlaying)
        ?? Mpris.players.values.find(p => p.canPlay) ?? null
    readonly property string title: {
        if (!player) return "";
        const parts = [player.trackTitle, player.trackArtist].filter(s => s);
        const text = parts.join(" · ");
        return text.length > 48 ? text.slice(0, 47) + "…" : text;
    }

    icon: player?.isPlaying ? "\u{F0387}" : (player ? "\u{F03E4}" : "\u{F0387}")
    label: title
    dim: !player?.isPlaying
    interactive: player !== null

    onClicked: if (player?.canTogglePlaying) player.togglePlaying()
    onScrolled: steps => {
        if (steps > 0 && player?.canGoNext) player.next();
        else if (steps < 0 && player?.canGoPrevious) player.previous();
    }
}
