#!/usr/bin/env python3
"""Render the static turntable assets: record body and tonearm swing frames.

Geometry is shared with turntable.luau (logical px):
  canvas 440x360, record centre (180,180), record r=150, label d=124,
  arm strip x 220..440, pivot (392,62), needle swings 0deg (rest) -> ARM_PLAY_DEG.
"""
import math, pathlib, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).parent.parent / "assets")
OUT.mkdir(parents=True, exist_ok=True)

CX = CY = 180
R_REC, R_PLATTER = 150, 160
ARM_X0, ARM_W, ARM_H = 220, 220, 360
PIVOT = (392, 62)
NEEDLE_PLAY = (CX + 112 * math.cos(math.radians(28)), CY + 112 * math.sin(math.radians(28)))
ARM_LEN = math.dist(PIVOT, NEEDLE_PLAY)
ARM_PLAY_DEG = math.degrees(math.atan2(PIVOT[0] - NEEDLE_PLAY[0], NEEDLE_PLAY[1] - PIVOT[1]))
ARM_FRAMES = 10


def body(scale=2):
    s = scale
    n = 360 * s
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    dx, dy = (x + 0.5) / s - CX, (y + 0.5) / s - CY
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    img = np.zeros((n, n, 4), np.float32)

    # soft cast shadow (drawn separately, blurred)
    sh = Image.new("L", (n, n), 0)
    ImageDraw.Draw(sh).ellipse([(CX + 2 - R_PLATTER + 2) * s, (CY + 6 - R_PLATTER + 2) * s,
                                (CX + 2 + R_PLATTER - 2) * s, (CY + 6 + R_PLATTER - 2) * s], fill=170)
    sh = np.asarray(sh.filter(ImageFilter.GaussianBlur(6 * s)), np.float32) / 255
    sh *= np.clip((176 - np.hypot(dx - 2, dy - 6)) / 8, 0, 1)  # fade out before the image edge
    img[..., 3] = sh

    def over(mask, rgb, alpha=1.0):
        a = np.clip(mask, 0, 1)[..., None] * alpha
        img[..., :3] = img[..., :3] * (1 - a) + np.asarray(rgb, np.float32) * a
        img[..., 3:] = img[..., 3:] * (1 - a) + a

    aa = lambda edge: np.clip(edge * s + 0.5, 0, 1)  # 1px antialiased disc edge

    # platter: brushed dark metal with a lit rim
    platter = aa(R_PLATTER - r)
    lum = 0.075 + 0.02 * np.cos(th - math.radians(-130))
    over(platter, np.stack([lum, lum * 1.04, lum], -1))
    rim = aa(R_PLATTER - r) * aa(r - (R_PLATTER - 2.2))
    over(rim, (0.32, 0.34, 0.33), 0.55)

    # vinyl: near-black with micro-grooves, track gaps, and a stationary anisotropic sheen
    vinyl = aa(R_REC - r)
    rng = np.random.default_rng(3)
    groove_noise = np.interp(r, np.linspace(0, R_REC, 4000), rng.normal(0, 1, 4000)).astype(np.float32)
    grooves = 0.010 * groove_noise + 0.006 * np.sin(r * s * 2.1)
    gaps = sum(np.exp(-((r - g) ** 2) / 0.5) for g in (131, 113, 96, 81))
    sheen = (np.abs(np.cos(th - math.radians(-38))) ** 18) * 0.16 + (np.abs(np.cos(th - math.radians(-38))) ** 4) * 0.035
    sheen *= np.clip((r - 64) / 20, 0, 1) * np.clip((R_REC - 2 - r) / 6, 0, 1)
    base = 0.040 + grooves + 0.045 * gaps + sheen
    over(vinyl, np.stack([base, base * 1.02, base * 1.06], -1))
    lip = aa(R_REC - r) * aa(r - (R_REC - 2.5))
    over(lip, (0.16, 0.17, 0.17), 0.8)
    # smooth run-out area around the label
    runout = aa(66 - r) * aa(r - 61.5)
    over(runout, (0.055, 0.057, 0.06))

    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA")
    out.save(OUT / "body.png", optimize=True)


