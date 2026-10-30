# Screen recording: what could come next

Today `hyprmonk record` takes the focused screen, a region or the focused
window (`crates/hyprmonk/src/recording.rs`), and `services/Recorder.qml`
starts it, pauses it, stops it and keeps the area and the two sound switches,
which sit under Recording in quick actions. `hyprmonk replay` keeps the last
minute. What the recorder can do was read from the `gpu-screen-recorder`
manual, version 6.1.6.

## A window's limits

Measured 2026-10-30 on the 1070 Ti, through the portal (`-w portal`), since
direct window capture is X11 only. It keeps the Vulkan encoder: 2536x1008 at
60 frames a second for 10.8% of a core, against about 25% for the screen. A
window on a workspace not showing records, and moving one between workspaces
changes nothing.

A window that changes size or closes freezes the picture for good, while the
recorder runs on and the file stays valid. Growing logs an allocation error,
shrinking nothing beyond the stream leaving `streaming`, and closing nothing
at all. So the shell ends the recording there. Opening a window on a tiled
workspace resizes its neighbours, and with them the recording.

## Smaller ideas

Nothing here has been tried yet.

- Following a window through a change of size, if a later recorder or portal
  allows it.
- Sound from one app only (`-a app:name`), to record a game without Discord
  or music.
- A short countdown, so the card that started it is not in the first frame.

Trimming is left out: that is a video editor's job.
