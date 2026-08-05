local lvgl = require("lvgl")
local f15 = lvgl.Font("montserrat", 15)   -- crashes pre-fix, errors pre-nearest
local f9  = lvgl.Font("montserrat", 9)
local f99 = lvgl.Font("montserrat", 99)   -- snaps to 48
assert(f15 ~= nil and f9 ~= nil and f99 ~= nil)
lvgl.Object(nil, { w = lvgl.HOR_RES(), h = lvgl.VER_RES(), bg_color = "#000000" })
  :Label{ text = "15", text_font = f15, align = lvgl.ALIGN.CENTER }
print("font_nearest: OK")
