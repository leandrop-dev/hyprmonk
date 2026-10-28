// The centre card: what is playing (services/Player.qml), or a dim note when
// nothing is. Click: the media panel; right click: play/pause; scroll: next or
// previous track.
import QtQuick
import qs
import qs.services

Module {
    id: root

    readonly property var player: Player.current

    icon: player?.isPlaying ? "\u{F0387}" : (player ? "\u{F03E4}" : "\u{F0387}")
    label: Player.summary.length > 48 ? Player.summary.slice(0, 47) + "…" : Player.summary
    dim: !player?.isPlaying
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
}
