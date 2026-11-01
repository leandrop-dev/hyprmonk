# Review of 2026-10-31

What the Rust and QML reviews found, to fix or to look into. Ticked once fixed;
"Still to try" lists the fixes that need a real test. QML paths are relative to
`config/quickshell/hyprmonk`, Rust paths to `crates/hyprmonk/src`.

Clean at the time: `cargo fmt`, pedantic clippy, the 26 tests; no generated file
can inject shell commands; no binding loops, restart loops or leaked objects.

## Still to try

- D-005, D-024: need a second monitor.

## To fix

### Security

- [x] D-001 `notifications/NotificationCard.qml:173`: the `<img>` removal can be
  bypassed by nested tags and an unclosed tag. Escape the `<` of any `img` tag
  instead of removing the tag.
- [x] D-002 `notifications/NotificationCard.qml:43`: any app can make a card
  fetch a remote icon. Allow only `file://` and `image://`.
- [x] D-003 `widgets/LevelRow.qml:60`, `panels/MediaPanel.qml:91`: app and player
  names are shown as rich text. Use `Text.PlainText`.

### Lock screen

- [x] D-004 `lock/Lock.qml:6`: nothing locks again after a crash while locked,
  whatever the comment says. Keep a marker in `XDG_RUNTIME_DIR` while locked and
  lock at startup if it is there.
- [x] D-005 `lock/LockSurface.qml:25`: with several monitors, losing the main one
  while locked leaves no password field. Fall back to the first connected screen.

### Bugs

- [x] D-006 `widgets/SectionList.qml:53`: moving up scrolls the picked row out of
  view. Work the positions out inside `keepInView()`.
- [x] D-007 `launcher/Launcher.qml:241`: Shift+Delete on a clip further down
  jumps the list to the top. Position the view on the current row.
- [x] D-008 `services/Clipboard.qml:83`: stepping through images quickly can show
  one clip's picture under another. Publish a result only for the wanted id.
- [x] D-009 `ThemeOutputs.qml:122,159,164`: with a Wallpaper tone saved, previews
  rewrite real app files. Work `positive` out from the saved tone.
- [x] D-010 `quickactions/QuickActions.qml:224,237`: a preview can stay on after
  the card closes. Require `root.open`, and clear the preview in `reset()`.
- [x] D-011 `wallpaper/Background.qml:35,58`: quick picks skip the fade or flash
  the background. Stop the fade on a new source and give it `from: 0`.
- [x] D-012 `services/Lyrics.qml:82,151`: a timeout for the old track wipes the
  new track's lyrics. Fail the key that was asked for.
- [x] D-013 `services/Bluez.qml:59,152`: Cancel then Pair can report failure and
  leave a good pairing untrusted. Stop `settle` in `pair()`.
- [x] D-014 `services/Notifications.qml:103`: a card added to a group can lose its
  age label. Set `arrived` before `tracked`, and read `now` first in `ago()`.

### Cost

- [x] D-015 `Theme.qml`, `ThemeOutputs.qml`: one wallpaper change rebuilt every
  tone 5 times. Measured for one change: Wallpaper tone 87 ms to 3 ms, Noir 9 ms
  to 0, a Tones.qml palette 0 before and after: it keeps its identity, so nothing
  downstream ran. The colours are now read in one go, once per change.
- [x] D-016 `services/Notifications.qml:70,102`: history has no limit, and
  transient notifications with no card stay. Expire those at once, cap history.
- [x] D-017 `services/Hardware.qml:166`, `services/Lyrics.qml:223`,
  `bar/Media.qml:31`: timers run while locked or in game mode. Use cava's condition.
- [x] D-018 `bar/Temperature.qml:11,37`: polls with the drawer closed, and only
  knows Intel. Run only while open, match `k10temp` and `zenpower`.
- [x] D-019 `quickactions/QuickActions.qml:265`: opening Appearance previews a
  wrong tone for a moment. Set `current` before `opened`.
- [x] D-020 `bar/TrayIcons.qml:130`: the second Canvas never unloads old icons.
  Unload the previous URL.

### Other machines

- [x] D-021 `bar/Bar.qml`, `bar/Media.qml`, `bar/HardwareDrawer.qml`: the bar's cards
  overlapped on smaller screens. The centre card stays centred while it fits,
  moves aside when it does not, and the media gives up its text, then itself. The
  drawer stops at the right card. Tried at 2560, 1920, 1366 and 1100 px wide.
