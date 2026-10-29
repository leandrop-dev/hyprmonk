#!/usr/bin/env bash
# hyprmonk installer. The repo stays the source of truth: configs are
# symlinked into ~/.config, so editing either side edits both.
set -euo pipefail

# Piped from curl there is no file, so no repo around it: main clones one.
REPO=""
[[ -n ${BASH_SOURCE[0]:-} ]] && REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${HYPRMONK_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/hyprmonk}"

usage() {
    cat <<EOF
usage: install.sh [step...]
   or: curl -fsSL https://raw.githubusercontent.com/leandrop-dev/hyprmonk/main/install.sh | bash
       (clones the repo to ~/.local/share/hyprmonk, or \$HYPRMONK_DIR, then runs it
       from there; steps go after bash -s --)
   or, once installed: hyprmonk menu|install|update|check|uninstall

With no step, in a terminal: a menu (Install, Update, Check, Uninstall).
Otherwise with no step, or with install: ${INSTALL_STEPS[*]}.

steps:
  install    every step above, without the menu (the apps as last picked)
  check      what is missing: packages, links, units, services, the login shell
  update     pull the repo, then run the steps its changes need
  uninstall  remove the links and units, putting back the *.bak-DATE copies
             (packages stay installed)
  packages   install the missing ones from pacman.txt (uses sudo)
  aur        install the missing ones from aur.txt with paru (uses sudo; gets paru first)
  apps       install the apps picked from apps.txt (all until some are picked
             in the menu; kept in ~/.config/hyprmonk/apps) with paru (uses sudo)
  link       symlink the configs into ~/.config (existing ones are moved to *.bak-DATE)
  folders    create ~/Pictures/Wallpapers, where the wallpaper picker looks
  defaults   what opens what (xdg-open): Zen, Nautilus, Loupe, mpv, Papers, Zed
  cursor     download the cursor theme (Bibata) to ~/.local/share/icons
  wallpapers download the cosmic-noir wallpapers, and pick one if none is set
  bin        build hyprmonk and install it to ~/.local/bin
  services   enable the systemd user units (they only start under Hyprland), and
             GNOME Keyring's and its SSH agent's sockets
  system     enable NetworkManager, Bluetooth, printing and Avahi (uses sudo)
  shell      zsh as your login shell, its config linked to ~/.zshrc (asks your
             password)
  udev       install the udev rule for device batteries (uses sudo)
  login      the login screen: SDDM with sddm-astronaut-theme, enabled in place of
             the current display manager (uses sudo; from the next boot); its
             look is picked in quick actions
  plugins    install and enable the hyprpm plugins (compiles; run inside Hyprland)
EOF
}

say() { printf '\033[1m::\033[0m %s\n' "$*"; }

# What Install runs, in order (plugins too from inside Hyprland).
INSTALL_STEPS=(packages aur apps link folders defaults cursor wallpapers bin services system shell login)

# repo path -> target, relative to the repo and $HOME
LINKS=(
    "config/hypr:.config/hypr"
    "config/quickshell/hyprmonk:.config/quickshell/hyprmonk"
    "config/matugen:.config/matugen"
    "config/kitty:.config/kitty"
    "config/uwsm:.config/uwsm"
    "config/starship:.config/starship"
)

# Every user unit in the repo is linked and enabled; each one checks for
# Hyprland itself, so none start in another desktop.
UNITS_DIR="config/systemd/user"
units() {
    local unit
    for unit in "$REPO/$UNITS_DIR"/*.service; do basename "$unit"; done
}

# The packages a list names (pacman.txt or aur.txt), without comments.
wanted_packages() {
    sed -e 's/#.*//' -e '/^\s*$/d' "$REPO/packages/$1"
}

missing_packages() {
    pacman -T $(wanted_packages "$1") || true
}

# The apps to pick from (packages/apps.txt): "name | packages | what".
app_lines() {
    sed -e 's/#.*//' -e '/^\s*$/d' "$REPO/packages/apps.txt"
}

