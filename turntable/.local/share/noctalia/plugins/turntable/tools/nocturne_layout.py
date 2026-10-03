#!/usr/bin/env python3
"""Nocturne — a dark editorial lockscreen for Noctalia (1366x768, eDP-1).

Left column: weekday, time, date, greeting and password on one margin.
Right: the Turntable plugin (spinning album-art vinyl + tonearm), haloed by the
ring visualizer, over a sparse star field.
Usage: nocturne.py <settings.toml>   (rewrites [lockscreen] + [lockscreen_widgets])
"""
import math, pathlib, random, re, sys

OUT, W, H = "eDP-1", 1366, 768
RSCALE = 0.88  # Noctalia multiplies background_radius by ui_scale
SERIF, SERIF_I = "Nocturne Serif", "Nocturne Serif Italic"
THIN, MONO = "Nocturne Sans Thin", "Nocturne Mono"
widgets = []


def add(type_, cx, cy, w, h, rot=0.0, wid=None, **s):
    widgets.append((wid, type_, cx, cy, w, h, rot, s))


def shape(cx, cy, w, h, color, opacity=1.0, radius=None, rot=0.0):
    """Blank label whose background tile is the shape."""
    r = min(w, h) / 2 / RSCALE + 1 if radius is None else radius
    add("label", cx, cy, w, h, rot, title=" ", shadow=False, opacity=0.0, background=True,
        background_color=color, background_opacity=opacity,
        background_radius=int(math.ceil(r)), background_padding=0)


def disc(cx, cy, d, color, opacity=1.0):
    shape(cx, cy, d, d, color, opacity)


def text(type_, x, cy, w, h, color, font, start=True, **kw):
    """Text block; x is the left edge when start=True, else the centre."""
    add(type_, x + w / 2 if start else x, cy, w, h, color=color, font_family=font, shadow=False,
        background=False, **kw)


def clock(x, cy, w, h, fmt, color, font, **kw):
    text("clock", x, cy, w, h, color, font, clock_style="digital", format=fmt, center_text=False, **kw)


def twinkle(cx, cy, size, color="on_surface", opacity=0.85):
    shape(cx, cy, size, 1.5, color, opacity, 1)
    shape(cx, cy, 1.5, size, color, opacity, 1)
    disc(cx, cy, 4, color, opacity)


# ═════════════ night sky ═════════════
random.seed(7)
for sx, sy in [(470, 92), (556, 168), (612, 64), (700, 128), (742, 236), (520, 300), (640, 352),
               (588, 470), (720, 520), (812, 90), (900, 150), (1240, 96), (1300, 220), (1268, 560),
               (380, 120), (300, 520), (450, 640), (1120, 690), (1320, 420), (660, 660), (80, 120)]:
    disc(sx, sy, random.choice((2, 2, 3, 3, 4)), "on_surface", round(random.uniform(0.25, 0.7), 2))
twinkle(664, 196, 18)
twinkle(560, 560, 12, "primary", 0.9)
twinkle(1300, 300, 14, "tertiary", 0.9)

# ═════════════ RIGHT · turntable ═════════════
RX, RY = 984, 372                                         # record centre on screen
add("fancy_audio_visualizer", RX, RY, 540, 540, visualization_mode="rings", sensitivity=1.4,
    rotation_speed=0.25, ring_opacity=0.65, inner_diameter=0.66, bloom_intensity=0.7,
    fade_when_idle=True, primary_color="primary", secondary_color="tertiary", background=False)
# plugin canvas is 440x428 with the record centred at (180,180)
add("screenager/turntable:record", RX - 180 + 220, RY - 180 + 214, 440, 428,
    show_info=True, accent="primary", background=False)

