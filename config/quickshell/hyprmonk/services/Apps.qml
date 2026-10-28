// What the launcher (launcher/Launcher.qml) lists and starts: the installed
// apps, the commands on PATH, and the hosts in ~/.ssh/config. Everything
// starts through `uwsm app`, in a unit of its own, so it outlives the shell.
//
// Each list is ranked by how well its name matches what is typed, then by
// how often it was started (kept in launcher.json), then by name.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string terminal: "kitty"

    // How well `typed` matches `text`: 0 for not at all. The start of the
    // text beats the start of a word, a word beats anywhere, and the letters
    // in order (gaps allowed) come last: only for names, where it rarely
    // matches by chance.
    function score(text: string, typed: string): int {
        return words(text, typed) || letters(text, typed);
    }

    function words(text: string, typed: string): int {
        const t = (text ?? "").toLowerCase();
        if (typed === "") return 1;
        if (t.startsWith(typed)) return 100;
        const at = t.indexOf(typed);
        if (at > 0 && /[\s\-_.]/.test(t[at - 1])) return 80;
        return at > 0 ? 60 : 0;
    }

    function letters(text: string, typed: string): int {
        const t = (text ?? "").toLowerCase();
        let from = 0;
        for (const c of typed) {
            from = t.indexOf(c, from) + 1;
            if (from === 0) return 0;
        }
        return 30;
    }

    function rank(list: var, typed: string, counts: var): var {
        const q = typed.trim().toLowerCase();
        return list
            .map(item => ({ item, score: item.match(q) }))
            .filter(found => found.score > 0)
            .sort((a, b) => b.score - a.score
                || (counts[b.item.key] ?? 0) - (counts[a.item.key] ?? 0)
                || a.item.name.localeCompare(b.item.name))
            .map(found => found.item);
    }

    // Apps: matched by name, then generic name and keywords, then comment.
    readonly property var apps: DesktopEntries.applications.values
        .filter(entry => !entry.noDisplay)
        .map(entry => ({
            kind: "app",
            key: entry.id,
            name: entry.name,
            detail: entry.genericName || entry.comment,
            icon: Quickshell.iconPath(entry.icon, "application-x-executable"),
            entry,
            match: q => Math.max(root.score(entry.name, q),
                                 Math.min(50, root.words(entry.genericName, q)),
                                 Math.min(50, Math.max(0, ...entry.keywords.map(k => root.words(k, q)))),
                                 Math.min(20, root.words(entry.comment, q)))
        }))

    function findApps(typed: string): var {
        return rank(apps, typed, usage.apps);
    }

    // Commands: the programs on PATH that start like the first word typed,
    // and what is typed, as typed: first once it has arguments, last before.
    property var programs: []

    function findCommands(typed: string): var {
        const line = typed.trim();
        const word = line.split(/\s+/)[0];
        const found = rank(programs.map(name => ({
            kind: "command",
            key: name,
            name,
            match: q => q === "" ? 1 : name.startsWith(q) ? 100 - name.length : 0
        })), word, usage.commands);
        const shown = found.slice(0, 200);
        if (line !== "" && !programs.includes(line)) {
            const typedLine = { kind: "command", key: line, name: line, typed: true };
            if (line.includes(" ")) shown.unshift(typedLine);
            else shown.push(typedLine);
        }
        return shown;
    }

    function refreshPrograms(): void {
        if (!pathScan.running) pathScan.running = true;
    }

    Process {
        id: pathScan

        command: ["sh", "-c", "IFS=:; for d in $PATH; do [ -d \"$d\" ] && ls -1 \"$d\"; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.programs = text.split("\n").filter(name => name !== "")
        }
    }

    // SSH: the hosts named in ~/.ssh/config (not the patterns); what is
    // typed connects as is when it names none of them.
    readonly property var hosts: {
        const found = [];
        let block = [];
        for (const line of sshConfig.text().split("\n")) {
            const [word, ...rest] = line.trim().split(/\s+/);
            const key = word.toLowerCase();
            if (key === "host") {
                block = rest.filter(name => !/[*?!]/.test(name)).map(name => ({ name, hostName: "", user: "" }));
                found.push(...block);
            } else if (key === "match") {
                block = [];
            } else if (key === "hostname") {
                block.forEach(host => host.hostName = rest[0]);
            } else if (key === "user") {
                block.forEach(host => host.user = rest[0]);
            }
        }
        // "user@address", or what of it the config gives.
        return found.map(host => ({
            name: host.name,
            detail: host.user && host.hostName ? host.user + "@" + host.hostName : host.hostName || (host.user ? host.user + "@" + host.name : "")
        }));
    }

    function findHosts(typed: string): var {
        const line = typed.trim();
        const found = rank(hosts.map(host => ({
            kind: "host",
            key: host.name,
            name: host.name,
            detail: host.detail,
            match: q => Math.max(root.score(host.name, q), Math.min(50, root.words(host.detail, q)))
        })), line, usage.hosts);
        if (line !== "" && !found.some(host => host.name === line))
            found.push({ kind: "host", key: line, name: line, detail: "", typed: true });
        return found;
    }

    FileView {
        id: sshConfig

        path: Quickshell.env("HOME") + "/.ssh/config"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    // Starting one; `inTerminal` for a command run in the terminal, which
    // stays open after it ends.
    function launch(item: var, inTerminal: bool): void {
        let command;
        if (item.kind === "app") {
            command = item.entry.runInTerminal
                ? ["uwsm", "app", "--", terminal, "-e", ...item.entry.command]
                : ["uwsm", "app", "--", item.entry.id + ".desktop"];
        } else if (item.kind === "command") {
            const name = item.name.split(/\s+/)[0];
            command = inTerminal
                ? ["uwsm", "app", "-a", name, "--", terminal, "--hold", "sh", "-c", item.name]
                : ["uwsm", "app", "-a", name, "--", "sh", "-c", item.name];
        } else {
            command = ["uwsm", "app", "-a", "ssh", "--", terminal, "-e", "ssh", item.name];
        }
        Quickshell.execDetached(command);
        count(item);
    }

    // Typed commands and hosts are kept too, so the ones used again rise.
    function count(item: var): void {
        const list = { app: "apps", command: "commands", host: "hosts" }[item.kind];
        const counts = Object.assign({}, usage[list]);
        counts[item.key] = (counts[item.key] ?? 0) + 1;
        usage[list] = counts;
    }

    FileView {
        path: Theme.stateDir + "/launcher.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: usage

            property var apps: ({})
            property var commands: ({})
            property var hosts: ({})
        }
    }
}
