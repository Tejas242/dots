#!/usr/bin/env python3
"""Turn album art into rotating record-label frames.

usage: make_label.py <art path|file:// url|http url|-> <cache dir> <frames> <size> [#rrggbb]
Prints the frame directory. Frames are cached by content hash, so a repeated
track costs nothing. '-' renders the idle label in the given accent colour.
"""
import hashlib, io, math, pathlib, shutil, sys, urllib.parse, urllib.request
from PIL import Image, ImageDraw, ImageFilter, ImageOps

src, cache, frames, size = sys.argv[1], pathlib.Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
accent = sys.argv[5] if len(sys.argv) > 5 else "#7ad08a"
clean = len(sys.argv) > 6 and sys.argv[6] == "clean"  # tiny bar disc: no vignette, light gloss, small spindle
SS = 2  # supersampling; 2x keeps edges clean and halves render time


def load_art():
    if src == "-":
        return None
    if src.startswith(("http://", "https://")):
        with urllib.request.urlopen(src, timeout=8) as r:
            return r.read()
    path = urllib.parse.unquote(urllib.parse.urlparse(src).path) if src.startswith("file://") else src
    return pathlib.Path(path).read_bytes()


data = load_art()
key = hashlib.sha1((data or accent.encode()) + f"{frames}:{size}:{clean}:v3".encode()).hexdigest()[:16]
out = cache / key
if (out / f"f{frames - 1:02d}.png").exists():
    print(out)
    sys.exit(0)

n = size * SS
if data:
    art = ImageOps.fit(Image.open(io.BytesIO(data)).convert("RGB"), (n, n), Image.LANCZOS)
else:  # idle label: accent disc with fine printed rings
    art = Image.new("RGB", (n, n), accent)
    d = ImageDraw.Draw(art)
    for rr, w in ((0.47, 2), (0.40, 1), (0.22, 1)):
        d.ellipse([n / 2 - n * rr, n / 2 - n * rr, n / 2 + n * rr, n / 2 + n * rr], outline=(0, 0, 0), width=w * SS)

mask = Image.new("L", (n, n), 0)
ImageDraw.Draw(mask).ellipse([0, 0, n - 1, n - 1], fill=255)

# stationary lighting: soft gloss from the upper left + darkened rim, applied after rotation
gloss = Image.new("L", (n, n), 0)
ImageDraw.Draw(gloss).ellipse([-n * 0.35, -n * 0.45, n * 0.75, n * 0.55], fill=60)
gloss = gloss.filter(ImageFilter.GaussianBlur(n * 0.12))
vign = Image.new("L", (n, n), 0)
ImageDraw.Draw(vign).ellipse([n * 0.05, n * 0.05, n * 0.95, n * 0.95], fill=255)
vign = Image.eval(vign.filter(ImageFilter.GaussianBlur(n * 0.06)), lambda v: 255 - v)

tmp = cache / (key + ".tmp")
shutil.rmtree(tmp, ignore_errors=True)
tmp.mkdir(parents=True)
white = Image.new("RGB", (n, n), (255, 255, 255))
black = Image.new("RGB", (n, n), (0, 0, 0))
for i in range(frames):
    f = art.rotate(-360.0 * i / frames, Image.BICUBIC)
    if not clean:
        f = Image.composite(black, f, vign.point(lambda v: int(v * 0.55)))
    f = Image.composite(white, f, gloss.point(lambda v: v // 3) if clean else gloss)
    d = ImageDraw.Draw(f)
    c = n / 2
    collar, pin = (n * 0.07, n * 0.03) if clean else (7 * SS, 3.2 * SS)
    d.ellipse([c - collar, c - collar, c + collar, c + collar], fill=(24, 26, 25))      # spindle collar
    d.ellipse([c - pin, c - pin, c + pin, c + pin], fill=(170, 176, 173))                # spindle
    f = f.convert("RGBA")
    f.putalpha(mask)
    f.resize((size, size), Image.LANCZOS).save(tmp / f"f{i:02d}.png", optimize=False, compress_level=1)
shutil.rmtree(out, ignore_errors=True)
tmp.rename(out)

# keep the cache small: newest 6 label sets
sets = sorted((p for p in cache.iterdir() if p.is_dir() and not p.name.endswith(".tmp")),
              key=lambda p: p.stat().st_mtime, reverse=True)
for old in sets[6:]:
    shutil.rmtree(old, ignore_errors=True)
print(out)
