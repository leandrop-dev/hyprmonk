# Games from Zendo: window rules

Asked from a Zendo session on 2026-11-06 and done the same day; see "What
was done" at the end. Zendo (the game
launcher, `~/Projects/zendo`) starts Windows games through umu-launcher and
Proton; Hyprland tiles their windows like any other, and some games keep the
size they were given as their own setting.

## What was seen

- Cat Quest (Epic, a Unity game) opened as a tile and saved that tile's size
  as its resolution: windowed, 235x465 (`Screenmanager Resolution Width` and
  `Height` in the prefix's `user.reg`). From then on it drew itself at that
  size, cropped even inside gamescope full screen, and its own Quit button
  was out of sight. Unity games keep their screen settings that way, so any
  of them can do the same.
- Other Epic games opened as tiles too; maximising them, or going full screen
  in the game, worked.
- Super+Q (`hl.dsp.window.close()`) on a game run inside gamescope closes
  gamescope's window, and gamescope then kills the game at once ("Parent of
  gamescopereaper was killed. Killing children."), so the game saves nothing
  it had not saved already. On a game's own window, close asks it politely,
  as its X button would.

## What to do here

A window rule for games, so they open floating and centred at the size they
ask for (or full screen), never squeezed into a tile. Something like the
satty rule in `config/hypr/rules.lua`:

```lua
hl.window_rule({
    name  = "games",
    match = { class = "^(steam_app_.*|gamescope)$" },
    float = true,
    center = true,
    tag   = "-hyprmonk-floating",
})
```

Whether it should float or go full screen, and whether the Floating layout's
tag handling needs it, is for here to decide.

## To check first

- The class. Proton's Wine names a game's windows `steam_app_<SteamGameId>`,
  and umu sets `SteamGameId` from Zendo's `GAMEID`: `steam_app_593280` for a
  game umu's database knows (`umu-593280`), `steam_app_default` for one it
  does not (`umu-default`). That comes from reading umu's `umu_run.py`
  (`SteamGameId = SteamAppId`, the part after `umu-`), not from a running
  game: confirm with `hyprctl clients` while one runs from Zendo. Games run
  inside gamescope show as `gamescope`; Steam's own Proton games are
  `steam_app_<appid>` already.
- Native Linux games have classes of their own and are not caught by this.
- A game that already saved a tiny size (Cat Quest) keeps it until told
  otherwise: in Zendo, its launch options' Arguments
  `-screen-fullscreen 1 -screen-width 1920 -screen-height 1080` (Unity's own),
  or deleting its `Screenmanager` values from the prefix's `user.reg`.

## What was done

- `config/hypr/rules.lua`, rule `games`: `steam_app_*` and `gamescope`
  windows float, centred at the size the game asks for, and drop the
  Floating layout's tag so they stay floating when it ends. Floating, not
  forced full screen, so launcher and settings windows are not stretched; a
  game asking for full screen still gets it.
- `config/hypr/floating.lua`: the Floating layout's float-everything rule
  leaves games out (`negative:` match), or it would give them 60% by 70% of
  the screen, a size a Unity game would then save.
- `config/hypr/rules.lua`, rule `zendo`: Zendo's windows float, centred. Zendo
  now sets its application id, so they are class `zendo`.
- Classes checked from Zendo while each game ran: 10 Second Ninja X
  `steam_app_435790` and Costume Quest `steam_app_default` (both XWayland),
  Cat Quest inside gamescope `gamescope`.
- Not changed: Super+Q on a gamescope game still closes gamescope and kills
  the game. Zendo's Stop asking the windows to close first is its own idea to
  take up.