- [x] D-022 `bar/Card.qml`: tall panels were cut off. Every panel now scrolls
  inside its card once it is taller than the bar's window has room for, with a
  thin marker for how far down it is. A tray submenu starts at its top.
- [x] D-023 `wallpaper/Background.qml:17`, `lock/LockSurface.qml:36`,
  `wallpaper/Picker.qml:178`, `services/Wallpaper.qml:42`,
  `notifications/NotificationCard.qml:40`, `services/Tray.qml:62`: `#`, `?` or `%25`
  in a path stops the picture loading. One helper that encodes the path.
- [x] D-024 `panels/NetworkPanel.qml:51`, `panels/BluetoothPanel.qml:35`: a closing
  panel can turn scanning off under a new one. Count watchers.
- [x] D-025 `panels/BluetoothPanel.qml:222`: a long adapter name overflows. Wrap it.

### Cleanup

- [x] D-026 `diskSize` in `services/Hardware.qml:22`; unused imports in
  `notifications/NotificationGroup.qml:10`, `panels/SoundPanel.qml:8`,
  `screenshot/ScreenshotMode.qml:13`; unused ids in `bar/Bar.qml:103`,
  `bar/Media.qml:62`, `bar/Module.qml:71`, `osd/Osd.qml:200`,
  `services/Wallpaper.qml:40`; stale comments in `services/Wallpaper.qml:2`,
  `Theme.qml:11`.
- [x] L-001 The linter's PRF-1 hits: only the tray's separator was always transparent,
  now an Item. The others are hover and selected fills, which Qt does not draw while
  transparent, or the picker's rim, so they stay Rectangles.

### Rust

- [x] R-001 `thumbnails.rs:118`: `%s` in a wallpaper's name is read as a
  placeholder, so it gets no thumbnail.
- [x] R-002 `recording.rs:183`: a failed `--info` silently means software encoding.
- [x] R-003 `screenshot.rs:235`: copied-screenshot previews pile up in RAM until
  logout. Keep the newest few.
- [x] R-004 `bluetooth.rs:149`, `installer.rs:13`, `thumbnails.rs:24`: add
  `# Errors` sections.

## To look into

- [x] I-001 `lock/Lock.qml`: the hidden preview window kept a whole lock surface
  alive. It is now made only while previewing, which took the shell from about
  405 MB to about 374 MB after a start (two starts each).
- [x] I-002 `panels/NetworkPanel.qml:120`, `panels/BluetoothPanel.qml:259`: an
  expanded row could open below the visible area. It now scrolls into view once
  the list has its new height. Tried on Wi-Fi with the list cut to 100 px and the
  last network opened; Bluetooth has the same code, tried only for loading.
- [ ] I-003 `services/Overlays.qml`: overlays can lose the keyboard. Opening a card
  now closes the notification centre first, as does locking (seen unmapping as the
  card opened), and Super+N, Super+Space, then typing works. Left: with several
  monitors, the OSD and pop-ups may remap as focus moves; the 240 ms wait is a
  timing guess with no failure seen.
- [x] I-004 `wallpaper/Picker.qml:165`: each tile costs two offscreen textures
  while scrolling. Left as it is: scrolling feels smooth.
- [ ] I-005 `services/Player.qml:44`: a stream after a normal track may keep the
  old length. Log `track` and `reported` when switching.
- [x] I-007 `services/Apps.qml:172`: odd file names on PATH went through `sh -c`.
  A program from PATH now runs by its file name; a test file with `$(…)` in its
  name failed before and runs now, and a typed line still goes through `sh -c`.
- [x] I-008 `panels/MediaPanel.qml:22`: the fixed height may be about 8 px short.
  Left as it is: it looks right by eye.
- [x] I-009 `bar/TrayIcons.qml:76`: icon updates may have skipped the shade check.
  They do not: `status` changes once for every new source, tried with the theme
  icon provider. The tray's pixmap provider was not tried.

## Back burner

- [ ] I-006 `panels/NetworkPanel.qml:114`: a typed password can be lost when its
  row scrolls away. Needs about 18 networks in reach.
- [ ] I-010 `services/Recorder.qml`: `stop()` has no forced kill if the recorder
  hangs. Only matters if that hang comes back.
