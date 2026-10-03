#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# noctalia-state-watch.sh
# Watches ~/.local/state/noctalia/settings.toml for writes and auto-commits
# to git so you always have a recoverable history.
#
# Run once at login via niri autostart. Requires: inotify-tools
# ─────────────────────────────────────────────────────────────────────────────

STATE_FILE="$HOME/.local/state/noctalia/settings.toml"
STATE_DIR="$HOME/.local/state/noctalia"
LOG="$HOME/.cache/noctalia/state-watch.log"
DEBOUNCE=3  # seconds — batch rapid writes into one commit

mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

# Ensure git is set up
cd "$STATE_DIR" || exit 1
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    git init
    git add settings.toml
    git commit -m "init: bootstrap state-watch"
fi

log "state-watch started, watching $STATE_FILE"

# inotifywait loop — CLOSE_WRITE fires when Noctalia finishes writing
inotifywait -m -e close_write --format '%f' "$STATE_DIR" 2>/dev/null | while read -r file; do
    [[ "$file" != "settings.toml" ]] && continue

    # Debounce: wait for rapid successive writes to settle
    sleep "$DEBOUNCE"

    # Drain any pending events during debounce (inotifywait is non-blocking here)
    if git diff --quiet HEAD -- settings.toml 2>/dev/null; then
        log "no change detected, skipping commit"
        continue
    fi

    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    git add settings.toml
    git commit -m "auto: settings.toml updated at $TIMESTAMP" >> "$LOG" 2>&1
    log "committed settings.toml ($(git rev-parse --short HEAD))"
done
