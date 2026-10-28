# hyprmonk

My Hyprland desktop on Arch (CachyOS): a Quickshell shell, small Rust helpers,
and colours generated from the wallpaper by matugen.

Early days: the wallpaper (Super+W to pick), the bar with its sound,
battery, calendar and media panels, a running cat that opens a hardware
drawer (temperature, CPU, memory, disk, network) and a live spectrum (cava),
notifications, the OSD, quick actions (Super+A: game mode, the panels'
tone), the power menu (Super+Shift+E), the key guide (Super+K), the lock
screen (Super+Alt+L, and on idle), the polkit agent, the Hyprland config and
the first helper. More panels come next (see [Roadmap](#roadmap)), all in
Quickshell.

## Install

On Arch (or an Arch-based distro) with or without a desktop; every package
comes from the official repos:

```bash
sudo pacman -S --needed git
git clone https://github.com/leandrop-dev/hyprmonk.git
cd hyprmonk
./install.sh            # install packages, link configs, make folders, build hyprmonk, enable the shell
./install.sh udev       # once: lets hyprmonk read the mouse battery (sudo)
```

Then start Hyprland: from a login screen pick **Hyprland (uwsm-managed)**;
on a system without one, log in on the text console and run
`uwsm start hyprland.desktop`. Then, from inside Hyprland:

```bash
./install.sh plugins   # hyprglass and hymission (compiles)
```

`install.sh` symlinks the configs, so the repo is the live config: edit either
side and both change. Anything already in the way is moved to `*.bak-DATE`.
Run `./install.sh help` for each step.

Wallpapers come from `~/Pictures/Wallpapers` (another folder: set `folder` in
`~/.local/state/hyprmonk/wallpaper.json`). Pick one with Super+W; its
colours become the accent everywhere (matugen).

## Layout

| Path | What |
|------|------|
| `config/hypr/` | Hyprland (Lua): `hyprland.lua` loads `look`, `input`, `binds`, `rules`, `plugins`, `gamemode`; `hypridle.conf` for idle |
| `config/quickshell/hyprmonk/` | The shell (`qs -c hyprmonk`): `Theme.qml`, `assets/`, `bar/`, `keyguide/`, `lock/`, `notifications/`, `osd/`, `panels/`, `polkit/`, `power/`, `quickactions/`, `services/`, `wallpaper/`, `widgets/` |
| `config/matugen/` | Templates for Hyprland, the shell and kitty |
| `config/uwsm/env` | Session environment (NVIDIA, cursor, toolkits) |
| `config/systemd/user/` | The shell's and hypridle's units; they only start under Hyprland |
| `crates/hyprmonk/` | The `hyprmonk` CLI |
| `udev/` | Access rules for the devices `hyprmonk` reads |
| `packages/pacman.txt` | What `install.sh check` expects |

Generated files never land in the repo: matugen writes to
`~/.local/state/hyprmonk/theme/`, and per-machine Hyprland additions go in
`~/.config/hyprmonk/local.lua`.

## hyprmonk

```
hyprmonk battery [--json]   charge of devices UPower cannot see
```

Today that is the SteelSeries Rival 3 Wireless, read over its receiver's HID
interface. The headset (Arctis Nova 7) already reaches the bar through UPower.

```bash
cargo test
cargo clippy --all-targets -- -D warnings
```

## Roadmap

- Quick actions still to come from HyprFlow: the screens (mirror, only the
  main one; need a second screen to test).
- Appearance: tones more distinct from each other (HyprFlow's look much
  alike); from HyprFlow, a panel to tweak a tone (card opacity, blur, text
  colour), hyprglass glass on the panels instead of plain blur, and the tone
  reaching kitty.
- Lights, parked (not a must-have): the keyboard and mouse in the accent.
  Through OpenRGB the Keychron took colours and effects, but the Rival 3
  Wireless ignored them over its receiver (rivalcfg has no light setting
  for it either), and a keyboard alone would not match the mouse. Back
  only with a way to drive both.
- Game mode extras from HyprFlow: variable refresh in fullscreen, Steam Big
  Picture, and notifications off while it is on.
- Media panel extras from HyprFlow: synced lyrics, art "skins" (the
  polaroid frame), a mini player, the spectrum's other styles (bars, peaks,
  LEDs...) and a picker for them.
- Events in the calendar (dots on their days, a list for the day picked);
  where they come from is still to choose: local, Google or CalDAV.
- Notifications grouped by app, as swaync does.
- OSD, to look at once things are stable: Caps Lock showed only on the
  first press, not on later ones.
- A clean install, still to do: run it on a fresh Arch with no desktop (a
  VM) and fix what shows up. `packages/pacman.txt` was checked against
  everything the shell, the config and the units run; what remains open:
  - A login screen to choose (greetd with tuigreet, SDDM, ly, or none: the
    text console and `uwsm start`). KWallet unlocks at login only if that
    login's PAM file has `pam_kwallet5.so` (Plasma's login has it today).
  - The GPU driver: hyprmonk does not install one (NVIDIA needs its own
    packages; `uwsm/env` sets the NVIDIA variables only when it is loaded).
  - How apps look outside Plasma (GTK and Qt themes for Dolphin and the
    rest).
- An installer that is pleasant to use: a gum menu (Install, Update,
  Uninstall, Check, Quit), installing gum first when it is missing (on Arch
  it is in `extra`). Update pulls and re-runs what changed; Uninstall
  removes the links (restoring the `*.bak-DATE` copies) and the units.
- What a fresh install brings besides the shell, to choose after trying the
  options: the file manager, icons, and wallpapers in the repo so the
  picker is not empty, with one as the default (only pictures whose licence
  lets them be shared).
- Screenshots: grim and slurp are installed, but no bind uses them yet.
- Fedora (and Fedora-based) once Arch is stable: a `packages/` list for
  dnf, and COPRs for what Fedora does not ship.

## Credits

- Ideas from [HyprFlow-Arch](https://github.com/AlejandroMinor/HyprFlow-Arch).
- The Rival 3 Wireless battery protocol from [rivalcfg](https://github.com/flozz/rivalcfg).
- The running cat's font from [runcat-text](https://github.com/AlejandroMinor/runcat-text)
  (BSD-2-Clause, its licence in `config/quickshell/hyprmonk/assets/runcat/`).

## License

MIT, see [LICENSE](LICENSE).
