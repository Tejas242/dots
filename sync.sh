#!/usr/bin/env bash
# Copy the live configs on this machine into the repo (one-way: $HOME -> repo).
# Each package mirrors $HOME, so install.sh can link it straight back.
#
#   ./sync.sh          refresh every package
#   ./sync.sh nvim     refresh only the listed packages
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$HOME"

# package : paths relative to $HOME (files or directories)
declare -A PACKAGES=(
  [niri]=".config/niri"
  [noctalia]=".config/noctalia/bar.toml .config/noctalia/services.toml .config/noctalia/shell.toml
              .config/noctalia/theme.toml .config/noctalia/widgets.toml .config/noctalia/templates
              .local/state/noctalia/settings.toml .local/bin/noctalia-state-watch.sh"
  [turntable]=".local/share/noctalia/plugins/turntable .local/share/fonts/nocturne"
  [nvim]=".config/nvim"
  [zsh]=".zshrc .zshenv .p10k.zsh"
  [git]=".gitconfig .config/git/ignore"
  [terminals]=".config/alacritty/alacritty.toml .config/kitty/kitty.conf .config/ghostty/config"
  [tools]=".config/fastfetch .config/btop/btop.conf .config/cava/config .config/MangoHud/MangoHud.conf"
  [cp]="CP/lib/template.cpp CP/lib/debug.h"
)

# never copied: VCS data, logs, backups, caches, generated plugin data
EXCLUDES=(--exclude=.git --exclude='*.log' --exclude='*.bak' --exclude='*.bak.*' --exclude='*.old'
          --exclude='__pycache__' --exclude='plugins/turntable/data')

selected=("$@")
[ ${#selected[@]} -eq 0 ] && selected=("${!PACKAGES[@]}")

for pkg in "${selected[@]}"; do
  [ -n "${PACKAGES[$pkg]+x}" ] || { echo "unknown package: $pkg" >&2; exit 1; }
  for path in ${PACKAGES[$pkg]}; do
    if [ ! -e "$path" ]; then
      echo "  skip  $pkg/$path (missing)"
      continue
    fi
    mkdir -p "$REPO/$pkg/$(dirname "$path")"
    if [ -d "$path" ]; then
      rsync -a --delete "${EXCLUDES[@]}" "$path/" "$REPO/$pkg/$path/"
    else
      rsync -a "$path" "$REPO/$pkg/$path"
    fi
  done
  echo "synced  $pkg"
done