def arm_frame(t, ss=4):
    """t in [0,1]: 0 = rest, 1 = playing."""
    deg = ARM_PLAY_DEG * t
    W, H = ARM_W * ss, ARM_H * ss
    px, py = (PIVOT[0] - ARM_X0) * ss, PIVOT[1] * ss
    a = math.radians(deg)
    ux, uy = -math.sin(a), math.cos(a)  # unit vector pivot -> needle
    L = ARM_LEN * ss

    def P(d, off=0.0):  # point along the arm at distance d, offset perpendicular
        return (px + ux * d - uy * off, py + uy * d + ux * off)

    def draw_arm(dr, shadow=False):
        dark = (0, 0, 0, 255) if shadow else None
        c = lambda rgb: dark or rgb
        # counterweight behind the pivot
        q = [P(-22 * ss, -9 * ss), P(-22 * ss, 9 * ss), P(-46 * ss, 9 * ss), P(-46 * ss, -9 * ss)]
        dr.polygon(q, fill=c((38, 41, 40, 255)))
        q2 = [P(-24 * ss, -9 * ss), P(-24 * ss, -3 * ss), P(-44 * ss, -3 * ss), P(-44 * ss, -9 * ss)]
        if not shadow:
            dr.polygon(q2, fill=(70, 74, 72, 255))
        # tube
        dr.line([P(-22 * ss), P(L - 30 * ss)], fill=c((186, 191, 188, 255)), width=int(6 * ss))
        if not shadow:
            dr.line([P(-20 * ss, -1.2 * ss), P(L - 32 * ss, -1.2 * ss)], fill=(235, 238, 236, 255), width=int(1.6 * ss))
        # headshell + cartridge
        if not shadow:
            cart = [P(L - 12 * ss, -5.5 * ss), P(L - 12 * ss, 5.5 * ss), P(L + 9 * ss, 5.5 * ss), P(L + 9 * ss, -5.5 * ss)]
            dr.polygon(cart, fill=(20, 22, 21, 255))
        hs = [P(L - 32 * ss, -6.5 * ss), P(L - 32 * ss, 6.5 * ss), P(L + 2 * ss, 7.5 * ss), P(L + 2 * ss, -7.5 * ss)]
        dr.polygon(hs, fill=c((206, 211, 208, 255)))
        if not shadow:
            dr.line([P(L - 30 * ss, -5 * ss), P(L, -5.8 * ss)], fill=(244, 246, 245, 255), width=int(1.4 * ss))
            dr.line([P(L - 24 * ss, 7 * ss), P(L - 20 * ss, 15 * ss)], fill=(206, 211, 208, 255), width=int(2.4 * ss))
        # pivot housing
        for rad, col in ((26, (24, 27, 26, 255)), (20, (52, 56, 54, 255)), (13, (150, 156, 153, 255)), (5, (24, 27, 26, 255))):
            if shadow and rad < 26:
                break
            dr.ellipse([px - rad * ss, py - rad * ss, px + rad * ss, py + rad * ss], fill=c(col))

    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_arm(ImageDraw.Draw(sh), shadow=True)
    sh = sh.filter(ImageFilter.GaussianBlur(5 * ss))
    sh_a = np.asarray(sh, np.float32)
    sh_a[..., 3] *= 0.55
    shadow = Image.fromarray(sh_a.astype(np.uint8), "RGBA")
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(shadow, (int(5 * ss), int(9 * ss)))
    fg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_arm(ImageDraw.Draw(fg))
    canvas.alpha_composite(fg)
    return canvas.resize((ARM_W, ARM_H), Image.LANCZOS)


if __name__ == "__main__":
    body()
    for i in range(ARM_FRAMES):
        arm_frame(i / (ARM_FRAMES - 1)).save(OUT / f"arm{i:02d}.png", optimize=True)
    print(f"ok arm_play_deg={ARM_PLAY_DEG:.2f}")
