#!/bin/bash
# Pixel assertions for tests/theme.lua — run from the build dir.
set -e
./simulator/harness ../tests/theme.lua 300 /tmp/theme.bmp >/dev/null 2>&1
python3 - <<'PY'
import struct
d = open('/tmp/theme.bmp','rb').read()
off = struct.unpack('<I', d[10:14])[0]
w = struct.unpack('<i', d[18:22])[0]
def px(x, y):
    i = off + (y * w + x) * 4
    return d[i+2], d[i+1], d[i]          # r, g, b
# screen background is #0b0b10 (outside the box)
r, g, b = px(5, 5)
assert abs(r-0x0b) < 20 and abs(g-0x0b) < 20 and abs(b-0x10) < 20, f"screen bg: {(r,g,b)}"
# the unstyled Object is INVISIBLE: a pixel inside it, away from the
# label, matches the screen bg (no white card, no border)
r, g, b = px(210, 110)
assert r < 40 and g < 40 and b < 45, f"object not flat/transparent: {(r,g,b)}"
# the label text is bright off-white somewhere in its region
found = any(px(x, y)[0] > 200 and px(x, y)[2] > 200
            for y in range(24, 50) for x in range(24, 120))
assert found, "no bright label pixels — default text color/font wrong"
# glyph height: bright rows should span >= 12 px (montserrat 20 caps,
# not the 14 default) — collect rows containing bright pixels
rows = [y for y in range(20, 60) if any(px(x, y)[0] > 200 for x in range(24, 120))]
assert rows and (max(rows) - min(rows)) >= 12, f"glyph rows {rows} — font too small"
print("check-theme: OK")
PY
