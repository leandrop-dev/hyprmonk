// The shell's language, for this account: English, or Portuguese (Portugal).
// How to correct a translation or add a language: docs/translations.md.
// Every text the shell shows goes through `tr` (or `trn` for a count), keyed
// by its English: i18n/<code>.json beside the shell holds the translations,
// and a text missing there stays in English. The bindings that call `tr`
// read `strings`, so a switch re-translates the shell at once.
//
// Picked in Settings > Language and input, kept in language.json in the
// state directory; until then it follows LANG. The account's apps follow too,
// from the next login: language.env, beside it, sets LANG for the session
// (config/uwsm/env sources it); English removes it.
//
// IPC: qs -c hyprmonk ipc call language set <en|pt_PT>
//      qs -c hyprmonk ipc call language get
//      qs -c hyprmonk ipc call language missing   (texts shown untranslated)
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // Each in its own language, never translated.
    readonly property var languages: [
        { code: "en", name: "English", locale: "en_GB", lang: "" },
        { code: "pt_PT", name: "Português (Portugal)", locale: "pt_PT", lang: "pt_PT.UTF-8" }
    ]
    // Until one is picked: the language LANG names (pt_PT.UTF-8 gives
    // pt_PT), else one of the same tongue (pt_BR gives pt_PT), else English.
    readonly property string fromLocale: {
        const lang = Quickshell.env("LANG") ?? "";
        const tongue = entry => entry.locale.split("_")[0];
        const match = languages.find(entry => entry.lang !== "" && lang.startsWith(entry.locale))
            ?? languages.find(entry => entry.lang !== "" && lang.split("_")[0] === tongue(entry));
        return match?.code ?? "en";
    }
    readonly property string language: languages.some(entry => entry.code === saved.language) ? saved.language : fromLocale
    readonly property var current: languages.find(entry => entry.code === language)
    // Month and day names.
    readonly property var locale: Qt.locale(current.locale)

    property var strings: ({})
    property string loaded: ""  // the language `strings` holds
    // Texts looked up without a translation, as keys (filled in place: a
    // binding must not write a property it reads).
    readonly property var missing: ({})

    // Whether the system can give apps this language (locale -a).
    property var generated: []

    function tr(text: string, ...args): string {
        let out = strings[text];
        if (out === undefined) {
            out = text;
            if (language !== "en" && loaded === language) missing[text] = true;
        }
        for (let i = 0; i < args.length; i++) out = out.split("%" + (i + 1)).join(String(args[i]));
        return out;
    }

    // A text whose English means two things (Light: the tones, or a
    // strength): translated by "context|text", else as plain text.
    function trc(context: string, text: string, ...args): string {
        const key = context + "|" + text;
        return key in strings ? tr(key, ...args) : tr(text, ...args);
    }

    // A text kept in English as data (a page's name, say) and translated
    // where it shows: marked only so i18n/check.sh finds it.
    function mark(text: string): string {
        return text;
    }

    // A count: `one` for 1, `many` otherwise (as in English, Portuguese
    // counts 0 as many). %1 is the count.
    function trn(one: string, many: string, count: int, ...args): string {
        return tr(count === 1 ? one : many, count, ...args);
    }

    function setLanguage(code: string): void {
        const entry = languages.find(each => each.code === code);
        if (!entry) return;
        saved.language = code;
        envWriter.command = entry.lang === ""
            ? ["rm", "-f", Theme.stateDir + "/language.env"]
            : ["sh", "-c", 'printf "export LANG=%s LANGUAGE=%s\\n" "$2" "$3" > "$1"',
               "sh", Theme.stateDir + "/language.env", entry.lang, entry.code + ":" + entry.code.split("_")[0]];
        envWriter.running = true;
    }

    function generatedFor(code: string): bool {
        const entry = languages.find(each => each.code === code);
        return !entry || entry.lang === "" || generated.includes(entry.lang.replace("UTF-8", "utf8"));
    }

    FileView {
        path: root.language === "en" ? "" : Qt.resolvedUrl("../i18n/" + root.language + ".json").toString().replace(/^file:\/\//, "")
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.strings = JSON.parse(text());
                root.loaded = root.language;
            } catch (error) {
                console.warn("I18n: " + path + " is not valid JSON: " + error);
            }
        }
        onPathChanged: if (path === "") {
            root.strings = {};
            root.loaded = "";
        }
    }

    FileView {
        path: Theme.stateDir + "/language.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: saved
            property string language: ""  // "" until picked: from LANG
        }
    }

    Process {
        id: envWriter
    }

    Process {
        running: true
        command: ["locale", "-a"]
        stdout: StdioCollector {
            onStreamFinished: root.generated = text.split("\n").filter(line => line !== "")
        }
    }

    IpcHandler {
        target: "language"

        function set(code: string): string {
            root.setLanguage(code);
            return root.language;
        }

        function get(): string {
            return root.language;
        }

        function missing(): string {
            return Object.keys(root.missing).sort().join("\n") || "none";
        }
    }
}
