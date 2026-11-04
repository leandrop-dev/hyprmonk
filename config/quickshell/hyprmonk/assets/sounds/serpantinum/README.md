# Serpantinum's sounds

Copied from [serpantinum](https://github.com/ilyamiro/serpantinum) at commit
94cfef81bfa1863ce15d0243727087fd6552ebc0 (src/assets/sounds), under its
licence, the GNU AGPL 3.0 or later (LICENSE here). The rest of hyprmonk stays
MIT; these files are only played, never built into anything.

Serpantinum names no author for its sounds. Two carry tags naming
"Brukowskij" (open.wav: "UI click - soft wet"; close.wav: "UI - small
selection click"), so they may come from elsewhere.

What changed: each file was converted to mono 16-bit WAV with ffmpeg (Qt's
SoundEffect plays WAV), keeping its tags, and renamed for what it does here:

| Here | Serpantinum |
| --- | --- |
| click.wav | reusables/clickbutton/click.wav |
| on.wav, off.wav | reusables/switch/sfx.wav |
| open.wav | guide/barconfig/in.wav |
| close.wav | guide/barconfig/out.wav |
| connect.wav | network/connect.wav |
| disconnect.wav | network/disconnect.wav |
| tones/*.wav | notifications/* (four were MP3) |
| notify.wav | a link to tones/Botanica.wav |
