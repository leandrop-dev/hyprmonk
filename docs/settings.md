# Settings

A centred card (Super+comma, or quick actions > Settings), 880 by 680 (less
on a short screen), with its pages down the side in three groups: Desktop
(Display, Windows, Bar, Dock), Look and sound (Appearance, Sounds) and System
(Input, Power, Recording, Notifications). Display (Screens, Brightness, Night light),
Bar (Modules, Look), Appearance
(Theme, Motion, Fonts, Terminal, Login screen) and Sounds (Interface, Effects,
Microphone) list their sub-pages under them while open; a sub-page is a part
of its page (the page's `section`), so moving between them keeps what the
page holds. The arrows and Tab go through what the side shows. A page that
scrolls fades out at its foot under an arrow while there is more below
(`widgets/MoreBelow.qml`). Searches (keyboard layouts, AutoEQ, fonts) open their results in a
list over the page rather than pushing it down (`widgets/SearchField.qml`):
Up and Down mark one, Enter picks it, Escape empties the box. Ideas from noctalia, Ryoku and Shibumi Shell, no
code from them.

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
  spectrum's style, also shown under the pointer; how a new wallpaper
  comes in (`wallpaper/Background.qml`, kept as `transition` in
  `wallpaper.json`): fading in (400 ms), a soft edge wiping across from one
  of eight directions at random (900 ms), a soft circle growing from the
  picker's tile, the same spot on every screen, or the middle when set
  another way (1100 ms), or one of those at random; drawn through a
  MultiEffect mask, no shaders of our own. The picture shows at once and
  matugen's colours follow (`wallpaper transition <name>` over IPC);
  the two fonts (`settings/FontPicker.qml`), kept in `appearance.json`:
  the interface's (the shell, GTK and Qt apps, the Floating layout's title
  bars and the login screen) and the monospace one (kitty and code in
  apps), each picked from small cards written in it (those of
  `packages/pacman.txt`'s set that are installed) or searched for among
  every font Qt knows. Until picked, the shell and kitty have JetBrains Mono
  and apps their own (GNOME's, reset with gsettings; Noto Sans in qt6ct).
  Handed on by `ThemeOutputs.qml`: gsettings `font-name` and
  `monospace-font-name`, qt6ct's `[Fonts]`, `font_family` in
  `kitty-tone.conf` and `theme.font` in `tone.lua`. Icons an interface font
  lacks come from Symbols Nerd Font. A font installed while the shell runs
  shows after it restarts;
  fastfetch's look; the login
  screen's look. The tones, spectrum styles, wallpaper changes and login
  looks show as small previews (`widgets/PreviewCard.qml`) rather than
  names: a tone's background, a card, its text and accent; each spectrum
  style drawn from made-up levels; each change held half way, played under
  the pointer; each login look's background, a frame for a video one
  (made once with ffmpeg into `~/.cache/hyprmonk/login`). The page
  scrolls. How strong blur is stays on the Windows
  page: Hyprland has one strength for everything.
- [x] Bar: drag modules to reorder them, move them between the left and right
  cards, or hide them. The options scroll, the reset button below them. The bar sits at the top or the bottom of the screen;
  a panel opens from the card holding its module, below it or above it.
  Recording and Replay cannot be hidden, and the centre card stays as it is:
  its fitting rules depend on it. Below them: the clock in 24 or 12 hours,
  with seconds and the date or without; the workspaces in use, or always 1 to
  5 or 1 to 10 (empty ones dim, a click opens one); how they look:
  pills, numbers, dots, or a chomper that goes from the active one to the
  next, chomping, each shown on four made-up workspaces whose active one
  moves under the pointer; temperatures in °C or °F; and whether the cat
  slides out its drawer on the bar or opens a panel (`panels/HardwarePanel.qml`)
  of bars that fill as the readings change: the processor and each core, its
  temperature, the GPU, memory, each disk, and the network against the
  fastest seen while open.
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
- [x] Calendar > Holidays (`services/Calendar.qml`): the country whose public
  holidays the calendar under the clock marks, found by name or code in a
  pop-up list, or none; from LC_TIME or LANG until one is picked. Regional
  days (one part of the country only) and optional ones (days off for some)
  can each be left out; both show fainter. From Nager.Date
  (`date.nager.at/api/v3`, no key), a year at a time, kept in
  `~/.cache/hyprmonk/holidays` and fetched again after 30 days. Kept in
  `calendar.json`. IPC: `calendar country <code>`, `calendar holidays
  <yyyy-mm-dd>`.
- [x] Calendar > Calendars (`services/Events.qml`): the local calendar and
  each subscribed one, with a colour from seven (the accent first); a
  subscribed one is a name and its private iCal link (Google's "Secret
  address in iCal format", Outlook's published ICS link; webcal:// read as
  https://), removed with its folder. vdirsyncer fetches the links into
  `~/.local/share/hyprmonk/calendar/<id>` at the shell's start, every 15
  minutes and on "Fetch now", its last error shown; khal reads every folder,
  the subscribed ones read-only. The panel lists the six weeks it shows with
  one `khal list --json` (an array per day), a dot per event under each day
  (three at most) and the selected day's events under the month. Local
  events are added there (a title, from and to as 14:30 or neither for all
  day, once, weekly, monthly or yearly), one `.ics` file each in `local/`,
  and deleted by removing it. The links are kept in `calendars.json`; both
  configs are written to the state directory's `calendar/` with mode 600.
  Needs `khal` and `vdirsyncer`. IPC: `events sync`, `events list
  <yyyy-mm-dd>`.
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
  The page also holds the audio effects (`services/AudioEffects.qml`, kept
  in `audio-effects.json` in the state directory):
  - The equaliser, on whatever the default output is and before the
    correction: ten peaking bands an octave apart (31 Hz to 16 kHz, Q 1.41,
    ±12 dB), a preset (Flat, Bass, Treble, Vocal, Rock, Pop, Jazz,
    Classical) or Custom, which moving a band starts from what is heard and
    keeps. A preamp lowers the sound by the largest boost so that it never
    clips. Presets and bands change on the running filter. The sound panel
    has its switch and presets.
  - Night mode, after the equaliser and before the correction, on whatever
    the default output is: swh-plugins' SC4 compressor (RMS, 10 ms attack,
    300 ms release, 6 dB knee) and a lookahead limiter at -1 dB. Its
    strength, Light (-20 dB, 2:1, +5 dB), Medium (-28 dB, 4:1, +10 dB) or
    Strong (-36 dB, 8:1, +15 dB), changes on the running filter. The sound
    panel has its switch.
  - The headphone correction, AutoEQ's for the output in use: the Arctis
    Nova 7's comes ready (`assets/autoeq`), and any other is searched for in
    AutoEQ's index (cached a week in `~/.cache/hyprmonk`) and downloaded
    into the state directory's `audio/eq`. It follows the default output when
    that has one; unplugged, the filter waits instead of correcting other
    speakers.
  - The microphone's noise suppression (rnnoise, from
    noise-suppression-for-voice), with its voice threshold (0 to 95%, 50)
    and how long it holds after speaking (0 to 1000 ms, 150; longer lets the
    room in as a faint static). Both change on the running filter. Listen to
    yourself plays the microphone back in the headphones while the page is
    open.
  Each effect is a PipeWire filter-chain, written to `audio/<effect>.conf` in
  the state directory and run by its own user unit (`hyprmonk-music-eq`, `hyprmonk-night-mode`,
  `hyprmonk-headphone-eq`, `hyprmonk-noise-suppression`), so a shell reload does not cut the sound.
  Before one is stopped or restarted, WirePlumber is told to pass it by
  (`filter.smart.disabled`, taken off afterwards, since PipeWire reuses
  node ids) and given 1.5 s to notice: a filter that goes with a player
  still on it counts as an unplugged device, and WirePlumber pauses the
  player. The conf is written only after that, so a reload cutting it short
  leaves it to be done again.
  They are WirePlumber smart filters: whatever goes to or comes from the
  device passes through them, and the device stays the default, so apps are
  best left on the system default. The shell plays its own sounds through
  PulseAudio (`QT_AUDIO_BACKEND=pulseaudio` in its unit): Qt's PipeWire
  backend pins its stream to the output and loses it when a filter comes or
  goes. Over IPC, `qs -c hyprmonk ipc call effects toggle <eq|night|correction|noise>`,
  `effects preset <name>`, `effects band <0-9> <dB>`,
  `effects strength <light|medium|strong>`,
  `effects threshold <0-95>`, `effects hold <0-1000>` and `effects status`.
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
- [x] Display > Brightness (`services/Brightness.qml`): each screen's own
  brightness and contrast, set in the monitor over DDC/CI with ddcutil (as its
  buttons would, and kept by it), read when the page opens. A write takes
  about a third of a second, so while a slider moves only the latest value
  waits. A screen that does not answer says so. Below that, dimming every
  screen at once (30 to 100%), through hyprsunset's colour matrix, kept in
  `brightness.json`. No gamma: Hyprland gives programs no gamma ramps, only a
  colour matrix, which cannot bend the curve. The brightness keys step the
  focused screen by 5% (every screen that answers, when it does not), go
  on into the dimming below its lowest and take that off first going up,
  each step shown on screen. Over IPC,
  `qs -c hyprmonk ipc call brightness set <screen> <0-100>`, `brightness step <-100-100>`,
  `brightness dim <30-100>` and `brightness status`.
- [x] Display > Night light (`services/NightLight.qml`): off, between set
  times or always, and its warmth, 2500 to 6000 K (5500 to begin with),
  with a guide below: six warmths, what each suits, the nearest marked, a
  click picking it.
  hyprsunset holds the colour, run by `hyprmonk-sunset` while the night
  light is on or the screens are dimmed (it starts at login only then, by a marker file in the state
  directory); the shell works out the warmth each minute and sends it with
  `hyprctl hyprsunset temperature`, or `identity` outside the set times.
  Between set times (20:00 to 07:00 to begin with, in quarter hours, round
  midnight or not) it fades in over half an hour from the start and out over
  the half hour before the end, in even steps of mireds (a million over the
  kelvin), which look even to the eye. Kept in `night-light.json` in the state
  directory. Also a row in quick actions. Over IPC,
  `qs -c hyprmonk ipc call nightlight mode <off|scheduled|always>` and
  `nightlight status`.
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
