-- Theme surface through display-bound handles, rendered for pixel
-- assertions (tests/check-bind.sh): Lua-set defaults must override the arc
-- C theme on the display they were set on, and only there.
local lvgl = require("lvgl")

-- default (SDL) display: themed via its bound handle; the harness snapshots
-- it to the BMP given on its command line
local d = lvgl.bind()
d:set_theme {
  object = { bg_color = "#0000ff", bg_opa = 255, border_width = 0, radius = 0 },
  label = { text_color = "#ff0000" },
}
d.Object(nil, { x = 150, y = 80, w = 60, h = 40 })
d.Label { text = "THEME", x = 10, y = 10 }

-- second display: its own screen bg and label color; snapshotted explicitly
local right = harness_bind_display(240, 135)
right:set_theme {
  screen = { bg_color = "#204060" },
  label = { text_color = "#00ff00" },
}
right.Label { text = "RIGHT", x = 10, y = 10 }
harness_snapshot(right.screen(), "/tmp/bind-right.bmp")

-- the arc default label color must still hold where no Lua theme was set:
-- a label on the right display created BEFORE its theme existed would be
-- off-white; simplest cross-check is that d's theme did not leak to right
-- (asserted by pixel: right label is green, not red)
