# hyprmonk

My Hyprland desktop on Arch (CachyOS): a Quickshell shell, small Rust helpers,
and colours generated from the wallpaper by matugen.

Early days: the bar with its sound, battery, calendar and media panels,
notifications, the OSD, quick actions (Super+K, with a game mode), the polkit
agent, the Hyprland config and the first helper. More panels come next (see [Roadmap](#roadmap)), all in Quickshell.

## Install

```bash
git clone https://github.com/leandrop-dev/hyprmonk.git
cd hyprmonk
./install.sh            # check packages, link configs, build hyprmonk, enable the shell
./install.sh udev       # once: lets hyprmonk read the mouse battery (sudo)
```

Log in to **Hyprland (uwsm-managed)**. Then, from inside Hyprland:

```bash
./install.sh plugins                                           # hyprglass and hymission (compiles)
matugen image ~/Pictures/wallpaper.png --source-color-index 0  # colours from a wallpaper
```

`install.sh` symlinks the configs, so the repo is the live config: edit either
side and both change. Anything already in the way is moved to `*.bak-DATE`.
Run `./install.sh help` for each step.

## Layout

| Path | What |
|------|------|
| `config/hypr/` | Hyprland (Lua): `hyprland.lua` loads `look`, `input`, `binds`, `rules`, `plugins`, `gamemode` |
| `config/quickshell/hyprmonk/` | The shell (`qs -c hyprmonk`): `Theme.qml`, `bar/`, `notifications/`, `osd/`, `panels/`, `polkit/`, `quickactions/`, `services/`, `widgets/` |
| `config/matugen/` | Templates for Hyprland, the shell and kitty |
| `config/uwsm/env` | Session environment (NVIDIA, cursor, toolkits) |
| `config/systemd/user/` | The shell's unit; it only starts under Hyprland |
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

- Panels in HyprFlow's style: power menu, key guide, a cava spectrum in the
  centre card, a hardware drawer.
- A wallpaper: nothing draws one yet.
- Quick actions still to come from HyprFlow: the screens (mirror, only the
  main one; need a second screen to test), lights (OpenRGB for the ASUS Aura
  controller), the keyboard's effect, the appearance (tone), a random
  wallpaper, and the power menu once it exists.
- Game mode extras from HyprFlow: variable refresh in fullscreen, Steam Big
  Picture, notifications and lights off while it is on.
- Media panel extras from HyprFlow: synced lyrics, art "skins" (the
  polaroid frame), a mini player.
- Events in the calendar (dots on their days, a list for the day picked);
  where they come from is still to choose: local, Google or CalDAV.
- Notifications grouped by app, as swaync does.
- OSD, to look at once things are stable: Caps Lock showed only on the
  first press, not on later ones.
- A clean install: hyprmonk must work on an Arch or CachyOS install with no
  desktop yet, so `packages/` has to list everything it needs (today it
  leans on what Plasma already installed). Verify on a fresh install.

## Credits

- Ideas from [HyprFlow-Arch](https://github.com/AlejandroMinor/HyprFlow-Arch).
- The Rival 3 Wireless battery protocol from [rivalcfg](https://github.com/flozz/rivalcfg).

## License

MIT, see [LICENSE](LICENSE).
