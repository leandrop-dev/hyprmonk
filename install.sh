#!/usr/bin/env bash
# hyprmonk installer. The repo stays the source of truth: configs are
# symlinked into ~/.config, so editing either side edits both.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
usage: install.sh [step...]

With no step: packages aur link folders apps cursor wallpapers bin services login.

steps:
  check      list packages from packages/pacman.txt and aur.txt that are not installed
  packages   install the missing ones from pacman.txt (uses sudo)
  aur        install the missing ones from aur.txt with paru (uses sudo; gets paru first)
  link       symlink the configs into ~/.config (existing ones are moved to *.bak-DATE)
  folders    create ~/Pictures/Wallpapers, where the wallpaper picker looks
  apps       open folders in Nautilus and images in Loupe (xdg-open)
  cursor     download the cursor theme (Bibata) to ~/.local/share/icons
  wallpapers download the cosmic-noir wallpapers, and pick one if none is set
  bin        build hyprmonk and install it to ~/.local/bin
  services   enable the systemd user units (they only start under Hyprland)
  udev       install the udev rule for device batteries (uses sudo)
  login      the login screen: SDDM with sddm-astronaut-theme, enabled in place of
             the current display manager (uses sudo; from the next boot); its
             look is picked in quick actions
  plugins    install and enable the hyprpm plugins (compiles; run inside Hyprland)
EOF
}

say() { printf '\033[1m::\033[0m %s\n' "$*"; }

# repo path -> target, relative to the repo and $HOME
LINKS=(
    "config/hypr:.config/hypr"
    "config/quickshell/hyprmonk:.config/quickshell/hyprmonk"
    "config/matugen:.config/matugen"
    "config/kitty:.config/kitty"
    "config/uwsm:.config/uwsm"
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

step_check() {
    say "Checking packages"
    local list missing step
    for list in pacman.txt aur.txt; do
        missing=$(missing_packages "$list")
        step=$([[ $list == aur.txt ]] && echo aur || echo packages)
        if [[ -z $missing ]]; then
            echo "   $list: everything is installed"
        else
            echo "   $list: missing $(echo $missing)"
            echo "   install them: ./install.sh $step"
        fi
    done
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

step_folders() {
    say "Creating folders"
    command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update
    mkdir -p "$HOME/Pictures/Wallpapers"
    echo "   ok       ~/Pictures/Wallpapers"
}

# What xdg-open starts. Without it a folder opens in kitty: kitty-open.desktop
# claims folders too, and sorts first.
APPS=(
    "org.gnome.Nautilus.desktop:inode/directory"
    "org.gnome.Loupe.desktop:image/png image/jpeg image/webp image/gif image/bmp image/tiff image/svg+xml"
)

step_apps() {
    say "Setting default apps"
    local pair app
    for pair in "${APPS[@]}"; do
        app=${pair%%:*}
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
}

step_bin() {
    say "Building hyprmonk"
    # A fresh rustup has no toolchain, and cargo refuses to run without one.
    if ! rustup default >/dev/null 2>&1; then
        rustup default stable
    fi
    cargo install --locked --path "$REPO/crates/hyprmonk" --root "$HOME/.local"
}

step_services() {
    say "Enabling user services"
    systemctl --user daemon-reload
    systemctl --user enable $(units)
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

main() {
    local steps=("$@")
    [[ ${#steps[@]} -eq 0 ]] && steps=(packages aur link folders apps cursor wallpapers bin services login)
    local step
    for step in "${steps[@]}"; do
        case $step in
            check | packages | aur | link | folders | apps | cursor | wallpapers | bin | services | udev | login | plugins) "step_$step" ;;
            -h | --help | help) usage ;;
            *)
                usage >&2
                exit 2
                ;;
        esac
    done
}

main "$@"