app_names() {
    app_lines | awk -F' *[|] *' '{ print $1 }'
}

app_packages() {
    app_lines | awk -F' *[|] *' -v name="$1" '$1 == name { print $2 }'
}

# The picks, one name per line: those saved that apps.txt still has, or all
# of them until some are saved.
APPS_PICKED="$HOME/.config/hyprmonk/apps"
picked_apps() {
    if [[ -f $APPS_PICKED ]]; then
        grep -Fx -f <(app_names) "$APPS_PICKED" || true
    else
        app_names
    fi
}

picked_packages() {
    local name
    picked_apps | while IFS= read -r name; do app_packages "$name"; done | tr ' ' '\n' | sed '/^$/d'
}

missing_picked() {
    local packages
    packages=$(picked_packages)
    [[ -n $packages ]] && { pacman -T $packages || true; }
}

# One line per thing checked; the count of what is off at the end.
step_check() {
    say "Checking"
    local off=0 list missing step pair target unit
    for list in pacman.txt aur.txt apps; do
        if [[ $list == apps ]]; then
            missing=$(missing_picked) step=apps
        else
            missing=$(missing_packages "$list")
            step=$([[ $list == aur.txt ]] && echo aur || echo packages)
        fi
        if [[ -z $missing ]]; then
            echo "   ok       $list"
        else
            echo "   missing  $list: $(echo $missing) (./install.sh $step)"
            off=$((off + 1))
        fi
    done
    for pair in "${LINKS[@]}" "config/zsh/zshrc:.zshrc"; do
        target="$HOME/${pair#*:}"
        if [[ -L $target && $(readlink "$target") == "$REPO/${pair%%:*}" ]]; then
            echo "   ok       ~/${pair#*:}"
        else
            echo "   missing  ~/${pair#*:} (./install.sh $([[ ${pair#*:} == .zshrc ]] && echo shell || echo link))"
            off=$((off + 1))
        fi
    done
    for unit in $(units) "${SOCKETS[@]}"; do
        if systemctl --user is-enabled --quiet "$unit"; then
            echo "   ok       $unit"
        else
            echo "   off      $unit (./install.sh services)"
            off=$((off + 1))
        fi
    done
    for unit in NetworkManager.service bluetooth.service avahi-daemon.service $(pacman -T cups > /dev/null && echo cups.socket) sddm.service; do
        if systemctl is-enabled --quiet "$unit"; then
            echo "   ok       $unit"
        else
            echo "   off      $unit (./install.sh $([[ $unit == sddm.service ]] && echo login || echo system))"
            off=$((off + 1))
        fi
    done
    if [[ $(getent passwd "$USER" | cut -d: -f7) == */zsh ]]; then
        echo "   ok       login shell zsh"
    else
        echo "   off      login shell $(getent passwd "$USER" | cut -d: -f7) (./install.sh shell)"
        off=$((off + 1))
    fi
    if ((off == 0)); then
        say "Everything is in place"
    else
        say "$off to fix (the step after each)"
    fi
}

step_packages() {
    say "Installing packages (sudo)"
    local missing
    missing=$(missing_packages pacman.txt)
    if [[ -z $missing ]]; then
        echo "   everything is installed"
        return
    fi
    sudo pacman -S --needed $missing
}

# paru, from the repos where they have it (CachyOS), or else built once from
# the AUR's paru-bin (needs base-devel and git, from pacman.txt).
ensure_paru() {
    command -v paru >/dev/null && return
    if pacman -Si paru >/dev/null 2>&1; then
        sudo pacman -S --needed paru
        return
    fi
    local build
    build=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$build/paru-bin"
    (cd "$build/paru-bin" && makepkg -si)
    rm -rf "$build"
}

step_aur() {
    say "Installing AUR packages (sudo)"
    local missing
    missing=$(missing_packages aur.txt)
    if [[ -z $missing ]]; then
        echo "   everything is installed"
        return
    fi
    ensure_paru
    paru -S --needed $missing
}

