# Screen recording: what could come next

Ideas for later, none started. Today `hyprmonk record` takes the focused
screen with the system's sound (`crates/hyprmonk/src/recording.rs`), and
`services/Recorder.qml` starts it and stops it. What the recorder can do was
read from the `gpu-screen-recorder` manual, version 6.1.6; nothing here has
been tried yet.

## The plan

`Screen recording` in quick actions opens its options in the same card, as
Power profile does: what to record (Screen, Region, Window), and the system's
sound and the microphone as two switches that are remembered. Super+Shift+R
keeps starting at once with the last settings.

In the order to build them:

1. **Sound and microphone switches.** The easiest and the most used. No sound
   leaves out `-a`; both together is `-a "default_output|default_input"`.
2. **A region.** `-w region -region WxH+X+Y`, picked with slurp as screenshots
   do.
3. **Replay and pause.** Replay keeps the last seconds in memory (`-r
   seconds`) and saves them on a key, which suits game mode. SIGUSR2 pauses
   and resumes; a right click on the bar's dot could do it.
4. **A window.** The last, because of the catch below.

## To check first

- **A window goes through the portal.** Direct window capture is X11 only, so
  on Wayland it is `-w portal`, with a picker dialog. Whether that keeps the
  Vulkan encoder on the 1070 Ti, and what it costs, has to be measured.
- **Vulkan with a region.** Only the whole screen has been tested so far.

## Smaller ideas

- Sound from one app only (`-a app:name`), to record a game without Discord
  or music.
- A short countdown, so the card that started it is not in the first frame.

Trimming is left out: that is a video editor's job.
