#!/usr/bin/env python3
"""Pre-render morphing digits for the Nocturne clock.

usage: make_digits.py <font.ttf> <size px> <#rrggbb> <cache dir> <frames> <max pixel>

Writes <cache dir>/<key>/ with
  d0.png … d9.png        each digit at rest
  <a><b>/f00.png …       the morph from a to b, for every ordered pair a != b
  meta.json              {"w", "h", "top", "frames"}: image size, and how far the
                         image top sits above the cap line
and prints that directory. Sets are keyed by font, size and colour, so a palette
change renders a fresh set and prunes the stale one for the same font and size.

The morph interpolates the glyph outlines themselves: each contour is resampled
to the same number of points, start-aligned to its partner, and holes that only
one digit has grow from (or shrink to) a point. Halfway through, the shape
breaks into dithered pixels, the way screenager.dev's night is drawn, and
resolves back to a crisp glyph at the end.
"""
import hashlib, itertools, json, math, pathlib, shutil, sys

import numpy as np
from fontTools.pens.basePen import BasePen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw

font_path, size, color = sys.argv[1], float(sys.argv[2]), sys.argv[3]
cache, FRAMES, MAX_PIXEL = pathlib.Path(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
VERSION = "v1"
SS = 3  # supersampling
N = 160  # points per contour
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16

stem = pathlib.Path(font_path).stem
key = f"{stem}-{int(size)}-{color.lstrip('#').lower()}-{FRAMES}-{MAX_PIXEL}-{VERSION}"
out = cache / key
if (out / "meta.json").exists():
    print(out)
    sys.exit(0)

font = TTFont(font_path)
upm = font["head"].unitsPerEm
scale = size / upm
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
cap = font["OS/2"].sCapHeight * scale
adv = {d: font["hmtx"][cmap[ord(str(d))]][0] * scale for d in range(10)}

PAD = 2
MARGIN = math.ceil(0.04 * size) + 1  # room for round overshoot above cap / below baseline
W = math.ceil(max(adv.values())) + 2 * PAD
H = MARGIN + math.ceil(cap) + MARGIN
BASE_Y = MARGIN + cap


class Flatten(BasePen):
    def __init__(self, glyph_set):
        super().__init__(glyph_set)
        self.contours, self.cur = [], None

    def _moveTo(self, p):
        self.cur = [p]

    def _lineTo(self, p):
        self.cur.append(p)

    def _qCurveToOne(self, p1, p2):
        p0 = self.cur[-1]
        for i in range(1, 9):
            t = i / 8
            self.cur.append(tuple((1 - t) ** 2 * a + 2 * (1 - t) * t * b + t * t * c for a, b, c in zip(p0, p1, p2)))

    def _curveToOne(self, p1, p2, p3):
        p0 = self.cur[-1]
        for i in range(1, 13):
            t = i / 12
            u = 1 - t
            self.cur.append(tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d
                                  for a, b, c, d in zip(p0, p1, p2, p3)))

    def _closePath(self):
        if self.cur and len(self.cur) > 2:
            self.contours.append(self.cur)
        self.cur = None

    _endPath = _closePath


def signed_area(c):
    x, y = c[:, 0], c[:, 1]
    return 0.5 * float(np.dot(x, np.roll(y, -1)) - np.dot(np.roll(x, -1), y))


def resample(c):
    closed = np.vstack([c, c[:1]])
    seg = np.hypot(*np.diff(closed, axis=0).T)
    s = np.concatenate([[0], np.cumsum(seg)])
    t = np.linspace(0, s[-1], N, endpoint=False)
    return np.column_stack([np.interp(t, s, closed[:, 0]), np.interp(t, s, closed[:, 1])])


def outline(d):
    """Contours of digit d in image pixels, split into outers and holes."""
    pen = Flatten(glyphs)
    glyphs[cmap[ord(str(d))]].draw(pen)
    ox = (W - adv[d]) / 2
    contours = []
    for c in pen.contours:
        a = np.array(c, dtype=float)
        a = np.column_stack([ox + a[:, 0] * scale, BASE_Y - a[:, 1] * scale])
        contours.append(a)
    main = max(contours, key=lambda c: abs(signed_area(c)))
    sign = math.copysign(1, signed_area(main))
    outers, holes = [], []
    for c in contours:
        (outers if math.copysign(1, signed_area(c)) == sign else holes).append(c)
    # one winding for all, so partners interpolate without flipping
    norm = lambda c: resample(c if signed_area(c) > 0 else c[::-1])
    return [norm(c) for c in outers], [norm(c) for c in holes]


