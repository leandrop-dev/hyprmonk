// Audio effects, with no EasyEffects: a headphone correction and the
// microphone's noise suppression. Each is a PipeWire filter-chain run by its
// own user unit (config/systemd/user/hyprmonk-<effect>.service), from a conf
// this writes to the state directory while the effect is on and removes when
// it is turned off, so a unit starts at login only if it was left on. The
// units outlive the shell: a reload does not cut the sound.
//
// Both are WirePlumber smart filters: whatever goes to the device passes
// through the filter, and the device stays the default (the volume keys
// keep working on it).
// - correction: AutoEQ's correction for the headphones (Equalizer APO's
//   format, read as it is by PipeWire's param_eq), picked per output device
//   in Settings > Sounds; the Arctis Nova 7's comes ready (assets/autoeq).
//   It follows the default output when that has a correction; without the
//   headphones the filter waits rather than correct other speakers.
// - noise: rnnoise (noise-suppression-for-voice) on the default microphone,
//   following it when another becomes the default. The threshold is how sure
//   rnnoise must be that it hears a voice before it lets the sound through;
//   the hold, how long it stays open after the voice stops (longer lets the
//   room in as a faint static, shorter clips the ends of words).
//
// Kept in audio-effects.json.
// IPC: qs -c hyprmonk ipc call effects toggle correction|noise
//      | threshold <0-95> | hold <0-1000> | status
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

