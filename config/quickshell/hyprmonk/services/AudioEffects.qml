// Audio effects, with no EasyEffects: an equaliser, a headphone correction
// and the microphone's noise suppression. Each is a PipeWire filter-chain run by its
// own user unit (config/systemd/user/hyprmonk-<effect>.service), from a conf
// this writes to the state directory while the effect is on and removes when
// it is turned off, so a unit starts at login only if it was left on. The
// units outlive the shell: a reload does not cut the sound.
//
// All are WirePlumber smart filters: whatever goes to the device passes
// through the filter, and the device stays the default (the volume keys
// keep working on it). On the output, the equaliser comes first and the
// correction after it.
// - eq: ten bands with presets, on the default output (below).
// - night: a compressor and limiter for late listening, after the equaliser
//   (below).
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
// IPC: qs -c hyprmonk ipc call effects toggle eq|night|correction|noise
//      | preset <name> | band <0-9> <dB> | strength light|medium|strong
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
        live("noise-suppression", noiseConf(sourceName), "hyprmonk.noise-suppression",
            ["rnnoise:VAD Threshold (%)", settings.threshold, "rnnoise:VAD Grace Period (ms)", settings.hold]);
    }

    // Writes the effect's conf for its next start, and sets `params` (name,
    // value, ...) on its running node.
    function live(effect: string, text: string, node: string, params: var): void {
        const props = `{ params = [ ${params.map(param => typeof param === "string" ? JSON.stringify(param) : param).join(" ")} ] }`;
        queue(effect, ["sh", "-c", 'printf "%s" "$2" > "$1" && pw-cli set-param "$3" Props "$4" >/dev/null',
            "sh", `${dir}/${effect}.conf`, text, node, props]);
    }

    // The equaliser: ten bands an octave apart, before the correction, on
    // whatever the default output is. A preamp in front lowers the sound by
    // the largest boost, so that it never clips. Presets and bands change on
    // the running filter.
    readonly property var bands: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property int bandRange: 12  // dB, either way
    readonly property var presets: ({
        flat:      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        bass:      [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
        treble:    [0, 0, 0, 0, 0, 0, 2, 4, 5, 6],
        vocal:     [-2, -2, -1, 0, 2, 4, 4, 2, 0, -1],
        rock:      [4, 3, 2, 0, -1, -1, 1, 3, 4, 4],
        pop:       [-1, 0, 2, 3, 4, 3, 1, 0, -1, -1],
        jazz:      [3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
        classical: [3, 2, 1, 0, 0, 0, -1, -1, 1, 2]
    })
    readonly property var presetNames: Object.keys(presets).concat("custom")
    readonly property var presetLabels: ({ flat: I18n.mark("Flat"), bass: I18n.mark("Bass"), treble: I18n.mark("Treble"), vocal: I18n.mark("Vocal"), rock: I18n.mark("Rock"),
        pop: I18n.mark("Pop"), jazz: I18n.mark("Jazz"), classical: I18n.mark("Classical"), custom: I18n.mark("Custom") })

    readonly property bool eqOn: settings.eq
    readonly property string preset: settings.preset in presets || settings.preset === "custom" ? settings.preset : "flat"
    readonly property var gains: preset === "custom" ? bands.map((band, i) => settings.custom[i] ?? 0) : presets[preset]
    readonly property bool hasCustom: settings.custom.length > 0
    // The device the running equaliser is on.
    property string equalising: ""

    function setEq(on: bool): void {
        settings.eq = on;
        applyEq();
    }

    function setPreset(name: string): void {
        if (!presetNames.includes(name)) return;
        settings.preset = name;
        tuneEq();
    }

    // Moving a band starts Custom from what is heard.
    function setBand(index: int, gain: real): void {
        const custom = gains.slice();
        custom[index] = Math.max(-bandRange, Math.min(bandRange, Math.round(gain * 2) / 2));
        settings.custom = custom;
        settings.preset = "custom";
        tuneEq();
    }

    function applyEq(): void {
        if (!settingsRead) return;
        if (!settings.eq) {
            equalising = "";
            run("music-eq", "");
            return;
        }
        if (sinkName === "") return;  // no output yet
        equalising = sinkName;
        run("music-eq", eqConf(sinkName));
    }

    function tuneEq(): void {
        if (!settingsRead || !settings.eq || equalising === "") return;
        live("music-eq", eqConf(equalising), "hyprmonk.music-eq",
            ["pre:Mult", preamp(gains)].concat(...gains.map((gain, i) => [`b${i + 1}:Gain`, gain])));
    }

    function preamp(levels: var): real {
        return Math.pow(10, -Math.max(0, ...levels) / 20);
    }

    // Night mode: a compressor (swh-plugins' SC4) that brings quiet parts up
    // and loud ones down, so speech stays clear and bangs do not jump out,
    // then a limiter that keeps peaks under -1 dB. After the equaliser and
    // before the correction, on whatever the default output is. Its strength
    // changes on the running filter.
    readonly property var strengths: ({
        light:  { threshold: -20, ratio: 2, makeup: 5 },
        medium: { threshold: -28, ratio: 4, makeup: 10 },
        strong: { threshold: -36, ratio: 8, makeup: 15 }
    })
    readonly property var strengthNames: Object.keys(strengths)
    readonly property var strengthLabels: ({ light: I18n.mark("Light"), medium: I18n.mark("Medium"), strong: I18n.mark("Strong") })

    readonly property bool nightOn: settings.night
    readonly property string strength: settings.strength in strengths ? settings.strength : "medium"
    // The device the running night mode is on.
    property string darkening: ""

    function setNight(on: bool): void {
        settings.night = on;
        applyNight();
    }

    function setStrength(name: string): void {
        if (!(name in strengths)) return;
        settings.strength = name;
        if (!settingsRead || !settings.night || darkening === "") return;
        const level = strengths[strength];
        live("night-mode", nightConf(darkening), "hyprmonk.night-mode",
            ["comp:Threshold level (dB)", level.threshold, "comp:Ratio (1:n)", level.ratio, "comp:Makeup gain (dB)", level.makeup]);
    }

    function applyNight(): void {
        if (!settingsRead) return;
        if (!settings.night) {
            darkening = "";
            run("night-mode", "");
            return;
        }
        if (sinkName === "") return;  // no output yet
        darkening = sinkName;
        run("night-mode", nightConf(sinkName));
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
                # Last: the others shape the sound, this the headphones.
                filter.smart.after  = [ "hyprmonk-music-eq" "hyprmonk-night-mode" ]
            }
            playback.props = {
                node.name          = "hyprmonk.headphone-eq.output"
                node.passive       = true
                node.dont-fallback = true
            }
        }
    }`);
    }

    // Each band a peaking filter an octave wide (Q 1.41), one after the other;
    // the graph is copied for each channel.
    function eqConf(device: string): string {
        const nodes = gains.map((gain, i) =>
            `                    { type = builtin name = b${i + 1} label = bq_peaking control = { "Freq" = ${bands[i]} "Q" = 1.41 "Gain" = ${gain} } }`);
        const links = gains.map((gain, i) =>
            `                    { output = "${i === 0 ? "pre" : "b" + i}:Out" input = "b${i + 1}:In" }`);
        return conf(`    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Equaliser"
            media.name       = "Equaliser"
            filter.graph = {
                nodes = [
                    { type = builtin name = pre label = linear control = { "Mult" = ${preamp(gains)} } }
${nodes.join("\n")}
                ]
                links = [
${links.join("\n")}
                ]
            }
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {
                node.name           = "hyprmonk.music-eq"
                media.class         = Audio/Sink
                filter.smart        = true
                filter.smart.name   = "hyprmonk-music-eq"
                filter.smart.target = { node.name = ${JSON.stringify(device)} }
            }
            playback.props = {
                node.name          = "hyprmonk.music-eq.output"
                node.passive       = true
                node.dont-fallback = true
            }
        }
    }`);
    }

    // The compressor reads the level as RMS, more like what is heard than
    // peaks; the limiter looks ahead a few milliseconds.
    function nightConf(device: string): string {
        const level = strengths[strength];
        return conf(`    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Night mode"
            media.name       = "Night mode"
            filter.graph = {
                nodes = [
                    { type = ladspa name = comp plugin = sc4_1882 label = sc4
                      control = { "RMS/peak" = 0 "Attack time (ms)" = 10 "Release time (ms)" = 300 "Knee radius (dB)" = 6
                                  "Threshold level (dB)" = ${level.threshold} "Ratio (1:n)" = ${level.ratio} "Makeup gain (dB)" = ${level.makeup} } }
                    { type = ladspa name = limit plugin = fast_lookahead_limiter_1913 label = fastLookaheadLimiter
                      control = { "Input gain (dB)" = 0 "Limit (dB)" = -1 "Release time (s)" = 0.05 } }
                ]
                links = [
                    { output = "comp:Left output" input = "limit:Input 1" }
                    { output = "comp:Right output" input = "limit:Input 2" }
                ]
                inputs  = [ "comp:Left input" "comp:Right input" ]
                outputs = [ "limit:Output 1" "limit:Output 2" ]
            }
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {
                node.name           = "hyprmonk.night-mode"
                media.class         = Audio/Sink
                filter.smart        = true
                filter.smart.name   = "hyprmonk-night-mode"
                filter.smart.target = { node.name = ${JSON.stringify(device)} }
                filter.smart.after  = [ "hyprmonk-music-eq" ]
            }
            playback.props = {
                node.name          = "hyprmonk.night-mode.output"
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

    // Before a running filter is stopped or started again, WirePlumber is
    // told to pass it by (`filter.smart.disabled` in the filters metadata),
    // so the streams move on to the device first: a filter that goes away
    // with players still on it counts as a device unplugged, and WirePlumber
    // pauses them (linking/mpris-pause.lua). It notes the move a moment
    // later than it makes it, hence the wait. Afterwards the mark is taken
    // off, as PipeWire hands the same id to a node made later (the filter
    // started again would be passed by too).
    readonly property string aside: 'id=; aside() { systemctl --user is-active -q "$1" || return 0; id=$(pw-cli info "$2" | sed -n "1s/^[[:space:]]*id: //p"); [ -n "$id" ] || return 0; pw-metadata -n filters "$id" filter.smart.disabled true >/dev/null; sleep 1.5; }; '
        + 'back() { [ -z "$id" ] || pw-metadata -n filters -d "$id" filter.smart.disabled >/dev/null; }; '

    function run(effect: string, text: string): void {
        const unit = `hyprmonk-${effect}.service`;
        const file = `${dir}/${effect}.conf`;
        const node = `hyprmonk.${effect}`;
        queue(effect, text === ""
            ? ["sh", "-c", aside + 'aside "$2" "$3"; rm -f "$1"; systemctl --user stop "$2"; back', "sh", file, unit, node]
            // Restarted only when the conf changed: the shell loading again
            // starts it if it is not running, and leaves it be if it is. The
            // conf is written only once the filter is passed by, so a reload
            // cutting this short finds it unchanged, and does it again.
            : ["sh", "-c", aside + 'mkdir -p "$(dirname "$1")" && if printf "%s" "$3" | cmp -s - "$1"; then systemctl --user start "$2"; else aside "$2" "$4"; printf "%s" "$3" > "$1" && systemctl --user restart "$2"; back; fi', "sh", file, unit, text, node]);
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

    readonly property var jobs: ({ "headphone-eq": correctionJob, "noise-suppression": noiseJob, "music-eq": eqJob, "night-mode": nightJob })

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
        onExited: root.finished("headphone-eq", correctionJob)
    }

    Process {
        id: noiseJob
        stderr: StdioCollector { onStreamFinished: root.warn("noise-suppression", text) }
        onExited: root.finished("noise-suppression", noiseJob)
    }

    Process {
        id: eqJob
        stderr: StdioCollector { onStreamFinished: root.warn("music-eq", text) }
        onExited: root.finished("music-eq", eqJob)
    }

    Process {
        id: nightJob
        stderr: StdioCollector { onStreamFinished: root.warn("night-mode", text) }
        onExited: root.finished("night-mode", nightJob)
    }

    // A new default output with a correction of its own moves the filter there.
    onProfileChanged: if (settings.correction && profile && sinkName !== correcting) applyCorrection()
    // The equaliser and night mode follow the default output, whatever it is.
    onSinkNameChanged: {
        if (settings.eq && sinkName !== "" && sinkName !== equalising) applyEq();
        if (settings.night && sinkName !== "" && sinkName !== darkening) applyNight();
    }
    // And a new default microphone moves the noise suppression.
    onSourceNameChanged: if (settings.noise) applyNoise()

    property bool settingsRead: false

    function start(): void {
        settingsRead = true;
        applyCorrection();
        applyNoise();
        applyEq();
        applyNight();
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
            property bool eq: false
            property string preset: "flat"  // one of presets, or custom
            property var custom: []  // custom's gains, in dB, by band
            property bool night: false
            property string strength: "medium"  // one of strengths
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
            if (effect === "eq") {
                root.setEq(!root.eqOn);
                return root.eqOn;
            }
            if (effect === "night") {
                root.setNight(!root.nightOn);
                return root.nightOn;
            }
            return false;
        }

        function strength(name: string): void {
            root.setStrength(name);
        }

        function preset(name: string): void {
            root.setPreset(name);
        }

        function band(index: int, gain: real): void {
            root.setBand(index, gain);
        }

        function threshold(percent: int): void {
            root.setThreshold(percent);
        }

        function hold(ms: int): void {
            root.setHold(ms);
        }

        function status(): string {
            return `correction ${root.correctionOn ? "on" : "off"} ${root.correcting} (${root.profileFor(root.correcting || root.sinkName)?.name ?? "none"})\n`
                + `noise ${root.noiseOn ? "on" : "off"} ${root.sourceName} (threshold ${root.threshold} %, hold ${root.hold} ms)\n`
                + `eq ${root.eqOn ? "on" : "off"} ${root.equalising} (${root.preset}: ${root.gains.join(" ")})\n`
                + `night ${root.nightOn ? "on" : "off"} ${root.darkening} (${root.strength})`;
        }
    }
}
