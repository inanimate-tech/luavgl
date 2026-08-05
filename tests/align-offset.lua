-- Renders a red 20x20 marker at TOP_MID with y=40, offsets applied in the
-- adversarial order (y first, then align). check-align.sh asserts the pixel:
-- pre-fix, integer `align` called lv_obj_align(...,0,0) and zeroed the
-- offset, leaving the marker at y=0. (Coordinate getters are unreliable
-- before layout resolution, so the assertion is pixel-based.)
local lvgl = require("lvgl")
local root = lvgl.Object(nil, { w = lvgl.HOR_RES(), h = lvgl.VER_RES(),
                                bg_color = "#000000", border_width = 0, pad_all = 0 })
root:clear_flag(lvgl.FLAG.SCROLLABLE)
local m = root:Object{ w = 20, h = 20, bg_color = "#ff0000", border_width = 0, radius = 0, pad_all = 0 }
m:set{ y = 40 }
m:set{ align = lvgl.ALIGN.TOP_MID }
print("align-offset: rendered")
