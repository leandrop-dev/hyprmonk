# Optimizations

From a review of the `hyprmonk` crate (clippy pedantic, tests, a read for
idiom and errors) and of the shell's QML (the Qt QML linter, qmllint, and a
read for bindings, layout, lifecycle, lists, states and performance), on
2026-10-28. Ordered by what to do first. Each item says where, what goes
wrong, and the fix. "To check" marks what was found by reading but not yet
seen happening.

## 1. Idle CPU

Done 2026-10-29: in silence the shell went from 12.4% of a core to 2.0%,
cava from 2.2% to 0.4% (cava's `sleep_timer`, a repeated line skipped, the
spectrum redrawn only when it moved and eased at cava's 30 frames a second;
cava and the running cat still while locked or in game mode; the lyrics
clock still while paused). What is left:

- ~~The bar window is far larger than what it draws~~: measured
  2026-10-29, a bar-height window (growing only while a panel shows)
  changed nothing for the shell, Hyprland or the GPU, within noise, so the
  tall window stays. The running cat's frames still cost the shell about
  1.5% of a core; that is Qt's per-frame work, not the window's size.
- **The player's position is asked for twice a second** while both the
  media drawer (`bar/Media.qml:343`) and the lyrics (`services/Lyrics.qml`)
  run: ask in one place.

## 2. The wrong item picked

Done 2026-10-29: hovering picks a row only when the pointer really moves
(the launcher, quick actions, the key guide, the power menu), and the
launcher's list is told its index again whenever its model changes, with
`current` kept inside a shorter list. Still in the same pattern, not yet
changed: `wallpaper/Picker.qml:126` (mostly hidden by its explicit
scrolling) and `panels/LyricsView.qml` (until the next line).

## 3. Notifications and outside text

- **Notification bodies are rich text with links opened**
  (`notifications/NotificationCard.qml:163-176`). A sender's `<img src>` is
  fetched (remote addresses too), and a link of any scheme goes to
  `Qt.openUrlExternally`. Fix: strip `<img>`; open only http, https and
  mailto. To check.
- **Outside text read as markup**: lyrics (`panels/LyricsView.qml:65`),
  track titles (`bar/Media.qml:377`, `panels/MediaPanel.qml:133,144`, the
  OSD's caption), app names (`notifications/NotificationCard.qml:118`,
  `NotificationGroup.qml:37`), tray menu labels (`panels/TrayMenu.qml`),
  polkit (`polkit/Polkit.qml:125,188`). A `<b>` or `&amp;` in a title would
  render. Fix: `textFormat: Text.PlainText`.

## 4. Caps Lock

- **A second read is lost while one runs** (`osd/Osd.qml:107,129,195`,
  also `services/Keyboard.qml:42`). `devices.running = true` does nothing
  while `hyprctl devices` still runs, so a quick second press (or a burst
  of layout events) is missed, or the OSD shows the earlier state. Likely
  the roadmap's "Caps Lock only on the first press". Fix: a pending flag,
  run again from `onExited`, as `services/Wallpaper.qml` does. To check.

## 5. Overlay polish

- **Moving up in the key guide hides section headings**
  (`keyguide/KeyGuide.qml:193-196`, the same code in
  `quickactions/QuickActions.qml:278-281`). Keeping the row in view lines
  up with the row, under its heading. Fix: line up with the entry's top.
  Both copies of this sectioned list (with `startsSection`, `listHeight`,
  the sliding highlight) could become one widget.
- **Quick actions resets as it opens** (`quickactions/QuickActions.qml:166-175`).
  After a filtered run the next open shows the card growing and the
  highlight sliding to the top while it unfolds; the power menu and key
  guide highlights slide too. Fix: reset once the card has folded away.
- **A label stops short of the row's end**
  (`quickactions/QuickActions.qml:362`). Anchored to the value chip, which
  keeps its width when hidden: labels without a value end about 40 px early.
  Fix: anchor to the row's edge when the chip is hidden, or a RowLayout.
- **A card shrinking is cut while it animates** (`widgets/Overlay.qml:21`):
  the window takes the new height at once, the card over 160 ms. Quick
  actions avoids it with a fixed window; the key guide and the wallpaper
  picker do not (rare). Fix: a fixed window by default.

## 6. The hyprmonk crate

- **The screenshot name ignores `date` failing**
  (`crates/hyprmonk/src/screenshot.rs:347`): a failed `date` names every
  shot `Screenshot_.png`, each overwriting the last; two copies within a
  second share one preview file. Fix: check the exit status; milliseconds
  in the previews' names.
- **The battery JSON is written by hand** (`src/battery.rs:101-126`) while
  `serde_json` is already a dependency. Fix: `serde_json::json!`, dropping
  `json_object` and `json_escape`; the test output stays the same.
- **`std::env::args()` panics on arguments that are not UTF-8**
  (`src/main.rs:24`). Fix: `args_os` with `to_string_lossy`, so bad input
  gets the usage text.
- **"Show in folder" builds the `file://` link unencoded**
  (`src/screenshot.rs:200`): a space in the Pictures folder makes it
  invalid. Fix: percent-encode the path.
- Smaller: `run_with_input` writes all input before reading output, which
  would deadlock a future caller with large input and large output (say so,
  or write on a thread); `read_all` stops at the first device that fails
  (matters once there is more than one mouse); `pictures_folder` falls back
  to a relative path without `HOME`.

## 7. Smaller, as they come up

- **Lists rebuilt whole on any change**: workspace pills
  (`bar/Workspaces.qml:23`) lose their width animation when a workspace is
  created; every tray icon (`bar/TrayIcons.qml:16`) is rebuilt, tooltip and
  all, when one changes state; batteries; the notification centre's groups
  can jump while it is open. Fix: `ScriptModel`, as `Popups.qml` uses.
- **The Commands tab sorts every program on PATH per keystroke**
  (`services/Apps.qml:81-89`): about 3,600 objects built and sorted. Fix:
  build them once when the scan arrives (already sorted by name). Time it
  first.
- **Tray submenus that change while open** (`services/Tray.qml:20`,
  `panels/TrayMenu.qml:21`): the stored entry dies and the panel shows an
  empty submenu. Fix: one menu opener per level, drop dead entries. To
  check.
- **Tray icons that fail to load** (`bar/TrayIcons.qml:39`) leave a blank
  gap. Fix: fall back to the icon theme or a glyph.
- **Lyrics**: after switching to a paused player the old position is kept
  (read it once on a player change); a stalled LRCLIB request never times
  out (abort after 15 s, as an error); `line` can read past the end of a
  shorter list for a moment (`lines[index]?.text`).
- **The player's length after a track change** (`services/Player.qml:135`)
  may keep the previous track's length when the title arrives first. To
  check.
- **The media panel may be about 7 px short** (`panels/MediaPanel.qml:22`)
  with an artist line and a seek bar. To check on screen.
- **The previous wallpaper stays in memory** (`wallpaper/Background.qml:34-47`)
  under the new one. Fix: clear it once the fade ends.
- **The media drawer's hover** (`bar/Bar.qml:85`) covers only the modules
  row, not the card's edge.
- **The lock screen with several screens** (`lock/LockSurface.qml:164`):
  if the screen that has the password field goes away, none does.
- Lint: unused imports in `bar/Volume.qml:4` and `lock/Lock.qml:19`.

Checked and clean: no binding loops, no objects created and lost, every
`Connections` uses `function onFoo()`, no deprecated effect imports,
delegates declare what they use, no anchors mixed into layouts.
