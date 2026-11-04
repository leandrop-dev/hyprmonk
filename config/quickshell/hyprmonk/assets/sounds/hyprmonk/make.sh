#!/usr/bin/env bash
# hyprmonk's own interface sounds, made from sine waves with ffmpeg, so they
# are under the repo's MIT licence. Run this to remake them after changing a
# recipe: each is t (seconds) -> sample, at 48 kHz, written as 16-bit WAV,
# the format Qt's SoundEffect plays.
set -euo pipefail
cd "$(dirname "$0")"

make() {
    local name=$1 seconds=$2 expression=$3
    ffmpeg -loglevel error -y -f lavfi -i "aevalsrc='$expression':d=$seconds:s=48000" -c:a pcm_s16le "$name.wav"
}

# A note starting at `at` seconds, fading at `decay` per second.
note() {
    local hz=$1 at=$2 decay=$3 level=$4
    echo "$level*sin(2*PI*$hz*(t-$at))*exp(-$decay*(t-$at))*gte(t,$at)"
}

# A short tick: a high and a low sine, gone in 60 ms.
make click 0.06 "min(1,t/0.002)*(0.30*sin(2*PI*1800*t)+0.12*sin(2*PI*900*t))*exp(-t*90)"

# Switches: two notes, rising for on and falling for off.
make on 0.22 "min(1,t/0.002)*(0.25*sin(2*PI*880*t)*exp(-45*t)*lt(t,0.07)+$(note 1320 0.06 30 0.25))"
make off 0.22 "min(1,t/0.002)*(0.25*sin(2*PI*1320*t)*exp(-45*t)*lt(t,0.07)+$(note 880 0.06 30 0.25))"

# Cards: a soft sweep, up as one opens and down as it closes.
make open 0.14 "0.22*sin(PI*t/0.14)*sin(2*PI*(400*t+500*t*t/(2*0.14)))"
make close 0.14 "0.22*sin(PI*t/0.14)*sin(2*PI*(900*t-500*t*t/(2*0.14)))"

# A notification: a two-note chime, each note with its octave.
make notify 0.6 "min(1,t/0.003)*((0.22*sin(2*PI*1318.5*t)+0.06*sin(2*PI*2637*t))*exp(-9*t)*lt(t,0.12)+$(note 1975.5 0.11 7 0.22)+$(note 3951 0.11 7 0.06))"

# A device connecting or going: three notes of a major chord, up or down.
make connect 0.45 "min(1,t/0.002)*($(note 1046.5 0 14 0.2)+$(note 1318.5 0.08 14 0.2)+$(note 1568 0.16 10 0.2))"
make disconnect 0.45 "min(1,t/0.002)*($(note 1568 0 14 0.2)+$(note 1318.5 0.08 14 0.2)+$(note 1046.5 0.16 10 0.2))"
