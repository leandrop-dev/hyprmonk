// The saved Appearance tone outside the shell: GTK and Qt apps (theme,
// colours and icons), Hyprland's window borders, kitty and the login
// screen's Desktop look. A tone with its own accent
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
import qs.services

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

    // Qt apps (qt6ct, QT_QPA_PLATFORMTHEME in uwsm/env): a KDE colour scheme,
    // theme/qt-HASH.colors, which qt6ct-kde hands KDE apps in place of
    // Plasma's kdeglobals. From the tone's own colours, or else the
    // wallpaper's.
    readonly property var qtPalette: {
        const w = Theme.wallpaperColours;
        if (saved.accent) return {
            window: saved.background, view: Qt.darker(saved.background, 1.3), button: mix(0.09),
            header: mix(0.05), tooltip: mix(0.09), alternate: mix(0.03), text: saved.foreground, muted: mix(0.6),
            accent: saved.accent, accentText: saved.background, negative: Theme.warning,
            positive: saved.positive ?? Theme.positive
        };
        return {
            window: w.surface, view: w.surfaceLowest, button: w.surfaceHigh, header: w.surfaceContainer,
            tooltip: w.surfaceHighest, alternate: w.surfaceLow, text: w.surfaceText, muted: w.surfaceMuted,
            accent: w.accent, accentText: w.surface, negative: w.error, positive: Theme.positive
        };
    }

    readonly property string qtColours: {
        const p = qtPalette;
        const rgb = c => {
            const q = Qt.color(c);
            return [q.r, q.g, q.b].map(v => Math.round(v * 255)).join(",");
        };
        const neutral = "#e5a50a";  // warnings: no tone has its own yet
        // One colour set: its background, a second one for alternate rows,
        // its text; the rest the same for every set.
        const set = (name, bg, alternate, fg, muted) => [
            `[Colors:${name}]`,
            `BackgroundNormal=${rgb(bg)}`,
            `BackgroundAlternate=${rgb(alternate)}`,
            `ForegroundNormal=${rgb(fg)}`,
            `ForegroundInactive=${rgb(muted ?? p.muted)}`,
            `ForegroundActive=${rgb(p.accent)}`,
            `ForegroundLink=${rgb(p.accent)}`,
            `ForegroundVisited=${rgb(p.muted)}`,
            `ForegroundNegative=${rgb(p.negative)}`,
            `ForegroundNeutral=${rgb(neutral)}`,
            `ForegroundPositive=${rgb(p.positive)}`,
            `DecorationFocus=${rgb(p.accent)}`,
            `DecorationHover=${rgb(p.accent)}`,
            ""
        ].join("\n");
        return [
            "# Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit.",
            "[General]", "ColorScheme=hyprmonk", "Name=hyprmonk", "",
            set("Window", p.window, p.alternate, p.text),
            set("View", p.view, p.alternate, p.text),
            set("Button", p.button, p.window, p.text),
            set("Selection", p.accent, Qt.darker(p.accent, 1.2), p.accentText, p.accentText),
            set("Tooltip", p.tooltip, p.window, p.text),
            set("Complementary", p.view, p.window, p.text),
            set("Header", p.header, p.window, p.text),
            set("Header][Inactive", p.window, p.window, p.text),
            "[WM]",
            `activeBackground=${rgb(p.header)}`, `activeForeground=${rgb(p.text)}`, `activeBlend=${rgb(p.text)}`,
            `inactiveBackground=${rgb(p.window)}`, `inactiveForeground=${rgb(p.muted)}`, `inactiveBlend=${rgb(p.muted)}`,
            ""
        ].join("\n");
    }

    // Named after its colours: KDE apps keep a colour scheme they read by
    // its path, so new colours need a new path.
    readonly property string qtColoursPath: {
        let hash = 5381;
        for (let i = 0; i < qtColours.length; i++) hash = (hash * 33 + qtColours.charCodeAt(i)) >>> 0;
        return `${dir}/qt-${hash.toString(16)}.colors`;
    }

    // qt6ct's settings: Breeze, the colours above, the tone's icons, the
    // fonts GTK apps have. Running Qt apps read it again 3 s after it
    // changes, so it is written after the colours.
    readonly property string qtConfig: {
        return [
            "# Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit.",
            "[Appearance]",
            `color_scheme_path=${qtColoursPath}`,
            "custom_palette=true",
            `icon_theme=${iconTheme}`,
            "standard_dialogs=default",
            "style=Breeze",
            "",
            "[Fonts]",
            "fixed=\"JetBrainsMono Nerd Font,10\"",
            "general=\"Noto Sans,10\"",
            ""
        ].join("\n");
    }

    // The login screen's Desktop look (services/Login.qml): the astronaut
    // look's settings with the wallpaper, blurred all over and a little
    // darker as on the lock screen, the shell's font and the colours above.
    // A copy of the wallpaper goes with it: SDDM cannot read the home
    // folder. Nothing until `install.sh login` has made the folder (a save
    // that fails keeps its text as the file's, so a later one would not
    // write); then written, once Login has seen it (again as quick actions
    // open).
    readonly property bool loginReady: Login.ready
    readonly property string wallpaper: Wallpaper.path
    readonly property string loginWallpaper: wallpaper ? `${Login.dir}/wallpaper.${wallpaper.split(".").pop().toLowerCase()}` : ""
    property string loginTemplate: ""

    readonly property string login: {
        if (!loginTemplate) return "";
        const p = qtPalette;
        const c = value => Qt.color(value).toString();
        const settings = {
            Font: Theme.font,
            Background: loginWallpaper,
            DimBackground: "0.12",
            DimBackgroundColor: c(p.view),
            PartialBlur: "false",
            FullBlur: "true",
            Blur: "1.0",
            BlurMax: "48",
            HaveFormBackground: "false",
            HeaderTextColor: c(p.text),
            DateTextColor: c(p.text),
            TimeTextColor: c(p.text),
            FormBackgroundColor: c(p.window),
            BackgroundColor: c(p.window),
            LoginFieldBackgroundColor: c(p.window),
            PasswordFieldBackgroundColor: c(p.window),
            LoginFieldTextColor: c(p.text),
            PasswordFieldTextColor: c(p.text),
            UserIconColor: c(p.text),
            PasswordIconColor: c(p.text),
            PlaceholderTextColor: c(p.muted),
            WarningColor: c(p.negative),
            LoginButtonTextColor: c(p.text),
            LoginButtonBackgroundColor: c(p.accent),
            SystemButtonsIconsColor: c(p.text),
            SessionButtonTextColor: c(p.text),
            VirtualKeyboardButtonTextColor: c(p.text),
            DropdownTextColor: c(p.text),
            DropdownSelectedBackgroundColor: c(p.button),
            DropdownBackgroundColor: c(p.window),
            HighlightTextColor: c(p.accentText),
            HighlightBackgroundColor: c(p.accent),
            HighlightBorderColor: c(p.accent),
            HoverUserIconColor: c(p.accent),
            HoverPasswordIconColor: c(p.accent),
            HoverSystemButtonsIconsColor: c(p.accent),
            HoverSessionButtonTextColor: c(p.accent),
            HoverVirtualKeyboardButtonTextColor: c(p.accent)
        };
        const lines = loginTemplate.split("\n").map(line => {
            const key = line.split("=")[0];
            return line.includes("=") && key in settings ? `${key}="${settings[key]}"` : line;
        });
        return "# Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit.\n" + lines.join("\n");
    }

    onIconThemeChanged: apply.restart()
    onHyprlandChanged: apply.restart()
    onKittyChanged: apply.restart()
    onGtkChanged: apply.restart()
    onQtConfigChanged: apply.restart()
    onLoginChanged: apply.restart()
    onLoginReadyChanged: apply.restart()
    onWallpaperChanged: apply.restart()

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
        command: ["mkdir", "-p", root.dir, root.config + "/gtk-3.0", root.config + "/gtk-4.0", root.config + "/qt6ct"]
        onExited: {
            gsettings.running = true;
            kdeglobals.running = true;
            tone.write();
            kittyTone.write();
            gtkTone.write();
            gtk3.write();
            gtk4.write();
            if (!qtColoursFile.write()) qtConfigFile.write();
            if (root.login && root.loginReady) loginLook.write();
            if (root.wallpaper) loginPicture.running = true;
        }
    }

    component Output: FileView {
        property string content
        printErrors: false

        // Whether it had to be written.
        function write(): bool {
            if (text() === content) return false;
            setText(content);
            return true;
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

    Output {
        id: qtColoursFile
        path: root.qtColoursPath
        content: root.qtColours
        onSaved: qtConfigFile.write()
    }

    // What running Qt apps watch: after the colours.
    Output {
        id: qtConfigFile
        path: root.config + "/qt6ct/qt6ct.conf"
        content: root.qtConfig
        onSaved: qtColoursOld.running = true
    }

    FileView {
        path: Login.theme + "/Themes/astronaut.conf"
        printErrors: false
        onLoaded: root.loginTemplate = text()
    }

    Output {
        id: loginLook
        path: Login.dir + "/desktop.conf"
        content: root.login
    }

    // Only when it differs; the copies of other pictures (another type)
    // go.
    Process {
        id: loginPicture
        command: ["sh", "-c", '[ -d "$2" ] || exit 0; cmp -s "$1" "$3" && exit 0; rm -f "$2"/wallpaper.*; cp "$1" "$3"',
            "sh", root.wallpaper, Login.dir, root.loginWallpaper]
    }

    // Earlier colours, once no setting names them.
    Process {
        id: qtColoursOld
        command: ["find", root.dir, "-maxdepth", "1", "-name", "qt*.colors", "!", "-path", root.qtColoursPath, "-delete"]
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

    // KDE apps (KIconTheme::initTheme, KStyleManager) take their icons and
    // style from kdeglobals, not from qt6ct, unless Plasma's platform theme
    // runs; Plasma's own choices there are replaced. Read as they start.
    Process {
        id: kdeglobals
        command: ["sh", "-c", 'kwriteconfig6 --file kdeglobals --group Icons --key Theme "$1" && kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze',
            "sh", root.iconTheme]
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
