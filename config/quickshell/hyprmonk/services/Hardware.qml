// CPU, memory, disk and network use for the bar's hardware drawer, read
// every couple of seconds from /proc and df, and only while some drawer is
// open (watch() and unwatch()). CPU and network are rates: the first read
// after opening only sets the starting point.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int watchers: 0

    property real cpu: NaN          // percent
    property real memUsed: NaN      // bytes
    property real memTotal: NaN
    property real diskUsed: NaN     // bytes, on /
    property real diskSize: NaN
    property real down: NaN         // bytes a second, every interface but lo
    property real up: NaN

    property var last: null         // the previous read: {idle, total, rx, tx, at}

    function watch(): void {
        watchers += 1;
    }

    function unwatch(): void {
        watchers = Math.max(0, watchers - 1);
        if (watchers === 0) last = null;
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

    function parse(text: string): void {
        const now = Date.now();
        let idle = 0, total = 0, rx = 0, tx = 0;
        const mem = {};
        const lines = text.split("\n");
        for (const line of lines) {
            if (line.startsWith("cpu ")) {
                const f = line.trim().split(/\s+/).slice(1).map(Number);
                idle = f[3] + f[4];  // idle and iowait
                total = f.reduce((sum, n) => sum + n, 0);
                continue;
            }
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
        // df -P -B1 /: the last line, "device size used available use% /".
        const df = lines.filter(l => l.trim() !== "").pop()?.trim().split(/\s+/) ?? [];
        if (df.length >= 6) {
            diskSize = Number(df[1]);
            diskUsed = Number(df[2]);
        }
        memTotal = mem.MemTotal ?? NaN;
        memUsed = memTotal - (mem.MemAvailable ?? NaN);

        if (last) {
            const seconds = (now - last.at) / 1000;
            cpu = total > last.total ? 100 * (1 - (idle - last.idle) / (total - last.total)) : cpu;
            down = Math.max(0, (rx - last.rx) / seconds);
            up = Math.max(0, (tx - last.tx) / seconds);
        } else {
            soon.start();  // the rates need a second read: take it shortly
        }
        last = { idle, total, rx, tx, at: now };
    }

    Timer {
        id: soon
        interval: 500
        onTriggered: reader.running = true
    }

    Process {
        id: reader
        command: ["sh", "-c", "cat /proc/stat /proc/meminfo /proc/net/dev; df -P -B1 /"]
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
}
