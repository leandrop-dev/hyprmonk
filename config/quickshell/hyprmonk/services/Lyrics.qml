// Synced lyrics for the player the bar follows (services/Player.qml), from
// LRCLIB (lrclib.net: free, no account), kept per track while the shell
// runs. The media panel shows them in place of the track (its lyrics
// button); with `inBar` the bar's media module shows the line being sung.
// Both switches are kept in lyrics.json.
//
// IPC: qs -c hyprmonk ipc call lyrics toggle | bar | status | line
//
// Players report their position only when asked: while lyrics are shown it
// is asked every second, and a local clock runs in between, or lines would
// switch up to a second late.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs

Singleton {
    id: root

    readonly property MprisPlayer player: Player.current

    // Shown in the media panel, and in the bar.
    readonly property bool shown: settings.shown
    readonly property bool inBar: settings.inBar
    readonly property bool needed: (Panels.open === "media" && shown) || inBar

    function setShown(on: bool): void { settings.shown = on; }
    function setInBar(on: bool): void { settings.inBar = on; }

    // "idle" (no track), "loading", "synced", "plain" (no timing),
    // "instrumental", "none", or "error" (LRCLIB unreachable or busy: not
    // kept, and asked again in a while).
    property string status: "idle"
    property var lines: []   // synced: [{time, text}]; plain: [{time: -1, text}]
    readonly property int index: status === "synced" ? lineAt(position) : -1
    // `lines` and `index` update one after the other: guard the moment between.
    readonly property string line: index >= 0 ? (lines[index]?.text ?? "") : ""

    // The track as asked for, and what came back for each one asked before.
    readonly property var query: {
        if (!player || !player.trackTitle) return null;
        return clean(player.trackArtist, player.trackTitle, player.trackAlbum, Player.length);
    }
    readonly property string key: query ? [query.artist, query.title, Math.round(query.length)].join("\n") : ""
    property var cache: ({})

    onKeyChanged: lookUp()
    onNeededChanged: if (needed && status === "idle") lookUp()
    // Another player: its position, once, or a paused one would show the
    // last player's line.
    onPlayerChanged: player?.positionChanged()

    // Browsers send YouTube-style titles: "Artist - Title (Official Video)"
    // with no artist, or the channel ("Artist - Topic") as the artist. Featured
    // artists go too: LRCLIB lists the song under its own title.
    function clean(artist: string, title: string, album: string, length: real): var {
        let a = (artist ?? "").replace(/ - Topic$/, "").trim();
        let t = (title ?? "").trim();
        const dash = t.indexOf(" - ");
        if (dash > 0 && (a === "" || t.toLowerCase().startsWith(a.toLowerCase() + " - "))) {
            a = t.slice(0, dash).trim();
            t = t.slice(dash + 3).trim();
        }
        t = t.replace(/\s*[\(\[][^\)\]]*(official|video|audio|lyrics?|visuali[sz]er|remaster(ed)?|feat\.?|ft\.)[^\)\]]*[\)\]]/gi, "")
             .replace(/\s+(ft\.|feat\.?|featuring)\s.*$/i, "").trim();
        return { artist: a, title: t, album: (album ?? "").trim(), length };
    }

    function lookUp(): void {
        if (!query) {
            status = "idle";
            lines = [];
            return;
        }
        if (!needed) {
            status = "idle";  // asked for once they are shown
            return;
        }
        const known = cache[key];
        if (known) {
            apply(known);
            return;
        }
        status = "loading";
        lines = [];
        const asked = key, q = query;
        const params = { artist_name: q.artist, track_name: q.title };
        if (q.album) params.album_name = q.album;
        if (q.length > 0) params.duration = Math.round(q.length);
        // The exact match first; else a search, the closest length winning.
        request("get", params, (found, failed) => {
            if (failed) return fail(asked);
            if (found) return answer(asked, found);
            request("search", { artist_name: q.artist, track_name: q.title }, (results, failed) => {
                if (failed) return fail(asked);
                const usable = (results ?? []).filter(r => r.syncedLyrics || r.plainLyrics || r.instrumental);
                usable.sort((a, b) => Math.abs(a.duration - q.length) - Math.abs(b.duration - q.length));
                answer(asked, usable.find(r => r.syncedLyrics) ?? usable[0] ?? null);
            });
        });
    }

    // done(body, failed): body null when not found (404); failed when the
    // server could not answer, or took longer than `timeout` (aborted then).
    // A new request aborts the one before: its track is no longer wanted.
    property var pending: null

    function request(endpoint: string, params: var, done: var): void {
        const search = Object.keys(params).map(k => k + "=" + encodeURIComponent(params[k])).join("&");
        pending?.abort();
        const xhr = new XMLHttpRequest();
        pending = xhr;
        timeout.restart();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (pending !== xhr) return;  // aborted: replaced or timed out
            pending = null;
            timeout.stop();
            if (xhr.status === 404) return done(null, false);
            let body = null;
            try {
                body = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            done(body, body === null);
        };
        xhr.open("GET", "https://lrclib.net/api/" + endpoint + "?" + search);
        xhr.setRequestHeader("Lrclib-Client", "hyprmonk (https://github.com/leandrop-dev/hyprmonk)");
        xhr.send();
    }

    // A track changed meanwhile: keep the answer, show it only if still current.
    function answer(asked: string, found: var): void {
        const result = parse(found);
        cache[asked] = result;
        if (asked === key) apply(result);
    }

    function fail(asked: string): void {
        if (asked !== key) return;
        status = "error";
        lines = [];
        retry.restart();
    }

    Timer {
        id: timeout
        interval: 15000
        onTriggered: {
            const xhr = root.pending;
            root.pending = null;
            xhr?.abort();
            root.fail(root.key);
        }
    }

    Timer {
        id: retry
        interval: 30000
        onTriggered: if (root.status === "error") root.lookUp()
    }

    function apply(result: var): void {
        status = result.status;
        lines = result.lines;
    }

    // LRC: "[01:02.34] words", a line may carry several times; an empty one
    // is a pause, shown as a note.
    function parse(found: var): var {
        if (!found) return { status: "none", lines: [] };
        if (found.syncedLyrics) {
            const lines = [];
            for (const row of found.syncedLyrics.split("\n")) {
                const text = row.replace(/\[[^\]]*\]/g, "").trim() || "♪";
                // An exec loop: the QML engine has no matchAll.
                const stamp = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
                for (let t = stamp.exec(row); t; t = stamp.exec(row))
                    lines.push({ time: Number(t[1]) * 60 + Number(t[2]), text });
            }
            lines.sort((a, b) => a.time - b.time);
            if (lines.length > 0 && lines[0].time > 0) lines.unshift({ time: 0, text: "♪" });
            if (lines.length > 0) return { status: "synced", lines };
        }
        if (found.plainLyrics)
            return { status: "plain", lines: found.plainLyrics.split("\n").map(text => ({ time: -1, text })) };
        if (found.instrumental) return { status: "instrumental", lines: [] };
        return { status: "none", lines: [] };
    }

    // The last line whose time has come.
    function lineAt(seconds: real): int {
        let low = 0, high = lines.length - 1, found = -1;
        while (low <= high) {
            const mid = (low + high) >> 1;
            if (lines[mid].time <= seconds) {
                found = mid;
                low = mid + 1;
            } else {
                high = mid - 1;
            }
        }
        return found;
    }

    // The position: read from the player every second, run locally between.
    property real readAt: 0      // ms, when the player was last read
    property real readPosition: 0
    property real position: 0

    Connections {
        target: root.player

        function onPositionChanged(): void {
            root.readPosition = root.player.position;
            root.readAt = Date.now();
            root.position = root.readPosition;  // the clock is still while paused
        }
    }

    Timer {
        running: root.needed && root.status === "synced" && (root.player?.isPlaying ?? false)
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player.positionChanged()
    }

    Timer {
        running: root.needed && root.status === "synced" && (root.player?.isPlaying ?? false)
        interval: 100
        repeat: true
        onTriggered: {
            const playing = root.player?.isPlaying ?? false;
            root.position = root.readPosition + (playing ? (Date.now() - root.readAt) / 1000 : 0);
        }
    }

    IpcHandler {
        target: "lyrics"

        function toggle(): bool {
            root.setShown(!root.shown);
            return root.shown;
        }

        function bar(): bool {
            root.setInBar(!root.inBar);
            return root.inBar;
        }

        function status(): string {
            return root.status;
        }

        function line(): string {
            return root.line;
        }
    }

    FileView {
        path: Theme.stateDir + "/lyrics.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: settings
            property bool shown: false
            property bool inBar: false
        }
    }
}
