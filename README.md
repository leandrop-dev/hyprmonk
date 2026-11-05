<div align="center">

# hyprmonk

A Hyprland desktop for CachyOS and Arch: a Quickshell shell, small Rust
helpers, and colours taken from the wallpaper.

[![License: MIT](https://img.shields.io/badge/license-MIT-f25623?style=flat-square)](LICENSE)
![CachyOS and Arch](https://img.shields.io/badge/CachyOS%20%7C%20Arch-171717?style=flat-square&logo=archlinux&logoColor=ccd0cf)
![Hyprland](https://img.shields.io/badge/Hyprland-Lua%20config-171717?style=flat-square&logo=hyprland&logoColor=ccd0cf)
![Quickshell](https://img.shields.io/badge/shell-Quickshell-171717?style=flat-square)

</div>

hyprmonk is my own desktop, kept as dotfiles you can install from a bare
system. Everything on screen is drawn by one Quickshell shell, the configs
are symlinked from this repo (so the repo is the live config), and one
installer sets up the rest: packages, apps, services, the login screen and
the terminal.

It is early and personal: CachyOS is the main target, Arch works where it
costs nothing extra, and things change often. See the [Roadmap](#roadmap).

## Contents

- [What you get](#what-you-get)
- [Install](#install)
- [Keys](#keys)
- [Keeping it up to date](#keeping-it-up-to-date)
- [Making it yours](#making-it-yours)
- [Colours](#colours)
- [The hyprmonk command](#the-hyprmonk-command)
- [Layout](#layout)
- [Roadmap](#roadmap)
- [Credits](#credits)

## What you get

**The shell** (Quickshell, `config/quickshell/hyprmonk`)

- A bar with workspaces, the tray, network, Bluetooth, sound, microphone,
  batteries, the clock
  and the media in its centre card, with a live spectrum (cava, seven styles).
- Panels from the bar: Wi-Fi (networks, passwords, the connection editor for
  the rest), Bluetooth (pairing, connecting, batteries), sound (outputs,
  inputs, a mixer, the audio effects' switches), batteries, a calendar, and media with synced lyrics.
- A dock at the bottom (or any other edge) with the open apps and a dot per
  window: a click focuses an app, goes through its windows or minimises it,
  and hovering lists its windows to pick or close. It can hide, list only the
  current workspace's windows, or give way to the same list on the bar.
  Minimised windows wait in it, faded (Super+M, or a title bar's button).
- A running cat, faster the busier the CPU and resting when the machine is
  quiet, that opens a hardware drawer on the bar, or a panel of bars filling
  as they change: temperatures, CPU and each core, GPU and video memory,
  memory, disks and network.
- A launcher for apps, commands, SSH hosts and the clipboard history.
- Settings, in three groups, the longer pages split into sub-pages: each
  screen's resolution, refresh rate and scale, and where screens
  sit by dragging them on a map (a change goes back by itself unless kept),
  gaps, borders, blur, shadows, the layout (three tiling ones, or every
  window floating, resized from its borders) and animations, the bar's
  modules by drag and drop, at the top or the bottom, with its clock,
  workspaces (pills, numbers, dots or a chomper) temperature unit and the cat's drawer or panel, the dock (where it sits, whose windows,
  its size, hiding and growing icons), and the appearance, picked from small previews: the tone with each one's card opacity, blur and text
  colour, the spectrum's style, how a new wallpaper comes in (fade, wipe,
  a circle from where it was picked, or any), fastfetch's look and the login screen's
  look; the sounds (on or off, hyprmonk's set or serpantinum's, their
  volume and the notification tone); the audio effects (the equaliser, with presets
  and ten bands, night mode and its strength, the headphone correction, searched for in AutoEQ, and the noise suppression's threshold and hold,
  with a way to hear yourself); keyboard layouts, the mouse and focus; when the screen locks and the
  screens go off; what recordings hear, their quality and where they go; how
  long notifications stay, their corner, how many show and how many are kept.
- Quick actions: wallpaper, game mode, screen recording, power profile, audio
  output, microphone, keyboard layout, screens (extend, mirror or the main one
  only, kept or undone in 15 s), do not disturb, stay awake (the screen
  neither locks nor goes off until it is turned off; also a cup on the bar),
  settings and the power menu.
- Soft sounds for clicks, switches, cards and panels opening and closing,
  notifications and devices connecting, in two sets, quiet in game mode and
  do not disturb.
- Audio effects with no EasyEffects: an equaliser with presets (Flat, Bass,
  Treble, Vocal, Rock, Pop, Jazz, Classical or your own ten bands), changed
  live on any output, a night mode that brings quiet parts up and loud ones
  down for late listening, a headphone correction from AutoEQ
  (the Arctis Nova 7's comes ready, any other is searched for in Settings)
  and rnnoise's noise suppression for the microphone. Each is a PipeWire
  filter in front of the device, which stays the default, so the volume keys
  and every app keep working on it.
- Notifications with a notification centre, an on-screen card for what just
  changed (volume, microphone, audio output, keyboard layout, Caps and Num
  Lock, game mode, stay awake, power profile), a lock screen (on a key and
  when idle), a power menu, a key guide built from the bindings themselves,
  and the polkit agent for password prompts.
- An overview of every workspace (the hymission plugin).

**The desktop around it**

- Hyprland configured in Lua, started through uwsm, logged into from SDDM
  with a themed login screen.
- Always installed: kitty, Nautilus, Loupe, NetworkManager, Bluetooth,
  GNOME Keyring (with its SSH agent), clipboard history, USB drives mounted
  as they are plugged in, and the common codecs.
- Picked one by one at install: Zen Browser, mpv, Papers, Zed, GitHub CLI,
  Claude Code, opencode, Calculator,
  btop, Resources, KDE Partition Manager, Filelight, archive tools,
  LocalSend, GPU Screen Recorder, Deskflow, printing, Flatpak, firmware
  updates, and spell checking in English and Portuguese.
- zsh with starship, zoxide, fzf, suggestions, highlighting and history
  search, all in the desktop's colours.

## Install

You need CachyOS or Arch, with or without a desktop, and a working GPU
driver (hyprmonk does not install one). On CachyOS, picking **No Desktop**
in the installer gives the cleanest start.

```bash
sudo pacman -S --needed git
git clone https://github.com/leandrop-dev/hyprmonk.git ~/.local/share/hyprmonk
cd ~/.local/share/hyprmonk
./install.sh
```

Or in one line, which does the same (git, the clone in
`~/.local/share/hyprmonk`, the menu):

```bash
curl -fsSL https://raw.githubusercontent.com/leandrop-dev/hyprmonk/main/install.sh | bash
```

The clone can live anywhere (`HYPRMONK_DIR` picks another folder for the
one-liner), but it has to stay: the configs are links into it.

`./install.sh` opens a menu (it installs [gum](https://github.com/charmbracelet/gum)
first if it is missing):

| Entry | What it does |
|-------|--------------|
| **Install** | A checklist of the apps (`packages/apps.txt`), then every step: packages, AUR packages, the apps, configs, folders, default apps, cursor, wallpapers, the `hyprmonk` binary, user and system services, the udev rule for device batteries, zsh, the login screen |
| **Update** | Pulls the repo and runs only the steps its changes need, restarting the shell when its code changed |
| **Check** | Lists what is missing, and the step that fixes each |
| **Uninstall** | Removes the links and units and puts back what they replaced; says how to undo the rest |

sudo asks for your password for packages and services, and `chsh` once for
zsh. Then reboot and pick **Hyprland (uwsm-managed)** on the login screen. The
first login opens a terminal that builds the overview (hymission) and asks for
your password; until that is done, each login opens it again. By hand:

```bash
hyprmonk install plugins
```

**What the installer touches.** Configs already in the way are moved to
`*.bak-DATE`, and Uninstall brings the newest one back. SDDM is enabled in
place of the display manager that was there (to go back:
`sudo systemctl disable sddm` and enable the other). Packages come from the
official repos, the rest through paru: from CachyOS's own repo where it has
them, else the AUR; the installer gets paru first if needed. The lists, with
why each package is there, are in [`packages/`](packages).

Each step also runs on its own; `./install.sh help` lists them.

## Keys

`Super` is the main modifier. **Super+K shows every binding**, grouped, so
this is only the start.

| Keys | Action |
|------|--------|
| `Super` `Return` | Terminal (kitty) |
| `Super` `Space` | Launcher |
| `Super` `Shift` `V` | Clipboard history |
| `Super` `E` | Files (Nautilus) |
| `Super` `A` | Quick actions |
| `Super` `,` | Settings |
| `Super` `W` | Wallpapers |
| `Super` `Tab` | Overview |
| `Super` `N` / `Super` `Shift` `N` | Notification centre / clear notifications |
| `Super` `Q` | Close window |
| `Super` `F` / `Super` `Shift` `F` | Maximize / fullscreen |
| `Super` `V` | Toggle floating |
| `Super` `M` / `Super` `Shift` `M` | Minimise / bring back the last minimised window |
| `Super` `1`-`0` / `Super` `Shift` `1`-`0` | Go to / move to a workspace |
| `Super` `S` | Scratchpad |
| `Print`, then `R`, `W` or `S` | Screenshot of a region, a window or the screen (`Shift` copies it) |
| `Super` `Alt` `L` | Lock |
| `Super` `Shift` `R` | Start or stop screen recording |
| `Super` `Shift` `G` | Save the last minute, while it is being kept |
| `Super` `Shift` `E` | Power menu |
| `Super` `K` | Key guide |

## Keeping it up to date

Once installed, `hyprmonk` runs the installer from any folder:

```bash
hyprmonk update        # pull, then run what the changes need
hyprmonk check         # what is missing
hyprmonk menu          # the menu
hyprmonk install apps  # any step, or none for all of them
hyprmonk uninstall
```

Update refuses to pull over changes of your own in the clone; commit or stash
them first.

## Making it yours

The repo's files are the config, so editing `~/.config/hypr` edits the
clone. For changes that should survive updates, use the local files instead,
which the repo never touches:

| File | For |
|------|-----|
| `~/.config/hyprmonk/local.lua` | Hyprland settings for this machine (monitors, extra binds) |
| `~/.config/zsh/local.zsh` | Your own zsh: aliases, paths, functions |
| `~/.config/hyprmonk/apps` | The apps picked at install, ticked again next time |

Wallpapers come from `~/Pictures/Wallpapers`; the installer downloads the
cosmic-noir set there and starts with `noir-anime.png`. Another folder: set
`folder` in `~/.local/state/hyprmonk/wallpaper.json`. The picker draws from
thumbnails in `~/.cache/hyprmonk/wallpapers`, kept up to date as pictures come
and go. A new wallpaper shows at once, coming in as picked in Settings >
Appearance, and the colours follow once matugen has read it.

## Colours

The panels' look is a **tone**, picked in Settings > Appearance, which shows
each one while the pointer is over it:

- **Noir**, with its own orange accent and the cosmic-noir palette.
- **Wallpaper** and **Wallpaper Light**, whose colours matugen takes from the
  wallpaper, so a new wallpaper (Super+W) recolours everything.
- Fifteen more with palettes of their own, from HANCORE-linux's themes,
  four of them light (Harbor, Rose of Dune, The Greek, White Gold). These change
  kitty's 16 colours too.

The list keeps the dark tones and the light ones under their own headings.

The tone reaches past the shell: Hyprland's window borders and the Floating
layout's title bars, kitty (live, in open terminals, and translucent at the
tone's card opacity), the starship prompt and zsh's highlighting (from the next
prompt), fastfetch (the same, in the look picked), btop (live), Vesktop through its
Quick CSS (live), Zed (live), Zen and Heroic (at their next start), GTK apps
through adw-gtk3, Qt and KDE apps through qt6ct with Breeze and a KDE colour
scheme, the Yaru icons in the nearest colour, and the login screen's Desktop
look (the wallpaper blurred, in the tone's colours). Everything generated goes
to `~/.local/state/hyprmonk/theme/`, never into the repo, but for the files apps
keep in their own folders: the `hyprmonk` themes of btop, Zed and Heroic, a
first `btop.conf` and Zed `settings.json` if there is none, Heroic's theme
choice if it has none, Vesktop's `quickCss.css`, which is left alone if it
already holds CSS of your own, and `hyprmonk.css` in Zen's profile, with a
`userChrome.css` and `userContent.css` that import it if you have neither.

### Steam (optional)

Steam takes the tone through
[Adwaita-for-Steam](https://github.com/tkashkin/Adwaita-for-Steam), a skin that
patches Steam's own files, so it stays your choice: the installer leaves it
out. Steam has to have been opened once. Then:

```sh
git clone --depth 1 https://github.com/tkashkin/Adwaita-for-Steam ~/.cache/hyprmonk/adwaita-for-steam
cd ~/.cache/hyprmonk/adwaita-for-steam
./install.py --custom-css ~/.local/state/hyprmonk/theme/steam.css
```

Restart Steam to see it. From then on the shell copies each tone's `steam.css`
into the skin, and Steam shows it at its next start.

A Steam update can undo the skin; run `./install.py` the same way again.
`./install.py --uninstall` removes it.

## The hyprmonk command

A small Rust binary (`crates/hyprmonk`) for what the shell and the binds
need, installed to `~/.local/bin`:

```
hyprmonk battery [--json]                       charge of devices UPower cannot see
hyprmonk screenshot region|window|screen [--copy]
hyprmonk record MONITOR|region|window:ADDRESS [OPTIONS]
                                                records until stopped; the shell runs it
hyprmonk replay MONITOR [OPTIONS]
                                                keeps the last minute; the shell runs it
                                                OPTIONS: --sound --microphone --quality NAME --folder PATH
hyprmonk recording-saved FILE                   offers a finished recording; the shell runs it
hyprmonk portal-picker [ARGS]                   says what to share; the portal runs it
hyprmonk thumbnails FOLDER                      makes the wallpaper picker's thumbnails; the shell runs it
hyprmonk bluetooth-agent                        answers BlueZ's pairing requests; the shell runs it
hyprmonk menu | install [step...] | update | check | uninstall
```

- `battery` reads a SteelSeries Rival 3 Wireless over its receiver's HID
  interface (the protocol from rivalcfg). Devices UPower knows reach the bar
  without it.
- `screenshot` freezes the screen while a region or window is picked, then
  opens the shot in satty to annotate; Enter saves it to
  `~/Pictures/Screenshots`, `--copy` puts it on the clipboard instead. A
  notification offers Open and Show in folder.
- `record` is GPU Screen Recorder on the focused screen, a region picked with
  the mouse or the focused window, on the cheapest encoder the machine has
  (Vulkan when NVENC is too new for the driver). Which one is picked in quick
  actions; the system's sound, the microphone, the quality (the recorder's
  four presets) and the folder in Settings > Recording, all kept between
  sessions: the screen, sound on, the microphone off, very high quality and
  `~/Videos/Recordings` to begin with. A notification offers Open and Show
  in folder.
  A right click on the bar's dot pauses it. A window's recording ends if the
  window changes size or closes, because its picture would freeze there
  ([docs/recording.md](docs/recording.md)). A window needs no dialog:
  `portal-picker` answers the screen cast portal for it, and sharing a screen
  from another app still gets the usual one. After installing, that takes
  effect from the next login.
- `replay` keeps the last minute of the focused screen in memory, for
  `Super` `Shift` `G` to save. Keep the last minute in quick actions turns it
  on, with the same sound, quality and folder, and an icon on the bar saves
  it on a click and stops it on a right click. It stays off after a restart:
  while on it costs about 17% of a core, and 220 MB of memory on a still
  screen, more in a game.
- `bluetooth-agent` is the pairing agent Quickshell lacks: it passes what
  BlueZ asks to the shell, which shows the code in the Bluetooth panel.
- The installer commands find the clone through `~/.config/hypr`, a link
  into it; `HYPRMONK_DIR` overrides that.

Working on it:

```bash
cargo test
cargo clippy --all-targets -- -D warnings
```

## Layout

| Path | What |
|------|------|
| `install.sh` | The installer: the menu and every step |
| `config/hypr/` | Hyprland in Lua: `hyprland.lua` loads `look`, `input`, `floating`, `minimise`, `binds`, `rules`, `plugins`, `gamemode`; `hypridle.conf` |
| `config/quickshell/hyprmonk/` | The shell (`qs -c hyprmonk`): `bar/`, `dock/`, `panels/`, `launcher/`, `quickactions/`, `notifications/`, `osd/`, `lock/`, `power/`, `keyguide/`, `screenshot/`, `wallpaper/`, `polkit/`, `services/`, `widgets/`, `assets/` (the sounds, the cat's font, AutoEQ's ready corrections) |
| `config/matugen/` | Templates for Hyprland, the shell and kitty |
| `config/kitty/` | kitty, with the Noir palette |
| `config/zsh/`, `config/starship/` | zsh and its prompt |
| `config/fastfetch/` | fastfetch's presets, picked in Settings > Appearance |
| `config/uwsm/env` | The session's environment (NVIDIA, cursor, toolkits, SSH agent) |
| `config/systemd/user/` | Units for the shell, hypridle, udiskie, clipboard history and the four audio effects; they start only under Hyprland |
| `crates/hyprmonk/` | The `hyprmonk` command |
| `udev/` | Access rules for the devices `hyprmonk` reads |
| `packages/` | `pacman.txt` (official repos), `aur.txt` (through paru), `apps.txt` (picked at install) |
| `docs/` | Work planned in detail |

## Roadmap

**Next**

In this order.

1. **Night light.** Warmer colours between set times, or off.
2. **Brightness and gamma.** For each screen, in Settings > Display, with
   ideas from [serpantinum-gamma](https://github.com/ilyamiro/serpantinum-gamma).
3. **A font for everything.** One font picked in Settings for the shell,
   GTK and Qt apps and the terminal, starting from the set serpantinum has:
   its freely licensed ones (Nerd Fonts, JetBrains Mono, Fira Code, Roboto
   and the like), installed from the repos rather than copied. Its SF Pro
   and TT Commons are not free to pass on.

**Later**

An open list, in no fixed order.

- Calendar events from all three sources: local, Google and CalDAV.
- A phone module on the bar, beyond its battery: notifications, the clipboard,
  files, ringing it to find it. KDE Connect or an app of our own, still to
  decide.
- Two sister projects, each in a repo of its own and planned there: Zendo, a
  game launcher for every store with Proton and mods, and Cloister, a file
  manager to take over from Nautilus. hyprmonk will install them, give them
  keys and the tone (Zendo needs the tone's colours written to a file).
- Vesktop through a theme of its own instead of Quick CSS: a theme file in
  Vencord's themes folder, based on [Midnight](https://github.com/refact0r/midnight-discord)
  (MIT) and recoloured by the tone, translucent through Vencord's transparent
  window, as plasmonk-kde did it. Quick CSS is left for your own tweaks.
- The cards' open and close animations on one shared curve and speed.
- Settings in sub-pages where a page holds several things (Appearance >
  Tone, Spectrum, Terminal, Login), and the sidebar grouped.
- Apps the tone does not reach yet, starting from those serpantinum themes.
- Fedora, with its own package list, last of all. Notes for then: some
  packages come from the Terra repository, and gpu-screen-recorder has no
  Fedora package.

**Known issues**

- Pairing from a phone does not get through while the Bluetooth panel is
  searching, which it does for the first seconds: try again once it stops.
- The minimise button an app draws itself (Zen, Vesktop, GNOME apps) works
  only with our minimize-requests plugin, since Hyprland drops the request
  without telling anyone; `./install.sh plugins` adds it. Apps' own maximise
  and minimise buttons show and work in the Floating layout only; the tiling
  layouts ignore them, as they would fight the tiles.

**Parked**

- Keyboard and mouse lights in the accent: the Rival 3 Wireless ignores
  colours over its receiver, and the keyboard alone would not match it.

## Credits

- Ideas from [HyprFlow-Arch](https://github.com/AlejandroMinor/HyprFlow-Arch)
  and [serpantinum](https://github.com/ilyamiro/serpantinum), and the zsh
  setup's from [Ryoku](https://github.com/Ryoku-dev/ryoku); no code taken from
  any of them.
- The serpantinum sound set, copied under its AGPL-3.0 with a note of where
  each file came from (`assets/sounds/serpantinum`).
- The headphone corrections from [AutoEQ](https://github.com/jaakkopasanen/AutoEq)
  (MIT, its licence in `config/quickshell/hyprmonk/assets/autoeq/`), the
  Arctis Nova 7's from Rtings' measurement. The idea of
  keeping the default device while the effects run, and of an equaliser
  with presets, from
  [serpantinum-audio](https://github.com/ilyamiro/serpantinum-audio); no code
  or preset values taken.
- The Rival 3 Wireless battery protocol from [rivalcfg](https://github.com/flozz/rivalcfg).
- The hardware panel's bars after serpantinum's upright ones; no code taken.
- The running cat's font from [runcat-text](https://github.com/AlejandroMinor/runcat-text)
  (BSD-2-Clause, its licence in `config/quickshell/hyprmonk/assets/runcat/`),
  with the sleeping cat added from [RunCat](https://kyome.io/runcat/index.html)'s
  [RunCatResources](https://github.com/runcat-dev/RunCatResources) (Apache-2.0,
  `LICENSE-RunCatResources` beside it).
- Wallpapers from [cosmic-noir-theme](https://github.com/atraxsrc/cosmic-noir-theme)
  by atraxsrc (MIT), renders of subjects from HANCORE-linux's
  [omarchy-greek-noir-theme](https://github.com/HANCORE-linux/omarchy-greek-noir-theme);
  downloaded by the installer, not kept in this repo. kitty's 16 colours are
  its terminal scheme (`cosmic-term/Noir-term.ron`).
- The tones in `config/quickshell/hyprmonk/Tones.qml`: palettes from
  [HANCORE-linux](https://github.com/HANCORE-linux)'s Omarchy themes (MIT,
  `assets/LICENSE-HANCORE-themes` beside it), some of which adapt earlier
  schemes such as Kanso.
- fastfetch's presets are our own, inspired by
  [LierB/fastfetch](https://github.com/LierB/fastfetch)'s; no code taken.
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
