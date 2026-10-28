#!/usr/bin/env bash
# hyprmonk installer. The repo stays the source of truth: configs are
# symlinked into ~/.config, so editing either side edits both.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
usage: install.sh [step...]

With no step: check link bin services.

steps:
  check     list packages from packages/pacman.txt that are not installed
  link      symlink the configs into ~/.config (existing ones are moved to *.bak-DATE)
  bin       build hyprmonk and install it to ~/.local/bin
  services  enable the systemd user units (they only start under Hyprland)
  udev      install the udev rule for device batteries (uses sudo)
  plugins   install and enable the hyprpm plugins (compiles; run inside Hyprland)
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

step_check() {
    say "Checking packages"
    local wanted missing
    wanted=$(sed -e 's/#.*//' -e '/^\s*$/d' "$REPO/packages/pacman.txt")
    missing=$(pacman -T $wanted || true)
    if [[ -z $missing ]]; then
        echo "   everything is installed"
    else
        echo "   missing: $(echo $missing)"
        echo "   sudo pacman -S --needed $(echo $missing)"
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
    "hyprglass:https://github.com/hyprnux/hyprglass"
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
    [[ ${#steps[@]} -eq 0 ]] && steps=(check link bin services)
    local step
    for step in "${steps[@]}"; do
        case $step in
            check | link | bin | services | udev | plugins) "step_$step" ;;
            -h | --help | help) usage ;;
            *)
                usage >&2
                exit 2
                ;;
        esac
    done
}

main "$@"
