#!/bin/sh
# Print the most relevant MPRIS player as one JSON object (Playing > Paused > first).
# Uses only busctl (systemd), so there is nothing extra to install.
best="" best_rank=9 best_status="Stopped"
for p in $(busctl --user list --no-legend --no-pager 2>/dev/null | awk '$1 ~ /^org\.mpris\.MediaPlayer2\./ {print $1}'); do
  st=$(busctl --user get-property "$p" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player PlaybackStatus 2>/dev/null | awk -F'"' '{print $2}')
  case "$st" in Playing) r=0 ;; Paused) r=1 ;; *) r=2 ;; esac
  if [ "$r" -lt "$best_rank" ]; then best=$p best_rank=$r best_status=$st; fi
done
if [ -z "$best" ]; then
  echo '{"status":"None"}'
  exit 0
fi
meta=$(busctl --user get-property "$best" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Metadata --json=short 2>/dev/null)
pos=$(busctl --user get-property "$best" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Position 2>/dev/null | awk '{print $2}')
printf '{"status":"%s","player":"%s","position":%s,"metadata":%s}\n' \
  "$best_status" "$best" "${pos:-0}" "${meta:-null}"
