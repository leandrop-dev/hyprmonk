# The tone for Zendo: `tone.json`

Asked from a Zendo session on 2026-11-07. Zendo (the game launcher,
`~/Projects/zendo`) keeps its own colours (Noir's) by default, as it may run
on any desktop; on a computer with hyprmonk, its Settings can switch it to
hyprmonk's tone, which it then follows (its own colours while the file is
missing). hyprmonk writes the
file from `ThemeOutputs.qml` (property `zendo`, output `zendoTone`), done on
2026-11-07.

## What Zendo reads

`~/.local/state/hyprmonk/theme/tone.json`, next to `tone.lua` (Zendo uses
`$HOME/.local/state`, as `Theme.stateDir` does, whatever `XDG_STATE_HOME`
says):

```json
{
  "version": 1,
  "name": "noir",
  "label": "Noir",
  "light": false,
  "background": "#171717",
  "foreground": "#ccd0cf",
  "accent": "#f25623",
  "positive": "#88a57d",
  "negative": "#e05a4c"
}
```

- `version`: 1. A Zendo that meets a newer number keeps its colours and
  says so in its Settings, so bump it only for a change old Zendos would
  read wrong; new keys alone need no bump (Zendo ignores keys it does not
  know).
- `name`: the tone's key in `Theme.tones` (`noir`, `kanso`, `wallpaper`).
- `label`: its name as Settings > Appearance shows it; Zendo's Settings say
  "Following hyprmonk's tone: Kanso". Left out, Zendo shows `name`.
- `light`: the tone's `light`. Zendo then darkens on hover instead of
  lightening, and uses a darker green and red when the file brings none.
- `background`, `foreground`: the saved tone's, with the text colour
  Settings gave it (what `Theme.toneOf(Theme.savedTone)` returns), as
  `#rrggbb`. Zendo mixes its greys (cards, lines, dim text) from these two.
- `accent`: always there, already resolved: the tone's own, or the
  wallpaper's (`saved.accent ?? Theme.wallpaperAccent`).
- `positive`: optional; `Theme.positiveOf(saved)` fits.
- `negative`: optional, a red for errors. The tones have none of their own,
  so it is left out for them (Zendo uses its own red). Only the dark
  Wallpaper tone sends one, matugen's `Theme.wallpaperColours.error`:
  that is the dark scheme's pale red, which would not read on Wallpaper
  Light, so that tone leaves Zendo its darker red.

Every colour must be `#` and six hex digits; a file Zendo cannot read
leaves its colours as they were, and it reads it again on its next look.

## When to write it

As the other app outputs in `ThemeOutputs.qml`: for the saved tone only
(a preview under the pointer repaints nothing), and only when the text
changes. That covers each moment Zendo cares about:

- the tone saved in Settings > Appearance changes;
- the tone's text colour is changed or reset there;
- the wallpaper changes while a tone without its own accent is saved
  (the accent, and for the wallpaper tones the colours, follow it).

Card opacity and blur do not matter to Zendo; its window is opaque.

Zendo looks at the file's modification time every 2 seconds while it
follows hyprmonk, and repaints when it changes; it needs no IPC call. A
file written in place could be read half-written; Zendo copes (it keeps
its colours and looks again), but writing it whole (a temporary file
renamed over it) avoids the flicker of an error note.

## In ThemeOutputs.qml

Done as sketched below, with `negative` added for the dark Wallpaper tone
only. FileView saves atomically (a temporary file renamed over it), so
Zendo never reads half a file. The original sketch:

```qml
    // Zendo's window (theme/tone.json, docs/zendo-tone.md).
    readonly property string zendo: JSON.stringify({
        version: 1,
        name: Theme.savedTone,
        label: saved.label,
        light: saved.light,
        background: hex(saved.background),
        foreground: hex(saved.foreground),
        accent: hex(saved.accent ?? Theme.wallpaperAccent),
        positive: hex(Theme.positiveOf(saved))
    }, null, 2) + "\n"
```

with `onZendoChanged: apply.restart()` beside the others, an
`Output { id: zendoTone; path: root.dir + "/tone.json"; content: root.zendo }`,
and `zendoTone.write();` in the list of writes after `folders` runs. For a
tone without its own accent (the wallpaper one), add
`negative: hex(Theme.wallpaperColours.error)`, the field `qtPalette`
already uses for its negative.

## On Zendo's side (done)

- `crates/zendo-core/src/tone.rs` reads the file; `crates/zendo/src/app/themes.rs`
  follows it.
- Zendo's Settings have a Theme section: Zendo (the default) or hyprmonk,
  offered when `~/.local/state/hyprmonk` exists. It is `theme = "zendo"` or
  `"hyprmonk"` in `~/.config/zendo/config.toml`.
- Checked in a throwaway home with hand-written files for Noir, Harbor
  (light) and Kanso: each painted the window, and changing the file
  repainted it within the 2-second look.
