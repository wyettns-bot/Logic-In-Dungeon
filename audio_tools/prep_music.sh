#!/bin/sh
# prep_music.sh SRC OUT [noloop-trim]: trim silence at both ends, level to -16 LUFS, write Ogg Vorbis
SRC="$1"; OUT="$2"
TRIM="silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.05,areverse,silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.25,areverse"
[ "$3" = "seamless" ] && TRIM="anull"          # already a perfect loop: leave its ends alone
M=$(ffmpeg -hide_banner -i "$SRC" -map 0:a -af "$TRIM,loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" -f null - 2>&1 | sed -n '/^{/,/^}/p')
g() { echo "$M" | grep "\"$1\"" | sed -E 's/.*: "([^"]+)".*/\1/'; }
ffmpeg -hide_banner -loglevel error -y -i "$SRC" -map 0:a -af "$TRIM,loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=$(g input_i):measured_TP=$(g input_tp):measured_LRA=$(g input_lra):measured_thresh=$(g input_thresh):offset=$(g target_offset):linear=true,aresample=44100" -c:a libvorbis -q:a 6 "$OUT"
