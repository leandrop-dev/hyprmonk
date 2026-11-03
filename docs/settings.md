# Settings

A centred card (Super+comma, or quick actions > Settings) with its pages down
the side. Ideas from noctalia, Ryoku and Shibumi Shell,
no code from them.

The Display, Windows and Bar pages keep to `settings.json` in the state
directory, holding only what was changed, so the rest follows the repo's config.
Hyprland options are also written to `settings.lua`, loaded after `look.lua`, and
applied at once with `hyprctl eval`.

## Pages

- [x] Windows: gaps, border size, rounding, blur size and passes.
- [x] Appearance (was Tone, and quick actions' Appearance, Spectrum, Fastfetch
  and Login look rows): the tone, shown while the pointer is over it; the
  saved tone's card opacity, blur behind the cards on or off, and text colour,
  which apps follow too, kept per tone in `appearance.json` with a reset; the
  spectrum's style, also shown under the pointer; fastfetch's look; the login
  screen's look. The page scrolls. How strong blur is stays on the Windows
  page: Hyprland has one strength for everything.
- [x] Bar: drag modules to reorder them, move them between the left and right
  cards, or hide them. A panel opens under the card holding its module.
  Recording and Replay cannot be hidden, and the centre card stays as it is:
  its fitting rules depend on it.
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
