# Screen recording: what could come next

Ideas for later. Today `hyprmonk record` takes the focused screen
(`crates/hyprmonk/src/recording.rs`) or a region, and `services/Recorder.qml`
starts it, stops it and keeps the area and the two sound switches, which sit
under Recording in quick actions. What the recorder can do was read from the
`gpu-screen-recorder` manual, version 6.1.6; nothing below has been tried yet.

## The plan

Record area in quick actions gains Window beside Screen and Region.
Super+Shift+R keeps starting at once with the last settings.

In the order to build them:

1. **Replay and pause.** Replay keeps the last seconds in memory (`-r
   seconds`) and saves them on a key, which suits game mode. SIGUSR2 pauses
   and resumes; a right click on the bar's dot could do it.
2. **A window.** The last, because of the catch below.

## To check first

- **A window goes through the portal.** Direct window capture is X11 only, so
  on Wayland it is `-w portal`, with a picker dialog. Whether that keeps the
  Vulkan encoder on the 1070 Ti, and what it costs, has to be measured.

## Smaller ideas

- Sound from one app only (`-a app:name`), to record a game without Discord
  or music.
- A short countdown, so the card that started it is not in the first frame.

Trimming is left out: that is a video editor's job.