Singleton {
    id: root

    readonly property string dir: Theme.stateDir + "/audio"

    // The corrections that come ready, by a part of the device's node name.
    readonly property var ready: [
        { match: "Arctis_Nova_7", name: "SteelSeries Arctis Nova 7", source: "Rtings",
          file: path(Qt.resolvedUrl("../assets/autoeq/SteelSeries Arctis Nova 7 ParametricEQ.txt")) }
    ]

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property string sinkName: sink?.name ?? ""
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property string sourceName: source?.name ?? ""

    // A device's correction: the one picked for it, or one that comes ready.
    function profileFor(device: string): var {
        if (device === "") return null;
        return settings.profiles[device] ?? ready.find(profile => device.includes(profile.match)) ?? null;
    }

    readonly property var settingsProfiles: settings.profiles  // the picked ones
    readonly property var profile: profileFor(sinkName)
    readonly property bool correctionOn: settings.correction
    // The device the running filter corrects: the default output when that
    // has a correction, else the last one that did.
    property string correcting: ""

    readonly property bool noiseOn: settings.noise
    readonly property int threshold: settings.threshold
    readonly property int hold: settings.hold

    function path(url: url): string {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""));
    }

    function setCorrection(on: bool): void {
        settings.correction = on;
        applyCorrection();
    }

    function applyCorrection(): void {
        if (!settingsRead) return;
        if (!settings.correction) {
            correcting = "";
            run("headphone-eq", "");
            return;
        }
        const device = profile ? sinkName : correcting;
        const chosen = profileFor(device);
        if (!chosen) return;  // nothing to correct yet; waits for a device that has one
        correcting = device;
        run("headphone-eq", correctionConf(device, chosen));
    }

    // AutoEQ's corrections (github.com/jaakkopasanen/AutoEq, MIT): its index,
    // kept a week in the cache and searched in Settings > Sounds, and the one
    // picked for an output device, downloaded to the state directory.
    readonly property string autoeq: "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results"
    property var catalogue: []  // { name, source, form, path, words }
    property bool catalogueFailed: false
    readonly property bool cataloguing: indexJob.running
    property string fetching: ""  // the path of the one downloading
    property bool fetchFailed: false

    function loadCatalogue(): void {
        if (catalogue.length === 0 && !indexJob.running) indexJob.running = true;
    }

    // The ones with every word in their name or source.
    function search(text: string): var {
        const words = text.toLowerCase().split(/\s+/).filter(word => word !== "");
        if (words.length === 0) return [];
        return catalogue.filter(entry => words.every(word => entry.words.includes(word))).slice(0, 40);
    }

    // Downloads it for the default output, and turns the correction on.
    function pick(entry: var): void {
        if (sinkName === "" || downloadJob.running) return;
        const file = `${dir}/eq/${sinkName}.txt`;
        const url = `${autoeq}/${entry.path}/${entry.path.split("/").pop()}%20ParametricEQ.txt`;
        fetching = entry.path;
        fetchFailed = false;
        downloadJob.profile = { name: entry.name, source: entry.source, path: entry.path, file };
        downloadJob.device = sinkName;
        // -g: the paths can hold brackets, which curl would read as ranges.
        downloadJob.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && curl -fsSLg "$2" -o "$1.part" && grep -q "^Filter" "$1.part" && mv "$1.part" "$1"', "sh", file, url];
        downloadJob.running = true;
    }

    // Back to the one that comes ready, or none.
    function forget(device: string): void {
        const profiles = Object.assign({}, settings.profiles);
        delete profiles[device];
        settings.profiles = profiles;
        if (device === correcting) correcting = "";
        applyCorrection();
    }

    Process {
        id: indexJob
        command: ["sh", "-c", 'mkdir -p "$(dirname "$1")"; if [ ! -f "$1" ] || [ -z "$(find "$1" -mtime -7)" ]; then curl -fsSL "$2" -o "$1.part" && mv "$1.part" "$1"; fi; cat "$1"',
            "sh", Quickshell.env("HOME") + "/.cache/hyprmonk/autoeq-index.md", root.autoeq + "/INDEX.md"]
        stdout: StdioCollector {
            // - [Name](./source/rig form/Name) by Source on Rig
            onStreamFinished: {
                const entries = [];
                for (const line of text.split("\n")) {
                    const found = line.match(/^- \[(.+)\]\(\.\/(.+)\) by (.+?)(?: on .+)?$/);
                    if (!found) continue;
                    const [, name, path, source] = found;
                    const form = decodeURIComponent(path.split("/")[1] ?? "").match(/in-ear|over-ear|earbud/)?.[0] ?? "";
                    entries.push({ name, source, form, path, words: `${name} ${source}`.toLowerCase() });
                }
                root.catalogue = entries;
                root.catalogueFailed = entries.length === 0;
            }
        }
        stderr: StdioCollector { onStreamFinished: root.warn("autoeq index", text) }
    }

    Process {
        id: downloadJob

        property string device: ""
        property var profile: null

        stderr: StdioCollector { onStreamFinished: root.warn("autoeq", text) }
        onExited: code => {
            root.fetching = "";
            root.fetchFailed = code !== 0;
            if (code !== 0) return;
            settings.profiles = Object.assign({}, settings.profiles, { [device]: profile });
            if (device === root.correcting) root.correcting = "";
            root.setCorrection(true);
        }
    }

    function setNoise(on: bool): void {
        settings.noise = on;
        applyNoise();
    }

    function setThreshold(percent: int): void {
        settings.threshold = Math.max(0, Math.min(95, percent));
        tune();
    }

    function setHold(ms: int): void {
        settings.hold = Math.max(0, Math.min(1000, ms));
        tune();
    }

    // Changed on the running filter, so the sound goes on: the conf is
    // written for the next start, and the filter told.
    function tune(): void {
        if (!settingsRead || !settings.noise || sourceName === "") return;
        const file = `${dir}/noise-suppression.conf`;
        const props = `{ params = [ "rnnoise:VAD Threshold (%)" ${settings.threshold} "rnnoise:VAD Grace Period (ms)" ${settings.hold} ] }`;
        queue("noise-suppression", ["sh", "-c", 'printf "%s" "$2" > "$1" && pw-cli set-param hyprmonk.noise-suppression Props "$3" >/dev/null',
            "sh", file, noiseConf(sourceName), props]);
    }

    // The microphone played back in the headphones, through the noise
    // suppression when it is on: what others hear. Settings > Sounds stops
    // it when it closes.
    property bool listening: false

    Process {
        running: root.listening
        command: ["pw-loopback",
            "--capture-props", '{ node.name = "hyprmonk.mic-test" node.description = "Microphone test" }',
            "--playback-props", '{ node.name = "hyprmonk.mic-test.output" node.description = "Microphone test" }']
        stderr: StdioCollector { onStreamFinished: root.warn("mic-test", text) }
        onExited: root.listening = false
    }

    function applyNoise(): void {
        if (!settingsRead) return;
        if (!settings.noise) {
            run("noise-suppression", "");
            return;
        }
        if (sourceName === "") return;  // no microphone yet
        run("noise-suppression", noiseConf(sourceName));
    }

    // PipeWire's own filter-chain.conf, with one filter-chain.
    function conf(module: string): string {
        return `context.properties = { log.level = 0 }
context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}
context.modules = [
    { name = libpipewire-module-rt args = { } flags = [ ifexists nofail ] }
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-adapter }
${module}
]
`;
    }

    function correctionConf(device: string, profile: var): string {
        // Names the profile, so that another picked into the same file is
        // a change too, and the filter starts again with it.
        return conf(`    # ${profile.name} by ${profile.source ?? "AutoEQ"}
    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Headphone correction"
            media.name       = "Headphone correction"
            filter.graph = {
                nodes = [
                    { type = builtin name = eq label = param_eq config = { filename = ${JSON.stringify(profile.file)} } }
                ]
                inputs  = [ "eq:In 1" "eq:In 2" ]
                outputs = [ "eq:Out 1" "eq:Out 2" ]
            }
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {
                node.name         = "hyprmonk.headphone-eq"
                media.class       = Audio/Sink
                filter.smart      = true
                filter.smart.name = "hyprmonk-headphone-eq"
                filter.smart.target = { node.name = ${JSON.stringify(device)} }
            }
            playback.props = {
                node.name          = "hyprmonk.headphone-eq.output"
                node.passive       = true
                node.dont-fallback = true
            }
        }
    }`);
    }

    // Stereo whatever the microphone has; PipeWire converts a mono one.
    function noiseConf(device: string): string {
        return conf(`    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Noise suppression"
            media.name       = "Noise suppression"
            filter.graph = {
                nodes = [
                    { type = ladspa name = rnnoise plugin = "librnnoise_ladspa" label = noise_suppressor_stereo
                      control = { "VAD Threshold (%)" = ${settings.threshold} "VAD Grace Period (ms)" = ${settings.hold} } }
                ]
            }
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {
                node.name          = "hyprmonk.noise-suppression.input"
                node.passive       = true
                node.dont-fallback = true
            }
            playback.props = {
                node.name           = "hyprmonk.noise-suppression"
                media.class         = Audio/Source
                filter.smart        = true
                filter.smart.name   = "hyprmonk-noise-suppression"
                filter.smart.target = { node.name = ${JSON.stringify(device)} }
            }
        }
    }`);
    }

    // Writes the effect's conf and (re)starts its unit, or with no conf
    // removes it and stops the unit. One run at a time per effect; a change
    // meanwhile runs after it.
    property var pending: ({})

    function run(effect: string, text: string): void {
        const unit = `hyprmonk-${effect}.service`;
        const file = `${dir}/${effect}.conf`;
        queue(effect, text === ""
            ? ["sh", "-c", 'rm -f "$1"; systemctl --user stop "$2"', "sh", file, unit]
            // Restarted only when the conf changed: the shell loading again
            // starts it if it is not running, and leaves it be if it is.
            : ["sh", "-c", 'mkdir -p "$(dirname "$1")" && if printf "%s" "$3" | cmp -s - "$1"; then systemctl --user start "$2"; else printf "%s" "$3" > "$1" && systemctl --user restart "$2"; fi', "sh", file, unit, text]);
    }

    function queue(effect: string, command: var): void {
        const job = jobs[effect];
        if (job.running) {
            pending[effect] = command;
            return;
        }
        job.command = command;
        job.running = true;
    }

    readonly property var jobs: ({ "headphone-eq": correctionJob, "noise-suppression": noiseJob })

    function warn(effect: string, errors: string): void {
        if (errors.trim() !== "") console.warn(`effects: ${effect}:`, errors.trim());
    }

    // Runs what was asked for meanwhile, if anything.
    function finished(effect: string, job: Process): void {
        const next = pending[effect];
        if (!next) return;
        delete pending[effect];
        job.command = next;
        job.running = true;
    }

    Process {
        id: correctionJob
        stderr: StdioCollector { onStreamFinished: root.warn("headphone-eq", text) }
        onExited: root.finished("headphone-eq", this)
    }

    Process {
        id: noiseJob
        stderr: StdioCollector { onStreamFinished: root.warn("noise-suppression", text) }
        onExited: root.finished("noise-suppression", this)
    }

    // A new default output with a correction of its own moves the filter there.
    onProfileChanged: if (settings.correction && profile && sinkName !== correcting) applyCorrection()
    // And a new default microphone moves the noise suppression.
    onSourceNameChanged: if (settings.noise) applyNoise()

    property bool settingsRead: false

    function start(): void {
        settingsRead = true;
        applyCorrection();
        applyNoise();
    }

    FileView {
        path: Theme.stateDir + "/audio-effects.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.start()
        onLoadFailed: root.start()

        JsonAdapter {
            id: settings
            property bool correction: false
            property var profiles: ({})  // device node name: { name, file }
            property bool noise: false
            property int threshold: 50  // VAD threshold, 0 to 95 %
            property int hold: 150  // VAD grace period, 0 to 1000 ms
        }
    }

    IpcHandler {
        target: "effects"

        function toggle(effect: string): bool {
            if (effect === "correction") {
                root.setCorrection(!root.correctionOn);
                return root.correctionOn;
            }
            if (effect === "noise") {
                root.setNoise(!root.noiseOn);
                return root.noiseOn;
            }
            return false;
        }

        function threshold(percent: int): void {
            root.setThreshold(percent);
        }

        function hold(ms: int): void {
            root.setHold(ms);
        }

        function status(): string {
            return `correction ${root.correctionOn ? "on" : "off"} ${root.correcting} (${root.profileFor(root.correcting || root.sinkName)?.name ?? "none"})\n`
                + `noise ${root.noiseOn ? "on" : "off"} ${root.sourceName} (threshold ${root.threshold} %, hold ${root.hold} ms)`;
        }
    }
}
