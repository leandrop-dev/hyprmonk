// Tones with their own colours, added to Theme's. The palettes are
// HANCORE-linux's themes for Omarchy, each from its colors.toml; the licence
// is in assets/LICENSE-HANCORE-themes. Where a theme's accent does not read on
// its background, or is its text colour, it takes a colour of its own palette
// that does. `positive` is their green, or the nearest calm colour where theirs
// is not one; `terminal` is kitty's 16 colours, one that cannot be read
// swapped for `positive`.
pragma Singleton

import Quickshell

Singleton {
    readonly property var list: ({
        banish: { label: "Banish", background: "#0c0b0d", foreground: "#d8d1cc", card: 0.88, light: false,
            accent: "#ff2fb3", positive: "#53b1ca",
            terminal: ["#0c0b0d", "#ff4a78", "#f2f2ea", "#8f57ff", "#6c70e0", "#bd5cff", "#53b1ca", "#d8d1cc", "#7d8581", "#ff6f93", "#fefef6", "#a375ff", "#9488ff", "#b985ff", "#8ac7d8", "#e0e1e4"] },
        batou: { label: "Batou", background: "#121212", foreground: "#a4a4a4", card: 0.88, light: false,
            accent: "#e19e74", positive: "#a5a297",
            terminal: ["#121212", "#e19e74", "#a5a297", "#c6c4b0", "#605d5b", "#8a8575", "#c2bbb0", "#dbd9d3", "#383735", "#984b1e", "#637380", "#8f4445", "#b7a798", "#b3adad", "#90947a", "#a4a4a4"] },
        blackgold: { label: "Black Gold", background: "#0d0d0d", foreground: "#ebdbb2", card: 0.88, light: false,
            accent: "#bfa75d", positive: "#a3850e",
            terminal: ["#0d0d0d", "#d35f5f", "#a3850e", "#4d574e", "#6e6a58", "#bfa75d", "#7a6a2c", "#f6f1dd", "#303531", "#d35f5f", "#a3850e", "#4d574e", "#6e6a58", "#bfa75d", "#7a6a2c", "#f6f1dd"] },
        blackmoney: { label: "Black Money", background: "#0c0c0c", foreground: "#d8d4b4", card: 0.88, light: false,
            accent: "#88c6a3", positive: "#689e80",
            terminal: ["#0c0c0c", "#dd5670", "#689e80", "#525b54", "#d8d4b4", "#689e80", "#88c6a3", "#ece4d4", "#4e594a", "#dd5670", "#689e80", "#525b54", "#d8d4b4", "#689e80", "#88c6a3", "#ece4d4"] },
        harbor: { label: "Harbor", background: "#dfe4c4", foreground: "#1c2d28", card: 0.92, light: true,
            accent: "#4c6c94", positive: "#556753",
            terminal: ["#dfe4c4", "#b14752", "#556753", "#556753", "#4c6c94", "#8a5b81", "#3d727d", "#384f54", "#7d8794", "#b14752", "#556753", "#556753", "#4c6c94", "#8a5b81", "#3d727d", "#1c2d28"] },
        harbordark: { label: "Harbor Dark", background: "#1b1b1b", foreground: "#efebdc", card: 0.88, light: false,
            accent: "#e75a50", positive: "#a99b7a",
            terminal: ["#1b1b1b", "#f44336", "#e75a50", "#a99b7a", "#e58980", "#77838a", "#6d6d6d", "#e1ce98", "#817f68", "#e75a50", "#77838a", "#a99b7a", "#e58980", "#9ba2a6", "#888888", "#efebdc"] },
        inkypinky: { label: "Inky Pinky", background: "#13131d", foreground: "#c8c8c8", card: 0.88, light: false,
            accent: "#7c7ca8", positive: "#a6b2c7",
            terminal: ["#13131d", "#ea90a8", "#a6b2c7", "#d18ba2", "#7c7ca8", "#9f859f", "#919ab7", "#a1a2a7", "#434353", "#f6bfce", "#d1d9e4", "#e3aebf", "#bcbcd4", "#bfadbf", "#d2d7e3", "#c8c8c8"] },
        kanso: { label: "Kanso", background: "#090e13", foreground: "#c5c9c7", card: 0.88, light: false,
            accent: "#8ba4b0", positive: "#87a987",
            terminal: ["#090e13", "#c4746e", "#8a9a7b", "#c4b28a", "#8ba4b0", "#a292a3", "#8ea4a2", "#c8c093", "#393b44", "#e46876", "#87a987", "#e6c384", "#7fb4ca", "#938aa9", "#7aa89f", "#a4a7a4"] },
        lasthorizon: { label: "Last Horizon", background: "#0c0b0c", foreground: "#fafcfb", card: 0.88, light: false,
            accent: "#b59790", positive: "#87a9b0",
            terminal: ["#0c0b0c", "#c38b7b", "#87a9b0", "#6b5e73", "#b59790", "#c4d8e2", "#a5a0b6", "#cfd3cd", "#584e51", "#c38b7b", "#87a9b0", "#6b5e73", "#b59790", "#c4d8e2", "#a5a0b6", "#e2dddc"] },
        oxford: { label: "Oxford", background: "#292b31", foreground: "#d6d1c9", card: 0.88, light: false,
            accent: "#bda07f", positive: "#a8b49d",
            terminal: ["#292b31", "#dd5544", "#76856a", "#f3e9bd", "#bda07f", "#b7a593", "#9b907f", "#ffffff", "#646466", "#f28b7c", "#a8b49d", "#fff4d4", "#d8c3a5", "#b0a89d", "#c7c0b5", "#d6d1c9"] },
        roseofdune: { label: "Rose of Dune", background: "#f5e6d3", foreground: "#35302a", card: 0.92, light: true,
            accent: "#76634c", positive: "#76634c",
            terminal: ["#f5e6d3", "#a02b16", "#9e4f5b", "#644535", "#76634c", "#78292e", "#713a56", "#a94a34", "#c8ac86", "#a02b16", "#9e4f5b", "#694c45", "#76634c", "#78292e", "#713a56", "#a94a34"] },
        softechoes: { label: "Soft Echoes", background: "#232631", foreground: "#e5d9d6", card: 0.88, light: false,
            accent: "#cf8094", positive: "#98c09b",
            terminal: ["#8c98a9", "#cf8094", "#98c09b", "#ccc490", "#959ee3", "#c298d7", "#86bed3", "#d4ccca", "#717d8f", "#eca2b4", "#bbdfbd", "#ded7aa", "#b5bffe", "#e0b9f4", "#aaddf1", "#f5ebe7"] },
        thegreek: { label: "The Greek", background: "#d0d0c8", foreground: "#242424", card: 0.92, light: true,
            accent: "#6b1f2f", positive: "#51573b",
            terminal: ["#d0d0c8", "#db0030", "#2e3125", "#51573b", "#51573b", "#43432b", "#6b1f2f", "#383835", "#6b7360", "#db0030", "#2e3125", "#51573b", "#51573b", "#43432b", "#6b1f2f", "#242424"] },
        turbonite: { label: "Turbonite", background: "#0b0c0c", foreground: "#eae9e3", card: 0.88, light: false,
            accent: "#ed9a1d", positive: "#ebd698",
            terminal: ["#0b0c0c", "#f24331", "#6e6a64", "#ed9a1d", "#847b4e", "#a7a483", "#ebd698", "#cac8c4", "#31363a", "#f24331", "#6e6a64", "#ed9a1d", "#847b4e", "#a7a483", "#ebd698", "#f9f9f8"] },
        whitegold: { label: "White Gold", background: "#dedbc8", foreground: "#0c0c14", card: 0.92, light: true,
            accent: "#005c32", positive: "#725c0a",
            terminal: ["#dedbc8", "#4b0304", "#725c0a", "#2e311a", "#005c32", "#762b2f", "#3b3b3b", "#665e4a", "#9a9078", "#4b0304", "#725c0a", "#005c32", "#2e311a", "#762b2f", "#3b3b3b", "#0c0c14"] }
    })
}
