// The events the calendar shows (panels/CalendarPanel.qml), read with khal:
// - Subscribed calendars: a Google (or other) calendar's private iCal link,
//   fetched by vdirsyncer into a folder of its own at the shell's start and
//   every 15 minutes after, and shown read-only.
// - The local calendar: events added in the shell, one .ics file each in
//   ~/.local/share/hyprmonk/calendar/local; deleting one removes its file.
// The links, names and colours are kept in calendars.json in the state
// directory; both tools' configs are written from it into the state
// directory's calendar folder, readable only by the user (the links are
// secret).
//
// IPC: qs -c hyprmonk ipc call events sync
//      qs -c hyprmonk ipc call events list <yyyy-mm-dd>
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string data: Quickshell.env("HOME") + "/.local/share/hyprmonk/calendar"
    readonly property string dir: Theme.stateDir + "/calendar"
    readonly property string khalConfig: dir + "/khal.conf"
    readonly property string syncConfig: dir + "/vdirsyncer.conf"

    // The colours a calendar can take; "" is the accent.
    readonly property var colours: ["", "#e5737b", "#e8b05c", "#8cc56b", "#5cb8c4", "#6f9ff0", "#b48cf0"]

    property bool available: false  // khal and vdirsyncer installed
    readonly property var feeds: saved.feeds  // [{ id, name, url, colour }]
    readonly property string localColour: saved.localColour

    // By "yyyy-MM-dd", the events listed for the days last asked for:
    // [{ title, location, start, end, allDay, calendar, uid, repeats }],
    // start and end "HH:mm" ("" all day).
    property var days: ({})
    property date from: new Date()
    property date to: new Date()

    property bool syncing: false
    property string syncError: ""
    property date synced: new Date(0)

    function colourOf(calendar: string): color {
        const value = calendar === "local" ? localColour : (feeds.find(feed => feed.id === calendar)?.colour ?? "");
        return value === "" ? Theme.accent : value;
    }

    function nameOf(calendar: string): string {
        return calendar === "local" ? "Local" : (feeds.find(feed => feed.id === calendar)?.name ?? calendar);
    }

    function eventsOn(day: date): var {
        return days[Qt.formatDate(day, "yyyy-MM-dd")] ?? [];
    }

    // The days the panel shows, listed now and after every change.
    function show(first: date, last: date): void {
        from = first;
        to = last;
        list();
    }

    function list(): void {
        if (!available) return;
        if (listing.running) {
            listing.again = true;
            return;
        }
        listing.first = from;
        listing.command = ["khal", "-c", khalConfig, "list",
            "--json", "title", "--json", "location", "--json", "start-time", "--json", "end-time",
            "--json", "all-day", "--json", "calendar", "--json", "uid", "--json", "repeat-symbol",
            Qt.formatDate(from, "yyyy-MM-dd"), Qt.formatDate(to, "yyyy-MM-dd")];
        listing.running = true;
    }

    function sync(): void {
        if (!available || syncing) return;
        syncing = true;
        syncer.running = true;
    }

    // Both configs, then the events again (and a sync when a link is new).
    function configure(): void {
        const feedBlocks = feeds.map(feed => `
[[${feed.id}]]
path = ${data}/${feed.id}
readonly = True
`).join("");
        const khal = `[calendars]
[[local]]
path = ${data}/local
${feedBlocks}
[locale]
timeformat = %H:%M
dateformat = %Y-%m-%d
longdateformat = %Y-%m-%d
datetimeformat = %Y-%m-%d %H:%M
longdatetimeformat = %Y-%m-%d %H:%M
firstweekday = 0

[default]
default_calendar = local

[sqlite]
path = ${Quickshell.env("HOME")}/.cache/hyprmonk/khal.db
`;
        const pairs = feeds.map(feed => `
[pair ${feed.id}]
a = "${feed.id}_link"
b = "${feed.id}_folder"
collections = null
conflict_resolution = "a wins"

[storage ${feed.id}_link]
type = "http"
url = ${JSON.stringify(feed.url)}

[storage ${feed.id}_folder]
type = "filesystem"
path = ${JSON.stringify(data + "/" + feed.id)}
fileext = ".ics"
`).join("");
        const vdirsyncer = `[general]
status_path = ${JSON.stringify(dir + "/status")}
${pairs}`;
        writer.command = ["sh", "-c",
            'umask 077 && mkdir -p "$1" "$2/local" && printf "%s" "$3" > "$1/khal.conf" && '
            + 'printf "%s" "$4" > "$1/vdirsyncer.conf" && d="$2" && shift 4 && for id; do mkdir -p "$d/$id"; done',
            "sh", dir, data, khal, vdirsyncer].concat(feeds.map(feed => feed.id));
        writer.running = true;
    }

    // A link as given: webcal:// is https://.
    function addFeed(name: string, url: string, colour: string): string {
        const link = url.trim().replace(/^webcal:\/\//i, "https://");
        if (!/^https?:\/\/\S+$/i.test(link)) return "That is not a web link";
        if (feeds.some(feed => feed.url === link)) return "That calendar is already here";
        const id = "feed" + Date.now();
        saved.feeds = feeds.concat([{ id, name: name.trim() || "Calendar", url: link, colour }]);
        configure();
        return "";
    }

    function removeFeed(id: string): void {
        saved.feeds = feeds.filter(feed => feed.id !== id);
        remover.command = ["sh", "-c", 'rm -rf "$1/$3" && rm -f "$2/status/$3".*', "sh", data, dir, id];
        remover.running = true;
    }

    function setColour(calendar: string, colour: string): void {
        if (calendar === "local") saved.localColour = colour;
        else saved.feeds = feeds.map(feed => feed.id === calendar ? Object.assign({}, feed, { colour }) : feed);
    }

    // A local event: a title, its day, and from and to as "HH:mm" (both ""
    // for all day; to before from ends an hour after); repeat "" or weekly,
    // monthly or yearly.
    function add(title: string, day: date, start: string, end: string, repeat: string): void {
        const text = title.trim().replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\n/g, "\\n");
        if (text === "") return;
        const uid = `${Date.now()}-${Math.floor(Math.random() * 1e6)}@hyprmonk`;
        const stamp = when => Qt.formatDateTime(when, "yyyyMMdd'T'HHmmss");
        let lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//hyprmonk//calendar//EN", "BEGIN:VEVENT",
                     "UID:" + uid, "DTSTAMP:" + new Date().toISOString().replace(/[-:]|\.\d+/g, "")];
        if (start === "") {
            const next = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1);
            lines.push("DTSTART;VALUE=DATE:" + Qt.formatDate(day, "yyyyMMdd"), "DTEND;VALUE=DATE:" + Qt.formatDate(next, "yyyyMMdd"));
        } else {
            const at = text => {
                const [hours, minutes] = text.split(":").map(Number);
                return new Date(day.getFullYear(), day.getMonth(), day.getDate(), hours, minutes);
            };
            const begins = at(start);
            let ends = end === "" ? null : at(end);
            if (!ends || ends <= begins) ends = new Date(begins.getTime() + 3600000);
            lines.push("DTSTART:" + stamp(begins), "DTEND:" + stamp(ends));
        }
        if (repeat !== "") lines.push("RRULE:FREQ=" + repeat.toUpperCase());
        lines.push("SUMMARY:" + text, "END:VEVENT", "END:VCALENDAR");
        adder.command = ["sh", "-c", 'umask 077 && mkdir -p "$1" && printf "%s" "$3" > "$1/$2.part" && mv "$1/$2.part" "$1/$2"',
                         "sh", data + "/local", uid.replace("@", "-") + ".ics", lines.join("\r\n") + "\r\n"];
        adder.running = true;
    }

    // Only a local event: the file holding its UID goes.
    function remove(uid: string): void {
        adder.command = ["sh", "-c", 'grep -lF "UID:$2" "$1"/*.ics | while read -r f; do rm -f "$f"; done',
                         "sh", data + "/local", uid];
        adder.running = true;
    }

    Component.onCompleted: checker.running = true

    Process {
        id: checker
        command: ["sh", "-c", "command -v khal && command -v vdirsyncer"]
        onExited: code => {
            root.available = code === 0;
            if (root.available) root.configure();
        }
    }

    Process {
        id: writer
        onExited: {
            root.list();
            if (root.feeds.length > 0) root.sync();
        }
    }

    Process {
        id: remover
        onExited: root.configure()
    }

    Process {
        id: adder
        onExited: root.list()
    }

    Process {
        id: listing

        property date first: new Date()
        property bool again: false

        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                text.split("\n").forEach((line, i) => {
                    let list = null;
                    try {
                        list = JSON.parse(line);
                    } catch (error) {
                        return;
                    }
                    const day = new Date(listing.first.getFullYear(), listing.first.getMonth(), listing.first.getDate() + i);
                    found[Qt.formatDate(day, "yyyy-MM-dd")] = list.map(entry => ({
                        title: entry.title,
                        location: entry.location,
                        start: entry["start-time"],
                        end: entry["end-time"],
                        allDay: entry["all-day"] === "True",
                        calendar: entry.calendar,
                        uid: entry.uid,
                        repeats: entry["repeat-symbol"] !== ""
                    })).sort((a, b) => (a.allDay ? "" : a.start).localeCompare(b.allDay ? "" : b.start));
                });
                root.days = found;
            }
        }
        onExited: {
            if (!again) return;
            again = false;
            root.list();
        }
    }

    Process {
        id: syncer

        command: ["sh", "-c", 'vdirsyncer -c "$1" discover < /dev/null > /dev/null && vdirsyncer -c "$1" sync > /dev/null',
                  "sh", root.syncConfig]
        stderr: StdioCollector {
            id: syncErrors
        }
        onExited: code => {
            root.syncing = false;
            root.synced = new Date();
            // The last error line, with the calendar's name for its id.
            const last = syncErrors.text.trim().split("\n").filter(line => /error/i.test(line)).pop() ?? "";
            root.syncError = code === 0 ? "" : root.feeds.reduce((text, feed) => text.split(feed.id).join(feed.name),
                                                                last.replace(/^error:\s*/i, "") || "The calendars could not be fetched");
            root.list();
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.available && root.feeds.length > 0
        onTriggered: root.sync()
    }

    FileView {
        path: Theme.stateDir + "/calendars.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: saved
            property var feeds: []
            property string localColour: ""
        }
    }

    IpcHandler {
        target: "events"

        function sync(): string {
            root.sync();
            return root.available ? "syncing" : "khal or vdirsyncer is missing";
        }

        function list(day: string): string {
            const parts = day.split("-").map(Number);
            return root.eventsOn(new Date(parts[0], parts[1] - 1, parts[2]))
                .map(entry => (entry.allDay ? "all day" : entry.start + "-" + entry.end) + " " + entry.title + " (" + root.nameOf(entry.calendar) + ")")
                .join("\n") || "nothing, or not listed yet";
        }
    }
}
