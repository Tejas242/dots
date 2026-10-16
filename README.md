<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/header-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/header-light.svg">
  <img src="docs/header-dark.svg" alt="dots. cachyos · niri · noctalia · astronvim" width="560">
</picture>

<br>
<br>

<img src="docs/desktop.png" alt="A dark green desktop at 1366×768: a thin glass bar along the top with a workspace indicator on the left, a small island in the middle and quiet status on the right; Neovim's start screen on the left, fastfetch and cava stacked on the right, 4px corners and 6px gaps." width="100%">

<sub>workspace 3 · neovim, fastfetch, cava · 1366×768 · every colour taken from the wallpaper</sub>

<br>
<br>

A scrollable-tiling Wayland desktop for a two-core laptop with a small screen.<br>
Noctalia reads a palette off the wallpaper and writes it into everything else.<br>
The bar keeps quiet. The lock screen plays records.

<br>

<img src="docs/rule.svg" width="240" alt="">

</div>

<br>

## the bar

<picture>
  <source media="(prefers-reduced-motion: reduce)" srcset="docs/bar.png">
  <img src="docs/bar.gif" alt="The bar's left, centre and right at 2×: the long green workspace pill glides from one workspace to the next and back, then the pointer rests on the camera icon and the colour picker and clipboard slide out to its left." width="100%">
</picture>

<sub>left · centre · right at 2× · switching workspaces, then hovering the recorder · a real recording</sub>

A 22px strip of glass that stays out of the way, so the island in the middle can be the one live thing at the top of the screen.

- **workspaces** — a page indicator instead of numbers. The long pill is where you are, a light dot has windows, a dim dot is empty. The pill stretches and glides when you switch.
- **tools** — the colour picker, clipboard and tray fold into the screen recorder and slide out when you hover it. The recorder stays visible because it turns red while it records.
- **one ink** — icons sit a step quieter than numbers. Colour always means something: green is where you are, red is a busy CPU, a recording or a low battery.
- **one rhythm** — 5px between items, 18px between groups (tools · machine · connection), 10px at the ends. Nothing is boxed in a pill.
- **the middle** — empty on purpose. The island there is Ember, a separate project that isn't in this repo.
- **updates** — built only from Noctalia's own config keys, with no patches. Noctalia never rewrites `~/.config/noctalia`, so the bar survives updates.

<br>

## moving around

<picture>
  <source media="(prefers-reduced-motion: reduce)" srcset="docs/moving.png">
  <img src="docs/moving.gif" alt="A new terminal column opens on the right and the whole strip of windows scrolls left to make room, then scrolls back to Neovim, and the launcher opens over a frosted blur." width="100%">
</picture>

<sub>a new column scrolls the strip · back to the first column · the launcher over blur · a real recording</sub>

niri lays windows out on an endless horizontal strip, so opening one never squeezes the others: the strip scrolls instead. Its springs are stiff and critically damped, so motion is quick and never wobbles, and everything behind glass is blurred.

<br>

## the lock screen

<picture>
  <source media="(prefers-reduced-motion: reduce)" srcset="docs/lockscreen.png">
  <img src="docs/lockscreen.gif" alt="Locking up: a circle opens from the desktop onto a pixel-art night, a vinyl record drops in and spins the album art, the tonearm swings over, and the greeting types itself above a password field drawn as a key." width="100%">
</picture>

**Nocturne** is a lock-screen layout built from **Turntable**, a Noctalia plugin in this repo (1.5k lines of Luau).