step_apps() {
    say "Installing the apps picked (sudo)"
    if [[ -z $(picked_apps) ]]; then
        echo "   none picked"
        return
    fi
    local missing
    missing=$(missing_picked)
    if [[ -z $missing ]]; then
        echo "   everything is installed: $(picked_apps | paste -sd, - | sed 's/,/, /g')"
        return
    fi
    ensure_paru
    paru -S --needed $missing
}

step_folders() {
    say "Creating folders"
    command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update
    mkdir -p "$HOME/Pictures/Wallpapers"
    echo "   ok       ~/Pictures/Wallpapers"
}

# What xdg-open starts. Without it a folder opens in kitty: kitty-open.desktop
# claims folders too, and sorts first.
APPS=(
    "zen.desktop:x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml"
    "org.gnome.Nautilus.desktop:inode/directory"
    "org.gnome.Loupe.desktop:image/png image/jpeg image/webp image/gif image/bmp image/tiff image/svg+xml"
    "mpv.desktop:video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg video/ogg audio/mpeg audio/flac audio/ogg audio/x-wav audio/mp4 audio/x-opus+ogg"
    "org.gnome.Papers.desktop:application/pdf image/vnd.djvu application/vnd.comicbook+zip"
    "dev.zed.Zed.desktop:text/plain text/markdown application/json application/toml application/x-yaml application/x-shellscript text/x-python text/x-csrc text/x-chdr text/x-c++src text/rust"
)

# Whether an app's desktop entry is installed, for the system or the user
# (Flatpak's included).
has_desktop_entry() {
    local dir
    for dir in /usr/share/applications "$HOME/.local/share/applications" \
        /var/lib/flatpak/exports/share/applications "$HOME/.local/share/flatpak/exports/share/applications"; do
        [[ -e $dir/$1 ]] && return 0
    done
    return 1
}