def align(p, q):
    """Rotate q's start so it lies closest to p, point for point."""
    best = min(range(0, N, 2), key=lambda k: float(np.sum((p - np.roll(q, -k, axis=0)) ** 2)))
    best = min((best - 1, best, best + 1), key=lambda k: float(np.sum((p - np.roll(q, -k, axis=0)) ** 2)))
    return np.roll(q, -best, axis=0)


def pair(a, b):
    """Match contour lists a -> b; a contour without a partner grows from or shrinks to a point."""
    centroid = lambda c: c.mean(axis=0)
    if len(a) < len(b):
        swapped = [(q, p) for p, q in pair(b, a)]
        return swapped
    best = None
    for perm in itertools.permutations(range(len(a)), len(b)):
        cost = sum(float(np.sum((centroid(a[i]) - centroid(b[j])) ** 2)) for j, i in enumerate(perm))
        if best is None or cost < best[0]:
            best = (cost, perm)
    used = set(best[1]) if best else set()
    out = [(a[i], align(a[i], b[j])) for j, i in enumerate(best[1])] if best else []
    for i in range(len(a)):
        if i not in used:
            out.append((a[i], np.repeat(centroid(a[i])[None], N, axis=0)))
    return out


def render(contours, pixel):
    big = np.zeros((H * SS, W * SS), dtype=bool)
    for c in contours:
        if abs(signed_area(c)) < 0.25:
            continue
        m = Image.new("1", (W * SS, H * SS), 0)
        ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in c], fill=1)
        big ^= np.asarray(m, dtype=bool)
    alpha = big.reshape(H, SS, W, SS).mean(axis=(1, 3))
    if pixel > 1:  # dither into art pixels, like the site's night
        ph, pw = -(-H // pixel), -(-W // pixel)
        padded = np.zeros((ph * pixel, pw * pixel))
        padded[:H, :W] = alpha
        cells = padded.reshape(ph, pixel, pw, pixel).mean(axis=(1, 3))
        thresh = BAYER[np.arange(ph)[:, None] % 4, np.arange(pw)[None, :] % 4]
        on = (cells > thresh).astype(float)
        alpha = np.kron(on, np.ones((pixel, pixel)))[:H, :W]
    rgb = tuple(int(color.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    img = np.zeros((H, W, 4), dtype=np.uint8)
    img[..., :3] = rgb
    img[..., 3] = np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


tmp = cache / (key + ".partial")
shutil.rmtree(tmp, ignore_errors=True)
tmp.mkdir(parents=True)
shapes = {d: outline(d) for d in range(10)}
for d in range(10):
    outers, holes = shapes[d]
    render(outers + holes, 1).save(tmp / f"d{d}.png", optimize=True)
for a, b in itertools.permutations(range(10), 2):
    matched = pair(shapes[a][0], shapes[b][0]) + pair(shapes[a][1], shapes[b][1])
    folder = tmp / f"{a}{b}"
    folder.mkdir()
    for i in range(FRAMES):
        t = i / (FRAMES - 1)
        e = t * t * (3 - 2 * t)
        pixel = max(1, round(1 + (MAX_PIXEL - 1) * math.sin(math.pi * t) ** 1.5))
        render([p * (1 - e) + q * e for p, q in matched], pixel).save(folder / f"f{i:02d}.png", optimize=True)
(tmp / "meta.json").write_text(json.dumps({"w": W, "h": H, "top": MARGIN, "frames": FRAMES}))

prefix = f"{stem}-{int(size)}-"
for old in cache.glob(prefix + "*"):
    if old.is_dir() and old.name != key and not old.name.endswith(".partial"):
        shutil.rmtree(old, ignore_errors=True)
tmp.rename(out)
print(out)