- **record** — the current track's album art at 33⅓ rpm, with a tonearm that swings on and off. Labels are pre-rendered at 48 angles once per track and swapped by opacity, so spinning never decodes an image.
- **clock** — light hours over black minutes; every digit morphs outline-to-outline, breaking into dithered pixels halfway. Click the time to switch 12h / 24h.
- **key** — the password field dressed as a key, portrait on the bow. Click the bow to flip it and see how long the screen has been locked.
- **sky** — [screenager.dev](https://screenager.dev)'s pixel-art night, rendered by the site's own generator at exactly 1366×768.
- **cost** — ~30 updates a second while something moves, one a second when nothing does.

The plugin also ships `disc`, the same record 18px wide for a bar. Left click plays or pauses, right click skips, middle click goes back. This setup leaves it off, since the island shows the music.

<details>
<summary>rebuild the layout or the artwork</summary>

<br>

```sh
cd ~/.local/share/noctalia/plugins/turntable/tools

# place the widgets: rewrites [lockscreen] and [lockscreen_widgets]
python3 nocturne_layout.py ~/.local/state/noctalia/settings.toml

# record body and tonearm frames
python3 render_assets.py

# the night sky (needs the screenager.dev source and brave)
./render_night.sh [seed-hex]
```

Needs `python-pillow`, `python-numpy` and `busctl` (systemd). The layout is measured for one 1366×768 output named `eDP-1`.

</details>

<br>

## palette

<img src="docs/meadow.png" alt="The wallpaper: a pixel-art meadow with a man asleep in the grass beside a turquoise lake, under a forest. A thin bar along the top and fine green audio bars along the bottom edge." width="100%">

<img src="docs/palette.svg" alt="Palette: surface #0f150e, container #1b211a, outline #889484, on surface #dee5d8, primary #72dd71, secondary #a5d29e, tertiary #9ccaff, error #ffb4ab" width="100%">

Material tones (`m3-content`) that Noctalia pulled from the meadow above. They are not hard-coded: change the wallpaper and the bar, borders, terminals, btop, cava, GTK, Qt, Zen, VS Code, Zed, Obsidian and Neovim all change with it. Neovim repaints live on `SIGUSR1`.

<br>

## what's inside

Each folder mirrors `$HOME`.

| package | |
| :-- | :-- |
| **`niri`** | Compositor config split into `cfg/*.kdl`. 6px gaps, 4px corners, a 1px border in the palette colour, soft shadows, blur behind windows. `noctalia.kdl` is generated. |
| **`noctalia`** | Shell: a 22px glass bar, launcher, panels, notifications, idle and lid handling, theme templates. Includes the GUI-edited `settings.toml`. |
| **`turntable`** | The Noctalia plugin behind the lock screen and the bar's disc, plus its fonts (OFL). |
| **`nvim`** | AstroNvim v6. Everforest for code, wallpaper accents for the chrome, an animated start screen, CompetiTest for contests. |
| **`terminals`** | Alacritty (the one bound to a key), Kitty, Ghostty. Colours come from Noctalia. |
| **`zsh`** | CachyOS zsh config, a lean one-line Powerlevel10k, zoxide as `cd`. |
| **`tools`** | fastfetch, btop, cava, MangoHud. |
| **`git`** | Name, noreply email, `gh` as the credential helper. No tokens. |
| **`cp`** | Competitive-programming `template.cpp` and `debug.h`. |
| **`extras`** | Optional, never installed. See [below](#extras). |

<details>
<summary>neovim</summary>

<br>

- **start screen** — the SCREENAGER mark in a primary → tertiary gradient that a light sweeps across once, a greeting for the time of day, three recent files, the song playing, plugin count, startup time, git branch.
- **colours** — Everforest (hard, transparent) owns syntax. Floats, borders, the cursor line number and the indent scope follow the wallpaper; `SIGUSR1` swaps in the full Matugen base16 palette without a restart.
- **contests** — CompetiTest listens for Competitive Companion from launch and files problems as `<contest>/<A>.cpp` for Codeforces and AtCoder. clangd for C++, with Tree-sitter for the first C++ buffer deferred one tick so a contest file opens instantly.

| keys | |
| :-- | :-- |
| <kbd>Space</kbd> <kbd>r</kbd> <kbd>i</kbd> / <kbd>c</kbd> | receive problem / contest |
| <kbd>Space</kbd> <kbd>r</kbd> <kbd>r</kbd> | run test cases |
| <kbd>Space</kbd> <kbd>r</kbd> <kbd>a</kbd> / <kbd>e</kbd> | add / edit a test case |

</details>

<details>
<summary>noctalia</summary>

<br>

- **bar** — see [the bar](#the-bar). 55% opacity over niri's blur, laid out in `bar.toml`, tuned in `widgets.toml`.
- **settings** — the Settings window saves to `~/.local/state/noctalia/settings.toml`, which wins over the files. Bar changes belong in `bar.toml`, so the files stay the truth.
- **pop-ups** — the volume, brightness and media OSDs are off, because the island shows them.
- **idle** — lock at 10 min, screen off at 11, suspend at 30. Closing the lid locks and suspends.
- **templates** — built-in: alacritty, btop, cava, gtk3, gtk4, niri, qt. Community: claude-code, codex, zen-browser, obsidian, vscode, zed, fastfetch, zathura. Own: VS Code Insiders and Neovim.
- **state** — `noctalia-state-watch.sh` (autostarted by niri) commits every write of `settings.toml` to a local git repo in `~/.local/state/noctalia`. Needs `inotify-tools`.

</details>

<br>

## install

```sh
git clone https://github.com/Tejas242/dots ~/dots
cd ~/dots
./install.sh --deps        # pacman + AUR packages, then every package into $HOME
```

```sh
./install.sh               # every package, no system packages
./install.sh nvim zsh      # only the ones you name
```

Files are **copied**, not symlinked: Noctalia rewrites `settings.toml` atomically, which would replace a symlink. Anything that would be overwritten moves to `~/.dots-backup/<timestamp>/` first. Then log out and back in.

On first start:

1. Noctalia renders its templates from the wallpaper (`noctalia.kdl`, terminal themes, `nvim/lua/matugen.lua`).
2. `nvim` bootstraps lazy.nvim and installs plugins.
3. Wallpaper paths in `theme.toml` and `settings.toml` are absolute (`/home/screenager/…`). Point them at your own home, or pick a wallpaper in Noctalia's settings.
4. The bar uses two third-party Noctalia plugins that aren't in this repo: `oldirtty/color_picker` and `noctalia/screen_recorder`. Install them or drop them from `bar.toml`.
5. The middle of the bar is left empty for Ember. Without it, that stretch is plain glass.

<details>
<summary>packages</summary>

<br>

**`--deps` installs** &nbsp; `niri` `zsh` `zoxide` `neovim` `ripgrep` `fd` `git` `gcc` `rsync` `python-pillow` `python-numpy` `alacritty` `kitty` `ghostty` `fastfetch` `btop` `cava` `mangohud`, and `noctalia-git` from the AUR (via `paru` or `yay`).

**used by the configs, not installed** &nbsp; `cachyos-zsh-config` `zsh-theme-powerlevel10k` `ttf-jetbrains-mono-nerd` `ttf-roboto` `inotify-tools` `gpu-screen-recorder` `zen-browser` `youtube-music` `nautilus`

</details>

<br>

## keys

<details>
<summary>niri · <kbd>Mod</kbd> is Super · <kbd>Mod</kbd> <kbd>Shift</kbd> <kbd>Esc</kbd> lists all of them</summary>

<br>

| keys | |
| :-- | :-- |
| <kbd>Mod</kbd> <kbd>Return</kbd> | terminal |
| <kbd>Mod</kbd> <kbd>A</kbd> | launcher |
| <kbd>Mod</kbd> <kbd>B</kbd> · <kbd>M</kbd> · <kbd>E</kbd> | browser · music · files |
| <kbd>Mod</kbd> <kbd>H</kbd> <kbd>J</kbd> <kbd>K</kbd> <kbd>L</kbd> | focus column left · window down · window up · column right |
| <kbd>Mod</kbd> <kbd>Ctrl</kbd> <kbd>H</kbd> <kbd>J</kbd> <kbd>K</kbd> <kbd>L</kbd> | move them |
| <kbd>Mod</kbd> <kbd>1</kbd>–<kbd>9</kbd> | workspace |
| <kbd>Mod</kbd> <kbd>Ctrl</kbd> <kbd>1</kbd>–<kbd>9</kbd> | send column to workspace |
| <kbd>Mod</kbd> <kbd>Tab</kbd> | previous workspace |
| <kbd>Mod</kbd> + wheel | workspaces; with <kbd>Shift</kbd>, columns |
| <kbd>Mod</kbd> <kbd>-</kbd> / <kbd>=</kbd> | column width ∓10%; with <kbd>Shift</kbd>, window height |
| <kbd>Mod</kbd> <kbd>C</kbd> | centre column |
| <kbd>Mod</kbd> <kbd>Ctrl</kbd> <kbd>F</kbd> | fill the available width |
| <kbd>Mod</kbd> <kbd>W</kbd> | tabbed column |
| <kbd>Mod</kbd> <kbd>T</kbd> · <kbd>F</kbd> | float · fullscreen |
| <kbd>Mod</kbd> <kbd>O</kbd> | overview |
| <kbd>Mod</kbd> <kbd>Q</kbd> | close window |
| <kbd>Mod</kbd> <kbd>Alt</kbd> <kbd>L</kbd> | lock |
| <kbd>Mod</kbd> <kbd>Shift</kbd> <kbd>Q</kbd> | session menu |
| <kbd>Ctrl</kbd> <kbd>Shift</kbd> <kbd>1</kbd> · <kbd>2</kbd> · <kbd>3</kbd> | screenshot region · screen · window |
| <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>Delete</kbd> | quit niri |

</details>

<br>

## sync

Edit configs where they live, then pull them back into the repo:

```sh
cd ~/dots
./sync.sh                  # or: ./sync.sh nvim noctalia
git add -A && git commit -m "sync" && git push
```

The `PACKAGES` table at the top of `sync.sh` is the list of tracked paths; add one there to start tracking it. On the way in, `sync.sh` swaps the git email for the GitHub noreply address and blanks the weather location.

<br>

## extras

`extras/niri/nocturne.kdl` is a heavier niri overlay, tuned for a Vega 3:

- windows open by growing out of a small pill into a card, and close like a CRT switching off (custom shaders)
- slightly under-damped springs, so motion lands softly
- a `#72dd71 → #8fd3c8` gradient focus ring, 6px corners, blur only behind terminals

Copy it next to `config.kdl` and add `include "./nocturne.kdl"` as the last line. Remove the line to undo.

<br>

<div align="center">

<img src="docs/rule.svg" width="240" alt="">

<br>
<br>

<sub>
<a href="https://github.com/YaLTeR/niri">niri</a> ·
<a href="https://github.com/noctalia-dev/noctalia">noctalia</a> ·
<a href="https://github.com/AstroNvim/AstroNvim">astronvim</a> ·
wallpaper from a GitHub collection that doesn't know who painted it either
</sub>

<br>

<sub>the long version, with a rubber duck: <a href="https://screenager.dev/setup">screenager.dev/setup</a></sub>

</div>