step_defaults() {
    say "Setting default apps"
    local pair app
    for pair in "${APPS[@]}"; do
        app=${pair%%:*}
        if ! has_desktop_entry "$app"; then
            echo "   skipped  ${app%.desktop}: not installed"
            continue
        fi
        xdg-mime default "$app" ${pair#*:}
        echo "   ok       ${app%.desktop}: ${pair#*:}"
    done
}

# The cursor: Bibata (GPL-3.0), not in the official repos, so its release
# archive, pinned by checksum. uwsm/env names it.
CURSOR_THEME="Bibata-Modern-Ice"
CURSOR_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz"
CURSOR_SHA256="a68cae60c4dc706350e194ebc91c5fe48bc7bc9d59e119555834a2a7ee5078ef"

step_cursor() {
    say "Installing the cursor ($CURSOR_THEME)"
    local icons="$HOME/.local/share/icons"
    if [[ -f $icons/$CURSOR_THEME/index.theme ]]; then
        echo "   ok       ~/.local/share/icons/$CURSOR_THEME"
        return
    fi
    local archive
    archive=$(mktemp --suffix=.tar.xz)
    curl -fsSL -o "$archive" "$CURSOR_URL"
    if ! echo "$CURSOR_SHA256  $archive" | sha256sum --check --quiet -; then
        rm -f "$archive"
        echo "   the download does not match its checksum; nothing installed" >&2
        return 1
    fi
    mkdir -p "$icons"
    tar -xf "$archive" -C "$icons"
    rm -f "$archive"
    echo "   installed ~/.local/share/icons/$CURSOR_THEME"
}

# Wallpapers from cosmic-noir-theme (MIT), at a fixed commit, into the
# picker's folder; the first one becomes the wallpaper unless one is set.
WALLPAPERS_URL="https://raw.githubusercontent.com/atraxsrc/cosmic-noir-theme/6b2e9d97a99c4a8f8f20afe0687dc58802470c83/backgrounds"
WALLPAPERS=(
    noir-anime.png noir-anime-1.png noir-anime-2.png noir-city.png
    noir-cosmic-astronaut.png noir-eagle.png noir-geisha-vivid.png
    noir-hyundai-blueprint.png noir-js-mug.png noir-neon-city.png
    noir-panel.png noir-reaper-skull.png noir-samurai.png
    noir-sushi-switch.png noir-tower.png
)

step_wallpapers() {
    say "Downloading wallpapers (cosmic-noir-theme)"
    local folder="$HOME/Pictures/Wallpapers" name
    mkdir -p "$folder"
    for name in "${WALLPAPERS[@]}"; do
        if [[ -s $folder/$name ]]; then
            echo "   ok       $name"
            continue
        fi
        curl -fsSL -o "$folder/$name.part" "$WALLPAPERS_URL/$name"
        mv "$folder/$name.part" "$folder/$name"
        echo "   fetched  $name"
    done
    # The shell makes the colours from it on its first start.
    local state="$HOME/.local/state/hyprmonk/wallpaper.json"
    if [[ ! -e $state ]]; then
        mkdir -p "$(dirname "$state")"
        printf '{\n    "path": "%s",\n    "folder": ""\n}\n' "$folder/${WALLPAPERS[0]}" > "$state"
        echo "   wallpaper ${WALLPAPERS[0]}"
    fi
}

link_one() {
    local source="$REPO/$1" target="$HOME/$2"
    if [[ -L $target && $(readlink "$target") == "$source" ]]; then
        echo "   ok       ~/$2"
        return
    fi
    mkdir -p "$(dirname "$target")"
    if [[ -L $target ]]; then
        rm "$target"
    elif [[ -d $target && -z $(ls -A "$target") ]]; then
        rmdir "$target"
    elif [[ -e $target ]]; then
        local backup
        backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$target" "$backup"
        echo "   moved    ~/$2 -> ${backup#"$HOME"/}"
    fi
    ln -s "$source" "$target"
    echo "   linked   ~/$2"
}

step_link() {
    say "Linking configs"
    local pair unit
    for pair in "${LINKS[@]}"; do
        link_one "${pair%%:*}" "${pair#*:}"
    done
    for unit in $(units); do
        link_one "$UNITS_DIR/$unit" ".config/systemd/user/$unit"
    done
    unlink_gone_units
}

# Units the repo no longer has: their links (and the links enabling them)
# would point at nothing.
unlink_gone_units() {
    local link unit
    for link in "$HOME/.config/systemd/user"/*.service; do
        [[ -L $link && $(readlink "$link") == "$REPO/$UNITS_DIR/"* && ! -e $link ]] || continue
        unit=$(basename "$link")
        rm -f "$link" "$HOME/.config/systemd/user/graphical-session.target.wants/$unit"
        echo "   removed  ~/.config/systemd/user/$unit (no longer in the repo)"
    done
}

step_bin() {
    say "Building hyprmonk"
    # A fresh rustup has no toolchain, and cargo refuses to run without one.
    if ! rustup default >/dev/null 2>&1; then
        rustup default stable
    fi
    cargo install --locked --path "$REPO/crates/hyprmonk" --root "$HOME/.local"
}

# Started when first asked for: secrets (unlocked at login by SDDM's PAM file)
# and SSH keys (uwsm/env points SSH_AUTH_SOCK at it).
SOCKETS=(gnome-keyring-daemon.socket gcr-ssh-agent.socket)

step_services() {
    say "Enabling user services"
    unlink_gone_units
    systemctl --user daemon-reload
    systemctl --user enable $(units) "${SOCKETS[@]}"
}

# System services a desktop needs, enabled and started. The network is left
# alone when another manager runs it: switching would cut the connection.
step_system() {
    say "Enabling system services (sudo)"
    local other
    if systemctl is-enabled --quiet NetworkManager.service; then
        echo "   ok       NetworkManager.service"
    else
        other=$(systemctl list-unit-files --state=enabled --no-legend systemd-networkd.service iwd.service connman.service | awk '{print $1}' | paste -sd' ')
        if [[ -n $other ]]; then
            echo "   skipped  NetworkManager.service: $other runs the network; disable it and enable NetworkManager yourself" >&2
        else
            sudo systemctl enable --now NetworkManager.service
            echo "   enabled  NetworkManager.service"
        fi
    fi
    local unit
    for unit in bluetooth.service avahi-daemon.service $(pacman -T cups > /dev/null && echo cups.socket); do
        if systemctl is-enabled --quiet "$unit"; then
            echo "   ok       $unit"
        else
            sudo systemctl enable --now "$unit"
            echo "   enabled  $unit"
        fi
    done
    # Printers and other .local names: systemd-resolved finds them where it
    # runs (CachyOS); otherwise nss-mdns does, from nsswitch.conf.
    if systemctl is-enabled --quiet systemd-resolved.service; then
        echo "   ok       .local names through systemd-resolved"
    elif grep -q '^hosts:.*mdns' /etc/nsswitch.conf; then
        echo "   ok       .local names through nss-mdns"
    else
        sudo sed -i 's/^hosts:\(.*\) resolve/hosts:\1 mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
        if grep -q '^hosts:.*mdns' /etc/nsswitch.conf; then
            echo "   set      .local names through nss-mdns (/etc/nsswitch.conf)"
        else
            echo "   skipped  /etc/nsswitch.conf: its hosts line has no resolve to put mdns_minimal before" >&2
        fi
    fi
}

# zsh with config/zsh/zshrc; local additions go in ~/.config/zsh/local.zsh.
step_shell() {
    say "Setting up zsh"
    link_one "config/zsh/zshrc" ".zshrc"
    mkdir -p "$HOME/.config/zsh"
    local zsh current
    zsh=$(command -v zsh) || { echo "   run the packages step first" >&2; return 1; }
    current=$(getent passwd "$USER" | cut -d: -f7)
    if [[ $current == "$zsh" ]]; then
        echo "   ok       login shell $zsh"
        return
    fi
    chsh -s "$zsh"
    echo "   set      login shell $zsh (was $current), from the next login"
}

step_udev() {
    say "Installing the udev rule (sudo)"
    sudo install -Dm644 "$REPO/udev/70-hyprmonk.rules" /etc/udev/rules.d/70-hyprmonk.rules
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=hidraw --action=change
}

# The login screen: SDDM with sddm-astronaut-theme (GPL-3.0) at a fixed
# commit, in its astronaut look until another is picked. SDDM replaces
# whichever display manager is enabled, from the next boot.
LOGIN_THEME="sddm-astronaut-theme"
LOGIN_LOOKS="/var/lib/hyprmonk-login"
LOGIN_COMMIT="abb3163c724935af888ba5ea9ac0c4f22afd8048"
LOGIN_URL="https://github.com/Keyitdev/sddm-astronaut-theme/archive/$LOGIN_COMMIT.tar.gz"
LOGIN_SHA256="3e7ccde7158b336bb7ea6c69a18cefe27a9c82d6c04c4bef03b5b1519d6ae11c"

step_login() {
    say "Setting up the login screen (sudo)"
    if ! pacman -Q sddm > /dev/null; then
        echo "   run the packages step first" >&2
        return 1
    fi
    local theme="/usr/share/sddm/themes/$LOGIN_THEME" fonts="/usr/share/fonts/$LOGIN_THEME"
    if [[ -f $theme/.hyprmonk-commit && $(< "$theme/.hyprmonk-commit") == "$LOGIN_COMMIT" ]]; then
        echo "   ok       $theme"
    else
        local tmp
        tmp=$(mktemp -d)
        curl -fsSL -o "$tmp/theme.tar.gz" "$LOGIN_URL"
        if ! echo "$LOGIN_SHA256  $tmp/theme.tar.gz" | sha256sum --check --quiet -; then
            rm -rf "$tmp"
            echo "   the download does not match its checksum; nothing installed" >&2
            return 1
        fi
        mkdir "$tmp/theme"
        tar -xzf "$tmp/theme.tar.gz" -C "$tmp/theme" --strip-components=1
        echo "$LOGIN_COMMIT" > "$tmp/theme/.hyprmonk-commit"
        sudo rm -rf "$theme" "$fonts"
        sudo mkdir -p "$(dirname "$theme")" "$fonts"
        sudo cp -r "$tmp/theme" "$theme"
        sudo cp -r "$theme/Fonts/." "$fonts"
        sudo chmod -R u=rwX,go=rX "$theme" "$fonts"
        sudo fc-cache "$fonts"
        rm -rf "$tmp"
        echo "   installed $theme"
    fi

    # The look the theme reads is the one $LOGIN_LOOKS/current.conf links
    # to, in a folder of the user's: the shell picks one there (quick
    # actions > Login look) and writes the Desktop look, with no sudo.
    sudo install -d -o "$USER" -g "$(id -gn)" -m 755 "$LOGIN_LOOKS"
    [[ -L $LOGIN_LOOKS/current.conf ]] || ln -s "$theme/Themes/astronaut.conf" "$LOGIN_LOOKS/current.conf"
    sudo ln -sfn "$LOGIN_LOOKS/current.conf" "$theme/Themes/hyprmonk-current.conf"
    sudo sed -i 's|^ConfigFile=.*|ConfigFile=Themes/hyprmonk-current.conf|' "$theme/metadata.desktop"
    echo "   set      $LOGIN_LOOKS (the look: $(basename "$(readlink "$LOGIN_LOOKS/current.conf")" .conf))"

    sudo mkdir -p /etc/sddm.conf.d
    printf '[General]\nInputMethod=qtvirtualkeyboard\n\n[Theme]\nCurrent=%s\n' "$LOGIN_THEME" \
        | sudo tee /etc/sddm.conf.d/hyprmonk.conf > /dev/null
    echo "   set      /etc/sddm.conf.d/hyprmonk.conf"

    local link=/etc/systemd/system/display-manager.service current=""
    [[ -L $link ]] && current=$(basename "$(readlink -f "$link")")
    if [[ $current == sddm.service ]]; then
        echo "   ok       sddm.service"
        return
    fi
    if [[ -n $current ]]; then
        sudo systemctl disable "$current"
        echo "   disabled $current (to go back: systemctl disable sddm, enable $current)"
    fi
    sudo systemctl enable sddm.service
    echo "   enabled  sddm.service, the login screen from the next boot"
}

# name -> repository
PLUGINS=(
    "hymission:https://github.com/gfhdhytghd/hymission"
)

# ok, failed (registered but its build failed) or missing. hyprpm has no
# machine-readable output, so this reads `hyprpm list` without its colours.
plugin_state() {
    hyprpm list | sed 's/\x1b\[[0-9;]*m//g' | awk -v name="$1" '
        $2 == "Repository" { here = (tolower($3) == tolower(name)); if (here) found = 1 }
        here && /failed to build/ { failed = 1 }
        END { print found ? (failed ? "failed" : "ok") : "missing" }'
}

step_plugins() {
    say "Installing hyprpm plugins (this compiles them)"
    if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        echo "   run this step from inside a Hyprland session" >&2
        return 1
    fi
    hyprpm update
    local pair name url
    for pair in "${PLUGINS[@]}"; do
        name=${pair%%:*} url=${pair#*:}
        case $(plugin_state "$name") in
            ok) echo "   ok       $name" ;;
            failed)
                # A failed build stays registered; add again from scratch.
                echo "   rebuild  $name (its last build failed)"
                hyprpm remove "$name"
                hyprpm add "$url"
                ;;
            missing) hyprpm add "$url" ;;
        esac
        hyprpm enable "$name"
    done
    hyprpm reload
}

# Pull the repo, then hand over to the installer as pulled (it may have
# changed): it runs what the changed files need.
step_update() {
    say "Updating hyprmonk"
    if [[ -n $(git -C "$REPO" status --porcelain) ]]; then
        echo "   the repo has changes of its own; commit or stash them first" >&2
        return 1
    fi
    local before
    before=$(git -C "$REPO" rev-parse HEAD)
    git -C "$REPO" pull --ff-only
    if [[ $(git -C "$REPO" rev-parse HEAD) == "$before" ]]; then
        echo "   already up to date"
        return
    fi
    exec "$REPO/install.sh" --updated-from "$before"
}

# The steps the changes since a commit need, in Install's order; the shell
# restarts when its code changed.
updated_from() {
    local changed step wanted=()
    changed=$(git -C "$REPO" diff --name-only "$1" HEAD)
    echo "$changed" | sed 's/^/   changed  /'
    want() { [[ " ${wanted[*]} " == *" $1 "* ]] || wanted+=("$1"); }
    while IFS= read -r file; do
        case $file in
            packages/pacman.txt) want packages ;;
            packages/aur.txt) want aur ;;
            packages/apps.txt) want apps ;;
            install.sh) want link; want defaults; want services; want system; want login ;;
            config/systemd/user/*) want link; want services ;;
            crates/* | Cargo.*) want bin ;;
            udev/*) [[ -e /etc/udev/rules.d/70-hyprmonk.rules ]] && want udev ;;
        esac
    done <<< "$changed"
    for step in "${INSTALL_STEPS[@]}" udev; do
        [[ " ${wanted[*]} " == *" $step "* ]] && "step_$step"
    done
    if echo "$changed" | grep -q '^config/quickshell/' && systemctl --user is-active --quiet hyprmonk-shell.service; then
        systemctl --user restart hyprmonk-shell.service
        echo "   restarted the shell"
    fi
    say "Updated to $(git -C "$REPO" log -1 --format='%h %s' | cut -c1-70)"
}

# Undo link and services: links into this repo go, the newest *.bak-DATE
# copy of each comes back. What stays is listed at the end.
step_uninstall() {
    say "Uninstalling hyprmonk's configs"
    local pair target backup unit
    for unit in $(units); do
        systemctl --user disable "$unit" || true
    done
    for pair in "${LINKS[@]}" "config/zsh/zshrc:.zshrc" $(units | sed "s|.*|$UNITS_DIR/&:.config/systemd/user/&|"); do
        target="$HOME/${pair#*:}"
        [[ -L $target && $(readlink "$target") == "$REPO/${pair%%:*}" ]] || continue
        rm "$target"
        backup=$(compgen -G "$target.bak-*" | sort | tail -1 || true)
        if [[ -n $backup ]]; then
            mv "$backup" "$target"
            echo "   restored ~/${pair#*:} (from ${backup##*/})"
        else
            echo "   removed  ~/${pair#*:}"
        fi
    done
    if [[ -x $HOME/.local/bin/hyprmonk ]] && command -v cargo > /dev/null; then
        cargo uninstall --root "$HOME/.local" hyprmonk
    fi
    systemctl --user daemon-reload
    cat <<EOF
   Left as they are (the shell stops at the next login):
     packages            pacman -Rns what you no longer want
     the login screen    sudo systemctl disable sddm, then enable the one before
     zsh as login shell  chsh -s /bin/bash
     wallpapers, cursor  ~/Pictures/Wallpapers, ~/.local/share/icons/$CURSOR_THEME
     state and picks     ~/.local/state/hyprmonk, ~/.config/hyprmonk
