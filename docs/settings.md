# Settings

A centred card (Super+comma, or quick actions > Settings) with its pages down
the side. Ideas from noctalia, Ryoku and Shibumi Shell,
no code from them.

The Display, Windows, Bar, Dock, Sounds, Input and Power pages keep to `settings.json` in the
state directory, holding only what was changed, so the rest follows the repo's
config. Hyprland options are also written to `settings.lua`, loaded after
`look.lua` and `input.lua`, and applied at once with `hyprctl eval`.

## Pages

- [x] Windows: gaps, border size, rounding, blur size and passes; the tiling
  layout (dwindle, master or scrolling; Super+J toggles a split only in
  dwindle) or floating (`hypr/floating.lua`: every window floats at 60% by 70%
  of the screen, centred, and keeps the size given it; borders resize and
  windows snap; the open windows float when it is picked and tile back when
  it is left; apps may maximise themselves only here; title bars with
  minimise, maximise and close for the apps that draw none), shadows on or
  off, and animations on or off at normal, fast (0.6 times as long) or slow
  (1.5 times) speed. A speed goes through
  `hyprmonk_animations` in `look.lua`, which sets every animation at that
  many times its time. Game mode holds shadows and animations off whatever
  these say.
- [x] Appearance (was Tone, and quick actions' Appearance, Spectrum, Fastfetch
  and Login look rows): the tone, shown while the pointer is over it; the
  saved tone's card opacity, blur behind the cards on or off, and text colour,
  which apps follow too, kept per tone in `appearance.json` with a reset; the
  spectrum's style, also shown under the pointer; fastfetch's look; the login
  screen's look. The page scrolls. How strong blur is stays on the Windows
  page: Hyprland has one strength for everything.
- [x] Bar: drag modules to reorder them, move them between the left and right
  cards, or hide them. The bar sits at the top or the bottom of the screen;
  a panel opens from the card holding its module, below it or above it.
  Recording and Replay cannot be hidden, and the centre card stays as it is:
  its fitting rules depend on it. Below them: the clock in 24 or 12 hours,
  with seconds and the date or without; the workspaces in use, or always 1 to
  5 or 1 to 10 (empty ones dim, a click opens one); temperatures in °C or °F.
  These are kept in `barLook`, apart from the modules. The window list (the
  dock's apps, at the bar's size) starts hidden, since the dock shows the same.
- [x] Dock (`dock/`, `services/Windows.qml`): shown or not; the edge it sits
  on (bottom, top, left or right, upright on the sides); whose windows it
  lists, every workspace's or the current one's (minimised ones by the
  workspace they came from, `hyprmonk-from-<id>`), which the bar's window list
  follows too; its buttons' size, 32 to 56 pixels; hiding: never (it keeps
  its space), always, or while a window of the workspace on its screen
  touches it (floating windows' places are read twice a second while that is
  picked), coming back as the pointer reaches the edge; icons growing under
  the pointer; and a dot per window. Kept in `dock`. Also over IPC: `qs -c
  hyprmonk ipc call dock set <key> <value>`, `dock toggle`, and for the bar
  `bar move <module> <left|right|hidden> <index>` and `bar set <key> <value>`.
- [x] Sounds (`services/Sounds.qml`): sounds on or off (on to begin with);
  the set, hyprmonk's own (`assets/sounds/hyprmonk`, sine waves made by its
  `make.sh` with ffmpeg) or serpantinum's (copied under its AGPL, see the
  README beside them); their volume, 0 to 100% (50), squared so the middle
  sounds half as loud; and the notification tone: the set's own, the
  hyprmonk chime, or one of serpantinum's seven. A click on a button, chip or
  row clicks, a switch sounds on or off, a card or bar panel opening or
  closing sweeps, a shown notification chimes, and the network going online
  or off or a Bluetooth device coming or going (not as the shell starts)
  plays connect or disconnect. Quiet in game mode and do not disturb, except
  for a notification shown anyway. Each set is one WAV per kind, since Qt's
  SoundEffect plays WAV. Kept in `sounds`; over IPC, `qs -c hyprmonk ipc call
  sounds play <kind>` and `sounds set <on|set|tone|volume> <value>`.
- [x] Display: resolution, refresh rate and scale, for each screen, picked first
  and applied together. An applied change is only tried until kept, and goes
  back after 15 seconds, so a mode the screen cannot show fixes itself and a
  restart starts from the last one kept. Only scales that give a whole number
  of pixels are offered.
  With more than one screen, a map shows where they sit: click one to pick it,
  drag it to move it. Where it is dropped it snaps against another screen,
  sharing at least half an edge and overlapping none, lined up with that
  screen's edge or middle when close. A move waits for Apply like a mode.
  A screen made larger or smaller keeps touching what it touched: one against
  its right or bottom edge keeps that edge where it is, and only the screen
  being changed moves. Should that overlap another screen or touch none, it
  takes the nearest place that does not.
  "Main screen" marks the picked screen as the one quick actions' Screens row
  keeps (until picked, the one at the top left). That row tries Extend, Mirror
  or Main screen only for every other screen, and a Keep this layout row counts
  down beside it. A screen kept mirroring or off keeps its own mode in
  `settings.json`, for when it is back beside the others.
- [x] Input: up to four keyboard layouts, found by code or name (XKB's
  `base.lst`), the first the default; the mouse's sensitivity, acceleration
  (adaptive or flat) and natural scroll; focus following the pointer, or a
  click moving the keyboard while scrolling still follows the pointer.
- [x] Power: lock after 5 minutes to an hour or never, and the screens off
  after the lock (or after going idle, when it never locks). hypridle reads
  its config only as it starts, so the shell writes a copy of
  `hypr/hypridle.conf` with these times to `hypridle.conf` in the state
  directory, which hyprmonk-idle.service reads when it is there, and restarts
  the service when the copy changes.
- [x] Recording (was quick actions' Record system sound and Record microphone
  rows): the system's sound and the microphone, the quality (GPU Screen
  Recorder's medium, high, very high or ultra presets, very high its own
  default) and the folder, an absolute path or `~/` (empty for Recordings in
  the Videos folder, made when first needed). They are kept with the record
  area in `recorder.json`, which stays in quick actions beside the button, and
  passed to `hyprmonk record` and `hyprmonk replay` as `--sound`,
  `--microphone`, `--quality` and `--folder`. A replay that is on keeps what it
  started with.
- [x] Notifications: how long a pop-up stays when its sender does not say (5
  to 60 seconds, 10 to begin with; a low one half as long, an urgent one until
  dismissed), the corner they show in (the newest nearest it), how many show
  at once (4 to begin with; fewer drops the oldest at once) and how many the
  centre keeps (200; urgent ones are never dropped). Kept with do not disturb,
  which stays in quick actions, in `notifications.json`. "Send a test" shows
  the result.
