#!/usr/bin/env bash
# Render screenager.dev's night header as the lock screen wallpaper (assets/night.png).
#
#   tools/render_night.sh [seed-hex]      default 5eed0001; try others from the site's
#                                         "new night" button (?night=<hex> in the URL)
#
# Bundles the site's own generator (src/lib/night) so sky, ridges, rooftops and the
# dither palette stay identical, with one lock-screen patch: Saturn is left out
# (the record is the round thing on this screen). SATURN=1 keeps a small one at
# top centre instead. Renders headless (SwiftShader
# WebGL2) at 1366x768 with reduced motion, so the intro is skipped.
set -euo pipefail

SEED="${1:-5eed0001}"
SATURN="${SATURN:-0}"
SITE="${SITE:-$HOME/portfolio/screenager.dev}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/assets/night.png"
BROWSER="${BROWSER:-brave}"
W=1366 H=768

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/night"
cp "$SITE"/src/lib/night/*.ts "$SITE/src/lib/css-colour.ts" "$work/night/"
rm -f "$work"/night/*.test.ts
sed -i 's#@/lib/night/#./#g; s#@/lib/css-colour#./css-colour#' "$work"/night/*.ts

python3 - "$work/night/generate.ts" "$SATURN" <<'EOF'
import sys
p, saturn = sys.argv[1], sys.argv[2] == "1"
s = open(p).read()
a = """  const radius = Math.min(clamp(H * 0.17, 36, 96), W * 0.13, H * 0.2)
  const planet: Planet = {
    x: clamp(W * lerp(0.6, 0.78, rand()), radius * 2.6, W - radius * 2.6),
    y: H * 0.3,"""
b = """  const radius = 54
  const planet: Planet = {
    x: (rand(), W * 0.468),
    y: H * %s,""" % ("0.19" if saturn else "-10")
if a not in s:
    sys.exit("render_night: the site's planet placement changed; update the patch")
open(p, "w").write(s.replace(a, b))
EOF

cat > "$work/entry.ts" <<'EOF'
import { mountNight } from "./night/render"

const seed = Number.parseInt(new URLSearchParams(location.search).get("seed") ?? "1", 16)
mountNight(document.querySelector("canvas") as HTMLCanvasElement, { seed, setting: "city" })
EOF
bun build "$work/entry.ts" --target browser --outfile "$work/night.js" >/dev/null

vars="$(sed -n '/^:root {/,/^}/p' "$SITE/src/styles/color.css" | grep -- '--night')"
cat > "$work/index.html" <<EOF
<!doctype html><meta charset="utf-8"><style>
:root{$vars}
html,body{margin:0;overflow:hidden}
.frame{position:relative;width:${W}px;height:${H}px;overflow:hidden;
  background:linear-gradient(var(--night-sky) 35%,var(--night-horizon))}
canvas{position:absolute;inset:0 auto auto 0;image-rendering:pixelated}
</style><div class="frame"><canvas></canvas></div><script src="night.js"></script>
EOF

# A brand-new profile can stall on its first headless launch, so keep one around.
profile="${XDG_CACHE_HOME:-$HOME/.cache}/turntable-night-browser"
rm -f "$OUT"
for _ in 1 2; do
  timeout 60 "$BROWSER" --no-first-run --no-default-browser-check --disable-extensions \
    --headless=new --user-data-dir="$profile" \
    --use-angle=swiftshader --enable-unsafe-swiftshader --force-prefers-reduced-motion \
    --hide-scrollbars --window-size="$W,$H" --virtual-time-budget=4000 \
    --allow-file-access-from-files --screenshot="$OUT" "file://$work/index.html?seed=$SEED" \
    >"$work/browser.log" 2>&1 || true
  [ -s "$OUT" ] && break
done
[ -s "$OUT" ] || { echo "render_night: $BROWSER produced no image" >&2; exit 1; }
echo "night $SEED -> $OUT"
