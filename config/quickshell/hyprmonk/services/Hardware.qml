// CPU, memory, disk and network use for the bar's hardware drawer.
//
// CPU use is read every second, always: the running cat in the bar shows it.
// Memory, the disks and the network every two seconds, only while some
// drawer is open (watch() and unwatch()); the apps using the most memory only
// while their tooltip shows (watchApps() and unwatchApps()). The network is a
// rate: the first read after opening only sets the starting point.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: NaN          // percent
    property var cores: []          // percent, per core
    property real memUsed: NaN      // bytes
    property real memTotal: NaN
    property real diskUsed: NaN     // bytes, on /
    property real diskSize: NaN
    property var disks: []          // [{mount, used, size}], one per device
    property real down: NaN         // bytes a second, every interface but lo
    property real up: NaN
    property var apps: []           // [{name, bytes}], the ten using the most memory

    property int watchers: 0
    property int appWatchers: 0
    property var lastCpu: []        // per cpu line of /proc/stat: {idle, total}
    property var lastNet: null      // {rx, tx, at}

    function watch(): void {
        watchers += 1;
    }

    function unwatch(): void {
        watchers = Math.max(0, watchers - 1);
        if (watchers === 0) lastNet = null;
    }

    function watchApps(): void {
        appWatchers += 1;
    }

    function unwatchApps(): void {
        appWatchers = Math.max(0, appWatchers - 1);
    }

    // 1.2G, 340M, 12K: powers of 1024, as free and df -h print them.
    function human(bytes: real): string {
        if (isNaN(bytes)) return "–";
        const units = ["B", "K", "M", "G", "T"];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i += 1;
        }
        return (bytes >= 10 || i === 0 ? Math.round(bytes) : bytes.toFixed(1)) + units[i];
    }

    function parseStat(text: string): void {
        const now = text.split("\n").filter(line => line.startsWith("cpu")).map(line => {
            const f = line.trim().split(/\s+/).slice(1).map(Number);
            return { idle: f[3] + f[4], total: f.reduce((sum, n) => sum + n, 0) };  // idle and iowait
        });
        if (lastCpu.length === now.length) {
            const use = now.map((s, i) => {
                const total = s.total - lastCpu[i].total;
                return total > 0 ? 100 * (1 - (s.idle - lastCpu[i].idle) / total) : 0;
            });
            cpu = use[0];
            cores = use.slice(1);
        }
        lastCpu = now;
    }

    // /proc/meminfo and /proc/net/dev, then "---", then df.
    function parse(text: string): void {
        const at = Date.now();
        const [procs, dfOut] = text.split("\n---\n");
        let rx = 0, tx = 0;
        const mem = {};
        for (const line of procs.split("\n")) {
            const meminfo = line.match(/^(MemTotal|MemAvailable):\s+(\d+) kB/);
            if (meminfo) {
                mem[meminfo[1]] = Number(meminfo[2]) * 1024;
                continue;
            }
            // "  eth0: rx_bytes 7 more numbers tx_bytes ..."
            const net = line.match(/^\s*([^\s:]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/);
            if (net && net[1] !== "lo") {
                rx += Number(net[2]);
                tx += Number(net[3]);
            }
        }
        memTotal = mem.MemTotal ?? NaN;
        memUsed = memTotal - (mem.MemAvailable ?? NaN);

        // "source mount size used", a device once under its shortest mount
        // (btrfs mounts one device at many subvolumes).
        const byDevice = {};
        for (const line of (dfOut ?? "").trim().split("\n").slice(1)) {
            const [source, mount, size, used] = line.trim().split(/\s+/);
            const known = byDevice[source];
            if (!known || mount.length < known.mount.length)
                byDevice[source] = { mount, size: Number(size), used: Number(used) };
        }
        disks = Object.values(byDevice);
        const rootDisk = disks.find(d => d.mount === "/");
        diskSize = rootDisk?.size ?? NaN;
        diskUsed = rootDisk?.used ?? NaN;

        if (lastNet) {
            const seconds = (at - lastNet.at) / 1000;
            down = Math.max(0, (rx - lastNet.rx) / seconds);
            up = Math.max(0, (tx - lastNet.tx) / seconds);
        } else {
            soon.start();  // the rates need a second read: take it shortly
        }
        lastNet = { rx, tx, at };
    }

    // `ps` lines "pid ppid rss comm": each process counts toward the app it
    // belongs to, the ancestor that Hyprland or systemd started (a terminal's
    // programs toward the terminal); a shell Hyprland ran a program through
    // gives way to that program.
    function rank(text: string): void {
        const procs = {};
        for (const line of text.trim().split("\n")) {
            const m = line.trim().match(/^(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/);
            if (m) procs[m[1]] = { ppid: m[2], kb: Number(m[3]), name: m[4] };
        }
        const launchers = ["Hyprland", "start-hyprland", "systemd", "uwsm", "init"];
        const shells = ["sh", "bash", "zsh", "fish", "dash"];
        const appOf = pid => {
            const chain = [pid];
            for (;;) {
                const p = procs[chain[chain.length - 1]];
                const parent = procs[p.ppid];
                if (!parent || p.ppid === "1" || launchers.includes(parent.name)) break;
                chain.push(p.ppid);
            }
            let i = chain.length - 1;
            while (i > 0 && shells.includes(procs[chain[i]].name)) i -= 1;
            return procs[chain[i]].name;
        };
        const totals = {};
        for (const pid in procs) {
            const name = appOf(pid);
            totals[name] = (totals[name] ?? 0) + procs[pid].kb * 1024;
        }
        apps = Object.entries(totals)
            .map(([name, bytes]) => ({ name, bytes }))
            .sort((a, b) => b.bytes - a.bytes)
            .slice(0, 10);
    }

    FileView {
        id: stat
        path: "/proc/stat"
        printErrors: false
        onLoaded: root.parseStat(text())
    }

    Timer {
        running: true
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: stat.reload()
    }

    Process {
        id: reader
        command: ["sh", "-c", "cat /proc/meminfo /proc/net/dev; echo ---; "
            + "df -B1 -l -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay --output=source,target,size,used"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        running: root.watchers > 0
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }

    Timer {
        id: soon
        interval: 500
        onTriggered: reader.running = true
    }

    Process {
        id: ps
        command: ["ps", "-eo", "pid=,ppid=,rss=,comm="]
        stdout: StdioCollector {
            onStreamFinished: root.rank(text)
        }
    }

    Timer {
        running: root.appWatchers > 0
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: ps.running = true
    }
}