EOF
}

# The menu, in Noir's colours (the shell's tone is not running yet).
ACCENT="#f25623" TEXT="#ccd0cf" MUTED="#848685" BACKGROUND="#171717"
export GUM_CHOOSE_CURSOR_FOREGROUND=$ACCENT GUM_CHOOSE_SELECTED_FOREGROUND=$ACCENT
export GUM_CHOOSE_HEADER_FOREGROUND=$MUTED GUM_CHOOSE_ITEM_FOREGROUND=$TEXT
export GUM_CONFIRM_PROMPT_FOREGROUND=$TEXT
export GUM_CONFIRM_SELECTED_BACKGROUND=$ACCENT GUM_CONFIRM_SELECTED_FOREGROUND=$BACKGROUND
export GUM_CONFIRM_UNSELECTED_BACKGROUND="#2a2a2a" GUM_CONFIRM_UNSELECTED_FOREGROUND=$TEXT

ensure_gum() {
    command -v gum > /dev/null && return
    say "The menu needs gum; installing it (sudo)"
    sudo pacman -S --needed gum
}

# The apps checklist, ticked as last saved (all the first time); saved to
# $APPS_PICKED. Apps unticked later stay installed.
pick_apps() {
    local picks
    picks=$(app_names | gum choose --no-limit --height 20 \
        --header "Apps to install (space ticks, enter goes on); the rest of the desktop always comes" \
        --selected="$(picked_apps | paste -sd, -)") || return 1
    mkdir -p "$(dirname "$APPS_PICKED")"
    printf '%s\n' "$picks" | sed '/^$/d' > "$APPS_PICKED"
}

