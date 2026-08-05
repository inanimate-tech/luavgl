#!/bin/bash
# Pixel assertion for tests/align-offset.lua — run from the build dir.
set -e
./simulator/harness ../tests/align-offset.lua 300 /tmp/align-offset.bmp >/dev/null 2>&1
python3 - <<'PY'
import struct
d = open('/tmp/align-offset.bmp','rb').read()
off = struct.unpack('<I', d[10:14])[0]
w = struct.unpack('<i', d[18:22])[0]
def px(x, y):
    i = off + (y * w + x) * 4
    b, g, r = d[i], d[i+1], d[i+2]
    return r, g, b
at40 = px(120, 50)   # inside the marker if offset survived
at0  = px(120, 5)    # inside the marker if offset was clobbered
assert at40[0] > 200 and at40[1] < 80, f"marker missing at y=40 zone: {at40}"
assert at0[0] < 80, f"marker wrongly at y=0 zone: {at0}"
print("check-align: OK")
PY
