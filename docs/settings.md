# Settings

A centred card (Super+comma, or quick actions > Settings) with its pages down
the side, built a page at a time. Ideas from noctalia, Ryoku and Shibumi Shell,
no code from them.

The Windows and Bar pages keep to `settings.json` in the state directory, holding
only what was changed, so the rest follows the repo's config. Hyprland options are also
written to `settings.lua`, loaded after `look.lua`, and applied at once with
`hyprctl eval`.

## Pages

- [x] Windows: gaps, border size, rounding, blur size and passes.
- [x] Tone: card opacity, blur behind the cards on or off, and text colour, which
  apps follow too. Kept per tone in `appearance.json`, with a reset. How strong
  blur is stays on the Windows page: Hyprland has one strength for everything.
- [x] Bar: drag modules to reorder them, move them between the left and right
  cards, or hide them. A panel opens under the card holding its module.
  Recording and Replay cannot be hidden, and the centre card stays as it is:
  its fitting rules depend on it.
- [ ] Display: resolution, refresh rate and scale. A change reverts after 15
  seconds unless kept, so a bad mode cannot leave the screen unusable.