# ═════════════ LEFT · time column ═════════════
# One compact block, vertically centred on the record (RY): status line, time,
# date, then the password pill with a quiet caption. One sans family throughout.
import os
TIME_FONT = os.environ.get("TIME_FONT", "Nocturne Sans ExtraLight")
X = 120
# animated time column (Turntable plugin): weekday, rolling digits, seconds hairline,
# date and a typed greeting; natural size 460x312, left edge at X
# typographic tower (Turntable plugin): stacked hairline/black time, seconds-meter
# divider, rail with am/pm, calendar block and battery cell, typed greeting.
# Natural size 313x419; centred vertically on the record together with the login.
CW, CH = 313, 419
CTOP = RY - (CH + 14 + 52) // 2
add("screenager/turntable:clock", X + CW / 2, CTOP + CH / 2, CW, CH, greeting="welcome back, screenager",
    accent="primary", background=False)
add("login_box", X + 128, CTOP + CH + 14 + 26, 288, 52, wid=f"lockscreen-login-box@{OUT}", layout="compact",
    show_login_button=False, show_unlock_hint=False, show_caps_lock=True, show_keyboard_layout=True,
    show_session_buttons=False, show_media=False, show_weather=False, input_opacity=0.35,
    input_radius=26, center_password_text=False, background_color="surface_variant",
    background_opacity=0.0, background_radius=26)

for i, c in enumerate(("primary", "secondary", "tertiary")):  # footer signature
    disc(X + 4 + i * 14, 716, 7, c)
clock(X + 52, 716, 120, 14, "WEEK {:%V}", "on_surface_variant", MONO)


# ── emit ──
def val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(round(v, 4))
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


ids, blocks, n = [], [], 0
for wid, type_, cx, cy, w, h, rot, s in widgets:
    if wid is None:
        n += 1
        wid = f"lockscreen-widget-{n:016x}"
    ids.append(wid)
    key = f'"{wid}"' if "@" in wid else wid
    b = [f"    [lockscreen_widgets.widget.{key}]", f"    box_height = {float(h)}",
         f"    box_width = {float(w)}", f"    cx = {round(float(cx), 2)}", f"    cy = {round(float(cy), 2)}",
         f'    output = "{OUT}"', f"    placement_height = {float(H)}",
         f"    placement_width = {float(W)}", f"    rotation = {round(rot, 4)}", f'    type = "{type_}"', "",
         f"        [lockscreen_widgets.widget.{key}.settings]"]
    b += [f"        {k} = {val(v)}" for k, v in sorted(s.items())]
    blocks.append("\n".join(b))

lock = ("[lockscreen]\nblur_intensity = 0.85\ntint_intensity = 0.82\n"
        "transition = [ \"disc\" ]\ntransition_duration = 950.0\nedge_smoothness = 0.45\n\n")
section = ["[lockscreen_widgets]", "enabled = true", "schema_version = 2", "widget_order = ["]
section.append(",\n".join(f'    "{i}"' for i in ids))
section += ["]", "", "    [lockscreen_widgets.grid]", "    cell_size = 8", "    major_interval = 4",
            "    visible = true", ""]
text_out = "\n".join(section) + "\n" + "\n\n".join(blocks) + "\n\n"

path = pathlib.Path(sys.argv[1])
src = path.read_text()
src = re.sub(r"^\[lockscreen\]\n.*?(?=^\[)", "", src, flags=re.S | re.M)
new = re.sub(r"^\[lockscreen_widgets\]\n.*?(?=^\[(?!lockscreen_widgets)[a-z])",
             lambda _: lock + text_out, src, count=1, flags=re.S | re.M)
assert new != src
# the Turntable plugin must be enabled for its widget type to resolve
m = re.search(r"^\[plugins\]\nenabled = \[(.*?)\]", new, flags=re.S | re.M)
if m and "screenager/turntable" not in m.group(1):
    new = new[:m.end(1)] + ', "screenager/turntable" ' + new[m.end(1):]
elif not m:
    new += '\n[plugins]\nenabled = [ "screenager/turntable" ]\n'
path.write_text(new)
print(f"{len(ids)} widgets")
