// What the calendar marks (panels/CalendarPanel.qml): a country's public
// holidays, from Nager.Date (date.nager.at, free, no key), kept a year at a
// time in ~/.cache/hyprmonk/holidays and fetched again after a month, so the
// calendar keeps them offline. Regional days (the Azores' in Portugal, say)
// and optional ones (Carnival) can be left out. The country starts as the
// one in LC_TIME or LANG, and is picked in Settings > Calendar; all kept in
// calendar.json in the state directory.
//
// IPC: qs -c hyprmonk ipc call calendar country <code, e.g. PT>
//      qs -c hyprmonk ipc call calendar holidays <yyyy-mm-dd>
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string api: "https://date.nager.at/api/v3"
    readonly property string cache: Quickshell.env("HOME") + "/.cache/hyprmonk/holidays"

    // From the locale until one is picked ("pt_PT.UTF-8" is PT).
    readonly property string localeCountry: {
        const found = /^[a-z]{2,3}_([A-Z]{2})/.exec(Quickshell.env("LC_TIME") || Quickshell.env("LANG") || "");
        return found ? found[1] : "";
    }
    readonly property string country: saved.country === "none" ? "" : (saved.country || localeCountry)
    readonly property bool regional: saved.regional
    readonly property bool optional: saved.optional

    // Every country it knows: [{ countryCode, name }], once Settings asks.
    property var countries: []
    readonly property string countryName: countries.find(entry => entry.countryCode === country)?.name ?? country

    // By "<country>-<year>": that year's holidays, as Nager.Date gives them.
    property var years: ({})
    property var wanted: []  // keys waiting to be fetched
    property var failed: ({})  // keys that could not be had, not asked again

    function setCountry(code: string): void {
        saved.country = code === "" ? "none" : code;
    }

    function setRegional(on: bool): void {
        saved.regional = on;
    }

    function setOptional(on: bool): void {
        saved.optional = on;
    }

    // Asks for the years a month shows: its own and, at either end of the
    // year, the next or the last (the weeks spill over).
    function need(month: date): void {
        if (country === "") return;
        const year = month.getFullYear();
        const list = [year];
        if (month.getMonth() === 0) list.push(year - 1);
        if (month.getMonth() === 11) list.push(year + 1);
        for (const each of list) fetchYear(each);
    }

    function fetchYear(year: int): void {
        const key = `${country}-${year}`;
        if (key in years || key in failed || wanted.includes(key)) return;
        wanted = wanted.concat([key]);
        next();
    }

    function next(): void {
        if (fetching.running || wanted.length === 0) return;
        const key = wanted[0];
        const [code, year] = key.split("-");
        fetching.key = key;
        fetching.command = ["sh", "-c",
            'mkdir -p "$1" && f="$1/$2.json"; '
            + 'if ! [ -s "$f" ] || [ -n "$(find "$f" -mtime +30)" ]; then '
            + 'curl -sfL -m 15 "$3" -o "$f.part" && mv "$f.part" "$f"; fi; cat "$f"',
            "sh", cache, key, `${api}/PublicHolidays/${year}/${code}`];
        fetching.running = true;
    }

    // The holidays on a day, as shown: { name, local, regional, optional }.
    function holidaysOn(day: date): var {
        const list = years[`${country}-${day.getFullYear()}`];
        if (!list) return [];
        const iso = Qt.formatDate(day, "yyyy-MM-dd");
        return list.filter(entry => entry.date === iso)
            .map(entry => ({
                name: entry.name,
                local: entry.localName,
                regional: !entry.global,
                optional: !(entry.types ?? []).includes("Public")
            }))
            .filter(entry => (regional || !entry.regional) && (optional || !entry.optional));
    }

    function loadCountries(): void {
        if (countries.length === 0 && !countryList.running) countryList.running = true;
    }

    onCountryChanged: {
        wanted = [];
        failed = {};
    }

    Process {
        id: fetching

        property string key: ""

        stdout: StdioCollector {
            onStreamFinished: {
                let list = null;
                try {
                    list = JSON.parse(text);
                } catch (error) {}
                if (Array.isArray(list)) root.years = Object.assign({}, root.years, { [fetching.key]: list });
                else root.failed = Object.assign({}, root.failed, { [fetching.key]: true });
            }
        }
        onExited: {
            root.wanted = root.wanted.filter(key => key !== fetching.key);
            root.next();
        }
    }

    Process {
        id: countryList

        command: ["sh", "-c",
            'mkdir -p "$1" && f="$1/countries.json"; '
            + 'if ! [ -s "$f" ] || [ -n "$(find "$f" -mtime +30)" ]; then '
            + 'curl -sfL -m 15 "$2" -o "$f.part" && mv "$f.part" "$f"; fi; cat "$f"',
            "sh", root.cache, root.api + "/AvailableCountries"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    if (Array.isArray(list)) root.countries = list.sort((a, b) => a.name.localeCompare(b.name));
                } catch (error) {}
            }
        }
    }

    FileView {
        path: Theme.stateDir + "/calendar.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: saved
            property string country: ""  // "" for the locale's, "none" for none
            property bool regional: true
            property bool optional: true
        }
    }

    IpcHandler {
        target: "calendar"

        function country(code: string): string {
            root.setCountry(code.toUpperCase());
            return root.country;
        }

        function holidays(day: string): string {
            const parts = day.split("-").map(Number);
            const date = new Date(parts[0], parts[1] - 1, parts[2]);
            root.fetchYear(parts[0]);
            return root.holidaysOn(date).map(entry => entry.name + (entry.regional ? " (regional)" : "")
                + (entry.optional ? " (optional)" : "")).join("\n") || "none, or not fetched yet";
        }
    }
}
