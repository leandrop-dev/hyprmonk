#!/usr/bin/env bash
# hyprmonk installer. The repo stays the source of truth: configs are
# symlinked into ~/.config, so editing either side edits both.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
usage: install.sh [step...]

With no step: packages link folders cursor icons wallpapers bin services.

steps:
  check      list packages from packages/pacman.txt that are not installed
  packages   install the missing ones (uses sudo)
  link       symlink the configs into ~/.config (existing ones are moved to *.bak-DATE)
  folders    create ~/Pictures/Wallpapers, where the wallpaper picker looks
  cursor     download the cursor theme (Bibata) to ~/.local/share/icons
  icons      download the icon themes (Cosmic-Noir) to ~/.local/share/icons
  wallpapers download the cosmic-noir wallpapers, and pick one if none is set
  bin        build hyprmonk and install it to ~/.local/bin
  services   enable the systemd user units (they only start under Hyprland)
  udev       install the udev rule for device batteries (uses sudo)
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

wanted_packages() {
    sed -e 's/#.*//' -e '/^\s*$/d' "$REPO/packages/pacman.txt"
}

missing_packages() {
    pacman -T $(wanted_packages) || true
}

step_check() {
    say "Checking packages"
    local missing
    missing=$(missing_packages)
    if [[ -z $missing ]]; then
        echo "   everything is installed"
    else
        echo "   missing: $(echo $missing)"
        echo "   install them: ./install.sh packages"
    fi
}

step_packages() {
    say "Installing packages (sudo)"
    local missing
    missing=$(missing_packages)
    if [[ -z $missing ]]; then
        echo "   everything is installed"
        return
    fi
    sudo pacman -S --needed $missing
}

step_folders() {
    say "Creating folders"
    command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update
    mkdir -p "$HOME/Pictures/Wallpapers"
    echo "   ok       ~/Pictures/Wallpapers"
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

# The icons: Cosmic-Noir from cosmic-icon-themes (GPL-3.0, from the Kanagawa
# pack), not in the official repos, so its release archives, pinned by
# checksum. All three folder colours: Dark for most tones, Orange (#f25623)
# for Noir, Sage kept to pick.
ICONS_URL="https://github.com/atraxsrc/cosmic-icon-themes/releases/download/v1.2.0"
ICONS=(
    "Cosmic-Noir-Dark:63471526d117c06fbdb1d23af4f93d47015a56e6cb49731123b201bb2edde52b"
    "Cosmic-Noir-Orange:12195bc0ed208d6f791113592aa774e2fe13f4a453798cc685c24fe5f217f077"
    "Cosmic-Noir-Sage:cbe2973f4db31cd16126a5ebdacda194bbb1de932ff23d5e51d31f35134eecd8"
)

step_icons() {
    say "Installing the icons (Cosmic-Noir)"
    local icons="$HOME/.local/share/icons" entry name sha archive
    mkdir -p "$icons"
    for entry in "${ICONS[@]}"; do
        name=${entry%%:*}
        sha=${entry#*:}
        if [[ -f $icons/$name/index.theme ]]; then
            echo "   ok       ~/.local/share/icons/$name"
            continue
        fi
        archive=$(mktemp --suffix=.tar.xz)
        curl -fsSL -o "$archive" "$ICONS_URL/$name.tar.xz"
        if ! echo "$sha  $archive" | sha256sum --check --quiet -; then
            rm -f "$archive"
            echo "   $name does not match its checksum; not installed" >&2
            return 1
        fi
        tar -xf "$archive" -C "$icons"
        rm -f "$archive"
        echo "   installed ~/.local/share/icons/$name"
    done
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
    [[ ${#steps[@]} -eq 0 ]] && steps=(packages link folders cursor icons wallpapers bin services)
    local step
    for step in "${steps[@]}"; do
        case $step in
            check | packages | link | folders | cursor | icons | wallpapers | bin | services | udev | plugins) "step_$step" ;;
            -h | --help | help) usage ;;
            *)
                usage >&2
                exit 2
                ;;
        esac
    done
}

main "$@"
