#!/usr/bin/env bash
# Restore packages from this repo into $HOME (repo -> $HOME).
#
#   ./install.sh                 install every package
#   ./install.sh nvim zsh        install only the listed packages
#   ./install.sh --deps          also install the Arch/CachyOS packages first
#
# Files are copied, not symlinked: Noctalia rewrites settings.toml atomically,
# which would silently replace a symlink. Anything that would be overwritten is
# moved to ~/.dots-backup/<timestamp>/ first, so nothing is ever lost.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.dots-backup/$STAMP"

DEPS=(niri zsh zoxide neovim ripgrep fd git gcc rsync python-pillow python-numpy
      alacritty kitty ghostty fastfetch btop cava mangohud)
AUR_DEPS=(noctalia-git)

want_deps=0
selected=()
for arg in "$@"; do
  case "$arg" in
    --deps) want_deps=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) selected+=("$arg") ;;
  esac
done

if [ "$want_deps" -eq 1 ]; then
  sudo pacman -S --needed "${DEPS[@]}"
  if command -v paru >/dev/null; then paru -S --needed "${AUR_DEPS[@]}"
  elif command -v yay >/dev/null; then yay -S --needed "${AUR_DEPS[@]}"
  else echo "install ${AUR_DEPS[*]} from the AUR manually"; fi
fi

if [ ${#selected[@]} -eq 0 ]; then
  for d in "$REPO"/*/; do
    name="$(basename "$d")"
    [ "$name" = extras ] || selected+=("$name")
  done
fi

for pkg in "${selected[@]}"; do
  src="$REPO/$pkg"
  [ -d "$src" ] || { echo "unknown package: $pkg" >&2; exit 1; }
  while IFS= read -r -d '' file; do
    rel="${file#"$src"/}"
    dest="$HOME/$rel"
    if [ -e "$dest" ] && ! cmp -s "$file" "$dest"; then
      mkdir -p "$BACKUP/$(dirname "$rel")"
      mv "$dest" "$BACKUP/$rel"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a "$file" "$dest"
  done < <(find "$src" -type f -print0)
  echo "installed  $pkg"
done

if [[ " ${selected[*]} " == *" turntable "* ]]; then
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
fi
[ -d "$BACKUP" ] && echo "previous files saved in $BACKUP"
echo "done. Log out and back in (or restart niri) to pick everything up."
