# Translations

The shell speaks English or Portuguese (Portugal), picked for each account in
Settings > Language and input. The shell changes at once; the account's apps
(GTK, Qt, the terminal) follow from the next login. One person can keep
English while another, on their own account, has Portuguese.

Until a language is picked, the shell follows the account's `LANG`:
`pt_PT.UTF-8` gives Portuguese (Portugal), and so does another Portuguese,
such as `pt_BR`; anything else gives English.

## Where the files are

| File | What |
|------|------|
| `config/quickshell/hyprmonk/i18n/pt_PT.json` | The Portuguese translations, one entry per text |
| `config/quickshell/hyprmonk/i18n/check.sh` | Checks a translation file against the shell |
| `config/quickshell/hyprmonk/services/I18n.qml` | The lookup, and the list of languages |
| `config/uwsm/env` | Reads `language.env` at login, so the apps get the language |
| `~/.local/state/hyprmonk/language.json` | This account's choice |
| `~/.local/state/hyprmonk/language.env` | `LANG` and `LANGUAGE` for this account's apps; there only when the language is not English |

The repo's files are the config: `~/.config/quickshell/hyprmonk/i18n/` is the
same folder as the clone's, so editing either edits both.

## How a translation file is written

A flat JSON object, its keys sorted. Each key is the English text exactly as
the shell has it, and each value is what to show instead:

```json
{
  "Do not disturb": "Não incomodar",
  "Fetched at %1, and every 15 minutes": "Obtido às %1, e a cada 15 minutos",
  "MMMM yyyy": "MMMM 'de' yyyy",
  "tones|Light": "Claros"
}
```

- **`%1`, `%2`** are filled in by the shell: a time, a name, a number. Keep
  each one, in whatever place the sentence needs.
- **`\n`** starts a new line, as in `"Bluetooth\nNothing connected"`.
- **`context|text`** keys are for an English word with two meanings. "Light"
  is both a strength (Leve) and the heading over the light tones
  (`tones|Light`, Claros). The plain key is used wherever there is no context
  key.
- **Date formats** are keys too: `MMMM yyyy` (the calendar's month),
  `dddd d MMMM` (its day line) and `dddd dd · MMMM` (the lock screen). They
  use Qt's date letters, with literal words in single quotes (`'de'`). Month
  and day names come from the language itself.
- **Proper names** that stay the same (AutoEQ, Wi-Fi, SSH, hyprmonk) map to
  themselves. That keeps them from being reported as missing.
- **A text missing from the file** shows in English.

## Correcting a translation

1. Change the value in `i18n/pt_PT.json`; never change the key.
2. Save. The shell reads the file again as it is saved, so the change shows
   at once.
3. Run `config/quickshell/hyprmonk/i18n/check.sh` to make sure the file still
   matches.

A file that is not valid JSON is not loaded: the shell keeps the last good
one and writes a warning to its log
(`journalctl --user -u hyprmonk-shell`).

To keep the file sorted after editing by hand:

```sh
cd ~/.config/quickshell/hyprmonk/i18n
jq -S . pt_PT.json > pt_PT.sorted && mv pt_PT.sorted pt_PT.json
```

## Finding what is not translated

- `i18n/check.sh [code]` (default `pt_PT`) prints:
  - **Missing:** texts the shell has that the file lacks.
  - **Unused:** entries in the file that nothing in the shell shows any more.
  - **Unwrapped:** QML text properties that hold a plain literal rather than
    going through the lookup. Some of these are only numbers, times or names,
    which stay as they are.
- `qs -c hyprmonk ipc call language missing` lists the texts the running
  shell has shown untranslated since it started. Open every page and panel
  first, so the list is complete.

The key guide's sections and descriptions come from `config/hypr/binds.lua`
(`"Section: description"`). `check.sh` reads them from the running Hyprland,
so run it inside a session.

## Adding a new text to the shell

Every text the shell shows goes through `I18n` (`services/I18n.qml`), keyed by
its English:

| Call | For |
|------|-----|
| `I18n.tr("Save")` | A text shown as it is |
| `I18n.tr("Pair with %1?", name)` | A sentence with something filled in |
| `I18n.trn("%1 window", "%1 windows", count)` | A count: the first for 1, the second otherwise (0 too) |
| `I18n.trc("tones", "Light")` | A word whose English has two meanings, translated as `tones\|Light` |
| `I18n.mark("Display")` | Text kept in English as data (a page's name, a label in a list), translated with `I18n.tr(…)` where it shows |

The rules:

- **Translate where the text is shown, never in data.** Ids, saved settings,
  IPC values and keys stay English.
- **Use whole sentences with placeholders, not pieces.** Write
  `I18n.tr("Fetched at %1, and every 15 minutes", time)`, not
  `"Fetched at " + time + …`, since another language may need a different
  word order.
- **Keep glyphs outside the text:** `"\u{F0415}  " + I18n.tr("Add an event")`.
- **Only plain double-quoted literals go inside the call**, so `check.sh` can
  find them.
- **Import the lookup:** a file that uses `I18n` imports `qs.services`.

Then run `check.sh` for each language: the new text shows as missing.
Translate it in each file.

## Adding a language

Spanish (Spain) as the example, `es_ES`:

1. **List it** in `languages` in `services/I18n.qml`:

   ```qml
   { code: "es_ES", name: "Español (España)", locale: "es_ES", lang: "es_ES.UTF-8" }
   ```

   - **`name`** is written in the language itself, and never translated.
   - **`locale`** gives the month and day names.
   - **`lang`** is the `LANG` the account's apps get.

   The chip in Settings > Language and input, the `LANG` it follows and the
   apps' `language.env` all come from this line.
2. **Start its file** from the Portuguese one, then translate every value
   (the keys stay English):

   ```sh
   cd ~/.config/quickshell/hyprmonk/i18n
   cp pt_PT.json es_ES.json
   ```

   Or start from `{}` and let `./check.sh es_ES` list every text as missing.
3. **Check it:** run `./check.sh es_ES` until nothing is missing or unused.
4. **Try it:** run `qs -c hyprmonk ipc call language set es_ES`, open every
   page and panel, then run `qs -c hyprmonk ipc call language missing`.
5. **For the apps,** the system must have the locale generated. When it has
   not, Settings > Language and input shows the two commands to run in a
   terminal: uncomment the line in `/etc/locale.gen`, then
   `sudo locale-gen`.

The calendar follows on its own:
- Weekday initials take two letters in English and three in other
  languages.
- When the language's country is the calendar's country (`pt_PT` with
  Portugal), holidays show their local names first.

## What stays as it comes

These are not the shell's to translate:

- **App names:** they follow `LANG` already.
- **Device, network and keyboard layout names.**
- **Messages from outside the shell:** the text of other apps'
  notifications, and polkit's own messages.

These are not translated yet:

- The `hyprmonk` command's and the installer's output.
- The login screen, which is the same for every account.

## Other accounts

Each account keeps its own language, in its own state folder. A second
account needs hyprmonk installed for it: home folders are private (`700`),
so it cannot use the clone in another person's home.
