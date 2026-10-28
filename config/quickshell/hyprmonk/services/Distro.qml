// The running system's logo (a Nerd Font glyph), from /etc/os-release: its
// ID, else the first ID_LIKE known here (an Arch derivative without a logo of
// its own gets Arch's), else Tux.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var logos: ({
        "arch": "\u{F303}",
        "cachyos": "\u{F385}",
        "endeavouros": "\u{F322}",
        "manjaro": "\u{F312}",
        "garuda": "\u{F337}",
        "artix": "\u{F31F}",
        "archcraft": "\u{F345}",
        "arcolinux": "\u{F346}",
        "debian": "\u{F306}",
        "ubuntu": "\u{F31B}",
        "linuxmint": "\u{F30E}",
        "pop": "\u{F32A}",
        "elementary": "\u{F309}",
        "zorin": "\u{F32F}",
        "kali": "\u{F327}",
        "mx": "\u{F33F}",
        "deepin": "\u{F321}",
        "fedora": "\u{F30A}",
        "nobara": "\u{F380}",
        "rhel": "\u{F316}",
        "centos": "\u{F304}",
        "almalinux": "\u{F31D}",
        "rocky": "\u{F32B}",
        "opensuse-tumbleweed": "\u{F37D}",
        "opensuse-leap": "\u{F37E}",
        "opensuse": "\u{F314}",
        "suse": "\u{F314}",
        "gentoo": "\u{F30D}",
        "nixos": "\u{F313}",
        "void": "\u{F32E}",
        "alpine": "\u{F300}",
        "slackware": "\u{F318}",
        "mageia": "\u{F310}",
        "solus": "\u{F32D}",
        "freebsd": "\u{F30C}",
        "openbsd": "\u{F328}"
    })
    readonly property string tux: "\u{F31A}"

    property string logo: tux

    FileView {
        path: "/etc/os-release"
        onLoaded: {
            const fields = {};
            for (const line of text().split("\n")) {
                const pair = line.match(/^([A-Z_]+)=(.*)$/);
                if (pair) fields[pair[1]] = pair[2].replace(/^["']|["']$/g, "");
            }
            const ids = [fields.ID ?? "", ...(fields.ID_LIKE ?? "").split(/\s+/)];
            root.logo = root.logos[ids.find(id => root.logos[id] !== undefined)] ?? root.tux;
        }
    }
}
