#!/usr/bin/env python3
"""Nocturne — a lockscreen for Noctalia in screenager.dev's clothes (1366x768, eDP-1).

Background: the site's pixel-art night (tools/render_night.sh -> assets/night.png),
shown crisp as the lock screen's own wallpaper.
Corners: the site's chrome; a typed "~ locked" path top-left, the battery top-right.
Left column: time tower, then a greeting and the password field dressed as a key,
all on one margin. Right: the Turntable record, haloed by the ring visualizer.
Usage: nocturne_layout.py <settings.toml>   (rewrites [lockscreen] + [lockscreen_widgets])

The key is drawn around Noctalia's own login box, so it leans on the compact
layout's geometry (input inset 16 px, 38 px tall, 240x70 minimum panel). After a
Noctalia update, open the lockscreen editor or lock once and check the key still
meets the field; if not, update PILL_* here and in login.luau.
"""
import pathlib, re, sys

OUT, W, H = "eDP-1", 1366, 768
NIGHT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "night.png"
widgets = []


def add(type_, cx, cy, w, h, rot=0.0, wid=None, **s):
    widgets.append((wid, type_, cx, cy, w, h, rot, s))


# ═════════════ RIGHT · turntable ═════════════
RX, RY = 984, 372                                         # record centre on screen
add("fancy_audio_visualizer", RX, RY, 540, 540, visualization_mode="rings", sensitivity=1.4,
    rotation_speed=0.25, ring_opacity=0.65, inner_diameter=0.66, bloom_intensity=0.7,
    fade_when_idle=True, primary_color="primary", secondary_color="tertiary", background=False)
# plugin canvas is 440x428 with the record centred at (180,180)
add("screenager/turntable:record", RX - 180 + 220, RY - 180 + 214, 440, 428,
    show_info=True, accent="primary", background=False)

# ═════════════ LEFT · time column ═════════════
# Two plugin widgets on one left margin X, and the stock login box laid exactly
# over the key widget's blade. Sizes are the widgets' natural sizes, so the host
# never rescales them (keep in sync with clock.luau / login.luau).
X = 120
CAP_TOP = RY - 159                # hours cap line on screen: level with the record's top edge

# time tower: 377x336, hours caps 76 px below its top; black digits ink ~5 px in
CW, CH, C_CAP, C_INK = 377, 336, 76, 5
ROW, CAP = 117.6 + 14, 117.6
ctop = CAP_TOP - C_CAP
add("screenager/turntable:clock", X - C_INK + CW / 2, ctop + CH / 2, CW, CH, accent="primary", background=False)
BASELINE = CAP_TOP + ROW + CAP    # minutes baseline on screen

# key: greeting + bow/neck/bits around the field; 372x133, greeting caps 11 px below
# its top, the field centred 100 px below its top and starting 58 px in. The gap
# between greeting and field is where Noctalia puts its status line (wrong
# password, caps lock): 8 px + a 38 px strip above the 70 px login box.
KW, KH, K_GREET, K_CY, PILL_X, PILL_W = 372, 133, 11, 100, 58, 314
ktop = BASELINE + 26 - K_GREET
add("screenager/turntable:login", X + KW / 2, ktop + KH / 2, KW, KH, greeting="auto", name="screenager",
    background=False)
# compact login box: input inset 16 px all round, 38 px tall; 4 px corners like the bow
add("login_box", X + PILL_X - 16 + (PILL_W + 32) / 2, ktop + K_CY, PILL_W + 32, 70,
    wid=f"lockscreen-login-box@{OUT}", layout="compact", show_session_buttons=False, show_media=False,
    show_weather=False, show_unlock_hint=False, show_login_button=False, show_caps_lock=True,
    show_keyboard_layout=True, input_opacity=0.35, input_radius=4,
    center_password_text=False, background_color="surface_variant", background_opacity=0.0,
    background_radius=4)

# ═════════════ corners · the site's chrome ═════════════
GUTTER, CORNER_Y = 40, 35
PW, PH = 260, 20                  # path: left-anchored
add("screenager/turntable:path", GUTTER + PW / 2, CORNER_Y, PW, PH, background=False)
BW, BH = 220, 20                  # battery: right-anchored
add("screenager/turntable:battery", W - GUTTER - BW / 2, CORNER_Y, BW, BH, accent="primary", background=False)


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

# the night is pixel art: no blur, no tint
lock = ("[lockscreen]\nblur_intensity = 0.0\ntint_intensity = 0.0\n"
        f"wallpaper = {val(str(NIGHT))}\n"
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
