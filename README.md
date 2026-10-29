# hyprmonk

My Hyprland desktop on Arch (CachyOS): a Quickshell shell, small Rust helpers,
and colours generated from the wallpaper by matugen.

Early days: the wallpaper (Super+W to pick), the bar with its tray, sound,
battery, calendar and media panels, a running cat that opens a hardware
drawer (temperature, CPU, memory, disk, network), a live spectrum (cava, in
seven styles) and synced lyrics, notifications, the OSD, the launcher
(Super+Space: apps, commands, SSH hosts), quick actions
(Super+A: game mode, the panels' tone, Noir among them, the spectrum's
style), the power menu (Super+Shift+E), the key guide (Super+K), the lock
screen (Super+Alt+L, and on idle), screenshots (Print, then R, W or S), the
polkit agent, the Hyprland config and the helpers. More panels come next
(see [Roadmap](#roadmap)), all in Quickshell.

## Install

On Arch (or an Arch-based distro) with or without a desktop. Packages come
from the official repos, except the icons (Yaru) and qt6ct-kde, from the AUR
through paru, which the installer gets first (from the repos on CachyOS, else
built once from `paru-bin`):

```bash
sudo pacman -S --needed git
git clone https://github.com/leandrop-dev/hyprmonk.git
cd hyprmonk
./install.sh            # packages, AUR packages, configs, folders, default apps, cursor, wallpapers, hyprmonk, the shell, the login screen
./install.sh udev       # once: lets hyprmonk read the mouse battery (sudo)
```

Then reboot: the login screen is SDDM (in place of the display manager that
was enabled; to go back, `sudo systemctl disable sddm` and enable the other).
Pick **Hyprland (uwsm-managed)** there. Then, from inside Hyprland:

```bash
./install.sh plugins   # hymission, the overview (compiles)
```

`install.sh` symlinks the configs, so the repo is the live config: edit either
side and both change. Anything already in the way is moved to `*.bak-DATE`.
Run `./install.sh help` for each step.

Wallpapers come from `~/Pictures/Wallpapers` (another folder: set `folder` in
`~/.local/state/hyprmonk/wallpaper.json`). The installer downloads the
cosmic-noir set there and starts with `noir-anime.png`. Pick another with
Super+W; its colours become the accent everywhere (matugen).

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
| `docs/` | Work planned in detail (`optimizations.md`) |

Generated files never land in the repo: matugen writes to
`~/.local/state/hyprmonk/theme/`, and per-machine Hyprland additions go in
`~/.config/hyprmonk/local.lua`.

## hyprmonk

```
hyprmonk battery [--json]                    charge of devices UPower cannot see
hyprmonk screenshot region|window|screen [--copy]
                                             take a screenshot
```

`battery` reads the SteelSeries Rival 3 Wireless over its receiver's HID
interface. The headset (Arctis Nova 7) already reaches the bar through UPower.

`screenshot` freezes the screen (hyprpicker) while a region or a window is
picked (slurp), takes it with grim, then opens it in satty to annotate: Enter
saves it to `~/Pictures/Screenshots`. With `--copy` it goes to the clipboard
instead. A notification shows it, with Open and Show in folder. Print starts
the screenshot mode, whose card lists the keys.

```bash
cargo test
cargo clippy --all-targets -- -D warnings
```

## Roadmap

- Optimizations from a review of the crate and the shell, in
  [docs/optimizations.md](docs/optimizations.md): the bar's idle CPU first.
- Quick actions still to come from HyprFlow: the screens (mirror, only the
  main one; need a second screen to test).
- Appearance: two tones for now, Noir and Wallpaper (Black, Slate, Espresso
  and the light ones were dropped; more to pick later). Only Wallpaper takes
  its colours from the wallpaper; every other tone brings its own accent and
  green, as Noir does, and the tone's accent reaches everything: the shell,
  Hyprland's window borders, kitty, GTK and Qt apps do (`ThemeOutputs.qml`).
- Appearance: from HyprFlow, a panel to tweak a tone (card opacity, blur, text
  colour).
- Lights, parked (not a must-have): the keyboard and mouse in the accent.
  Through OpenRGB the Keychron took colours and effects, but the Rival 3
  Wireless ignored them over its receiver (rivalcfg has no light setting
  for it either), and a keyboard alone would not match the mouse. Back
  only with a way to drive both.
- Events in the calendar (dots on their days, a list for the day picked);
  where they come from is still to choose: local, Google or CalDAV.
- Screenshots: the notification's preview of a copied screenshot shows a
  grey picture instead of the shot.
- A clean install, still to do: run it on a fresh Arch with no desktop (a
  VM) and fix what shows up. `packages/pacman.txt` was checked against
  everything the shell, the config and the units run; what remains open:
  - The login screen: done, SDDM (on X11, as Arch ships it) with the
    [sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme)
    (GPL-3.0) in its astronaut look (`install.sh login`: the theme at a
    fixed commit into `/usr/share/sddm/themes`, its fonts, the settings in
    `/etc/sddm.conf.d/hyprmonk.conf`, SDDM enabled in place of the display
    manager before it). SDDM's PAM file unlocks KWallet. Later, a
    picker for its ten themes: `hyprmonk sddm-theme NAME` changes
    `ConfigFile=` in the theme's `metadata.desktop` through pkexec (the
    shell's polkit agent asks), listed in a card or quick action.
  - The GPU driver: hyprmonk does not install one (NVIDIA needs its own
    packages; `uwsm/env` sets the NVIDIA variables only when it is loaded).
  - How apps look outside Plasma. GTK: done, adw-gtk3 and GTK's named
    colours, the wallpaper's from matugen and a tone's own over them, in
    `~/.config/gtk-{3,4}.0/gtk.css` (written by the shell under Hyprland,
    by Plasma under Plasma); open GTK 4 apps change with the tone, GTK 3
    ones when opened again. Qt: done, qt6ct (`qt6ct-kde` from the AUR, so
    KDE apps take its colours) with Breeze, a KDE colour scheme in the tone
    (`theme/qt-HASH.colors`) and the tone's Yaru; open Qt apps change
    colour with the tone 3 s later, their icons when opened again. KDE apps
    read their icons and style from `~/.config/kdeglobals`, so the shell
    sets those there too, replacing Plasma's choices.
- An installer that is pleasant to use: a gum menu (Install, Update,
  Uninstall, Check, Quit), installing gum first when it is missing (on Arch
  it is in `extra`). Update pulls and re-runs what changed; Uninstall
  removes the links (restoring the `*.bak-DATE` copies) and the units.
- What a fresh install brings besides the shell:
  - Files: done, Nautilus (GTK 4, sandboxed thumbnailers, `FileManager1`
    for Show in folder), on Super+E and for folders (`install.sh apps`).
    [Strata](https://github.com/lgse/strata) to look at again once it is
    older than two months and in the official repos.
  - Images: done, Loupe (sandboxed decoders), what Open on a screenshot
    starts.
  - Icons: [Yaru](https://github.com/ubuntu/yaru), as Omarchy does
    (`yaru-icon-theme` from the AUR, `install.sh aur`). Done for GTK apps:
    Noir takes Yaru's orange, Wallpaper the colour nearest its accent. The
    shell's own icons stay Yaru's orange (`QS_ICON_THEME` is read once);
    Qt apps take the tone's too.
- The terminal: done, kitty's 16 colours from cosmic-noir's terminal
  palette (`config/kitty/noir.conf`), its text, background and cursor from
  the tone, reloaded live on a pick. A light tone, if one comes back, needs
  a darker take on the palette to stay readable.
- More from [cosmic-noir-theme](https://github.com/atraxsrc/cosmic-noir-theme),
  where the wallpapers come from (its palette is the Noir tone): its btop
  and fastfetch colours.
- Fedora (and Fedora-based) once Arch is stable: a `packages/` list for
  dnf, and COPRs for what Fedora does not ship.

## Credits

- Ideas from [HyprFlow-Arch](https://github.com/AlejandroMinor/HyprFlow-Arch).
- The Rival 3 Wireless battery protocol from [rivalcfg](https://github.com/flozz/rivalcfg).
- The running cat's font from [runcat-text](https://github.com/AlejandroMinor/runcat-text)
  (BSD-2-Clause, its licence in `config/quickshell/hyprmonk/assets/runcat/`).
- Wallpapers from [cosmic-noir-theme](https://github.com/atraxsrc/cosmic-noir-theme)
  by atraxsrc (MIT), renders of subjects from HANCORE-linux's
  [omarchy-greek-noir-theme](https://github.com/HANCORE-linux/omarchy-greek-noir-theme);
  downloaded by the installer, not kept in this repo. kitty's 16 colours are
  its terminal scheme (`cosmic-term/Noir-term.ron`).
- Synced lyrics from [LRCLIB](https://lrclib.net), looked up while the media
  panel shows them.
- The cursor: [Bibata](https://github.com/ful1e5/Bibata_Cursor) Modern Ice
  (GPL-3.0), downloaded by the installer.
- The icons: [Yaru](https://github.com/ubuntu/yaru) by the Ubuntu community
  (CC BY-SA 4.0 and GPL-3.0), installed from the AUR.
- The login screen: [sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme)
  by Keyitdev (GPL-3.0), downloaded by the installer.

## License

MIT, see [LICENSE](LICENSE).
