// The saved Appearance tone outside the shell: GTK apps (theme, colours and
// icons), Hyprland's window borders and kitty. A tone with its own accent
// writes its colours over the wallpaper's (which matugen writes); one without
// writes nothing over them. Only the saved tone counts, so a preview does not
// repaint every app.
//
// Each file is written only when its text changes, and each program reloads
// only then: a start of the shell changes nothing.
//
// IPC: qs -c hyprmonk ipc call gtk reload  (matugen, after gtk-colors.css)
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Scope {
    id: root

    readonly property var saved: Theme.tones[Theme.savedTone] ?? Theme.tones.noir
    readonly property string dir: Theme.stateDir + "/theme"
    readonly property string config: Quickshell.env("HOME") + "/.config"

    function hex(c: color): string {
        return c.toString();
    }

    // The tone's foreground over its background, at an opacity: its greys.
    function mix(alpha: real): string {
        return hex(Qt.tint(saved.background, Qt.alpha(saved.foreground, alpha)));
    }

    // Icons: Yaru (from the AUR), in the colour a tone names (`icons`, "" for
    // Yaru's own orange) or else the one nearest in hue to the accent; a dark
    // tone takes the -dark variant. The shell's own icons are QS_ICON_THEME
    // (uwsm/env), read once at its start.
    readonly property string iconTheme: {
        const name = "icons" in saved ? saved.icons : yaruNearest(saved.accent ?? Theme.wallpaperAccent);
        return "Yaru" + (name ? "-" + name : "") + (saved.light ? "" : "-dark");
    }

    // A greyish accent takes a muted colour (wartybrown when warm, sage when
    // cool); the others the closest hue, around the circle. Hues sampled from
    // each colour's folder.
    readonly property var yaruHues: ({ "": 17, red: 350, yellow: 38, olive: 85, prussiangreen: 179, blue: 210, purple: 250, magenta: 299 })

    function yaruNearest(accent: color): string {
        const hue = Math.max(0, accent.hslHue) * 360;
        if (accent.hslSaturation < 0.25) return hue < 70 || hue > 330 ? "wartybrown" : "sage";
        let best = "", distance = 360;
        for (const name in yaruHues) {
            const apart = Math.abs(hue - yaruHues[name]);
            const around = Math.min(apart, 360 - apart);
            if (around < distance) {
                best = name;
                distance = around;
            }
        }
        return best;
    }

    // Hyprland's window borders (theme/tone.lua, loaded after matugen's
    // colors.lua).
    readonly property string hyprland: "-- Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit.\n"
        + (saved.accent ? `theme.accent = "rgba(${hex(saved.accent).slice(1)}ee)"\n` : "")

    // kitty's text, background, cursor and selection (theme/kitty-tone.conf,
    // after matugen's in kitty.conf). Its 16 colours do not change.
    readonly property string kitty: {
        const lines = ["# Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit."];
        if (saved.accent) {
            const colours = {
                foreground: hex(saved.foreground),
                background: hex(saved.background),
                selection_foreground: hex(saved.background),
                selection_background: hex(saved.accent),
                cursor: hex(saved.accent),
                cursor_text_color: hex(saved.background),
                url_color: hex(saved.positive ?? saved.accent),
                active_border_color: hex(saved.accent),
                inactive_border_color: mix(0.25),
                active_tab_foreground: hex(saved.background),
                active_tab_background: hex(saved.accent),
                inactive_tab_foreground: mix(0.6),
                inactive_tab_background: mix(0.06)
            };
            for (const name in colours) lines.push(name.padEnd(24) + colours[name]);
        }
        return lines.join("\n") + "\n";
    }

    // GTK's named colours (theme/gtk-tone.css, after matugen's
    // gtk-colors.css). Content darker than the window, bars and sidebars a
    // step lighter, cards and pop-ups lighter still, as libadwaita has them.
    readonly property string gtk: {
        const lines = ["/* Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit. */"];
        if (saved.accent) {
            const fg = hex(saved.foreground);
            const colours = {
                window_bg_color: hex(saved.background),
                window_fg_color: fg,
                view_bg_color: hex(Qt.darker(saved.background, 1.3)),
                view_fg_color: fg,
                headerbar_bg_color: mix(0.05),
                headerbar_fg_color: fg,
                headerbar_backdrop_color: mix(0.05),
                sidebar_bg_color: mix(0.05),
                sidebar_fg_color: fg,
                sidebar_backdrop_color: mix(0.05),
                card_bg_color: mix(0.06),
                card_fg_color: fg,
                popover_bg_color: mix(0.09),
                popover_fg_color: fg,
                dialog_bg_color: mix(0.09),
                dialog_fg_color: fg,
                accent_bg_color: hex(saved.accent),
                accent_fg_color: hex(saved.background),
                success_bg_color: hex(saved.positive ?? Theme.positive),
                destructive_bg_color: hex(Theme.warning),
                error_bg_color: hex(Theme.warning)
            };
            for (const name in colours) lines.push(`@define-color ${name} ${colours[name]};`);
        }
        return lines.join("\n") + "\n";
    }

    // ~/.config/gtk-{3,4}.0/gtk.css: the wallpaper's colours, then the
    // tone's. Real files, not links into the repo: Plasma writes its own
    // there in a Plasma session (through a link it would write into the
    // repo), and the shell writes these back in Hyprland. GTK4's libadwaita
    // reads CSS variables, named after the same colours.
    readonly property string gtkImports: "/* Written by hyprmonk's shell while Hyprland runs; Plasma writes its own. Do not edit. */\n"
        + `@import url("file://${dir}/gtk-colors.css");\n`
        + `@import url("file://${dir}/gtk-tone.css");\n`
    readonly property var libadwaitaColours: [
        "window-bg", "window-fg", "view-bg", "view-fg", "headerbar-bg", "headerbar-fg",
        "headerbar-backdrop", "sidebar-bg", "sidebar-fg", "sidebar-backdrop", "card-bg", "card-fg",
        "popover-bg", "popover-fg", "dialog-bg", "dialog-fg", "accent-bg", "accent-fg",
        "success-bg", "destructive-bg", "destructive-fg", "error-bg", "error-fg"
    ]
    readonly property string gtk4: gtkImports + "\n:root {\n"
        + libadwaitaColours.map(name => `  --${name}-color: @${name.replace(/-/g, "_")}_color;`).join("\n")
        + "\n}\n"

    onIconThemeChanged: apply.restart()
    onHyprlandChanged: apply.restart()
    onKittyChanged: apply.restart()
    onGtkChanged: apply.restart()

    // Waits for the files to be read (and a burst of changes to settle).
    Timer {
        id: apply
        interval: 500
        running: true
        onTriggered: folders.running = true
    }

    // Written into folders a fresh install may not have yet.
    Process {
        id: folders
        command: ["mkdir", "-p", root.dir, root.config + "/gtk-3.0", root.config + "/gtk-4.0"]
        onExited: {
            gsettings.running = true;
            tone.write();
            kittyTone.write();
            gtkTone.write();
            gtk3.write();
            gtk4.write();
        }
    }

    component Output: FileView {
        property string content
        printErrors: false

        function write(): void {
            if (text() !== content) setText(content);
        }
    }

    Output {
        id: tone
        path: root.dir + "/tone.lua"
        content: root.hyprland
        onSaved: hyprReload.running = true
    }

    Output {
        id: kittyTone
        path: root.dir + "/kitty-tone.conf"
        content: root.kitty
        onSaved: kittyReload.running = true
    }

    Output {
        id: gtkTone
        path: root.dir + "/gtk-tone.css"
        content: root.gtk
        onSaved: gtkReload.restart()
    }

    Output {
        id: gtk3
        path: root.config + "/gtk-3.0/gtk.css"
        content: root.gtkImports
        onSaved: gtkReload.restart()
    }

    Output {
        id: gtk4
        path: root.config + "/gtk-4.0/gtk.css"
        content: root.gtk4
        onSaved: gtkReload.restart()
    }

    Process {
        id: hyprReload
        command: ["hyprctl", "reload", "config-only"]
    }

    // kitty reads its config again on USR1, as after matugen.
    Process {
        id: kittyReload
        command: ["pkill", "-USR1", "-x", "kitty"]
    }

    // The theme GTK draws with, light or dark, the icons, and the cursor
    // (named in uwsm/env; GTK 3 apps read it from here, not from there).
    Process {
        id: gsettings
        command: ["sh", "-c", 'i=org.gnome.desktop.interface; gsettings set $i gtk-theme "$1" && gsettings set $i color-scheme "$2" && gsettings set $i icon-theme "$3" && gsettings set $i cursor-theme "$4" && gsettings set $i cursor-size "$5"',
            "sh", root.saved.light ? "adw-gtk3" : "adw-gtk3-dark", root.saved.light ? "prefer-light" : "prefer-dark", root.iconTheme,
            Quickshell.env("XCURSOR_THEME") || "Adwaita", Quickshell.env("XCURSOR_SIZE") || "24"]
    }

    // Open GTK4 apps read their CSS again when light or dark changes: to the
    // other and back, with a pause they notice (without it the two changes
    // arrive as none); they may show the other for that moment. GTK3 apps
    // read it only as they start (Plasma has a GTK module for that), so they
    // take a new tone when opened again. Once for a burst of writes.
    Timer {
        id: gtkReload
        interval: 200
        onTriggered: gtkRefresh.running = true
    }

    Process {
        id: gtkRefresh
        command: ["sh", "-c", 'gsettings set org.gnome.desktop.interface color-scheme "$2" && sleep 0.15 && gsettings set org.gnome.desktop.interface color-scheme "$1"',
            "sh", root.saved.light ? "prefer-light" : "prefer-dark", root.saved.light ? "prefer-dark" : "default"]
    }

    IpcHandler {
        target: "gtk"

        function reload(): void {
            gtkReload.restart();
        }
    }
}
