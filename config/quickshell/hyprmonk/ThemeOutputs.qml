// The saved Appearance tone outside the shell: GTK and Qt apps (theme,
// colours and icons), Hyprland's window borders, kitty, zsh's prompt and
// highlighting, fastfetch, btop, Vesktop, Zed, Zen, Heroic, Steam's skin, and the
// login screen's Desktop look. A tone with its own accent
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
    // after matugen's in kitty.conf), and its 16 colours if the tone has them;
    // otherwise those stay noir.conf's.
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
            (saved.terminal ?? []).forEach((colour, index) => lines.push(`color${index}`.padEnd(24) + colour));
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

    // zsh (config/zsh/zshrc): starship's prompt, the repo's starship.toml
    // with the tone's palette added (the colours it names), and the
    // suggestion and highlight colours. Both read as a terminal opens.
    property string starshipTemplate: ""
    readonly property string starship: {
        if (!starshipTemplate) return "";
        const p = qtPalette;
        const c = value => Qt.color(value).toString();
        return "# Written by the shell (ThemeOutputs.qml) for the saved tone, from\n"
            + "# ~/.config/starship/starship.toml. Do not edit.\n"
            + starshipTemplate
            + `\n[palettes.hyprmonk]\naccent = "${c(p.accent)}"\ntext = "${c(p.text)}"\nmuted = "${c(p.muted)}"\n`
            + `positive = "${c(p.positive)}"\nwarning = "${c(p.negative)}"\n`;
    }

    readonly property string zsh: {
        const p = qtPalette;
        const c = value => Qt.color(value).toString();
        const styles = {
            command: c(p.accent), builtin: c(p.accent), alias: c(p.accent), function: c(p.accent),
            "precommand": c(p.accent), "unknown-token": c(p.negative), "reserved-word": c(p.muted),
            "single-quoted-argument": c(p.positive), "double-quoted-argument": c(p.positive),
            "dollar-quoted-argument": c(p.positive), comment: c(p.muted), default: c(p.text)
        };
        const lines = [
            "# Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit.",
            `ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=${c(p.muted)}'`
        ];
        for (const name in styles) lines.push(`ZSH_HIGHLIGHT_STYLES[${name}]='fg=${styles[name]}'`);
        // fastfetch's colours, for zshrc to pass it.
        lines.push("hyprmonk_fastfetch=("
            + `--color-keys '${c(p.accent)}' --color-title '${c(p.accent)}' --color-output '${c(p.text)}' `
            + `--color-separator '${c(p.muted)}' --logo-color-1 '${c(p.accent)}' --logo-color-2 '${c(p.text)}')`);
        return lines.join("\n") + "\n";
    }

    // btop's theme (~/.config/btop/themes), on the terminal's own background,
    // which follows the tone. Whatever measures how busy something is runs
    // from calm to the accent to the warning colour.
    readonly property string btop: {
        const p = qtPalette;
        const c = value => Qt.color(value).toString();
        const box = mix(0.25);
        const colours = {
            main_fg: c(p.text), title: c(p.text), hi_fg: c(p.accent), selected_bg: c(p.accent),
            selected_fg: c(p.accentText), inactive_fg: c(p.muted), graph_text: c(p.muted), meter_bg: c(p.button),
            proc_misc: c(p.accent), cpu_box: box, mem_box: box, net_box: box, proc_box: box, div_line: box
        };
        const lines = ["# Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit.", 'theme[main_bg]=""'];
        for (const name in colours) lines.push(`theme[${name}]="${colours[name]}"`);
        for (const name of ["temp", "cpu", "used", "process"]) {
            lines.push(`theme[${name}_start]="${c(p.positive)}"`, `theme[${name}_mid]="${c(p.accent)}"`,
                       `theme[${name}_end]="${c(p.negative)}"`);
        }
        for (const name of ["free", "cached", "available", "download", "upload"]) {
            lines.push(`theme[${name}_start]="${c(p.muted)}"`, `theme[${name}_mid]="${c(p.text)}"`,
                       `theme[${name}_end]="${c(p.accent)}"`);
        }
        return lines.join("\n") + "\n";
    }

    // Vesktop's Quick CSS, which it applies live and needs no setting for:
    // Discord's own colour names, the ones its code uses today, and little
    // else. It is written only over itself or nothing, so a file with CSS of
    // someone's own stays.
    readonly property string vesktopMark: "/* Written by the shell (ThemeOutputs.qml)"
    readonly property string vesktop: {
        const p = qtPalette;
        const c = value => Qt.color(value).toString();
        const colours = {
            "background-base-lowest": c(p.view), "background-base-lower": c(p.window),
            "background-base-low": c(p.window), "chat-background-default": c(p.window),
            "background-surface-high": c(p.button), "background-surface-higher": c(p.button),
            "background-surface-highest": c(p.tooltip), "card-background-default": c(p.alternate),
            "background-mod-subtle": mix(0.06), "background-mod-normal": mix(0.1), "background-mod-strong": mix(0.14),
            "border-subtle": mix(0.08), "border-normal": mix(0.14), "border-strong": mix(0.25), "border-focus": c(p.accent),
            "text-default": c(p.text), "text-strong": c(p.text), "text-muted": c(p.muted), "text-subtle": c(p.muted),
            "text-link": c(p.accent), "text-brand": c(p.accent), "text-danger": c(p.negative),
            "text-feedback-critical": c(p.negative), "brand-500": c(p.accent),
            "interactive-icon-default": c(p.muted), "interactive-icon-hover": c(p.text),
            "interactive-icon-active": c(p.text), "interactive-hover": c(p.text), "interactive-muted": mix(0.3),
            "channels-default": c(p.muted), "input-background-default": c(p.alternate), "input-border-default": mix(0.14),
            "control-primary-background-default": c(p.accent), "control-primary-background-hover": c(p.accent),
            "control-primary-border-default": c(p.accent), "control-primary-border-hover": c(p.accent),
            "control-primary-text-default": c(p.accentText), "control-primary-text-hover": c(p.accentText),
            "control-secondary-background-default": c(p.button), "control-secondary-background-hover": mix(0.14),
            "control-secondary-text-default": c(p.text), "control-secondary-text-hover": c(p.text),
            "status-positive": c(p.positive), "status-danger": c(p.negative)
        };
        const lines = [root.vesktopMark + " for the saved tone. Do not edit. */",
                       ".theme-dark, .theme-darker, .theme-midnight, .theme-light, .visual-refresh {"];
        for (const name in colours) lines.push(`    --${name}: ${colours[name]} !important;`);
        return lines.join("\n") + "\n}\n";
    }

    // Zed's theme (~/.config/zed/themes), named `hyprmonk` for every tone. A
    // tone's terminal colours colour the code; without them, its own few.
    readonly property string zed: {
        const p = qtPalette;
        const c = value => Qt.color(value).toString();
        const ansi = (index, otherwise) => c(saved.terminal?.[index] ?? otherwise);
        const syntax = {
            keyword: ansi(5, p.accent), function: ansi(4, p.accent), type: ansi(6, p.positive), string: ansi(2, p.positive),
            number: ansi(3, p.accent), boolean: ansi(3, p.accent), constant: ansi(3, p.accent), property: c(p.text),
            variable: c(p.text), operator: c(p.muted), punctuation: c(p.muted), comment: c(p.muted),
            "comment.doc": c(p.muted), attribute: ansi(6, p.positive), tag: ansi(4, p.accent), title: c(p.accent),
            link_uri: c(p.accent), link_text: c(p.accent), emphasis: c(p.accent), "emphasis.strong": c(p.accent)
        };
        const style = {
            background: c(p.window), "editor.background": c(p.window), "editor.gutter.background": c(p.window),
            "editor.foreground": c(p.text), "editor.line_number": mix(0.35), "editor.active_line_number": c(p.accent),
            "editor.active_line.background": mix(0.05), "editor.wrap_guide": mix(0.08), "editor.active_wrap_guide": mix(0.14),
            "editor.subheader.background": c(p.header), text: c(p.text), "text.muted": c(p.muted), "text.placeholder": c(p.muted),
            "text.disabled": mix(0.4), "text.accent": c(p.accent), icon: c(p.text), "icon.muted": c(p.muted),
            "icon.disabled": mix(0.4), "icon.accent": c(p.accent), border: mix(0.14), "border.variant": mix(0.08),
            "border.focused": c(p.accent), "border.selected": c(p.accent), "border.transparent": "#00000000",
            "border.disabled": mix(0.08), "surface.background": c(p.header), "elevated_surface.background": c(p.tooltip),
            "panel.background": c(p.header), "panel.focused_border": c(p.accent), "status_bar.background": c(p.header),
            "title_bar.background": c(p.header), "toolbar.background": c(p.window), "tab_bar.background": c(p.header),
            "tab.active_background": c(p.window), "tab.inactive_background": c(p.header), "scrollbar.thumb.background": mix(0.25),
            "scrollbar.track.background": "#00000000", "element.background": c(p.button), "element.hover": mix(0.1),
            "element.active": mix(0.14), "element.selected": mix(0.14), "element.disabled": mix(0.06),
            "ghost_element.background": "#00000000", "ghost_element.hover": mix(0.1), "ghost_element.active": mix(0.14),
            "ghost_element.selected": mix(0.14), "ghost_element.disabled": "#00000000", "drop_target.background": mix(0.14),
            "search.match_background": mix(0.25), created: c(p.positive), modified: c(p.accent), deleted: c(p.negative),
            conflict: c(p.negative), error: c(p.negative), warning: c(p.accent), info: c(p.accent), success: c(p.positive),
            hint: c(p.muted), hidden: c(p.muted), ignored: c(p.muted), "terminal.background": c(p.window),
            "terminal.foreground": c(p.text), "terminal.ansi.black": ansi(0, p.window), "terminal.ansi.red": ansi(1, p.negative),
            "terminal.ansi.green": ansi(2, p.positive), "terminal.ansi.yellow": ansi(3, p.accent),
            "terminal.ansi.blue": ansi(4, p.accent), "terminal.ansi.magenta": ansi(5, p.accent),
            "terminal.ansi.cyan": ansi(6, p.positive), "terminal.ansi.white": ansi(7, p.text),
            players: [{ cursor: c(p.accent), background: c(p.accent), selection: mix(0.2) }],
            syntax: {}
        };
        for (const name in syntax) style.syntax[name] = { color: syntax[name] };
        return JSON.stringify({
            "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
            name: "hyprmonk",
            author: "hyprmonk's shell (ThemeOutputs.qml). Do not edit.",
            themes: [{ name: "hyprmonk", appearance: saved.light ? "light" : "dark", style: style }]
        }, null, 2) + "\n";
    }

    // Zen's own colours and Firefox's beneath them, for its window and for its
    // about: pages. One file serves userChrome.css and userContent.css, so
    // each part names where it counts. Zen reads it as it starts.
    readonly property string zen: {
        const p = qtPalette;
        const c = value => Qt.color(value).toString();
        const window = {
            "zen-primary-color": c(p.accent), "zen-colors-primary": c(p.button), "zen-colors-secondary": mix(0.06),
            "zen-colors-tertiary": mix(0.04), "zen-colors-border": mix(0.14), "zen-dialog-background": c(p.tooltip),
            "zen-main-browser-background": c(p.window), "zen-main-browser-background-toolbar": c(p.window),
            "zen-main-browser-background-old": c(p.window), "zen-main-browser-background-toolbar-old": c(p.window),
            "zen-themed-toolbar-bg": c(p.window), "zen-themed-toolbar-bg-transparent": c(p.window),
            "zen-toolbar-element-bg": mix(0.1), "zen-toolbar-element-bg-hover": mix(0.14),
            "toolbar-bgcolor": c(p.window), "toolbar-color": c(p.text), "toolbarbutton-icon-fill": c(p.text),
            "toolbox-textcolor": c(p.text), "toolbox-textcolor-inactive": c(p.muted), "lwt-text-color": c(p.text),
            "sidebar-text-color": c(p.text), "tab-selected-bgcolor": mix(0.1), "tab-selected-textcolor": c(p.text),
            "toolbar-field-background-color": mix(0.06), "toolbar-field-color": c(p.text),
            "toolbar-field-focus-background-color": c(p.tooltip), "toolbar-field-focus-color": c(p.text),
            "urlbar-box-bgcolor": c(p.tooltip), "arrowpanel-background": c(p.tooltip), "arrowpanel-color": c(p.text),
            "arrowpanel-border-color": mix(0.14), "color-accent-primary": c(p.accent),
            "color-accent-primary-hover": c(p.accent), "color-accent-primary-active": c(p.accent)
        };
        const pages = {
            "zen-primary-color": c(p.accent), "zen-colors-primary": c(p.button), "zen-colors-secondary": mix(0.06),
            "zen-colors-tertiary": mix(0.04), "zen-colors-border": mix(0.14), "in-content-page-background": c(p.window),
            "in-content-page-color": c(p.text), "in-content-box-background": mix(0.06),
            "newtab-background-color": c(p.window), "newtab-background-color-secondary": mix(0.06),
            "newtab-text-primary-color": c(p.text), "color-accent-primary": c(p.accent),
            "color-accent-primary-hover": c(p.accent), "color-accent-primary-active": c(p.accent)
        };
        const part = (where, selector, colours) => {
            const lines = [`@-moz-document url-prefix("${where}") {`, `    ${selector} {`];
            for (const name in colours) lines.push(`        --${name}: ${colours[name]} !important;`);
            return lines.concat("    }", "}").join("\n");
        };
        // Zen sets a space's gradient on the background elements themselves.
        return "/* Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit. */\n"
            + part("chrome:", ":root, .zen-browser-generic-background", window) + "\n"
            + part("about:", ":root", pages) + "\n";
    }

    // Heroic's theme (~/.config/heroic/themes), picked by name; the class is
    // the file's name. Heroic reads it as it starts.
    readonly property string heroic: {
        const p = qtPalette;
        const c = value => Qt.color(value).toString();
        const colours = {
            background: c(p.window), "background-darker": c(p.view), "background-secondary": mix(0.05),
            "background-lighter": mix(0.09), "body-background": c(p.view), "current-background": c(p.view),
            "navbar-background": c(p.window), "navbar-accent": c(p.accent), "navbar-active": c(p.accent),
            "navbar-active-background": mix(0.1), accent: c(p.accent), "accent-overlay": c(p.accent),
            "text-default": c(p.text), "text-title": c(p.text), "text-secondary": c(p.muted),
            "text-tertiary": c(p.accentText), primary: c(p.accent), "primary-hover": c(p.accent),
            success: c(p.positive), "success-hover": c(p.positive), danger: c(p.negative), "danger-hover": c(p.negative),
            "cancel-button": c(p.negative), "input-background": mix(0.06), "modal-background": c(p.window),
            "modal-border": mix(0.14), "icons-background": mix(0.09), "action-icon": c(p.accent),
            "action-icon-hover": c(p.text), "action-icon-active": c(p.accent), "neutral-06": c(p.text),
            "anticheat-supported": c(p.positive), "anticheat-running": c(p.text), "anticheat-planned": c(p.accent),
            "anticheat-denied": c(p.negative), "anticheat-broken": c(p.negative), "icon-disabled": c(p.muted)
        };
        const lines = ["/* Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit. */", "body.hyprmonk {"];
        for (const name in colours) lines.push(`  --${name}: ${colours[name]};`);
        return lines.concat("}").join("\n") + "\n";
    }

    // Colours for Adwaita-for-Steam, the skin that restyles Steam. It is not
    // installed from here; if it is there, this is copied into it as its
    // custom.css. Steam reads it as it starts.
    readonly property string steam: {
        const p = qtPalette;
        const c = value => Qt.color(value).toString();
        const shade = saved.light ? "rgba(0, 0, 0, 0.07)" : "rgba(0, 0, 0, 0.36)";
        const colours = {
            "adw-color-scheme": saved.light ? "light" : "dark",
            "adw-accent-bg-light": c(p.accent), "adw-accent-bg-dark": c(p.accent), "adw-accent-fg": c(p.accentText),
            "adw-destructive-bg-light": c(p.negative), "adw-destructive-bg-dark": c(p.negative), "adw-destructive-fg": c(p.window),
            "adw-success-bg-light": c(p.positive), "adw-success-bg-dark": c(p.positive), "adw-success-fg": c(p.window),
            "adw-warning-bg-light": c(p.accent), "adw-warning-bg-dark": c(p.accent), "adw-warning-fg": c(p.accentText),
            "adw-error-bg-light": c(p.negative), "adw-error-bg-dark": c(p.negative), "adw-error-fg": c(p.window),
            "adw-window-bg": c(p.window), "adw-window-fg": c(p.text), "adw-view-bg": c(p.view), "adw-view-fg": c(p.text),
            "adw-headerbar-bg": c(p.header), "adw-headerbar-fg": c(p.text), "adw-headerbar-backdrop": c(p.window),
            "adw-headerbar-shade": shade, "adw-headerbar-darker-shade": shade,
            "adw-sidebar-bg": c(p.header), "adw-sidebar-fg": c(p.text), "adw-sidebar-backdrop": c(p.window),
            "adw-sidebar-shade": shade, "adw-secondary-sidebar-bg": c(p.header), "adw-secondary-sidebar-fg": c(p.text),
            "adw-secondary-sidebar-backdrop": c(p.window), "adw-secondary-sidebar-shade": shade,
            "adw-card-bg": mix(0.06), "adw-card-fg": c(p.text), "adw-card-shade": shade,
            "adw-dialog-bg": c(p.tooltip), "adw-dialog-fg": c(p.text), "adw-popover-bg": c(p.tooltip),
            "adw-popover-fg": c(p.text), "adw-popover-shade": shade, "adw-thumbnail-bg": c(p.tooltip),
            "adw-thumbnail-fg": c(p.text), "adw-shade": shade, "adw-banner": mix(0.4)
        };
        const lines = ["/* Written by the shell (ThemeOutputs.qml) for the saved tone. Do not edit. */", ":root {"];
        for (const name in colours) lines.push(`    --${name}: ${colours[name]} !important;`);
        return lines.concat("}").join("\n") + "\n";
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
    onStarshipChanged: apply.restart()
    onZshChanged: apply.restart()
    onBtopChanged: apply.restart()
    onVesktopChanged: apply.restart()
    onZedChanged: apply.restart()
    onZenChanged: apply.restart()
    onHeroicChanged: apply.restart()
    onSteamChanged: apply.restart()
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
        command: ["mkdir", "-p", root.dir, root.config + "/gtk-3.0", root.config + "/gtk-4.0", root.config + "/qt6ct",
                  root.config + "/btop/themes", root.config + "/vesktop/settings", root.config + "/zed/themes",
                  root.config + "/heroic/themes", root.config + "/heroic/store"]
        onExited: {
            gsettings.running = true;
            kdeglobals.running = true;
            tone.write();
            kittyTone.write();
            gtkTone.write();
            gtk3.write();
            gtk4.write();
            if (!qtColoursFile.write()) qtConfigFile.write();
            if (root.starship) starshipTone.write();
            zshTone.write();
            btopTheme.write();
            btopConfig.running = true;
            zedTheme.write();
            zedConfig.running = true;
            if (!zenTheme.write()) zenProfile.running = true;
            heroicTheme.write();
            heroicConfig.running = true;
            if (!steamTheme.write()) steamSkin.running = true;
            const quickCss = vesktopCss.text();
            if (quickCss !== root.vesktop && (!quickCss || quickCss.startsWith(root.vesktopMark))) vesktopWrite.running = true;
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
        path: root.config + "/starship/starship.toml"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.starshipTemplate = text()
    }

    Output {
        id: starshipTone
        path: root.dir + "/starship.toml"
        content: root.starship
    }

    Output {
        id: zshTone
        path: root.dir + "/zsh-tone.zsh"
        content: root.zsh
    }

    Output {
        id: btopTheme
        path: root.config + "/btop/themes/hyprmonk.theme"
        content: root.btop
        onSaved: btopReload.running = true
    }

    // Named once, for a btop that has no settings yet; after that it is
    // btop's own to change.
    Process {
        id: btopConfig
        command: ["sh", "-c", '[ -e "$1" ] || printf \'color_theme = "hyprmonk"\\ntheme_background = False\\n\' > "$1"',
            "sh", root.config + "/btop/btop.conf"]
    }

    // btop reads its settings and theme again on USR2.
    Process {
        id: btopReload
        command: ["pkill", "-USR2", "-x", "btop"]
    }

    Output {
        id: zedTheme
        path: root.config + "/zed/themes/hyprmonk.json"
        content: root.zed
    }

    // Named once, for a Zed that has no settings yet, as for btop.
    Process {
        id: zedConfig
        command: ["sh", "-c", '[ -e "$1" ] || printf \'{\\n  "theme": "hyprmonk"\\n}\\n\' > "$1"',
            "sh", root.config + "/zed/settings.json"]
    }

    Output {
        id: zenTheme
        path: root.dir + "/zen.css"
        content: root.zen
        onSaved: zenProfile.running = true
    }

    // Into the profile Zen last used, with what makes it read that file. A
    // userChrome.css of someone's own stays: it can import the file itself.
    Process {
        id: zenProfile
        command: ["sh", "-c", `[ -f "$2/installs.ini" ] || exit 0
            profile=$(sed -n 's/^Default=//p' "$2/installs.ini" | head -n 1)
            [ -n "$profile" ] || exit 0
            chrome="$2/$profile/chrome"
            mkdir -p "$chrome"
            cmp -s "$1" "$chrome/hyprmonk.css" || cp "$1" "$chrome/hyprmonk.css"
            for file in userChrome userContent; do
                [ -e "$chrome/$file.css" ] || echo '@import "hyprmonk.css";' > "$chrome/$file.css"
            done
            grep -qs legacyUserProfileCustomizations "$2/$profile/user.js" \\
                || echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$2/$profile/user.js"`,
            "sh", zenTheme.path, root.config + "/zen"]
    }

    Output {
        id: heroicTheme
        path: root.config + "/heroic/themes/hyprmonk.css"
        content: root.heroic
    }

    // Picked for a Heroic that has no folder or theme set: a choice of
    // someone's own stays. Heroic writes these files whole, so it can undo
    // this; it is done again at the next chance.
    Process {
        id: heroicConfig
        command: ["sh", "-c", `set_once() {
                [ -e "$1" ] || echo "$2" > "$1"
                jq -e "($3 // \\"\\") != \\"\\"" "$1" > /dev/null && return
                jq --arg value "$4" "$3 = \\$value" "$1" > "$1.new" && mv "$1.new" "$1"
            }
            set_once "$1/config.json" '{"version":"v0"}' .defaultSettings.customThemesPath "$1/themes"
            set_once "$1/store/config.json" '{}' .theme hyprmonk.css`,
            "sh", root.config + "/heroic"]
    }

    Output {
        id: steamTheme
        path: root.dir + "/steam.css"
        content: root.steam
        onSaved: steamSkin.running = true
    }

    Process {
        id: steamSkin
        command: ["sh", "-c", '[ -d "$2" ] || exit 0; cmp -s "$1" "$2/custom.css" || cp "$1" "$2/custom.css"',
            "sh", steamTheme.path, Quickshell.env("HOME") + "/.local/share/Steam/steamui/adwaita"]
    }

    // Read at once and kept up to date: whether it may be written depends on
    // what it holds.
    FileView {
        id: vesktopCss
        path: root.config + "/vesktop/settings/quickCss.css"
        printErrors: false
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    // In place, not by FileView: that saves a new file over the old one, and
    // Vencord watches the file it first opened, so it would miss every change
    // from then on.
    Process {
        id: vesktopWrite
        command: ["sh", "-c", 'printf %s "$1" > "$2"', "sh", root.vesktop, vesktopCss.path]
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
