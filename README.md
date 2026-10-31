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
  inputs, a mixer), batteries, a calendar, and media with synced lyrics.
- A running cat, faster the busier the CPU and resting when the machine is
  quiet, that opens a hardware drawer:
  temperature, CPU, memory, disk and network.
- A launcher for apps, commands, SSH hosts and the clipboard history.
- Quick actions: appearance (the tone), wallpaper, game mode, screen recording,
  power profile, audio output, microphone, keyboard layout, do not disturb, the spectrum's
  style, the login screen's look and the power menu.
- Notifications with a notification centre, an on-screen card for what just
  changed (volume, microphone, audio output, keyboard layout, Caps and Num
  Lock, game mode, power profile), a lock screen (on a key and when idle),
  a power menu, a key guide built from the bindings themselves, and the
  polkit agent for password prompts.
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
| `Super` `W` | Wallpapers |
| `Super` `Tab` | Overview |
| `Super` `N` / `Super` `Shift` `N` | Notification centre / clear notifications |
| `Super` `Q` | Close window |
| `Super` `F` / `Super` `Shift` `F` | Maximize / fullscreen |
| `Super` `V` | Toggle floating |
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
`folder` in `~/.local/state/hyprmonk/wallpaper.json`.

## Colours

The panels' look is a **tone**, picked in quick actions (Appearance). There
are two for now:

- **Noir**, with its own orange accent and the cosmic-noir palette.
- **Wallpaper**, whose colours matugen takes from the wallpaper, so a new
  wallpaper (Super+W) recolours everything.

The tone reaches past the shell: Hyprland's window borders, kitty (live, in
open terminals), the starship prompt and zsh's highlighting (from the next
prompt), GTK apps through adw-gtk3, Qt and KDE apps through qt6ct with Breeze
and a KDE colour scheme, the Yaru icons in the nearest colour, and the login
screen's Desktop look (the wallpaper blurred, in the tone's colours).
Everything generated goes to `~/.local/state/hyprmonk/theme/`, never into the
repo.

## The hyprmonk command

A small Rust binary (`crates/hyprmonk`) for what the shell and the binds
need, installed to `~/.local/bin`:

```
hyprmonk battery [--json]                       charge of devices UPower cannot see
hyprmonk screenshot region|window|screen [--copy]
hyprmonk record MONITOR|region|window:ADDRESS [--sound] [--microphone]
                                                records until stopped; the shell runs it
hyprmonk replay MONITOR [--sound] [--microphone]
                                                keeps the last minute; the shell runs it
hyprmonk recording-saved FILE                   offers a finished recording; the shell runs it
hyprmonk portal-picker [ARGS]                   says what to share; the portal runs it
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
  (Vulkan when NVENC is too new for the driver). Which one, the system's sound
  and the microphone are set in quick actions and kept between sessions: the
  screen, sound on and the microphone off to begin with. It saves
  to `~/Videos/Recordings`, and a notification offers Open and Show in folder.
  A right click on the bar's dot pauses it. A window's recording ends if the
  window changes size or closes, because its picture would freeze there
  ([docs/recording.md](docs/recording.md)). A window needs no dialog:
  `portal-picker` answers the screen cast portal for it, and sharing a screen
  from another app still gets the usual one. After installing, that takes
  effect from the next login.
- `replay` keeps the last minute of the focused screen in memory, for
  `Super` `Shift` `G` to save. Keep the last minute in quick actions turns it
  on, with the same sound settings, and an icon on the bar saves it on a click
  and stops it on a right click. It stays off after a restart: while on it
  costs about 17% of a core, and 220 MB of memory on a still screen, more in a
  game.
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
| `config/hypr/` | Hyprland in Lua: `hyprland.lua` loads `look`, `input`, `binds`, `rules`, `plugins`, `gamemode`; `hypridle.conf` |
| `config/quickshell/hyprmonk/` | The shell (`qs -c hyprmonk`): `bar/`, `panels/`, `launcher/`, `quickactions/`, `notifications/`, `osd/`, `lock/`, `power/`, `keyguide/`, `screenshot/`, `wallpaper/`, `polkit/`, `services/`, `widgets/` |
| `config/matugen/` | Templates for Hyprland, the shell and kitty |
| `config/kitty/` | kitty, with the Noir palette |
| `config/zsh/`, `config/starship/` | zsh and its prompt |
| `config/uwsm/env` | The session's environment (NVIDIA, cursor, toolkits, SSH agent) |
| `config/systemd/user/` | Units for the shell, hypridle, udiskie and clipboard history; they start only under Hyprland |
| `crates/hyprmonk/` | The `hyprmonk` command |
| `udev/` | Access rules for the devices `hyprmonk` reads |
| `packages/` | `pacman.txt` (official repos), `aur.txt` (through paru), `apps.txt` (picked at install) |
| `docs/` | Work planned in detail |

## Roadmap

**Next**

- The rest of the optimizations in [docs/optimizations.md](docs/optimizations.md).

**Later**

An open list, in no fixed order.

- A Settings app or panel for what does not fit in quick actions: display size
  and refresh rate, border sizes, window gaps, rearranging the bar's modules.
  Ideas to gather from noctalia, HANCORE-linux and Ryoku.
- More tones, with ideas from HANCORE-linux's themes, and a panel to adjust one
  (card opacity, blur, text colour).
- btop and fastfetch following the appearance, the Wallpaper tone included.
- A picker for fastfetch's look, with presets like LierB/fastfetch's.
- A simple Vesktop theme that follows the appearance.
- Calendar events from all three sources: local, Google and CalDAV.
- A phone module on the bar, beyond its battery: notifications, the clipboard,
  files, ringing it to find it. KDE Connect or an app of our own, still to
  decide.
- Screen quick actions (mirror, main screen only) and the lock screen on
  several screens.
- The Rust and QML reviewers again, to keep it all lean.
- Fedora, with its own package list, last of all.

**Known issues**

- Pairing from a phone does not get through while the Bluetooth panel is
  searching, which it does for the first seconds: try again once it stops.

**Parked**

- Keyboard and mouse lights in the accent: the Rival 3 Wireless ignores
  colours over its receiver, and the keyboard alone would not match it.

## Credits

- Ideas from [HyprFlow-Arch](https://github.com/AlejandroMinor/HyprFlow-Arch),
  and the zsh setup's from [Ryoku](https://github.com/Ryoku-dev/ryoku); no
  code taken from either.
- The Rival 3 Wireless battery protocol from [rivalcfg](https://github.com/flozz/rivalcfg).
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
