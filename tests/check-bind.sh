#!/bin/bash
# Pixel assertions for tests/bind-theme.lua — run from the build dir.
# Proves the Lua theme surface (set_theme) lands on the display it was set
# on: default display gets red labels + blue objects, the second display
# gets its own screen bg + green label, and neither leaks into the other.
set -e
./simulator/harness ../tests/bind-theme.lua 300 /tmp/bind-left.bmp >/dev/null 2>&1
python3 - <<'PY'
import struct

def load(path):
    d = open(path, 'rb').read()
    off = struct.unpack('<I', d[10:14])[0]
    w = struct.unpack('<i', d[18:22])[0]
    def px(x, y):
        i = off + (y * w + x) * 4
        return d[i+2], d[i+1], d[i]          # r, g, b
    return px

# --- default display (themed via lvgl.bind() handle) ---
px = load('/tmp/bind-left.bmp')
# the themed Object is a filled blue box at 150,80 60x40
r, g, b = px(180, 100)
assert b > 180 and r < 60 and g < 60, f"object default bg not blue: {(r,g,b)}"
# the label text is red somewhere in its region (theme text_color override)
found = any(px(x, y)[0] > 150 and px(x, y)[1] < 90 and px(x, y)[2] < 90
            for y in range(8, 40) for x in range(8, 120))
assert found, "no red label pixels — label theme did not apply"
# and NOT green anywhere in that region (right display's theme must not leak)
leak = any(px(x, y)[1] > 150 and px(x, y)[0] < 90
           for y in range(8, 40) for x in range(8, 120))
assert not leak, "green pixels on default display — theme leaked across displays"

# --- second display (headless, snapshotted by the script) ---
px = load('/tmp/bind-right.bmp')
# screen bg is #204060 (screen key applied to the active screen)
r, g, b = px(200, 100)
assert abs(r-0x20) < 24 and abs(g-0x40) < 24 and abs(b-0x60) < 24, \
    f"right screen bg: {(r,g,b)}"
# label is green, not red — per-display label defaults
found = any(px(x, y)[1] > 150 and px(x, y)[0] < 90
            for y in range(8, 40) for x in range(8, 120))
assert found, "no green label pixels on the second display"
leak = any(px(x, y)[0] > 150 and px(x, y)[1] < 90 and px(x, y)[2] < 90
           for y in range(8, 40) for x in range(8, 120))
assert not leak, "red pixels on second display — theme leaked across displays"
print("check-bind: OK")
PY