menu() {
    ensure_gum
    gum style --border rounded --border-foreground "$ACCENT" --foreground "$TEXT" --padding "0 2" --margin "1 0" \
        "hyprmonk" "$(gum style --foreground "$MUTED" "Hyprland and a Quickshell desktop, from $REPO")"
    local action steps
    action=$(gum choose --header "What to do?" Install Update Check Uninstall Quit) || return 0
    case $action in
        Install)
            pick_apps || return 0
            steps=("${INSTALL_STEPS[@]}")
            [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && steps+=(plugins)
            gum style --foreground "$MUTED" "Steps: ${steps[*]}" "sudo asks your password for packages and services; chsh for zsh."
            gum confirm "Install?" || return 0
            run_steps "${steps[@]}"
            [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && say "Reboot, log in to Hyprland, then run ./install.sh plugins"
            ;;
        Update) step_update ;;
        Check) step_check ;;
        Uninstall)
            gum confirm --default=false "Remove hyprmonk's links and units, putting back what they replaced?" || return 0
            step_uninstall
            ;;
        Quit) ;;
    esac
}

run_steps() {
    local step
    for step in "$@"; do
        case $step in
            install) run_steps "${INSTALL_STEPS[@]}" ;;
            check | update | uninstall | packages | aur | apps | link | folders | defaults | cursor | wallpapers | bin | services | system | shell | udev | login | plugins) "step_$step" ;;
            -h | --help | help) usage ;;
            *)
                usage >&2
                exit 2
                ;;
        esac
    done
}

# Run as `curl ... | bash`: get git and the repo (kept, the configs link into
# it), then the installer from there, its keys from the terminal rather than
# the pipe.
bootstrap() {
    if ! command -v git > /dev/null; then
        say "Installing git (sudo)"
        sudo pacman -S --needed git
    fi
    if [[ -f $CLONE/packages/pacman.txt ]]; then
        say "Using the clone in $CLONE"
    else
        say "Cloning hyprmonk into $CLONE"
        git clone https://github.com/leandrop-dev/hyprmonk.git "$CLONE"
    fi
    if [[ -t 1 ]]; then
        exec "$CLONE/install.sh" "$@" < /dev/tty
    fi
    exec "$CLONE/install.sh" "$@"
}

main() {
    if [[ ! -f $REPO/packages/pacman.txt ]]; then
        bootstrap "$@"
    elif [[ ${1:-} == --updated-from ]]; then
        updated_from "$2"
    elif [[ $# -gt 0 ]]; then
        run_steps "$@"
    elif [[ -t 0 && -t 1 ]]; then
        menu
    else
        run_steps "${INSTALL_STEPS[@]}"
    fi
}

main "$@"
